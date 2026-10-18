extends Node2D
## 主控制器：刷怪、开火、掉落、构筑、HUD。

const TIERS := {
	1: {"rate": 1.0, "uses": 20.0, "name": "基础", "color": Color(0.56, 0.70, 1.0)},
	2: {"rate": 3.0, "uses": 24.0, "name": "加法", "color": Color(0.49, 0.94, 0.66)},
	3: {"rate": 9.0, "uses": 28.0, "name": "脉冲", "color": Color(0.36, 0.88, 0.82)},
	4: {"rate": 27.0, "uses": 34.0, "name": "共振", "color": Color(1.0, 0.56, 0.64)},
}

## 脉冲：自身不产出，每 PULSE_SEC 把「自身基础值」加到相邻的主动模块上（叠加，见 PULSE_STACK_MAX）
const PULSE_SEC := 3.0
const PULSE_STACK_MAX := 9.0

const CRAFT_UNLOCK := {2: 4, 3: 10, 4: 18}

## 武器品质 = 电路板布局（槽位数量 + 连接方式）。
## 相邻 = 网格曼哈顿距离 1，所以直线是链、T/十字/双排会在中间形成枢纽。
const LAYOUTS := {
	1: [Vector2i(0, 0), Vector2i(1, 0)],
	2: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	3: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
	4: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, -1), Vector2i(1, 1)],
	5: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
}
const QUALITY_NAME := {1: "白", 2: "绿", 3: "蓝", 4: "紫", 5: "金"}
## 波次 → 品质：开局蓝（4 槽 T 型），12 波紫（5 槽十字），20 波金（6 槽双排）
const QUALITY_SCHEDULE := {12: 4, 20: 5}
## 武器自带基础伤害：不吃模块次数，模块烧光时留一条底（否则 DPS 直接归零 = 必死）
const QUALITY_BASE := {1: 0.5, 2: 0.8, 3: 1.0, 4: 1.5, 5: 2.0}
const WAVE_SEC := 40.0
const DROP_CHANCE := 0.65
const HP_BASE := 4.0
const HP_GROWTH := 1.115
const SPAWN_BASE := 2.0
const SPAWN_GROWTH := 0.06
const MAX_ENEMIES := 240
const LEVEL_COST_BASE := 3.0
const LEVEL_COST_GROWTH := 1.18
const CONTACT_DPS := 7.0
## 受击补偿：每损失这么多 HP 补 1 个模块（弹药系统的劣势补偿，挨打就回填）
const DAMAGE_PER_MODULE := 8.0
const CROWD_CAP := 6
const FIRE_RANGE := 260.0
const PULSE_DUR := 0.30

var weapon := {"interval": 1.0, "mul": 1.0, "quality": 3, "base": 1.0, "layout": [], "slots": []}
var inventory := {1: 0, 2: 0, 3: 0, 4: 0}
var level := 1
var hp := 100.0
var max_hp := 100.0
var elapsed := 0.0
var wave := 1
var fire_t := 0.0
var spawn_acc := 0.0
var dead := false
var kill_times: Array = []
var kills_total := 0
var damage_credit := 0.0
var modules_from_damage := 0
var rng := RandomNumberGenerator.new()

var player: Node2D
var hud_status: Label
var hud_ammo: Label
var hud_tip: Label
var build_root: Control
var build_text: Label
var board_root: Control
var build_info: Label
var flash: ColorRect
var flash_t := 0.0
var pulse_t := 0.0

# --- 无头自动对战（平衡验证用）：godot --headless -- playtest bot pt=1200 ---
var playtest := false
var bot := false
var pt_limit := 0.0
var pt_t := 0.0
var pt_print := 0.0
var bot_t := 0.0
var bot_ticks := 0

# --- 截图（迭代视觉用）：godot --path . -- shot=abs/path.png shotat=12 shotbuild shotbot ff=60 ---
var shot_path := ""
var shot_at := -1.0
var shot_build := false
var shot_bot := false
var ff := 0.0
## 电路板规则自检：godot --headless --path . -- boardtest
var boardtest := false
var demo_board := false
var bt_set := false
var bt_print := 0.0


