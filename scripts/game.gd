extends Node2D
## 主控制器：刷怪、开火、掉落、构筑、HUD。

## 模块表。tier 1 基础 / 2 加法 / 3 增幅（与加法同级，靠合成时间区分）/ 4 共振
## 增幅自身不出力（rate 0），每次开火把 boost 加到相邻模块的最终输出上
const TIERS := {
	1: {"rate": 1.0, "uses": 45.0, "name": "基础", "color": Color(0.56, 0.70, 1.0)},
	2: {"rate": 3.0, "uses": 60.0, "name": "加法", "color": Color(0.49, 0.94, 0.66)},
	3: {"rate": 0.0, "uses": 120.0, "name": "增幅", "color": Color(0.36, 0.88, 0.82), "boost": 5.0},
	4: {"rate": 27.0, "uses": 100.0, "name": "共振", "color": Color(1.0, 0.56, 0.64)},
}

## 配方：产物阶 → 原料阶 + 耗时。加法与增幅吃一样的 2 个基础，只用时间区分（6s vs 20s）
const RECIPES := {
	2: {"from": 1, "time": 3.0},
	3: {"from": 1, "time": 8.0},
	4: {"from": 3, "time": 14.0},
}
const CRAFT_UNLOCK := {2: 4, 3: 8, 4: 16}

## 合成装置：每台 = 1 个并行合成位。可反复制造，材料堆积就多做几台（变相缩短合成时间）。
## 开局免费 1 台，第 n 台的价钱 = 12 × 1.7^(n-2) 个基础模块，上限 8 台。
const DEVICE_COST_BASE := 12
const DEVICE_COST_GROWTH := 1.7
const DEVICE_MAX := 8

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

## 武器种类：射程 / 间隔 / 目标数 是三种不同的资源。
## 冲锋枪：高射速换弹药消耗；霰弹枪：多目标换单体伤害；狙击枪：长射程低消耗换出手频率。
## targets = -1 表示「范围内全部敌人」（激光环的清场定位）。
## 多目标伤害分摊：per = dmg × (1 + 0.1×(hits−1)) / hits —— 打得越多总伤越高，但每个目标更低。
const WEAPONS := {
	"pistol": {"name": "手枪", "range": 300.0, "interval": 0.70, "targets": 2, "mul": 1.00, "base": 1.0, "color": Color(0.55, 0.80, 1.00)},
	"smg": {"name": "冲锋枪", "range": 210.0, "interval": 0.30, "targets": 1, "mul": 1.10, "base": 0.5, "color": Color(1.00, 0.85, 0.45)},
	"shotgun": {"name": "霰弹枪", "range": 200.0, "interval": 0.90, "targets": 5, "mul": 1.11, "base": 0.8, "color": Color(1.00, 0.62, 0.35)},
	"sniper": {"name": "狙击枪", "range": 640.0, "interval": 2.50, "targets": 1, "mul": 1.00, "base": 3.0, "color": Color(0.70, 0.95, 0.75)},
	"laser": {"name": "激光环", "range": 420.0, "interval": 40.0, "targets": -1, "mul": 4.00, "base": 2.0, "color": Color(0.85, 0.55, 1.00)},
}
## 开局随机一把（激光环 wave 8 之后才入池）
const START_POOL := ["pistol", "smg", "shotgun"]
const WAVE_SEC := 40.0
const DROP_CHANCE := 0.40
const CHEST_GUARANTEE := 90.0
const HP_BASE := 4.0
const HP_GROWTH := 1.130
const SPAWN_BASE := 0.70
const SPAWN_GROWTH := 0.120
const MAX_ENEMIES := 240
const LEVEL_COST_BASE := 3.0
const LEVEL_COST_GROWTH := 1.18
const CONTACT_DPS := 3.0
## 受击补偿：每损失这么多 HP 补 1 个模块（弹药系统的劣势补偿，挨打就回填）
const DAMAGE_PER_MODULE := 8.0
const CROWD_CAP := 6
const FIRE_RANGE := 260.0
const PULSE_DUR := 0.30

## 敌人种类：hp_mult = (100 / 速度)^1.5 —— 速度越快血越少。
## 以后加新怪直接套这个公式，不用一张张手调。
const ENEMY_KINDS := {
	"flood": {"speed": 100.0, "hp_mult": 1.00, "radius": 13.0, "color": Color(0.92, 0.30, 0.34)},
	"runner": {"speed": 205.0, "hp_mult": 0.34, "radius": 9.0, "color": Color(1.00, 0.70, 0.26)},
	"rock": {"speed": 52.0, "hp_mult": 2.67, "radius": 19.0, "color": Color(0.56, 0.46, 0.86)},
	"shooter": {"speed": 70.0, "hp_mult": 1.71, "radius": 12.0, "color": Color(0.62, 0.86, 1.00)},
	# 精英血量是手设的 9.0（不套公式：它靠冲刺而非堆血量制造威胁）
	"charger": {"speed": 78.0, "hp_mult": 9.00, "radius": 20.0, "color": Color(1.00, 0.36, 0.42)},
}

## 波次编成：coeff = 总血量预算系数（1.0 = 涌潮基准），kinds = 相对权重。
## 每 5 波循环一次，所以玩家能从「这波怪变多了/变硬了」读出编成变化。
const WAVE_PLANS := [
	{"name": "涌潮", "coeff": 1.00, "kinds": {"flood": 1.0}},
	{"name": "混编", "coeff": 0.80, "kinds": {"flood": 5.0, "runner": 3.0, "shooter": 2.0}},
	{"name": "疾行", "coeff": 1.40, "kinds": {"runner": 1.0}},
	{"name": "磐石", "coeff": 0.60, "kinds": {"rock": 1.0}},
	{"name": "混编", "coeff": 0.80, "kinds": {"flood": 4.0, "rock": 2.0, "runner": 2.0, "shooter": 1.0}},
]

