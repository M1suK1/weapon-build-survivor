# ============================================================================
# 16. 开发控制台（docs/plan-v4.md §1）
# ============================================================================
const CONSOLE_MAX_LINES := 200
const CONSOLE_CMDS := ["help", "speed", "level", "wave", "weapon", "give", "device",
	"god", "hp", "kill", "spawn", "fps", "restart", "clear"]


## 屏幕下 45%：深色底 + 左侧青色竖线。输出区可滚动，输入行贴底。
func _make_console(parent: Node) -> void:
	console_root = Control.new()
	console_root.position = Vector2(0, 396)
	console_root.size = Vector2(1280, 324)
	console_root.mouse_filter = Control.MOUSE_FILTER_STOP
	console_root.process_mode = Node.PROCESS_MODE_ALWAYS
	console_root.visible = false
	parent.add_child(console_root)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.92)
	sb.border_color = Color(0.35, 0.85, 0.92, 0.85)
	sb.set_border_width_all(0)
	sb.border_width_left = 4
	panel.add_theme_stylebox_override("panel", sb)
	console_root.add_child(panel)

	# 顶部 1px 分隔线：把控制台和上面的 HUD 切开
	var top_line := ColorRect.new()
	top_line.color = Color(0.22, 0.34, 0.44, 0.9)
	top_line.position = Vector2(4, 0)
	top_line.size = Vector2(1276, 1)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	console_root.add_child(top_line)

	_label(console_root, Vector2(20, 8), 17, Color(0.62, 0.95, 1.0)).text = "控制台"
	_label(console_root, Vector2(92, 11), 13, Color(0.55, 0.60, 0.68)).text = \
		"help 看命令 · ↑↓ 历史 · Tab 补全 · ; 分隔 · Esc 关闭"

	console_rich = RichTextLabel.new()
	console_rich.position = Vector2(20, 38)
	console_rich.size = Vector2(1240, 206)
	console_rich.bbcode_enabled = true
	console_rich.scroll_active = true
	console_rich.scroll_following = true
	console_rich.mouse_filter = Control.MOUSE_FILTER_PASS
	console_rich.add_theme_font_size_override("normal_font_size", 14)
	console_root.add_child(console_rich)

	console_hint = _label(console_root, Vector2(20, 250), 13, Color(0.50, 0.56, 0.64))
	console_hint.text = ""

	_label(console_root, Vector2(20, 274), 16, Color(0.62, 0.95, 1.0)).text = ">"
	console_input = LineEdit.new()
	console_input.position = Vector2(42, 266)
	console_input.size = Vector2(1214, 42)
	console_input.add_theme_font_size_override("font_size", 16)
	console_input.placeholder_text = "输入命令，回车执行（输入 help 查看全部命令）"
	console_input.caret_blink = true
	console_input.text_submitted.connect(_console_submit)
	console_input.text_changed.connect(_console_hint_update)
	console_root.add_child(console_input)


## 暂停来源：任何一个来源还在，树就保持暂停（避免关掉构筑屏时把选卡也一起解除）
func _set_pause(key: String, on: bool) -> void:
	if on:
		pause_reasons[key] = true
	else:
		pause_reasons.erase(key)
	get_tree().paused = not pause_reasons.is_empty()


func _open_console() -> void:
	if console_root == null or console_open or dead or picking:
		return
	console_open = true
	console_root.visible = true
	_set_pause("console", true)
	console_input.text = ""
	console_hint.text = ""
	if console_lines.is_empty():
		_console_print("输入 help 看命令（↑↓ 历史 · Tab 补全 · Esc 关闭）")
	console_input.grab_focus.call_deferred()


func _close_console() -> void:
	if not console_open:
		return
	console_open = false
	if console_root != null:
		console_root.visible = false
	if console_input != null:
		console_input.release_focus()
	_set_pause("console", false)