func _ready() -> void:
	add_to_group("game")
	# 允许暂停时仍接收输入（Tab 退出构筑界面）
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: Array = []
	args.append_array(OS.get_cmdline_args())
	args.append_array(OS.get_cmdline_user_args())
	for a in args:
		if a == "playtest":
			playtest = true
		elif a == "bot":
			bot = true
		elif a.begins_with("pt="):
			pt_limit = float(a.substr(3))
		elif a.begins_with("shot="):
			shot_path = a.substr(5)
			shot_at = 12.0
		elif a.begins_with("shotat="):
			shot_at = float(a.substr(7))
		elif a == "boardtest":
			boardtest = true
		elif a == "demoboard":
			boardtest = true
			demo_board = true
		elif a == "shotbuild":
			shot_build = true
		elif a == "shotbot":
			shot_bot = true
		elif a.begins_with("ff="):
			ff = float(a.substr(3))
	if playtest:
		# 无头模拟按实时速度跑太慢，放大时间步（步长变粗，数值平衡够用）
		Engine.time_scale = 8.0
		Engine.max_fps = 0
	rng.randomize()
	_set_quality(3)
	for i in weapon.slots.size():
		weapon.slots[i] = _new_module(1)
	inventory[1] = 2
	_make_player()
	_make_hud()
	_refresh_hud()


func _new_module(tier: int) -> Dictionary:
	return {"tier": tier, "left": float(TIERS[tier].uses), "bonus": 0.0, "tick": 0.0}


func _make_player() -> void:
	player = Node2D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.name = "Player"
	player.add_to_group("player")
	add_child(player)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	player.add_child(cam)
	cam.make_current()