## 精英：wave 4 首只，之后每 6 波保证一只；同屏上限 3
const ELITE_FIRST_WAVE := 4
const ELITE_EVERY := 6
const ELITE_MAX := 3
const SHOOTER_MAX := 5

## 背包：武器与合成装置共同占用容量（-1 = 先不做上限）
var backpack_cap := -1
var weapons: Array = []
var weapon: Dictionary = {}
var sel := 0
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
## 掉血来源统计（调平衡用：分不清是杂兵磨死还是子弹打死就只能靠猜）
var dmg_src := {"contact": 0.0, "bullet": 0.0, "dash": 0.0}
## 最后一次挨打的时间：脱战 4s 后开始缓慢回血，否则子弹的零碎伤害会把人磨死
var last_hit_t := -99.0
var last_chest_t := 0.0
const REGEN_DELAY := 4.0
const REGEN_RATE := 1.2
var damage_credit := 0.0
var modules_from_damage := 0
var rng := RandomNumberGenerator.new()

var player: Node2D
var hud_status: Label
var hud_ammo: Label
var hud_tip: Label
var wpanel: Label
var build_root: Control
var build_text: Label
var board_root: Control
var build_info: Label
var flash: ColorRect
var flash_t := 0.0
var pulse_t := 0.0
var shots: Array = []

# --- 合成：每台装置一个并行位，装置可反复买（材料堆积就多做几台） ---
var devices: Array = []  # [{"kind": int, "left": float, "total": float}]，kind=0 表示空闲
var craft_seq := 0
## 各阶实际合出来的数量（平衡观察用，也进 playtest 日志）
var crafted := {1: 0, 2: 0, 3: 0, 4: 0}

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
var shot_guard := 0.0
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
			bot = true
		elif a.begins_with("ff="):
			ff = float(a.substr(3))
	if playtest:
		# 无头模拟按实时速度跑太慢，放大时间步（步长变粗，数值平衡够用）
		Engine.time_scale = 8.0
		Engine.max_fps = 0
	rng.randomize()
	var start_id: String = START_POOL[rng.randi() % START_POOL.size()]
	if bot:
		start_id = "smg"  # 测平衡时固定武器，免得随机开局把两次结果拉不开
	weapons.append(_make_weapon(start_id, 3))
	_use_weapon(0)
	for i in weapon.slots.size():
		weapon.slots[i] = _new_module(1)
	inventory[1] = 2
	devices.append(_new_device())
	_make_player()
	_make_hud()
	_refresh_hud()


## 模块寿命带 ±15% 抖动：否则同一批装上去的模块会同时烧光，DPS 出现断崖
func _new_module(tier: int) -> Dictionary:
	var u := float(TIERS[tier].uses) * rng.randf_range(0.85, 1.15)
	return {"tier": tier, "left": u, "max": u}


func _new_device() -> Dictionary:
	return {"kind": 0, "left": 0.0, "total": 0.0}


## 第 (n+1) 台装置的价格：开局那台免费，第 2 台 12、第 3 台 20、第 4 台 35 ……
func device_cost() -> int:
	return int(round(DEVICE_COST_BASE * pow(DEVICE_COST_GROWTH, maxf(0.0, devices.size() - 1.0))))


func _idle_device() -> int:
	for i in devices.size():
		if int(devices[i]["kind"]) == 0:
			return i
	return -1


func _busy_devices() -> int:
	var n := 0
	for d in devices:
		if int(d["kind"]) != 0:
			n += 1
	return n


## 用基础模块造一台新装置（材料堆积时的唯一出口）
func buy_device() -> bool:
	if devices.size() >= DEVICE_MAX:
		return false
	var cost := device_cost()
	if inventory[1] < cost:
		return false
	inventory[1] -= cost
	devices.append(_new_device())
	return true


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
	hud_tip.text = "WASD 移动    TAB 构筑    U 升级    C 加法  V 增幅  B 共振    X 造装置    1-9 选武器  F 开关    R 重开"

	wpanel = _label(layer, Vector2(18, 84), 17, Color(0.78, 0.86, 1.0))

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
		try_craft(2)
		_pass()
	elif k == KEY_V:
		try_craft(3)
		_pass()
	elif k == KEY_B:
		try_craft(4)
		_pass()
	elif k == KEY_X:
		if buy_device():
			_pass()
	elif k == KEY_R:
		get_tree().paused = false
		get_tree().reload_current_scene()
	elif k == KEY_F and weapons.size() > 0:
		var w: Dictionary = weapons[sel]
		w["enabled"] = not bool(w["enabled"])
		_pass()
	elif k >= KEY_1 and k <= KEY_9:
		var idx: int = k - KEY_1
		if idx < weapons.size():
			_use_weapon(idx)
			_pass()
	elif k == KEY_ESCAPE and build_root.visible:
		_toggle_build()


func _toggle_build() -> void:
	build_root.visible = not build_root.visible
	get_tree().paused = build_root.visible
	hud_status.visible = not build_root.visible
	hud_ammo.visible = not build_root.visible
	hud_tip.visible = not build_root.visible
	wpanel.visible = not build_root.visible
	if build_root.visible:
		_refresh_build()


func _pass() -> void:
	if build_root.visible:
		_refresh_build()
	else:
		_refresh_hud()