func _console_submit(raw: String) -> void:
	if console_input != null:
		console_input.text = ""
		console_input.caret_column = 0
	if console_hint != null:
		console_hint.text = ""
	# 批量：`god; speed 4; level 20`（§1.2）
	for one in raw.split(";", false):
		var line := one.strip_edges()
		if line.is_empty():
			continue
		if console_hist.is_empty() or String(console_hist[console_hist.size() - 1]) != line:
			console_hist.append(line)
			if console_hist.size() > 50:
				console_hist.pop_front()
		console_hist_i = console_hist.size()
		_console_print("> " + line, "#7f9bb0")
		_console_print(_console_run(line))


## ↑↓ 翻历史：下标停在 size 时表示「空输入」
func _console_hist_move(d: int) -> void:
	if console_hist.is_empty() or console_input == null:
		return
	console_hist_i = clampi(console_hist_i + d, 0, console_hist.size())
	console_input.text = "" if console_hist_i >= console_hist.size() else String(console_hist[console_hist_i])
	console_input.caret_column = console_input.text.length()


func _console_hint_update(txt: String) -> void:
	if console_hint == null:
		return
	var pre := txt.strip_edges().to_lower()
	if pre == "" or pre.contains(" "):
		console_hint.text = ""
		return
	var hits: Array = []
	for c in CONSOLE_CMDS:
		if String(c).begins_with(pre):
			hits.append(c)
	console_hint.text = ("匹配：" + "  ".join(hits)) if not hits.is_empty() else ""


## Tab：补全命令名；give 的第二个参数补模块 id（§1.1）
func _console_complete() -> void:
	if console_input == null:
		return
	var txt := console_input.text
	var parts := txt.strip_edges().split(" ", false)
	if parts.is_empty():
		console_input.text = "help"
		console_input.caret_column = 4
		return
	if txt.strip_edges().contains(" "):
		var head := String(parts[0]).to_lower()
		var prefix := String(parts[parts.size() - 1])
		var pool: Array = MODULES.keys() if head == "give" else (WEAPONS.keys() if head == "weapon" else [])
		for k in pool:
			var ks := String(k)
			if ks.begins_with(prefix) and ks != prefix:
				parts[parts.size() - 1] = ks
				console_input.text = " ".join(parts)
				console_input.caret_column = console_input.text.length()
				return
		return
	var pre := String(parts[0]).to_lower()
	for c in CONSOLE_CMDS:
		if String(c).begins_with(pre) and String(c) != pre:
			console_input.text = String(c) + " "
			console_input.caret_column = console_input.text.length()
			return


## 输出：`?` 红字（未知命令）、`!` 黄字（参数错）、其余正文绿字；只留最近 200 行
func _console_print(text: String, hex: String = "") -> void:
	if text == "":
		return
	var col := hex
	if col == "":
		if text.begins_with("?"):
			col = "#ff8f8f"
			text = text.substr(1)
		elif text.begins_with("!"):
			col = "#ffd27f"
			text = text.substr(1)
		else:
			col = "#cfe8d8"
	for ln in text.split("\n"):
		console_lines.append("[color=%s]%s[/color]" % [col, ln])
	while console_lines.size() > CONSOLE_MAX_LINES:
		console_lines.pop_front()
	if console_rich != null:
		console_rich.text = "\n".join(console_lines)
		console_rich.scroll_to_line(maxi(0, console_lines.size() - 1))


func _console_run(line: String) -> String:
	var parts := line.split(" ", false)
	if parts.is_empty():
		return ""
	var cmd := String(parts[0]).to_lower()
	var args: Array = []
	for i in range(1, parts.size()):
		args.append(String(parts[i]))
	match cmd:
		"help": return _cmd_help(args)
		"speed": return _cmd_speed(args)
		"level": return _cmd_level(args)
		"wave": return _cmd_wave(args)
		"weapon": return _cmd_weapon(args)
		"give": return _cmd_give(args)
		"device": return _cmd_device(args)
		"god": return _cmd_god(args)
		"hp": return _cmd_hp(args)
		"kill": return _cmd_kill(args)
		"spawn": return _cmd_spawn(args)
		"fps": return _cmd_fps(args)
		"restart": return _cmd_restart(args)
		"clear": return _cmd_clear(args)
	return _console_unknown(cmd)