func _label(parent: Node, pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _make_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	hud_status = _label(layer, Vector2(18, 14), 20, Color(0.95, 0.96, 1.0))
	hud_ammo = _label(layer, Vector2(18, 44), 20, Color(0.7, 0.95, 0.85))
	hud_tip = _label(layer, Vector2(18, 690), 16, Color(0.6, 0.65, 0.75))
	hud_tip.text = "WASD 移动    TAB 构筑（暂停）    U 升级    C 合成    R 重开"

	build_root = Control.new()
	build_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	build_root.visible = false
	build_root.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(build_root)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	build_root.add_child(bg)

	build_text = Label.new()
	build_text.position = Vector2(80, 60)
	build_text.add_theme_font_size_override("font_size", 19)
	build_text.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	build_root.add_child(build_text)

	board_root = Control.new()
	board_root.position = Vector2(100, 185)
	build_root.add_child(board_root)

	build_info = Label.new()
	build_info.position = Vector2(100, 500)
	build_info.add_theme_font_size_override("font_size", 17)
	build_info.add_theme_color_override("font_color", Color(0.82, 0.88, 0.98))
	build_root.add_child(build_info)

	flash = ColorRect.new()
	flash.color = Color(1, 0.2, 0.25, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	if k == KEY_TAB and not dead:
		_toggle_build()
	elif k == KEY_U:
		if try_level():
			_pass()
	elif k == KEY_C:
		try_craft()
		_pass()
	elif k == KEY_R:
		get_tree().paused = false
		get_tree().reload_current_scene()
	elif k == KEY_ESCAPE and build_root.visible:
		_toggle_build()


func _toggle_build() -> void:
	build_root.visible = not build_root.visible
	get_tree().paused = build_root.visible
	hud_status.visible = not build_root.visible
	hud_ammo.visible = not build_root.visible
	hud_tip.visible = not build_root.visible
	if build_root.visible:
		_refresh_build()


func _pass() -> void:
	if build_root.visible:
		_refresh_build()
	else:
		_refresh_hud()


func _process(delta: float) -> void:
	# 快进：先按 8 倍速把局面推到 ff 秒，再恢复正常速度拍图
	if ff > 0.0:
		if elapsed < ff:
			Engine.time_scale = 8.0
			return
		Engine.time_scale = 1.0
		ff = 0.0
	if shot_path == "" or shot_at < 0.0:
		return
	if elapsed < shot_at:
		return
	shot_at = -1.0
	Engine.time_scale = 1.0
	if shot_build and not build_root.visible:
		_toggle_build()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	print("shot saved: %s" % shot_path)
	get_tree().quit()


func _physics_process(delta: float) -> void:
	if dead or get_tree().paused:
		return
	elapsed += delta
	wave = int(elapsed / WAVE_SEC) + 1
	_ensure_weapon()
	_spawn(delta)
	_pulse_tick(delta)
	_fire(delta)
	_contact(delta)
	_hud_tick(delta)
	if playtest:
		_playtest_step(delta)
	elif shot_bot:
		_bot_step(delta)
	elif boardtest:
		_boardtest(delta)


## 电路板规则自检：固定摆一块已知的板，验证脉冲是否真的把基础值加给邻居
func _boardtest(delta: float) -> void:
	if not bt_set:
		bt_set = true
		weapon.interval = 1.0 if demo_board else 999.0  # 自检时不开火，排除弹药消耗的干扰
		weapon.base = 1.0
		weapon.slots[0] = _new_module(2)  # 加法
		weapon.slots[1] = _new_module(3)  # 脉冲（与加法相邻）
		weapon.slots[2] = _new_module(1)  # 基础（与脉冲相邻）
		weapon.slots[3] = _new_module(1)  # 基础（只与加法相邻）
		print("BOARD set  out=", _slot_out(), " power=", _shot_power())
	bt_print += delta
	if bt_print >= 0.5:
		bt_print = 0.0
		var out := _slot_out()
		print("t=%4.1f  out=%s  power=%5.1f  bonus=[%.1f, %.1f, %.1f, %.1f]" % [
			elapsed, str(out), _shot_power(),
			float(weapon.slots[0].bonus), float(weapon.slots[1].bonus),
			float(weapon.slots[2].bonus), float(weapon.slots[3].bonus),
		])
	if elapsed > 10.0 and shot_path == "":
		get_tree().quit()


func _playtest_step(delta: float) -> void:
	pt_t += delta
	if bot:
		_bot_step(delta)
	if pt_t - pt_print >= 5.0:
		pt_print = pt_t
		_pt_log()
	if pt_limit > 0.0 and pt_t >= pt_limit:
		get_tree().quit()


## 简化版「玩家」：每 3 次决策里有一次优先升级（解锁配方），其余优先合成（直接提升出力）
func _bot_step(delta: float) -> void:
	bot_t += delta
	if bot_t < 0.5:
		return
	bot_t = 0.0
	bot_ticks += 1
	if bot_ticks % 3 == 0 and try_level():
		return
	if try_craft():
		return
	try_level()


func _pt_log() -> void:
	var need: float = _spawn_rate() * _wave_hp()
	var comp := ""
	for m in weapon.slots:
		comp += "." if m == null else str(int(m.tier))
	print("t=%3d w=%2d hp=%3d dps=%5.1f need=%5.1f drop=%.2f burn=%.2f lvl=%2d slot=%d/%d [%s] kills=%d" % [
		int(pt_t), wave, int(maxf(hp, 0.0)), cur_dps(), need,
		cur_drop(), cur_burn(), level, _count_filled(), weapon.slots.size(), comp,
		kills_total,
	])


func _hud_tick(delta: float) -> void:
	flash_t = maxf(0.0, flash_t - delta)
	# 构筑屏/死亡屏打开时不要红色受击遮罩，否则整个面板被染红
	flash.color = Color(1, 0.2, 0.25, 0.0 if (build_root.visible or dead) else flash_t * 0.9)
	if pulse_t > 0.0:
		pulse_t = maxf(0.0, pulse_t - delta)
		queue_redraw()
	# 每 0.1s 刷一次 HUD，避免每帧拼字符串
	if fmod(elapsed, 0.1) < delta:
		_refresh_hud()


func _wave_hp() -> float:
	return HP_BASE * pow(HP_GROWTH, wave - 1)


func _spawn_rate() -> float:
	return SPAWN_BASE + wave * SPAWN_GROWTH


func _set_quality(q: int) -> void:
	q = clampi(q, 1, 5)
	weapon.quality = q
	weapon.base = float(QUALITY_BASE[q])
	weapon.layout = LAYOUTS[q].duplicate()
	while weapon.slots.size() < weapon.layout.size():
		weapon.slots.append(null)
	while weapon.slots.size() > weapon.layout.size():
		weapon.slots.pop_back()


func _ensure_weapon() -> void:
	var q := 3
	for w in QUALITY_SCHEDULE:
		if wave >= w:
			q = maxi(q, int(QUALITY_SCHEDULE[w]))
	if q != int(weapon.quality):
		_set_quality(q)


## 相邻 = 网格曼哈顿距离 1
func _neighbors(i: int) -> Array:
	var out: Array = []
	var a: Vector2i = weapon.layout[i]
	for j in weapon.layout.size():
		if j == i:
			continue
		var b: Vector2i = weapon.layout[j]
		if absi(a.x - b.x) + absi(a.y - b.y) == 1:
			out.append(j)
	return out


## 半径 r 内（曼哈顿距离 ≤ r）的所有槽位
func _within(i: int, r: int) -> Array:
	var out: Array = []
	var a: Vector2i = weapon.layout[i]
	for j in weapon.layout.size():
		if j == i:
			continue
		var b: Vector2i = weapon.layout[j]
		if absi(a.x - b.x) + absi(a.y - b.y) <= r:
			out.append(j)
	return out


## 每个槽位这次的「出力」。镜像是对邻居读数再算一份，不做连锁传播（否则指数爆炸）。
func _slot_out() -> Array:
	# 基础值 = 阶级固有值 + 脉冲累加进来的加成（bonus 视作该模块自身基础值的一部分）
	var base: Array = []
	base.resize(weapon.slots.size())
	for i in weapon.slots.size():
		var m = weapon.slots[i]
		if m == null:
			base[i] = 0.0
		else:
			base[i] = float(TIERS[int(m.tier)].rate) + float(m.get("bonus", 0.0))
	var eff := base.duplicate()
	# 共振：相邻同名（同阶）模块 +50%
	for i in weapon.slots.size():
		var m = weapon.slots[i]
		if m == null or int(m.tier) != 4:
			continue
		for j in _neighbors(i):
			if weapon.slots[j] != null and int(weapon.slots[j].tier) == 4:
				eff[j] = float(eff[j]) + float(base[j]) * 0.5
	var out: Array = []
	out.resize(weapon.slots.size())
	for i in weapon.slots.size():
		var m = weapon.slots[i]
		if m == null:
			out[i] = 0.0
			continue
		var v: float = eff[i]
		var t := int(m.tier)
		if t == 2:  # 加法：镜像相邻的低阶模块
			for j in _neighbors(i):
				if weapon.slots[j] != null and int(weapon.slots[j].tier) < t:
					v += float(eff[j])
		elif t == 3:
			v = 0.0  # 脉冲：自身不产出，值全部给相邻主动模块
		out[i] = v
	return out


func _shot_power() -> float:
	var total := float(weapon.base)
	for v in _slot_out():
		total += float(v)
	return total * weapon.mul


## 脉冲模块：每 PULSE_SEC 把自己的基础值加到相邻的「主动模块」上（叠加，封顶 PULSE_STACK_MAX 层）
func _pulse_tick(delta: float) -> void:
	var step := float(TIERS[3].rate)
	for i in weapon.slots.size():
		var m = weapon.slots[i]
		if m == null or int(m.tier) != 3:
			continue
		m.tick = float(m.tick) + delta
		while float(m.tick) >= PULSE_SEC:
			m.tick = float(m.tick) - PULSE_SEC
			for j in _neighbors(i):
				var n = weapon.slots[j]
				if n == null or int(n.tier) == 3:
					continue
				if float(n.bonus) + step <= step * PULSE_STACK_MAX + 0.001:
					n.bonus = float(n.bonus) + step


func _spawn(delta: float) -> void:
	spawn_acc += delta * _spawn_rate()
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		if get_tree().get_nodes_in_group("enemy").size() >= MAX_ENEMIES:
			break
		_spawn_enemy()


func _spawn_enemy() -> void:
	var e = Node2D.new()
	e.set_script(load("res://scripts/enemy.gd"))
	e.add_to_group("enemy")
	var ang: float = rng.randf() * TAU
	e.position = player.position + Vector2(cos(ang), sin(ang)) * rng.randf_range(520.0, 660.0)
	e.max_hp = _wave_hp()
	e.hp = e.max_hp
	e.speed = rng.randf_range(80.0, 105.0) + wave * 1.2
	add_child(e)


func _fire(delta: float) -> void:
	fire_t += delta
	if fire_t < weapon.interval:
		return
	fire_t -= weapon.interval
	if _nearest_enemy(FIRE_RANGE) == null:
		return  # 无目标不开火 → 不消耗次数（基础伤害也不打空气）
	var dmg := _shot_power()
	for i in weapon.slots.size():
		var m = weapon.slots[i]
		if m == null:
			continue
		m.left = float(m.left) - 1.0
		if m.left <= 0.0:
			weapon.slots[i] = null
	if dmg <= 0.0:
		return
	# 脉冲：射程内全部敌人吃满这次伤害（单目标 1 发/秒 追不上海量刷怪）
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if e.position.distance_to(player.position) <= FIRE_RANGE:
			e.hp = float(e.hp) - dmg
			e.hit = 0.18
			if e.hp <= 0.0:
				_kill(e)
	pulse_t = PULSE_DUR


func _draw() -> void:
	if pulse_t > 0.0 and player != null:
		var k: float = 1.0 - pulse_t / PULSE_DUR
		var r: float = FIRE_RANGE * (0.25 + 0.75 * k)
		draw_arc(player.position, r, 0.0, TAU, 48,
			Color(0.5, 0.75, 1.0, (1.0 - k) * 0.55), 3.0, true)


func _nearest_enemy(max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = e.position.distance_to(player.position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _kill(e: Node2D) -> void:
	kills_total += 1
	kill_times.append(elapsed)
	if rng.randf() < DROP_CHANCE:
		_spawn_pickup(e.position, 1)
	e.queue_free()


func _spawn_pickup(pos: Vector2, tier: int) -> void:
	var p = Node2D.new()
	p.set_script(load("res://scripts/pickup.gd"))
	p.add_to_group("pickup")
	p.position = pos
	p.tier = tier
	add_child(p)


func _contact(delta: float) -> void:
	var touching := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if e.position.distance_to(player.position) < 26.0:
			touching += 1
			if touching >= CROWD_CAP:
				break
	if touching > 0:
		var dmg: float = CONTACT_DPS * touching * delta
		hp -= dmg
		flash_t = 0.35
		_reward_damage(dmg)
	if hp <= 0.0:
		_die()


## 挨打换模块：弹药会耗尽，所以掉血要反哺构筑（越挨打越有料补）
func _reward_damage(dmg: float) -> void:
	damage_credit += dmg
	while damage_credit >= DAMAGE_PER_MODULE:
		damage_credit -= DAMAGE_PER_MODULE
		modules_from_damage += 1
		var t := _damage_reward_tier()
		# 掉在玩家脚边，能看见它被吸走，反馈比直接进背包好
		var n := _damage_reward_count()
		for k in n:
			_spawn_pickup(player.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(38.0, 58.0), t)


## 补偿只给「能产出的」模块：脉冲自身 0 出力，当补偿发等于发了个空槽
func _damage_reward_tier() -> int:
	if wave >= 12:
		return 2
	return 1


func _damage_reward_count() -> int:
	if wave >= 24:
		return 2
	return 1


func _die() -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	flash_t = 0.0
	flash.color = Color(1, 0.2, 0.25, 0.0)
	if playtest:
		print("DEAD t=%d w=%d lvl=%d kills=%d" % [int(pt_t), wave, level, kills_total])
		get_tree().quit()
		return
	build_root.visible = true
	board_root.visible = false
	build_info.visible = false
	hud_status.visible = false
	hud_ammo.visible = false
	hud_tip.visible = false
	build_text.position = Vector2(80, 240)
	build_text.add_theme_font_size_override("font_size", 26)
	build_text.text = "你被淹没了\n\n%s\n\n按 R 重开" % _run_summary()


func _run_summary() -> String:
	return "存活 %s   ·   波次 %d   ·   等级 %d   ·   击杀 %d   ·   受击补偿 %d" % [
		_fmt_time(elapsed), wave, level, kills_total, modules_from_damage
	]


func _fmt_time(t: float) -> String:
	return "%02d:%02d" % [int(t) / 60, int(t) % 60]


func _inv_total() -> int:
	return inventory[1] + inventory[2] + inventory[3] + inventory[4]


func _all_total() -> int:
	return _inv_total() + _count_filled()


func _count_tier(t: int) -> int:
	var n: int = inventory[t]
	for m in weapon.slots:
		if m != null and int(m.tier) == t:
			n += 1
	return n


## 从槽位里取该阶中寿命最少的模块（也顺手把快报废的先花掉）
func _take_from_slots(t: int) -> bool:
	var idx := -1
	var best := 2.0
	for i in weapon.slots.size():
		var m = weapon.slots[i]
		if m != null and int(m.tier) == t:
			var f: float = float(m.left) / float(TIERS[t].uses)
			if f < best:
				best = f
				idx = i
	if idx < 0:
		return false
	weapon.slots[idx] = null
	return true


func _take_tier(t: int, n: int, prefer_slots: bool = false) -> void:
	var left := n
	if prefer_slots:
		while left > 0 and _take_from_slots(t):
			left -= 1
	while left > 0 and inventory[t] > 0:
		inventory[t] -= 1
		left -= 1
	while left > 0:
		if not _take_from_slots(t):
			return
		left -= 1


## 主动模块 = 自己会产出数值的模块（脉冲靠邻居吃饭，不算）
func _count_active() -> int:
	var n := 0
	for m in weapon.slots:
		if m != null and int(m.tier) != 3:
			n += 1
	return n


## 整板出力（不含武器基础值，只用于互相比较）
func _board_total() -> float:
	var s := 0.0
	for v in _slot_out():
		s += v
	return s


## 把一个模块装进电路板。
## 规则：空槽优先；满了就试每一格「换上去之后整板出力最高」的那一格，
## 而且必须**严格高于当前出力**才换，否则留在库存等槽位空出来。
## 旧规则是「替换最低阶」，结果会把喂加法的 T1 全换掉，最后板上全是互相吃不到的加法。
func _install(t: int) -> void:
	var n: int = weapon.slots.size()
	if t != 3:
		for i in n:
			if weapon.slots[i] == null:
				weapon.slots[i] = _new_module(t)
				return
	# 脉冲自身不产出 → 不占空槽，必须有 ≥2 个主动邻居，且不能把最后一个主动模块换掉
	if t == 3:
		if _count_active() < 2:
			inventory[t] += 1
			return
		var out := _slot_out()
		var best := -1
		var best_fed := 1
		var best_own := 1e18
		for i in n:
			var m = weapon.slots[i]
			if m == null or int(m.tier) == 3:
				continue
			# 只换「本身就没什么产出」的格子（T1 或吃不到料的加法），
			# 别把板上的主力换成 3 秒不产出的脉冲
			if float(out[i]) > 4.0:
				continue
			var fed := 0
			for j in _neighbors(i):
				var nb = weapon.slots[j]
				if nb != null and int(nb.tier) != 3:
					fed += 1
			if fed < 2:
				continue
			if fed > best_fed or (fed == best_fed and float(out[i]) < best_own):
				best_fed = fed
				best_own = float(out[i])
				best = i
		if best >= 0:
			weapon.slots[best] = _new_module(3)
			return
		inventory[3] += 1
		return
	var now := _board_total()
	var best2 := -1
	var best_v := now + 0.001
	for i in n:
		var m = weapon.slots[i]
		if m == null or _count_active() <= 1:
			continue
		weapon.slots[i] = _new_module(t)
		var v := _board_total()
		weapon.slots[i] = m
		if v > best_v:
			best_v = v
			best2 = i
	if best2 >= 0:
		weapon.slots[best2] = _new_module(t)
		return
	inventory[t] += 1


func level_cost() -> int:
	return int(round(LEVEL_COST_BASE * pow(LEVEL_COST_GROWTH, level - 1)))


## 升级只吃库存（槽位是工作区，不能被顺手拆掉）——「多余的基础模块」才拿去升级
func try_level() -> bool:
	var cost := level_cost()
	if _inv_total() < cost:
		return false
	var left := cost
	for t in [1, 2, 3, 4]:
		var take: int = mini(left, inventory[t])
		inventory[t] -= take
		left -= take
		if left <= 0:
			break
	if left > 0:
		return false
	level += 1
	return true


## 合成吃「库存」（槽位是工作区，绝不能被合成顺手拆掉）：
## 2 个同阶库存模块 → 1 个高阶模块，直接换下电路板上最弱的那颗
func try_craft() -> bool:
	for t in [4, 3, 2]:
		if level < int(CRAFT_UNLOCK[t]):
			continue
		if inventory[t - 1] >= 2:
			inventory[t - 1] -= 2
			if t == 3:
				# 脉冲自身 0 出力：先存库存，凑够 2 个直接合成共振，别白占电路板的输出位
				inventory[3] += 1
			else:
				_install(t)
			return true
	return false


func add_module(tier: int) -> void:
	for i in weapon.slots.size():
		if weapon.slots[i] == null:
			weapon.slots[i] = _new_module(tier)
			return
	inventory[tier] += 1


func cur_dps() -> float:
	return _shot_power() / weapon.interval


func cur_burn() -> float:
	var b := 0.0
	for m in weapon.slots:
		if m != null:
			b += 1.0 / (float(TIERS[m.tier].uses) * weapon.interval)
	return b


func cur_drop() -> float:
	var cutoff := elapsed - 5.0
	while kill_times.size() > 0 and kill_times[0] < cutoff:
		kill_times.pop_front()
	var n := float(kill_times.size())
	return (n / 5.0) * DROP_CHANCE


func _refresh_hud() -> void:
	if hud_status == null:
		return
	hud_status.text = "HP %d/%d    波次 %d    时间 %s    等级 %d" % [
		int(maxf(hp, 0.0)), int(max_hp), wave, _fmt_time(elapsed), level
	]
	var net := cur_drop() - cur_burn()
	var sign_s := "+" if net >= 0.0 else ""
	hud_ammo.text = "DPS %5.1f    净弹药 %s%.2f/s    库存 %d    槽位 %d/%d" % [
		cur_dps(), sign_s, net, _inv_total(),
		_count_filled(), weapon.slots.size()
	]
	if _count_filled() == 0:
		hud_ammo.text += "    模块耗尽 · 仅基础 %.1f" % float(weapon.base)
	hud_ammo.add_theme_color_override("font_color",
		Color(0.7, 0.95, 0.85) if net >= 0.0 else Color(1.0, 0.55, 0.5))


func _count_filled() -> int:
	var n := 0
	for m in weapon.slots:
		if m != null:
			n += 1
	return n


func _refresh_build() -> void:
	if build_text == null or dead:
		return
	_rebuild_board()
	var lines: Array = []
	lines.append("构筑（暂停中）     TAB 返回")
	lines.append("")
	lines.append("武器  %s·%d 槽    interval %.2fs    mul ×%.2f    基础 %.1f    单次出力 %.1f" % [
		QUALITY_NAME[int(weapon.quality)], weapon.slots.size(), weapon.interval,
		weapon.mul, float(weapon.base), _shot_power()
	])
	build_text.text = "\n".join(lines)

	var info: Array = []
	info.append("库存    基础 %d    加法 %d    脉冲 %d    共振 %d" % [
		inventory[1], inventory[2], inventory[3], inventory[4]
	])
	info.append("受击补偿    +%d 个模块（每 %d HP 补 1 个）" % [
		modules_from_damage, int(DAMAGE_PER_MODULE)
	])
	info.append("")
	info.append("等级 %d  →  %d     需要 %d 个模块     [U]" % [
		level, level + 1, level_cost()
	])
	for t in [2, 3, 4]:
		var state := "解锁于 Lv%d" % int(CRAFT_UNLOCK[t])
		if level >= int(CRAFT_UNLOCK[t]):
			state = "可合成" if inventory[t - 1] >= 2 else "需 2 个%s" % TIERS[t - 1].name
		info.append("    2×%s → 1×%s     [C]    %s" % [TIERS[t - 1].name, TIERS[t].name, state])
	info.append("")
	info.append("净弹药 %+.2f/s     DPS %.1f" % [cur_drop() - cur_burn(), cur_dps()])
	build_info.text = "\n".join(info)


## 电路板视图：槽位按真实网格摆放，相邻槽位连线
func _rebuild_board() -> void:
	if board_root == null:
		return
	for c in board_root.get_children():
		c.queue_free()
	var out := _slot_out()
	var cell := 78.0
	var step := 96.0
	var minx := 0
	var miny := 0
	for p in weapon.layout:
		minx = mini(minx, int(p.x))
		miny = mini(miny, int(p.y))
	for i in weapon.layout.size():
		for j in range(i + 1, weapon.layout.size()):
			var a: Vector2i = weapon.layout[i]
			var b: Vector2i = weapon.layout[j]
			if absi(a.x - b.x) + absi(a.y - b.y) != 1:
				continue
			var pa := Vector2((a.x - minx) * step + cell * 0.5, (a.y - miny) * step + cell * 0.5)
			var pb := Vector2((b.x - minx) * step + cell * 0.5, (b.y - miny) * step + cell * 0.5)
			var link := ColorRect.new()
			link.color = Color(0.30, 0.40, 0.58)
			if absf(pa.x - pb.x) > 0.1:
				link.size = Vector2(step - cell + 8.0, 4.0)
			else:
				link.size = Vector2(4.0, step - cell + 8.0)
			link.position = (pa + pb) * 0.5 - link.size * 0.5
			board_root.add_child(link)
	for i in weapon.layout.size():
		var p: Vector2i = weapon.layout[i]
		var m = weapon.slots[i]
		var panel := Panel.new()
		panel.position = Vector2((p.x - minx) * step, (p.y - miny) * step)
		panel.size = Vector2(cell, cell)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(2)
		sb.bg_color = Color(0.09, 0.11, 0.16)
		sb.border_color = Color(0.28, 0.33, 0.44)
		if m != null:
			var col: Color = TIERS[int(m.tier)].color
			sb.border_color = col
			sb.bg_color = Color(col.r, col.g, col.b, 0.10)
		panel.add_theme_stylebox_override("panel", sb)
		board_root.add_child(panel)

		var name_l := Label.new()
		name_l.position = Vector2(0, 7)
		name_l.size = Vector2(cell, 24)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.add_theme_font_size_override("font_size", 16)
		if m == null:
			name_l.text = "%d 空" % (i + 1)
			name_l.add_theme_color_override("font_color", Color(0.42, 0.46, 0.56))
		else:
			name_l.text = TIERS[int(m.tier)].name
			name_l.add_theme_color_override("font_color", TIERS[int(m.tier)].color)
		panel.add_child(name_l)

		var out_l := Label.new()
		out_l.position = Vector2(0, 31)
		out_l.size = Vector2(cell, 22)
		out_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		out_l.add_theme_font_size_override("font_size", 15)
		out_l.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
		if m == null:
			out_l.text = "—"
		elif int(m.tier) == 3:
			# 脉冲不产出，显示「每次加多少 × 给几个邻居」
			var fed := 0
			for j in _neighbors(i):
				var n = weapon.slots[j]
				if n != null and int(n.tier) != 3:
					fed += 1
			out_l.text = "→%.0f×%d" % [float(TIERS[3].rate), fed]
		elif float(m.bonus) > 0.5:
			# 拆开显示：自身基础值 + 脉冲喂进来的加成
			out_l.text = "%.0f+%.0f" % [float(out[i]) - float(m.bonus), float(m.bonus)]
		else:
			out_l.text = "%.1f" % float(out[i])
		panel.add_child(out_l)

		var use_l := Label.new()
		use_l.position = Vector2(0, 53)
		use_l.size = Vector2(cell, 18)
		use_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		use_l.add_theme_font_size_override("font_size", 13)
		use_l.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
		use_l.text = "" if m == null else "%d/%d" % [int(m.left), int(TIERS[int(m.tier)].uses)]
		panel.add_child(use_l)

		# 脉冲充能条：脉冲自己显示本次脉冲的倒计时，其它模块显示已累计的加成进度
		if m != null:
			var ratio := 0.0
			if int(m.tier) == 3:
				ratio = clampf(float(m.tick) / PULSE_SEC, 0.0, 1.0)
			else:
				ratio = clampf(float(m.bonus) / (float(TIERS[3].rate) * PULSE_STACK_MAX), 0.0, 1.0)
			if ratio > 0.0:
				var bar := ColorRect.new()
				bar.color = Color(0.36, 0.88, 0.82, 0.9)
				bar.position = Vector2(9, cell - 7)
				bar.size = Vector2((cell - 18) * ratio, 3.0)
				panel.add_child(bar)