func _process(delta: float) -> void:
	# 快进：先按 8 倍速把局面推到 ff 秒，再恢复正常速度拍图
	# 死亡时 elapsed 会停住，必须跳出快进分支，否则会一直等下去
	if ff > 0.0 and not dead:
		if elapsed < ff:
			Engine.time_scale = 8.0
			return
		Engine.time_scale = 1.0
		ff = 0.0
	if ff > 0.0 and dead:
		Engine.time_scale = 1.0
		ff = 0.0
	if shot_path == "" or shot_at < 0.0:
		return
	# 死了之后 elapsed 不再推进，如果还在等 shotat 就会永久挂住 —— 死亡即立刻拍
	if not dead:
		if elapsed < shot_at:
			shot_guard += delta
			if shot_guard > 90.0:
				print("shot guard timeout")
				get_tree().quit()
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
	var prev_wave := wave
	wave = int(elapsed / WAVE_SEC) + 1
	if wave != prev_wave:
		_on_wave_start()
	if not boardtest:
		_ensure_weapon()
	_bot_move(delta)
	_spawn(delta)
	_craft_tick(delta)
	_fire(delta)
	_contact(delta)
	_hud_tick(delta)
	if playtest:
		_playtest_step(delta)
	elif shot_bot:
		_bot_step(delta)
	elif boardtest:
		_boardtest(delta)


## 电路板规则自检：金 6 槽 2×3 密堆，摆下共振×2 / 增幅 / 加法 / 基础×2
## 期望：out = [40.5, 45.5, 0, 1, 5, 6]  power = 100.0
func _boardtest(delta: float) -> void:
	if not bt_set:
		bt_set = true
		_set_quality(5)
		weapon.interval = 1.0 if demo_board else 999.0  # 自检时不开火，排除弹药消耗的干扰
		weapon.slots[0] = _new_module(4)  # 共振（邻 1 共振、3 基础）
		weapon.slots[1] = _new_module(4)  # 共振（邻 0 共振、2 增幅、4 加法）
		weapon.slots[2] = _new_module(3)  # 增幅（邻 1、5）
		weapon.slots[3] = _new_module(1)  # 基础（邻 0、4）
		weapon.slots[4] = _new_module(2)  # 加法（邻 1、3、5）
		weapon.slots[5] = _new_module(1)  # 基础（邻 2、4）
		print("BOARD set  out=", _slot_out(), " power=", _shot_power())
	bt_print += delta
	if bt_print >= 0.5:
		bt_print = 0.0
		print("t=%4.1f  out=%s  power=%5.1f" % [elapsed, str(_slot_out()), _shot_power()])
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


## 简化版「玩家」：优先把空闲装置填满（合成是唯一把材料变成出力的手段），
## 装置全忙且基础模块堆积时再造一台（变相缩短合成时间），每 3 次决策升一次级。
func _bot_step(delta: float) -> void:
	bot_t += delta
	if bot_t < 0.5:
		return
	bot_t = 0.0
	bot_ticks += 1
	if bot_ticks % 3 == 0:
		try_level()
	var guard := 0
	while guard < 4 and try_craft():
		guard += 1
	if _busy_devices() >= devices.size() and devices.size() < DEVICE_MAX:
		if inventory[1] >= device_cost():
			buy_device()
	if bot_ticks % 3 != 0:
		try_level()


## 机器人走位：只躲「能秒人的东西」（子弹、冲刺精英的蓄力线），不躲杂兵。
## 原因：脉冲式武器最怕把怪拉成一长串尾巴——只有扎进怪堆里，一次开火才清得动。
func _bot_move(delta: float) -> void:
	# 注意：条件里不能加 playtest——截图模式（shotbot）也要让 bot 动，否则它站着不动、
	# 捡不到宝箱，拍出来的图跟无头测试的结果完全对不上。
	if not bot or player == null or dead:
		return
	var push := Vector2.ZERO
	for b in get_tree().get_nodes_in_group("bullet"):
		if not is_instance_valid(b):
			continue
		var to_p: Vector2 = player.position - b.position
		var d := to_p.length()
		if d < 190.0 and d > 1.0:
			var side: float = signf(to_p.cross(b.dir))
			if side == 0.0:
				side = 1.0
			push += b.dir.rotated(side * PI * 0.5) * (1.0 - d / 190.0) * 2.6
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var to_e: Vector2 = player.position - e.position
		var de := to_e.length()
		# 贴脸才退（不是风筝）——站着打才清得动，但也不能让怪白贴
		if de < 70.0 and de > 1.0:
			push += to_e / de * (1.0 - de / 70.0) * 0.6
		if e.kind != "charger":
			continue
		if e.windup <= 0.0:
			continue
		var to_c: Vector2 = player.position - e.position
		var dc := to_c.length()
		if dc < 460.0 and dc > 1.0:
			var side2: float = signf(to_c.cross(e.facing))
			if side2 == 0.0:
				side2 = 1.0
			push += e.facing.rotated(side2 * PI * 0.5) * 2.4
	# 宝箱是主要成长来源，有箱子就顺路去捡（躲子弹仍优先，因为权重更大）
	var best: Node2D = null
	var best_d := 760.0
	for c in get_tree().get_nodes_in_group("chest"):
		if not is_instance_valid(c):
			continue
		var dd: float = player.position.distance_to(c.position)
		if dd < best_d:
			best_d = dd
			best = c
	if best != null and best_d > 26.0:
		push += player.position.direction_to(best.position) * 4.0
	if push.length() > 0.05:
		player.position += push.normalized() * float(player.SPEED) * delta
		if player.position.length() > 1100.0:
			player.position = player.position.normalized() * 1100.0