## 未知命令：编辑距离 ≤2 给一条「你是不是想输入」
func _console_unknown(cmd: String) -> String:
	var best := ""
	var bd := 99
	for c in CONSOLE_CMDS:
		var d := _edit_dist(cmd, String(c))
		if d < bd:
			bd = d
			best = String(c)
	var tail := "（你是不是想输入 %s）" % best if bd <= 2 else ""
	return "?未知命令：%s%s" % [cmd, tail]


func _edit_dist(a: String, b: String) -> int:
	var n := a.length()
	var m := b.length()
	var dp: Array = []
	for i in n + 1:
		var row: Array = []
		for j in m + 1:
			row.append(0)
		dp.append(row)
	for i in n + 1:
		dp[i][0] = i
	for j in m + 1:
		dp[0][j] = j
	for i in range(1, n + 1):
		for j in range(1, m + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			dp[i][j] = mini(mini(int(dp[i - 1][j]) + 1, int(dp[i][j - 1]) + 1), int(dp[i - 1][j - 1]) + cost)
	return int(dp[n][m])


func _cmd_help(args: Array) -> String:
	if args.is_empty():
		return "运行  speed <倍率> / level <n|+n> / wave <n> / restart\n" \
			+ "战斗  weapon <id> [品质1-5] / give <模块id> <数量> / device [台数] / god / hp <数值>\n" \
			+ "敌人  kill / spawn <种类> <数量> / fps / clear / help [命令]"
	var c := String(args[0]).to_lower()
	match c:
		"speed": return "speed <倍率>：0.25–8，speed 1 复原；倍速≠1 时 HUD 显示 ×N"
		"level": return "level <n> 直接设等级 / level +n 连升 n 级（不扣材料，每次弹四选一）"
		"wave": return "wave <n>：跳到第 n 波并触发开波（宝箱/精英）"
		"weapon": return "weapon <id> [品质1-5]：获得并选中一把武器（id 见 reference §1）"
		"give": return "give <模块id> <数量>：往库存加模块"
		"device": return "device [台数]：免费造装置（默认 1 台，上限 %d 台）" % DEVICE_MAX
		"god": return "god：无敌开关（HUD 左上显示 GOD）"
		"hp": return "hp <数值>：设置当前 HP"
		"kill": return "kill：清空场上敌人（不计击杀、不掉落）"
		"spawn": return "spawn <种类> <数量>：在屏外生成指定敌人（flood/runner/rock/shooter/charger）"
		"fps": return "fps：切换 F3 调试面板"
		"restart": return "restart：重开一局"
		"clear": return "clear：清空输出区"
		"help": return "help [命令]：列出全部命令 / 单条用法"
	return "!未知命令：%s" % c


func _cmd_speed(args: Array) -> String:
	if args.is_empty():
		return "!用法：speed <倍率>（当前 %.2f）" % Engine.time_scale
	var v := String(args[0]).to_float()
	if v < 0.25 or v > 8.0:
		return "!倍速范围 0.25–8：%s" % String(args[0])
	Engine.time_scale = v
	return "倍速 → %.2f" % v


func _cmd_level(args: Array) -> String:
	if args.is_empty():
		return "!用法：level <n> 或 level +n（当前 Lv%d，升级需要 %d 个模块，现有 %d）" % [
			level, level_cost(), _inv_total()]
	var txt := String(args[0])
	if txt.begins_with("+"):
		var n := maxi(1, int(txt.substr(1)))
		_gain_levels(n)
		return "连升 %d 级（一张一张选）" % n
	var n := int(txt)
	if n <= level:
		return "!等级只能往上：当前 Lv%d" % level
	level = n - 1
	_gain_level()
	return "等级 → %d（弹一次四选一）" % n


func _cmd_wave(args: Array) -> String:
	if args.is_empty():
		return "!用法：wave <n>（当前第 %d 波）" % wave
	var n := maxi(1, int(String(args[0])))
	elapsed = float(n - 1) * WAVE_SEC
	wave = n
	_on_wave_start()
	return "跳到第 %d 波" % wave


func _cmd_weapon(args: Array) -> String:
	if args.is_empty():
		var names: Array = []
		for w in weapons:
			names.append(String(w["id"]))
		return "当前武器：" + (", ".join(names) if not names.is_empty() else "无")
	var id := String(args[0])
	if not WEAPONS.has(id):
		return "!未知武器：%s（pistol/smg/shotgun/sniper/laser/beam/grenade/blade）" % id
	var q := clampi(int(String(args[1])) if args.size() > 1 else 3, 1, 5)
	for i in weapons.size():
		if String(weapons[i]["id"]) == id:
			_use_weapon(i)
			return "选中已有 %s（%s）" % [id, String(QUALITY_NAME[q])]
	if _backpack_used() >= backpack_cap:
		return "!背包已满（%d/%d）：先按 F 关掉不用的武器，或合成掉一些模块" % [_backpack_used(), backpack_cap]
	weapons.append(_make_weapon(id, q))
	_use_weapon(weapons.size() - 1)
	_refresh_hud()
	return "获得并选中 %s（%s）" % [id, String(QUALITY_NAME[q])]


func _cmd_give(args: Array) -> String:
	if args.size() < 2:
		return "!用法：give <模块id> <数量>"
	var id := String(args[0])
	if not MODULES.has(id):
		return "!未知模块：%s" % id
	var n := maxi(1, int(String(args[1])))
	_add_inv(id, n)
	_refresh_hud()
	return "获得 %s ×%d（库存 %d）" % [id, n, _inv(id)]


func _cmd_device(args: Array) -> String:
	var n := maxi(1, int(String(args[0]))) if not args.is_empty() else 1
	var added := 0
	for i in n:
		if devices.size() >= DEVICE_MAX:
			break
		var nd := _new_device()
		nd["auto"] = true
		devices.append(nd)
		added += 1
	return "装置 +%d（共 %d/%d）" % [added, devices.size(), DEVICE_MAX]


func _cmd_god(_args: Array) -> String:
	god = not god
	_refresh_hud()
	return "无敌 %s" % ("开" if god else "关")


func _cmd_hp(args: Array) -> String:
	if args.is_empty():
		return "!用法：hp <数值>（当前 %d/%d）" % [int(hp), int(max_hp)]
	var v := clampf(String(args[0]).to_float(), 1.0, 99999.0)
	max_hp = maxf(max_hp, v)
	hp = v
	_refresh_hud()
	return "HP = %d / %d" % [int(hp), int(max_hp)]


func _cmd_kill(args: Array) -> String:
	if not args.is_empty():
		return "!kill 不带参数：清空场上全部敌人"
	var n := 0
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
			n += 1
	return "清空 %d 只敌人（不计击杀、不掉落）" % n


func _cmd_spawn(args: Array) -> String:
	if args.is_empty():
		return "!用法：spawn <种类> <数量>（flood/runner/rock/shooter/charger）"
	var kind := String(args[0])
	if not ENEMY_KINDS.has(kind):
		return "!未知敌人类型：%s" % kind
	var n := clampi(int(String(args[1])) if args.size() > 1 else 1, 1, 200)
	var made := 0
	for i in n:
		if enemies.size() >= MAX_ENEMIES:
			break
		var ang := rng.randf() * TAU
		# 屏外生成：和正常刷怪同一个半径区间（docs/plan-v4.md §3.4）
		_spawn_enemy_at(player.position + Vector2.from_angle(ang) * rng.randf_range(SPAWN_R_MIN, SPAWN_R_MAX), kind)
		made += 1
	return "屏外生成 %s ×%d" % [kind, made]


func _cmd_fps(_args: Array) -> String:
	dbg_on = not dbg_on
	if dbg_root != null:
		dbg_root.visible = dbg_on
	_refresh_dbg_panel(enemies.size())
	return "F3 调试面板 %s" % ("开" if dbg_on else "关")


func _cmd_restart(_args: Array) -> String:
	pause_reasons.clear()
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()
	return "重开"


func _cmd_clear(_args: Array) -> String:
	console_lines.clear()
	if console_rich != null:
		console_rich.text = ""
	return ""