func _pt_log() -> void:
	# 需求 DPS = 每秒进来的总血量 = 刷怪速度 × 单个基础血 × 本波平均血量倍率
	var need: float = _spawn_rate() * _wave_hp() * _plan_avg_mult()
	var comp := ""
	for m in weapon.slots:
		comp += "." if m == null else str(int(m.tier))
	print("t=%3d w=%2d hp=%3d dps=%5.1f need=%5.1f drop=%.2f burn=%.2f lvl=%2d slot=%d/%d dev=%d/%d [%s] c=%d/%d/%d/%d kills=%d dmg c%.0f/b%.0f/d%.0f alive=%d" % [
		int(pt_t), wave, int(maxf(hp, 0.0)), cur_dps(), need,
		cur_drop(), cur_burn(), level, _count_filled(), weapon.slots.size(),
		_busy_devices(), devices.size(), comp,
		crafted[1], crafted[2], crafted[3], crafted[4], kills_total,
		float(dmg_src["contact"]), float(dmg_src["bullet"]), float(dmg_src["dash"]),
		get_tree().get_nodes_in_group("enemy").size(),
	])


func _hud_tick(delta: float) -> void:
	flash_t = maxf(0.0, flash_t - delta)
	if elapsed - last_hit_t > REGEN_DELAY:
		hp = minf(max_hp, hp + REGEN_RATE * delta)
	# 构筑屏/死亡屏打开时不要红色受击遮罩，否则整个面板被染红
	flash.color = Color(1, 0.2, 0.25, 0.0 if (build_root.visible or dead) else flash_t * 0.9)
	if pulse_t > 0.0:
		pulse_t = maxf(0.0, pulse_t - delta)
	for i in range(shots.size() - 1, -1, -1):
		shots[i]["t"] = float(shots[i]["t"]) - delta
		if float(shots[i]["t"]) <= 0.0:
			shots.remove_at(i)
	queue_redraw()
	# 每 0.1s 刷一次 HUD，避免每帧拼字符串
	if fmod(elapsed, 0.1) < delta:
		_refresh_hud()


func _wave_hp() -> float:
	return HP_BASE * pow(HP_GROWTH, wave - 1)


## 当前波次的编成模板（每 5 波循环一次）
func _plan() -> Dictionary:
	return WAVE_PLANS[(wave - 1) % WAVE_PLANS.size()]


## 本波敌人的平均血量倍率（用来把「总血量预算」换算成刷怪速度）
func _plan_avg_mult() -> float:
	var plan := _plan()
	var wsum := 0.0
	var msum := 0.0
	for k in plan["kinds"]:
		var w: float = float(plan["kinds"][k])
		wsum += w
		msum += w * float(ENEMY_KINDS[k]["hp_mult"])
	return msum / maxf(wsum, 0.001)


## 刷怪速度：先按预算系数缩放，再按平均血量倍率反比缩放
## → 每波「总血量/秒」大致相同，但密度与单个强度差别很大（这就是玩法的差别）
## 上限 1.7× 是同血量预算的补充：速度快的怪本来就多，不给上限疾行波会变成 9 只/秒的墙
func _spawn_rate() -> float:
	var base: float = SPAWN_BASE + wave * SPAWN_GROWTH
	var raw: float = base * float(_plan()["coeff"]) / maxf(_plan_avg_mult(), 0.05)
	return minf(raw, base * 1.2)


func _pick_kind() -> String:
	var plan := _plan()
	# 射手要占住「射程外打你」的位置，数量一多就没法玩了：同屏上限 10
	if _count_kind("shooter") >= SHOOTER_MAX:
		for k in plan["kinds"]:
			if k != "shooter":
				return k
	var total := 0.0
	for k in plan["kinds"]:
		total += float(plan["kinds"][k])
	var r := rng.randf() * total
	for k in plan["kinds"]:
		r -= float(plan["kinds"][k])
		if r <= 0.0:
			return k
	return "flood"


func _count_kind(k: String) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.kind == k:
			n += 1
	return n


## 造一把武器：品质决定电路板布局，种类决定射程/间隔/目标数
func _make_weapon(id: String, q: int) -> Dictionary:
	var kd: Dictionary = WEAPONS[id]
	var w := {
		"id": id, "quality": clampi(q, 1, 5), "base": 0.0, "layout": [], "slots": [],
		"range": float(kd["range"]), "interval": float(kd["interval"]),
		"targets": int(kd["targets"]), "mul": float(kd["mul"]),
		"enabled": true, "fire_t": 0.0,
	}
	_set_quality_of(w, q)
	return w


func _set_quality_of(w: Dictionary, q: int) -> void:
	q = clampi(q, 1, 5)
	w["quality"] = q
	w["base"] = float(QUALITY_BASE[q])
	w["layout"] = (LAYOUTS[q] as Array).duplicate()
	var slots: Array = w["slots"]
	while slots.size() < w["layout"].size():
		slots.append(null)
	while slots.size() > w["layout"].size():
		slots.pop_back()


func _set_quality(q: int) -> void:
	_set_quality_of(weapon, q)


## 切换「正在编辑/查看」的武器（电路板和合成都作用在它上面）
func _use_weapon(i: int) -> void:
	sel = clampi(i, 0, weapons.size() - 1)
	weapon = weapons[sel]


## 背包占用 = 武器数 + 装置数
func _backpack_used() -> int:
	return weapons.size() + devices.size()


## 一把武器此刻的 DPS（多目标按分摊公式算总伤）
func _weapon_dps(w: Dictionary) -> float:
	var t := int(w["targets"])
	var hits: float = 1.0
	if t < 0:
		hits = float(maxi(1, _count_in_range(float(w["range"]))))
	elif t > 1:
		hits = float(mini(t, maxi(1, _count_in_range(float(w["range"])))))
	var per := _shot_power_of(w) * (1.0 + 0.1 * (hits - 1.0)) / hits
	return per * hits / float(w["interval"])


## 理论 DPS：空槽按「当前能合成的最高阶」填满后能打到多少（给玩家看成长空间）
func _theory_dps(w: Dictionary) -> float:
	var best := 2
	if level >= int(CRAFT_UNLOCK[4]):
		best = 4
	elif level >= int(CRAFT_UNLOCK[3]):
		best = 3
	var fill: Array = (w["slots"] as Array).duplicate()
	for i in fill.size():
		if fill[i] == null:
			fill[i] = _new_module(best)
	var total := float(w["base"])
	for v in _slot_out(fill, w):
		total += float(v)
	total *= float(w["mul"])
	var t := int(w["targets"])
	var hits: float = 1.0
	if t < 0:
		hits = 4.0
	elif t > 1:
		hits = float(t)
	return total * (1.0 + 0.1 * (hits - 1.0)) / float(w["interval"])


func _count_in_range(r: float) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.position.distance_to(player.position) <= r:
			n += 1
	return n


func _ensure_weapon() -> void:
	var q := 3
	for wv in QUALITY_SCHEDULE:
		if wave >= wv:
			q = maxi(q, int(QUALITY_SCHEDULE[wv]))
	# 只升不降：宝箱给的品质高于当前波次基线时保留（否则随机品质毫无意义）
	for w in weapons:
		if q > int(w["quality"]):
			_set_quality_of(w, q)


## 相邻 = 网格曼哈顿距离 1
func _neighbors(i: int, w = null) -> Array:
	var ww: Dictionary = weapon if w == null else w
	var out: Array = []
	var a: Vector2i = ww["layout"][i]
	for j in (ww["layout"] as Array).size():
		if j == i:
			continue
		var b: Vector2i = ww["layout"][j]
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


## 每个槽位这次的「出力」。
## 顺序：共振（读 base）→ 加法镜像（读 eff，不连锁）→ 增幅（加到最终 out，不回流）
## slots 显式传入时用它（理论 DPS 会传一份「填满的假板子」）
func _slot_out(slots = null, w = null) -> Array:
	var ww: Dictionary = weapon if w == null else w
	var sl: Array = (ww["slots"] as Array) if slots == null else slots
	var base: Array = []
	base.resize(sl.size())
	for i in sl.size():
		var m = sl[i]
		base[i] = 0.0 if m == null else float(TIERS[int(m.tier)].rate)
	var eff := base.duplicate()
	# 共振：相邻同阶（T4）模块 +50% 基础值
	for i in sl.size():
		var m = sl[i]
		if m == null or int(m.tier) != 4:
			continue
		for j in _neighbors(i, ww):
			if sl[j] != null and int(sl[j].tier) == 4:
				eff[j] = float(eff[j]) + float(base[j]) * 0.5
	var out: Array = []
	out.resize(sl.size())
	for i in sl.size():
		var m = sl[i]
		if m == null:
			out[i] = 0.0
			continue
		var v: float = eff[i]
		var t := int(m.tier)
		if t == 2:  # 加法：镜像相邻的低阶（基础）模块
			for j in _neighbors(i, ww):
				if sl[j] != null and int(sl[j].tier) < t:
					v += float(eff[j])
		out[i] = v
	# 增幅：自身 0 出力，每次开火把 boost 加到相邻模块的最终输出上（不回流给别的增幅）
	for i in sl.size():
		var m = sl[i]
		if m == null or int(m.tier) != 3:
			continue
		var b := float(TIERS[3].boost)
		for j in _neighbors(i, ww):
			if sl[j] != null and int(sl[j].tier) != 3:
				out[j] = float(out[j]) + b
	return out


func _shot_power_of(w: Dictionary) -> float:
	var total := float(w["base"])
	for v in _slot_out(null, w):
		total += float(v)
	return total * float(w["mul"])


func _shot_power() -> float:
	return _shot_power_of(weapon)


## 合成计时：每台装置各自倒计时，到点后产物进电路板
## （满了会按整板出力决定换不换，换不动就进库存）
func _craft_tick(delta: float) -> void:
	for d in devices:
		if int(d["kind"]) == 0:
			continue
		d["left"] = float(d["left"]) - delta
		if float(d["left"]) > 0.0:
			continue
		var k: int = int(d["kind"])
		d["kind"] = 0
		d["left"] = 0.0
		crafted[k] += 1
		_install(k)


## 每波开始：精英保底（wave 4 首只，之后每 6 波一只，同屏上限 3）
## 同时在地图上随机扔一个宝箱，让玩家有理由离开中心区域。
func _on_wave_start() -> void:
	_spawn_chest_random()
	if wave < ELITE_FIRST_WAVE:
		return
	if (wave - ELITE_FIRST_WAVE) % ELITE_EVERY != 0:
		return
	if get_tree().get_nodes_in_group("enemy").size() >= MAX_ENEMIES:
		return
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.kind == "charger":
			alive += 1
	if alive >= ELITE_MAX:
		return
	_spawn_enemy("charger")


func _spawn(delta: float) -> void:
	# 90 秒保底一个宝箱，防止运气差到一把新武器都拿不到
	var since := elapsed - last_chest_t
	if since >= CHEST_GUARANTEE and get_tree().get_nodes_in_group("chest").is_empty():
		_spawn_chest_random()
	spawn_acc += delta * _spawn_rate()
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		if get_tree().get_nodes_in_group("enemy").size() >= MAX_ENEMIES:
			break
		_spawn_enemy()


func _spawn_enemy(forced: String = "") -> void:
	var kind := forced if forced != "" else _pick_kind()
	var kd: Dictionary = ENEMY_KINDS[kind]
	var e = Node2D.new()
	e.set_script(load("res://scripts/enemy.gd"))
	e.add_to_group("enemy")
	var ang: float = rng.randf() * TAU
	e.position = player.position + Vector2(cos(ang), sin(ang)) * rng.randf_range(520.0, 660.0)
	e.kind = kind
	e.radius = float(kd["radius"])
	e.body_color = kd["color"]
	e.max_hp = _wave_hp() * float(kd["hp_mult"])
	e.hp = e.max_hp
	e.speed = float(kd["speed"]) * (1.0 + wave * 0.01)
	add_child(e)


## 开火：每把武器各自按自己的间隔寻找目标。
## 无目标不开火（不消耗次数，也不打空气）；多目标按分摊公式结算。
func _fire(delta: float) -> void:
	for w in weapons:
		if not bool(w["enabled"]):
			continue
		var iv := float(w["interval"])
		w["fire_t"] = float(w["fire_t"]) + delta
		if float(w["fire_t"]) < iv:
			continue
		var targets := _targets_in_range(float(w["range"]), int(w["targets"]))
		if targets.is_empty():
			w["fire_t"] = minf(float(w["fire_t"]), iv)
			continue
		w["fire_t"] = float(w["fire_t"]) - iv
		var dmg := _shot_power_of(w)
		# 消耗次数：每次开火每个模块 -1（与目标数无关 → 高射速 = 高消耗）
		var sl: Array = w["slots"]
		for i in sl.size():
			var m = sl[i]
			if m == null:
				continue
			m["left"] = float(m["left"]) - 1.0
			if float(m["left"]) <= 0.0:
				sl[i] = null
				_refill(i, w)
		var hits := float(targets.size())
		var per: float = dmg * (1.0 + 0.1 * (hits - 1.0)) / hits
		for e in targets:
			if not is_instance_valid(e):
				continue
			e.hp = float(e.hp) - per
			e.hit = 0.18
			if e.hp <= 0.0:
				_kill(e)
		_add_shot(targets, w)


## 搜寻目标：最近优先；targets < 0 表示范围内全部
func _targets_in_range(r: float, n: int) -> Array:
	var cand: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = e.position.distance_to(player.position)
		if d <= r:
			cand.append({"e": e, "d": d})
	cand.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
	var out: Array = []
	if n < 0:
		for c in cand:
			out.append(c["e"])
	else:
		for i in mini(n, cand.size()):
			out.append(cand[i]["e"])
	return out


## 弹道特效：瞬发 hitscan + 短命拖尾线（比脉冲圆环更能读出「谁在打谁」）
func _add_shot(targets: Array, w: Dictionary) -> void:
	var col: Color = Color(WEAPONS[w["id"]]["color"])
	for e in targets:
		if not is_instance_valid(e):
			continue
		shots.append({"a": player.position, "b": e.position, "t": 0.16, "c": col})
	if shots.size() > 80:
		shots = shots.slice(shots.size() - 80)


func _draw() -> void:
	for s in shots:
		var k: float = clampf(float(s["t"]) / 0.16, 0.0, 1.0)
		var c: Color = s["c"]
		draw_line(s["a"], s["b"], Color(c.r, c.g, c.b, 0.85 * k), 2.5 * k + 0.5)
		draw_circle(s["b"], 5.0 * k, Color(c.r, c.g, c.b, 0.5 * k))


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
	if e.kind == "charger" and rng.randf() < 0.5:
		_spawn_chest(e.position)
	e.queue_free()


## 宝箱：一局的主要成长来源（新武器）。品质按波次给，激光环 8 波后才入池。
func _spawn_chest_random() -> void:
	# 别刷在 HUD 底下（屏幕左上那块），否则图标被文字盖住、看不见也点不到
	var half := get_viewport().get_visible_rect().size * 0.5
	for attempt in 8:
		var ang := rng.randf() * TAU
		var d := rng.randf_range(220.0, 620.0)
		var pos: Vector2 = player.position + Vector2(cos(ang), sin(ang)) * d
		var scr: Vector2 = pos - player.position + half
		if scr.x > 600.0 or scr.y > 190.0:
			_spawn_chest(pos)
			return
	_spawn_chest(player.position + Vector2(0.0, 380.0))


func _spawn_chest(pos: Vector2) -> void:
	last_chest_t = elapsed
	# 场上同时最多 3 个，多了先清掉最旧的
	var olds := get_tree().get_nodes_in_group("chest")
	if olds.size() >= 3:
		olds[0].queue_free()
	var c = Node2D.new()
	c.set_script(load("res://scripts/chest.gd"))
	c.add_to_group("chest")
	c.position = pos
	add_child(c)


## 开箱：优先给新武器；背包满了就给一包模块
func grant_chest(from_chest: bool = false) -> void:
	if from_chest:
		last_chest_t = elapsed
	if backpack_cap >= 0 and _backpack_used() >= backpack_cap:
		var t := 2 if wave >= 12 else 1
		for k in 2:
			_spawn_pickup(player.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30.0, 50.0), t)
		return
	var pool: Array = START_POOL.duplicate()
	# 狙击枪不适合当开局武器（单发/低射速，一个人清不动），只从宝箱里出
	pool.append("sniper")
	if wave >= 8:
		pool.append("laser")
	var id: String = pool[rng.randi() % pool.size()]
	var q := 2
	if wave >= 20:
		q = 4
	elif wave >= 10:
		q = 3
	# 30% 概率再高一档，让开箱有惊喜
	if rng.randf() < 0.3:
		q = mini(5, q + 1)
	var w := _make_weapon(id, q)
	w["slots"][0] = _new_module(1)
	weapons.append(w)
	_use_weapon(weapons.size() - 1)
	_refresh_hud()


func _spawn_pickup(pos: Vector2, tier: int) -> void:
	var p = Node2D.new()
	p.set_script(load("res://scripts/pickup.gd"))
	p.add_to_group("pickup")
	p.position = pos
	p.tier = tier
	add_child(p)


## 单次伤害入口（子弹 / 精英冲撞）。接触伤害仍走 _contact 的持续扣血。
func hurt_player(dmg: float, push: Vector2, src: String = "bullet") -> void:
	if dead:
		return
	last_hit_t = elapsed
	dmg_src[src] = float(dmg_src[src]) + dmg
	hp -= dmg
	flash_t = 0.35
	_reward_damage(dmg)
	if player != null and player.has_method("add_knock"):
		player.add_knock(push)
	if hp <= 0.0:
		_die()


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
		dmg_src["contact"] = float(dmg_src["contact"]) + dmg
		last_hit_t = elapsed
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


## 补偿只给「能产出的」模块：增幅自身 0 出力，当补偿发等于发了个空槽
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


## 整板出力（不含武器基础值，只用于互相比较）
func _board_total(w = null) -> float:
	var s := 0.0
	for v in _slot_out(null, w):
		s += v
	return s


## 模块烧光后立刻用库存里「补上去出力最高」的那一阶补上同一格（保拓扑），没有就空着
## ——不能简单地「取最高阶」：增幅在没有载体相邻时出力是 0，会把格子填成空槽
func _refill(i: int, w = null) -> void:
	var ww: Dictionary = weapon if w == null else w
	var sl: Array = ww["slots"]
	var best_t := 0
	var best_v := -0.001
	for t in [4, 3, 2, 1]:
		if inventory[t] <= 0:
			continue
		sl[i] = _new_module(t)
		var v := _board_total(ww)
		sl[i] = null
		if v > best_v:
			best_v = v
			best_t = t
	if best_t > 0:
		inventory[best_t] -= 1
		sl[i] = _new_module(best_t)


## 把一个模块装进电路板。
## 规则：空槽优先；满了就试每一格「换上去之后整板出力最高」的那一格，
## 而且必须**严格高于当前出力**才换，否则留在库存等槽位空出来。
## 旧规则是「替换最低阶」，结果会把喂加法的 T1 全换掉，最后板上全是互相吃不到的加法。
func _install(t: int) -> void:
	var n: int = weapon.slots.size()
	# 增幅是「支撑件」：板上一旦有载体（共振）且支撑已经 2 个，就攒在库存里当共振的料
	if t == 3 and _installed_count(4) >= 1 and _installed_count(3) >= 2:
		inventory[3] += 1
		return
	# 空槽也算候选：统一按「装完后整板出力最高」挑位子。
	# 所以增幅在没有载体相邻时出力是 0（等于不涨），会自己留在库存里。
	var now := _board_total()
	var best := -1
	var best_v := now + 0.001
	for i in n:
		var m = weapon.slots[i]
		weapon.slots[i] = _new_module(t)
		var v := _board_total()
		weapon.slots[i] = m
		if v > best_v:
			best_v = v
			best = i
	if best >= 0:
		weapon.slots[best] = _new_module(t)
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


## 合成吃「库存」（槽位是工作区，绝不能被合成顺手拆掉）。
## 有空闲装置才能开工，产物在 _craft_tick 到点后进板子。
## kind = 0 表示自动选：先共振（最值钱），再加法（便宜），攒够余量才做增幅。
func try_craft(kind: int = 0) -> bool:
	var slot := _idle_device()
	if slot < 0:
		return false
	if kind == 0:
		kind = _auto_recipe()
	if kind == 0:
		return false
	if not RECIPES.has(kind):
		return false
	if level < int(CRAFT_UNLOCK[kind]):
		return false
	var src := int(RECIPES[kind]["from"])
	if inventory[src] < 2:
		return false
	inventory[src] -= 2
	var t := float(RECIPES[kind]["time"])
	devices[slot]["kind"] = kind
	devices[slot]["total"] = t
	devices[slot]["left"] = t
	return true


func _auto_recipe() -> int:
	# 板子没满 → 先拿加法把格子垫起来（加法是唯一的「即插即用」底料）
	# 板子满了 → 攒增幅，够 2 个立刻换共振（共振是唯一的载体，27 的基量）
	if _count_filled() < weapon.slots.size():
		if level >= int(CRAFT_UNLOCK[2]) and inventory[1] >= 2:
			return 2
		return 0
	if level >= int(CRAFT_UNLOCK[4]) and inventory[3] >= 2:
		return 4
	if level >= int(CRAFT_UNLOCK[3]) and inventory[1] >= 2:
		return 3
	if level >= int(CRAFT_UNLOCK[2]) and inventory[1] >= 2:
		return 2
	return 0


func _installed_count(t: int) -> int:
	var n := 0
	for m in weapon.slots:
		if m != null and int(m.tier) == t:
			n += 1
	return n


func add_module(tier: int) -> void:
	for i in weapon.slots.size():
		if weapon.slots[i] == null:
			weapon.slots[i] = _new_module(tier)
			return
	inventory[tier] += 1


## 总 DPS：所有启用武器之和（多目标按分摊公式）
func cur_dps() -> float:
	var s := 0.0
	for w in weapons:
		if bool(w["enabled"]):
			s += _weapon_dps(w)
	return s


## 总弹药消耗/秒：每把启用武器各自按「每次开火每个模块 -1」累加
func cur_burn() -> float:
	var b := 0.0
	for w in weapons:
		if not bool(w["enabled"]):
			continue
		var iv := float(w["interval"])
		for m in w["slots"]:
			if m != null:
				b += 1.0 / (float(TIERS[m.tier].uses) * iv)
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
	hud_status.text = "HP %d/%d    波次 %d · %s    时间 %s    等级 %d" % [
		int(maxf(hp, 0.0)), int(max_hp), wave, _plan()["name"], _fmt_time(elapsed), level
	]
	var net := cur_drop() - cur_burn()
	var sign_s := "+" if net >= 0.0 else ""
	hud_ammo.text = "DPS %5.1f    净弹药 %s%.2f/s    库存 %d    槽位 %d/%d" % [
		cur_dps(), sign_s, net, _inv_total(),
		_count_filled(), weapon.slots.size()
	]
	if _count_filled() == 0:
		hud_ammo.text += "    模块耗尽 · 仅基础 %.1f" % float(weapon.base)
	hud_ammo.text += "    装置 %d/%d 台    背包 %d%s" % [
		_busy_devices(), devices.size(), _backpack_used(),
		"" if backpack_cap < 0 else "/%d" % backpack_cap
	]
	hud_ammo.add_theme_color_override("font_color",
		Color(0.7, 0.95, 0.85) if net >= 0.0 else Color(1.0, 0.55, 0.5))
	_refresh_weapon_panel()


## 左侧武器栏：每把武器一行，显示开关状态与「当前 DPS / 理论 DPS」
func _refresh_weapon_panel() -> void:
	if wpanel == null:
		return
	var s := ""
	for i in weapons.size():
		var w: Dictionary = weapons[i]
		var kd: Dictionary = WEAPONS[w["id"]]
		var on: bool = bool(w["enabled"])
		var mark := "▸" if i == sel else " "
		var cur := _weapon_dps(w) if on else 0.0
		var th := _theory_dps(w)
		var state := "[开]" if on else "[关]"
		s += "%s%d %s %s %s  %s  当前 %5.1f / 理论 %5.1f\n" % [
			mark, i + 1, state, str(kd["name"]), QUALITY_NAME[int(w["quality"])],
			("%d槽" % (w["slots"] as Array).size()), cur, th
		]
	wpanel.text = s
	wpanel.modulate = Color(1, 1, 1, 0.95)


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
	lines.append("武器  %s·%s·%d 槽    射程 %.0f    间隔 %.2fs    目标 %s    基础 %.1f    单次出力 %.1f    当前 DPS %.1f" % [
		str(WEAPONS[weapon["id"]]["name"]), QUALITY_NAME[int(weapon["quality"])],
		(weapon["slots"] as Array).size(), float(weapon["range"]), float(weapon["interval"]),
		"全部" if int(weapon["targets"]) < 0 else str(int(weapon["targets"])),
		float(weapon["base"]), _shot_power(), _weapon_dps(weapon)
	])
	if weapons.size() > 1:
		var names: Array = []
		for i in weapons.size():
			var w: Dictionary = weapons[i]
			names.append("%d.%s%s(%s)" % [
				i + 1, "▸" if i == sel else "", str(WEAPONS[w["id"]]["name"]),
				"开" if bool(w["enabled"]) else "关"
			])
		lines.append("切换   " + "   ".join(names) + "    1-9 选   F 开关")
	build_text.text = "\n".join(lines)

	var info: Array = []
	info.append("库存    基础 %d    加法 %d    增幅 %d    共振 %d" % [
		inventory[1], inventory[2], inventory[3], inventory[4]
	])
	info.append("受击补偿    +%d 个模块（每 %d HP 补 1 个）" % [
		modules_from_damage, int(DAMAGE_PER_MODULE)
	])
	info.append("")
	info.append("等级 %d  →  %d     需要 %d 个模块     [U]" % [
		level, level + 1, level_cost()
	])
	var keys := {2: "C", 3: "V", 4: "B"}
	var idle := _idle_device()
	for t in [2, 3, 4]:
		var src := int(RECIPES[t]["from"])
		var state := "解锁于 Lv%d" % int(CRAFT_UNLOCK[t])
		if level >= int(CRAFT_UNLOCK[t]):
			var mine := 0
			for d in devices:
				if int(d["kind"]) == t:
					mine += 1
			if inventory[src] < 2:
				state = "需 2 个%s" % TIERS[src].name
			elif idle < 0:
				state = "装置全忙"
			elif mine > 0:
				state = "可再开一台"
			else:
				state = "可合成"
		info.append("    [%s] 2×%s → 1×%s    %2ds    %s" % [
			keys[t], TIERS[src].name, TIERS[t].name, int(RECIPES[t]["time"]), state
		])
	if devices.size() < DEVICE_MAX:
		info.append("    [X] 造装置（当前 %d 台，空闲 %d）  需要 %d 个基础" % [
			devices.size(), devices.size() - _busy_devices(), device_cost()
		])
	else:
		info.append("    [X] 装置已满（%d 台）" % devices.size())
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
			# 增幅不产出，显示「每次给每个邻居加多少 × 给几个邻居」
			var fed := 0
			for j in _neighbors(i):
				var nb = weapon.slots[j]
				if nb != null and int(nb.tier) != 3:
					fed += 1
			out_l.text = "→%.0f×%d" % [float(TIERS[3].boost), fed]
		else:
			out_l.text = "%.1f" % float(out[i])
		panel.add_child(out_l)

		var use_l := Label.new()
		use_l.position = Vector2(0, 53)
		use_l.size = Vector2(cell, 18)
		use_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		use_l.add_theme_font_size_override("font_size", 13)
		use_l.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
		use_l.text = "" if m == null else "%d/%d" % [int(m.left), int(m.max)]
		panel.add_child(use_l)
