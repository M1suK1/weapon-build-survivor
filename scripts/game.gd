extends Node2D
## 主控制器：刷怪、开火、掉落、构筑、HUD。

## 模块目录（方案 v2.6 §1）。cls 决定网络里怎么结算：
##   flat  = 老实给 rate（默认）
##   mirror= 加法：把相邻「比自己低阶」的模块读数再镜像一份
##   boost = 增幅：自身 0 出力，把 boost 加到相邻非 boost 模块的最终输出上
##   reson = 共振：相邻同 cls 的模块基础值 +50%
## bind 非空 = 武器专属模块：只在该武器板上生效，否则只剩 rate（方案 §1.3）
const MODULES := {
	"base":   {"name": "基础",   "tier": 1, "rate": 1.0,  "uses": 45.0,  "cls": "flat",   "color": Color(0.56, 0.70, 1.0)},
	"add":    {"name": "加法",   "tier": 2, "rate": 3.0,  "uses": 60.0,  "cls": "mirror", "color": Color(0.49, 0.94, 0.66)},
	"amp":    {"name": "增幅",   "tier": 3, "rate": 0.0,  "uses": 120.0, "cls": "boost",  "color": Color(0.36, 0.88, 0.82), "boost": 5.0},
	"reson":  {"name": "共振",   "tier": 4, "rate": 27.0, "uses": 100.0, "cls": "reson",  "color": Color(1.0, 0.56, 0.64)},
	# --- 通用配方（10 个）：一点点、不喧宾夺主的增益 ---
	"edge":   {"name": "锋锐刃", "tier": 2, "rate": 2.0,  "uses": 40.0,  "cls": "flat",   "color": Color(0.86, 0.90, 0.98), "note": "单发倍率 +8%"},
	"temper": {"name": "淬火块", "tier": 2, "rate": 4.5,  "uses": 30.0,  "cls": "flat",   "color": Color(0.98, 0.72, 0.48), "note": "纯数值，烧得快"},
	"light":  {"name": "轻量片", "tier": 2, "rate": 1.5,  "uses": 90.0,  "cls": "flat",   "color": Color(0.72, 0.92, 0.86), "note": "每次只烧 0.5 次使用次数"},
	"extend": {"name": "增程器", "tier": 2, "rate": 1.0,  "uses": 50.0,  "cls": "flat",   "color": Color(0.60, 0.82, 1.0),  "note": "射程 +25"},
	"calib":  {"name": "校准镜", "tier": 3, "rate": 1.0,  "uses": 45.0,  "cls": "flat",   "color": Color(0.78, 0.86, 0.98), "note": "开火间隔 ×0.95"},
	"pierce": {"name": "贯穿弹", "tier": 3, "rate": 6.0,  "uses": 60.0,  "cls": "flat",   "color": Color(1.0, 0.86, 0.60),  "note": "穿透 +1（身后 120px 再吃 60%）"},
	"breaker":{"name": "破甲锥", "tier": 3, "rate": 5.0,  "uses": 50.0,  "cls": "flat",   "color": Color(0.90, 0.62, 0.42), "note": "对精英/磐石 +20%"},
	"coolant":{"name": "冷却片", "tier": 3, "rate": 3.0,  "uses": 70.0,  "cls": "flat",   "color": Color(0.56, 0.86, 0.94), "note": "开火间隔 ×0.92"},
	"recycle":{"name": "回收片", "tier": 3, "rate": 2.0,  "uses": 80.0,  "cls": "flat",   "color": Color(0.66, 0.90, 0.62), "note": "20% 概率给相邻 +3 次寿命"},
	"overload":{"name":"过载核", "tier": 4, "rate": 18.0, "uses": 70.0,  "cls": "flat",   "color": Color(1.0, 0.52, 0.42),  "note": "单发倍率 ×1.15"},
	"tempo":  {"name": "时序核", "tier": 4, "rate": 15.0, "uses": 90.0,  "cls": "flat",   "color": Color(0.86, 0.74, 1.0),  "note": "连击 +4%/发，上限 +40%"},
	# --- 武器特化配方（6 个）：只绑一把枪，换的是「玩法」不是数字 ---
	"multi":  {"name": "多膛组", "tier": 3, "rate": 6.0,  "uses": 55.0,  "cls": "flat",   "color": Color(0.90, 0.78, 1.0),  "note": "狙击枪目标数 +1", "bind": "sniper"},
	"belt":   {"name": "轻质弹链","tier": 3, "rate": 2.0, "uses": 100.0, "cls": "flat",   "color": Color(0.98, 0.84, 0.50), "note": "冲锋枪每次只烧 0.35 次", "bind": "smg"},
	"spread": {"name": "扩散器", "tier": 3, "rate": 5.0,  "uses": 50.0,  "cls": "flat",   "color": Color(1.0, 0.70, 0.54),  "note": "霰弹枪目标数 +2", "bind": "shotgun"},
	"focus":  {"name": "聚焦环", "tier": 4, "rate": 14.0, "uses": 80.0,  "cls": "flat",   "color": Color(0.70, 0.94, 1.0),  "note": "镭射倍率上限 +180%", "bind": "laser"},
	"charge": {"name": "集束装药","tier": 3, "rate": 5.5, "uses": 45.0,  "cls": "flat",   "color": Color(1.0, 0.60, 0.36),  "note": "榴弹爆炸半径 +40", "bind": "grenade"},
	"blade":  {"name": "长刃",   "tier": 3, "rate": 5.0,  "uses": 70.0,  "cls": "flat",   "color": Color(0.92, 0.86, 0.70), "note": "环绕刃半径 +25、倍率 +20%", "bind": "blade"},
}
## 配方 = 2 个「低一阶」的任意模块（T2 吃 3 个基础）。时间按阶区分，特化件更慢。
const CRAFT_COST := {2: 3, 3: 2, 4: 2}
const CRAFT_TIME := {2: 5.0, 3: 10.0, 4: 18.0}
const CRAFT_UNLOCK := {"add": 4, "amp": 8, "reson": 16, "edge": 5, "temper": 5, "light": 6, "extend": 7,
	"calib": 9, "pierce": 11, "breaker": 12, "coolant": 13, "recycle": 14, "overload": 17, "tempo": 18,
	"multi": 12, "belt": 12, "spread": 13, "focus": 20, "charge": 15, "blade": 15}
## UI / 自动合成都按这个顺序遍历
const MOD_ORDER := ["add", "amp", "reson", "edge", "temper", "light", "extend", "calib", "pierce",
	"breaker", "coolant", "recycle", "overload", "tempo", "multi", "belt", "spread", "focus", "charge", "blade"]
const CORE_ORDER := ["base", "add", "amp", "reson"]

## 升级三选一 buff 池（方案 §7.5）。cat：atk 攻击 / eco 经济 / sur 生存。
## 每张卡只给 1 层，max 是层数上限；层数影响见 _weapon_mods / _new_module / device_cost 等处。
const BUFFS := {
	"pierce": {"name": "穿透", "cat": "atk", "rar": "blue", "max": 3, "desc": "主目标身后 120px 内最近敌人吃 60%"},
	"elite": {"name": "破甲", "cat": "atk", "rar": "blue", "max": 4, "desc": "对冲刺精英与磐石 +25% 伤害"},
	"rate": {"name": "攻速", "cat": "atk", "rar": "white", "max": 8, "desc": "开火间隔 ×0.92"},
	"power": {"name": "强化", "cat": "atk", "rar": "white", "max": 6, "desc": "伤害倍率 ×1.10"},
	"range": {"name": "射程", "cat": "atk", "rar": "white", "max": 4, "desc": "射程 +60"},
	"target": {"name": "多目标", "cat": "atk", "rar": "gold", "max": 3, "desc": "每把武器目标数 +1"},
	"drop": {"name": "掉落", "cat": "eco", "rar": "white", "max": 6, "desc": "敌人掉落率 +0.04"},
	"uses": {"name": "耐久", "cat": "eco", "rar": "white", "max": 5, "desc": "新模块寿命 ×1.08"},
	"craft": {"name": "工艺", "cat": "eco", "rar": "blue", "max": 5, "desc": "合成时间 ×0.90"},
	"device": {"name": "降本", "cat": "eco", "rar": "blue", "max": 4, "desc": "装置造价 ×0.92"},
	"hp": {"name": "体魄", "cat": "sur", "rar": "white", "max": 6, "desc": "最大 HP +15，立即回血"},
	"contact": {"name": "护甲", "cat": "sur", "rar": "white", "max": 5, "desc": "接触伤害 ×0.92"},
	"regen": {"name": "恢复", "cat": "sur", "rar": "blue", "max": 4, "desc": "脱战回血 +0.5/s"},
	"iframe": {"name": "闪避", "cat": "sur", "rar": "gold", "max": 3, "desc": "受击无敌帧 +0.10s"},
}

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
	"sniper": {"name": "狙击枪", "range": 640.0, "interval": 2.50, "targets": 1, "mul": 1.00, "base": 3.0, "color": Color(0.70, 0.95, 0.75), "prefer": "shooter,charger"},
	"laser": {"name": "激光环", "range": 420.0, "interval": 40.0, "targets": -1, "mul": 4.00, "base": 2.0, "color": Color(0.85, 0.55, 1.00)},
	"beam": {"name": "镭射", "range": 380.0, "interval": 0.20, "targets": 1, "mul": 1.00, "base": 0.6, "color": Color(0.42, 0.98, 0.92), "prefer": "highest_hp"},
	"grenade": {"name": "榴弹炮", "range": 460.0, "interval": 1.60, "targets": 1, "mul": 1.30, "base": 0.8, "color": Color(1.00, 0.52, 0.22)},
	"blade": {"name": "环绕刃", "range": 105.0, "interval": 1.80, "targets": -1, "mul": 0.80, "base": 0.4, "color": Color(0.80, 0.92, 0.45)},
}
## 开局随机一把（激光环 wave 8 之后才入池）
const START_POOL := ["pistol", "smg", "shotgun"]
const WAVE_SEC := 40.0
const DROP_CHANCE := 0.30
const CHEST_GUARANTEE := 90.0
const HP_BASE := 1.80
const HP_GROWTH := 1.118
const SPAWN_BASE := 1.20
const SPAWN_GROWTH := 0.620
const MAX_ENEMIES := 420
const LEVEL_COST_BASE := 3.0
const LEVEL_COST_GROWTH := 1.18
const CONTACT_DPS := 2.2
## 受击补偿：每损失这么多 HP 补 1 个模块（弹药系统的劣势补偿，挨打就回填）
const DAMAGE_PER_MODULE := 8.0
const CROWD_CAP := 6
const FIRE_RANGE := 260.0
const PULSE_DUR := 0.30

## 敌人种类：hp_mult = (100 / 速度)^1.5 —— 速度越快血越少。
## 以后加新怪直接套这个公式，不用一张张手调。
const ENEMY_KINDS := {
	"flood": {"speed": 100.0, "hp_mult": 1.00, "radius": 13.0, "color": Color(0.92, 0.30, 0.34)},
	"runner": {"speed": 205.0, "hp_mult": 0.45, "radius": 9.0, "color": Color(1.00, 0.70, 0.26)},
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
var backpack_cap := 6
var weapons: Array = []
var weapon: Dictionary = {}
var sel := 0
## 构筑屏里当前选中的配方（MOD_ORDER 下标），[Q]/[E] 切换
var recipe_sel := 0
var inventory := {}
## 升级三选一：buffs[id] = 层数；offer = 本次 4 张卡；picking = 正在选卡（暂停战斗）
var buffs := {}
var offer: Array = []
var picking := false
var reroll_used := false
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
var pick_root: Control
var build_text: Label
var board_root: Control
var build_info: Label
var flash: ColorRect
var flash_t := 0.0
var pulse_t := 0.0
var shots: Array = []
var blast_fx: Array = []

# --- 合成：每台装置一个并行位，装置可反复买（材料堆积就多做几台） ---
var devices: Array = []  # [{"kind": int, "left": float, "total": float}]，kind=0 表示空闲
var craft_seq := 0
## 各阶实际合出来的数量（平衡观察用，也进 playtest 日志）
var crafted := {}

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
var shot_pick := false
var pick_delay := 0.0
var pick_wait := 0.0
var start_force := ""
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
		elif a.begins_with("start="):
			start_force = a.substr(6)
		elif a.begins_with("pickdelay="):
			pick_delay = float(a.substr(10))
		elif a == "shotpick":
			shot_pick = true
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
	if start_force != "":
		start_id = start_force
	weapons.append(_make_weapon(start_id, 3))
	_use_weapon(0)
	for i in weapon.slots.size():
		weapon.slots[i] = _new_module("base")
	_add_inv("base", 2)
	devices.append(_new_device())
	_make_player()
	_make_hud()
	_refresh_hud()


## 模块寿命带 ±15% 抖动：否则同一批装上去的模块会同时烧光，DPS 出现断崖
func _new_module(mid: String) -> Dictionary:
	var d: Dictionary = MODULES[mid]
	var u := float(d["uses"]) * rng.randf_range(0.85, 1.15) * pow(1.08, float(_bl("uses")))
	return {"id": mid, "tier": int(d["tier"]), "left": u, "max": u}


func _new_device() -> Dictionary:
	return {"kind": "", "left": 0.0, "total": 0.0}


## 第 (n+1) 台装置的价格：开局那台免费，第 2 台 12、第 3 台 20、第 4 台 35 ……
func device_cost() -> int:
	var base := DEVICE_COST_BASE * pow(DEVICE_COST_GROWTH, maxf(0.0, devices.size() - 1.0))
	return int(round(base * pow(0.92, float(_bl("device")))))


func _idle_device() -> int:
	for i in devices.size():
		if String(devices[i]["kind"]) == "":
			return i
	return -1


func _busy_devices() -> int:
	var n := 0
	for d in devices:
		if String(d["kind"]) != "":
			n += 1
	return n


## 用基础模块造一台新装置（材料堆积时的唯一出口）
func buy_device() -> bool:
	if devices.size() >= DEVICE_MAX:
		return false
	if _backpack_used() >= backpack_cap:
		return false
	var cost := device_cost()
	if _inv("base") < cost:
		return false
	_take_inv("base", cost)
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
	# 视野缩放：刷怪半径 540–660，不缩小镜头的话敌人全在屏幕外，看不到「一圈合围」
	cam.zoom = Vector2(0.72, 0.72)
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
	hud_tip.text = "WASD 移动   TAB 构筑   U 升级   Q/E 选配方  C 合成   X 造装置   1-9 选武器  F 开关   R 重开"

	wpanel = _label(layer, Vector2(18, 84), 17, Color(0.78, 0.86, 1.0))

	build_root = Control.new()
	build_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	build_root.visible = false
	build_root.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(build_root)

	pick_root = Control.new()
	pick_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	pick_root.visible = true
	layer.add_child(pick_root)
	var pbg := ColorRect.new()
	pbg.color = Color(0.03, 0.04, 0.07, 0.86)
	pbg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pick_root.add_child(pbg)

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
	build_info.position = Vector2(660, 190)
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
	if picking:
		if k >= KEY_1 and k <= KEY_4:
			_take_card(k - KEY_1)
		elif k == KEY_T:
			_reroll_recipe()
		return
	if k == KEY_TAB and not dead:
		_toggle_build()
	elif k == KEY_U:
		if try_level():
			_pass()
	elif k == KEY_C:
		try_craft(String(MOD_ORDER[recipe_sel]))
		_pass()
	elif k == KEY_V:
		try_craft("amp")
		_pass()
	elif k == KEY_B:
		try_craft("reson")
		_pass()
	elif k == KEY_Q:
		_cycle_recipe(-1)
	elif k == KEY_E:
		_cycle_recipe(1)
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
	# 选卡界面会冻结 elapsed，截图逻辑若还在等 shotat 就会永久挂住
	if picking and shot_path != "":
		elapsed = shot_at
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
	if shot_pick and not picking:
		_roll_offer()
		_open_pick()
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
	# 升级选卡时冻结战斗（但 bot 会自动选，免得无头测试卡住）
	if picking:
		pick_wait += delta
		if ((playtest or shot_bot) and not shot_pick) or (pick_delay > 0.0 and pick_wait > pick_delay):
			_take_card(0)
		return
	elapsed += delta
	var prev_wave := wave
	wave = int(elapsed / WAVE_SEC) + 1
	if wave != prev_wave:
		_on_wave_start()
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
		weapon["mul"] = 1.0  # 把武器倍率钉成 1.0，否则随机开局的霰弹枪 1.11 会让自检数字飘
		# 布局改成随机的了，但自检要的是固定 2×3，否则期望值对不上
		weapon["layout"] = (LAYOUTS[5] as Array).duplicate()
		while (weapon["slots"] as Array).size() < 6:
			weapon["slots"].append(null)
		weapon.interval = 1.0 if demo_board else 999.0  # 自检时不开火，排除弹药消耗的干扰
		weapon.slots[0] = _new_module("reson")  # 共振（邻 1 共振、3 基础）
		weapon.slots[1] = _new_module("reson")  # 共振（邻 0 共振、2 增幅、4 加法）
		weapon.slots[2] = _new_module("amp")  # 增幅（邻 1、5）
		weapon.slots[3] = _new_module("base")  # 基础（邻 0、4）
		weapon.slots[4] = _new_module("add")  # 加法（邻 1、3、5）
		weapon.slots[5] = _new_module("base")  # 基础（邻 2、4）
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
	# 升级与合成抢同一批材料：只在材料明显富余时升级，否则板子会被饿空
	if bot_ticks % 3 == 0 and _inv_total() >= level_cost() * 2:
		try_level()
	var guard := 0
	while guard < 4 and try_craft():
		guard += 1
	# 装置越多越好（每台 = 一个并行合成位），别等全忙了才想起来造
	if devices.size() < DEVICE_MAX and _inv("base") >= device_cost():
		buy_device()
	if _inv_total() >= level_cost() * 3:
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
	print("t=%3d w=%2d hp=%3d dps=%5.1f need=%5.1f drop=%.2f burn=%.2f lvl=%2d slot=%d/%d dev=%d/%d [%s] inv=[%s] c=%d/%d/%d/%d kills=%d dmg c%.0f/b%.0f/d%.0f alive=%d" % [
		int(pt_t), wave, int(maxf(hp, 0.0)), cur_dps(), need,
		cur_drop(), cur_burn(), level, _count_filled(), _board_weapon()["slots"].size(),
		_busy_devices(), devices.size(), comp, _inv_str(),
		crafted.get("base", 0), crafted.get("add", 0), crafted.get("amp", 0), crafted.get("reson", 0), kills_total,
		float(dmg_src["contact"]), float(dmg_src["bullet"]), float(dmg_src["dash"]),
		get_tree().get_nodes_in_group("enemy").size(),
	])


func _hud_tick(delta: float) -> void:
	flash_t = maxf(0.0, flash_t - delta)
	if elapsed - last_hit_t > REGEN_DELAY:
		hp = minf(max_hp, hp + (REGEN_RATE + 0.5 * float(_bl("regen"))) * delta)
	# 构筑屏/死亡屏打开时不要红色受击遮罩，否则整个面板被染红
	flash.color = Color(1, 0.2, 0.25, 0.0 if (build_root.visible or dead) else flash_t * 0.9)
	if pulse_t > 0.0:
		pulse_t = maxf(0.0, pulse_t - delta)
	for i in range(shots.size() - 1, -1, -1):
		shots[i]["t"] = float(shots[i]["t"]) - delta
		if float(shots[i]["t"]) <= 0.0:
			shots.remove_at(i)
	for i in range(blast_fx.size() - 1, -1, -1):
		blast_fx[i]["t"] = float(blast_fx[i]["t"]) - delta
		if float(blast_fx[i]["t"]) <= 0.0:
			blast_fx.remove_at(i)
	for w in weapons:
		w["blade_ph"] = float(w.get("blade_ph", 0.0)) + delta * 2.2
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
	return minf(raw, base * 1.8)


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
		"enabled": true, "fire_t": 0.0, "dmg": {},
	}
	_set_quality_of(w, q)
	return w


## 布局生成：以基础网络（二连/折角/T/方形/十字）为积木，随机旋转镜像后拼到已有格子上。
## 返回的格子永远连通（因为每块都贴着既有格子放），所以「插槽网络」不会出现孤岛。
func _gen_layout(n: int) -> Array:
	if n <= 2:
		return [Vector2i(0, 0), Vector2i(1, 0)].slice(0, n)
	var cells: Array = [Vector2i(0, 0)]
	var compact := rng.randf() < 0.6  # 60% 密堆（枢纽集中），40% 留缝（多个小岛）
	var guard := 0
	while cells.size() < n and guard < 400:
		guard += 1
		var want := mini(n - cells.size(), rng.randi_range(2, 3))
		var piece: Array = _roll_piece(want)
		var placed := false
		for attempt in 12:
			# 选一个锚点格子，把积木贴到它的空邻居上
			var anchor: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
			var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			var off: Vector2i = dirs[rng.randi_range(0, 3)]
			var ghost: Array = []
			for c in piece:
				ghost.append(anchor + off * (2 if not compact else 1) + c)
			var ok := cells.size() + ghost.size() <= n
			for g in ghost:
				if not ok:
					break
				if g in cells:
					ok = false
				if compact and not ok:
					break
			if not ok:
				continue
			if compact:
				# 密堆要求至少一个格子与已有格子相邻（保证连通且紧凑）
				var touch := false
				for g in ghost:
					for c2 in cells:
						if absi(g.x - c2.x) + absi(g.y - c2.y) == 1:
							touch = true
				if not touch:
					continue
			cells.append_array(ghost)
			placed = true
			break
		if not placed:
			# 兜底：往任意空格补一格
			for attempt2 in 40:
				var a2: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
				var dirs2: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
				var d2: Vector2i = dirs2[rng.randi_range(0, 3)]
				var cand: Vector2i = a2 + d2
				if not (cand in cells):
					cells.append(cand)
					break
	# 平移到左上角从 (0,0) 开始，方便画
	var minx := 999
	var miny := 999
	for c in cells:
		minx = mini(minx, c.x)
		miny = mini(miny, c.y)
	var out: Array = []
	for c in cells:
		out.append(Vector2i(c.x - minx, c.y - miny))
	out.sort_custom(func(a, b): return a.y * 100 + a.x < b.y * 100 + b.x)
	return out


## 从基础网络里抽一块（随机旋转 / 镜像）
func _roll_piece(want: int) -> Array:
	var base: Array
	match want:
		2: base = [Vector2i(0, 0), Vector2i(1, 0)]
		_: base = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]
	var rot := rng.randi_range(0, 3)
	var mir := rng.randi_range(0, 1)
	var out: Array = []
	for c in base:
		var p := Vector2i(c.x, c.y)
		if mir == 1:
			p.x = -p.x
		for r in rot:
			p = Vector2i(-p.y, p.x)
		out.append(p)
	return out
func _set_quality_of(w: Dictionary, q: int) -> void:
	q = clampi(q, 1, 5)
	w["quality"] = q
	w["base"] = float(QUALITY_BASE[q])
	w["layout"] = _gen_layout(int(LAYOUTS[q].size()))
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


## 一把武器此刻的 DPS（按板面实装模块算；多目标按分摊公式算总伤）
## 这是「理论 DPS」：假设目标一直够、弹药一直有
func _weapon_dps(w: Dictionary) -> float:
	var mo := _weapon_mods(w)
	var t := int(w["targets"])
	if t > 0:
		t += int(mo["targets"])
	var rng_d := float(w["range"]) + float(mo["range"])
	var hits: float = 1.0
	if t < 0:
		hits = float(maxi(1, _count_in_range(rng_d)))
	elif t > 1:
		hits = float(mini(t, maxi(1, _count_in_range(rng_d))))
	var per := _shot_power_of(w) * (1.0 + 0.1 * (hits - 1.0)) / hits
	return per * hits / (float(w["interval"]) * float(mo["iv"]))


## 理论 DPS 与 _weapon_dps 同义（v2.6 起不再假设空槽填满：那是「未来」不是「现在」）
func _theory_dps(w: Dictionary) -> float:
	return _weapon_dps(w)


## 实测 DPS：最近 5 秒真正打出去的伤害 ÷ 5
## 用 0.5 秒一个桶（10 个桶 = 5 秒），比存每条伤害省内存，也天然做成滚动窗口
const DMG_BUCKET := 0.5
const DMG_BUCKETS := 10


func _log_damage(w: Dictionary, dmg: float) -> void:
	if dmg <= 0.0:
		return
	var b := int(elapsed / DMG_BUCKET)
	var hist: Dictionary = w["dmg"]
	hist[b] = float(hist.get(b, 0.0)) + dmg
	# 顺手剪掉窗口外的桶，避免字典无限长
	for k in hist.keys():
		if int(k) < b - DMG_BUCKETS:
			hist.erase(k)


func _actual_dps(w: Dictionary) -> float:
	var b := int(elapsed / DMG_BUCKET)
	var hist: Dictionary = w["dmg"]
	var sum := 0.0
	for k in hist.keys():
		if int(k) > b - DMG_BUCKETS:
			sum += float(hist[k])
	return sum / (DMG_BUCKET * DMG_BUCKETS)


func _count_in_range(r: float) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.position.distance_to(player.position) <= r:
			n += 1
	return n


## v2.6 起品质只由「宝箱」决定：拿到即定死，不再跟着波次统一抬升
## （否则抽到什么最后都是紫 5 槽，宝箱的赌性就没了）
func _ensure_weapon() -> void:
	pass


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
## cls 决定行为；绑定武器的特化件在这个层面就是普通 flat（效果在 _weapon_mods 里生效）
func _slot_out(slots = null, w = null) -> Array:
	var ww: Dictionary = weapon if w == null else w
	var sl: Array = (ww["slots"] as Array) if slots == null else slots
	var base: Array = []
	base.resize(sl.size())
	for i in sl.size():
		var m = sl[i]
		base[i] = 0.0 if m == null else float(MODULES[String(m["id"])]["rate"])
	var eff := base.duplicate()
	# 共振：相邻同 cls 的模块 +50% 基础值
	for i in sl.size():
		var m = sl[i]
		if m == null or _cls(m) != "reson":
			continue
		for j in _neighbors(i, ww):
			if sl[j] != null and _cls(sl[j]) == "reson":
				eff[j] = float(eff[j]) + float(base[j]) * 0.5
	var out: Array = []
	out.resize(sl.size())
	for i in sl.size():
		var m = sl[i]
		if m == null:
			out[i] = 0.0
			continue
		var v: float = eff[i]
		if _cls(m) == "mirror":  # 加法：镜像相邻的低阶模块
			var t := int(m["tier"])
			for j in _neighbors(i, ww):
				if sl[j] != null and int(sl[j]["tier"]) < t:
					v += float(eff[j])
		out[i] = v
	# 增幅：自身 0 出力，把 boost 加到相邻模块的最终输出上（不回流给别的增幅）
	for i in sl.size():
		var m = sl[i]
		if m == null or _cls(m) != "boost":
			continue
		var b := float(MODULES[String(m["id"])]["boost"])
		for j in _neighbors(i, ww):
			if sl[j] != null and _cls(sl[j]) != "boost":
				out[j] = float(out[j]) + b
	return out


func _cls(m: Dictionary) -> String:
	return String(MODULES[String(m["id"])]["cls"])


## 武器级效果汇总：扫一遍板面，把带效果的模块折算成「这把枪的修正值」
## bind 非空的模块只在对应武器上生效（否则它只剩 rate，见方案 §1.3）
func _weapon_mods(w: Dictionary) -> Dictionary:
	var mo := {"mul": 1.0, "mul_add": 0.0, "iv": 1.0, "range": 0.0, "targets": 0,
		"pierce": 0, "elite": 0.0, "burn": 1.0, "recycle": 0.0, "combo": 0.0,
		"ramp_cap": 0.0, "blast": 0.0, "blade": 0.0}
	var wid := String(w["id"])
	for m in w["slots"]:
		if m == null:
			continue
		var mid := String(m["id"])
		var d: Dictionary = MODULES[mid]
		var b := String(d.get("bind", ""))
		if b != "" and b != wid:
			continue
		match mid:
			"edge": mo["mul_add"] = float(mo["mul_add"]) + 0.08
			"light": mo["burn"] = float(mo["burn"]) * 0.5
			"extend": mo["range"] = float(mo["range"]) + 25.0
			"calib": mo["iv"] = float(mo["iv"]) * 0.95
			"pierce": mo["pierce"] = int(mo["pierce"]) + 1
			"breaker": mo["elite"] = float(mo["elite"]) + 0.20
			"coolant": mo["iv"] = float(mo["iv"]) * 0.92
			"recycle": mo["recycle"] = float(mo["recycle"]) + 0.20
			"overload": mo["mul"] = float(mo["mul"]) * 1.15
			"tempo": mo["combo"] = float(mo["combo"]) + 0.04
			"multi", "spread": mo["targets"] = int(mo["targets"]) + 1
			"belt": mo["burn"] = float(mo["burn"]) * 0.35
			"focus": mo["ramp_cap"] = float(mo["ramp_cap"]) + 1.80
			"charge": mo["blast"] = float(mo["blast"]) + 40.0
			"blade": mo["blade"] = float(mo["blade"]) + 25.0
	# 「扩散器」对霰弹枪是 +2（不是 +1）
	if wid == "shotgun":
		for m in w["slots"]:
			if m != null and String(m["id"]) == "spread":
				mo["targets"] = int(mo["targets"]) + 1
	# 升级 buff：全局修正
	var bl := float(_bl("rate"))
	if bl > 0.0:
		mo["iv"] = float(mo["iv"]) * pow(0.92, bl)
	var bpow := float(_bl("power"))
	if bpow > 0.0:
		mo["mul"] = float(mo["mul"]) * pow(1.10, bpow)
	mo["range"] = float(mo["range"]) + 60.0 * float(_bl("range"))
	mo["pierce"] = int(mo["pierce"]) + _bl("pierce")
	mo["elite"] = float(mo["elite"]) + 0.25 * float(_bl("elite"))
	if int(w["targets"]) > 0:
		mo["targets"] = int(mo["targets"]) + _bl("target")
	return mo


func _shot_power_of(w: Dictionary) -> float:
	var mo := _weapon_mods(w)
	var total := float(w["base"])
	for v in _slot_out(null, w):
		total += float(v)
	return total * float(w["mul"]) * float(mo["mul"]) * (1.0 + float(mo["mul_add"]))


func _shot_power() -> float:
	return _shot_power_of(weapon)


## 合成计时：每台装置各自倒计时，到点后产物进电路板
## （满了会按整板出力决定换不换，换不动就进库存）
func _craft_tick(delta: float) -> void:
	for d in devices:
		if String(d["kind"]) == "":
			continue
		d["left"] = float(d["left"]) - delta
		if float(d["left"]) > 0.0:
			continue
		var k := String(d["kind"])
		d["kind"] = ""
		d["left"] = 0.0
		crafted[k] = int(crafted.get(k, 0)) + 1
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
	spawn_acc = minf(spawn_acc + delta * _spawn_rate(), 24.0)  # 卡顿后不要一口气吐出几百个
	while spawn_acc >= 1.0:
		if get_tree().get_nodes_in_group("enemy").size() >= MAX_ENEMIES:
			spawn_acc = minf(spawn_acc, 6.0)
			break
		var pat: Dictionary = _pick_pattern()
		var size := rng.randi_range(int(pat["min"]), int(pat["max"]))
		# 预算不够就等下一帧，让「一团 / 一圈」完整地出现
		if spawn_acc < float(size):
			break
		spawn_acc -= float(size)
		_emit_pattern(String(pat["id"]), size)


## 生成编队：单点 / 一团 / 弧线 / 一圈。同样的人数，排布不同，压迫感完全不同。
const PATTERNS := [
	{"id": "single", "w": 46, "min": 1, "max": 1, "wave": 1},
	{"id": "cluster", "w": 28, "min": 4, "max": 7, "wave": 2},
	{"id": "arc", "w": 18, "min": 6, "max": 9, "wave": 4},
	{"id": "ring", "w": 16, "min": 10, "max": 14, "wave": 6},
]


func _pick_pattern() -> Dictionary:
	var pool: Array = []
	var total := 0.0
	for p in PATTERNS:
		if wave < int(p["wave"]):
			continue
		pool.append(p)
		total += float(p["w"])
	var r := rng.randf() * total
	for p in pool:
		r -= float(p["w"])
		if r <= 0.0:
			return p
	return pool[0]


func _emit_pattern(id: String, n: int) -> void:
	var base_ang: float = rng.randf() * TAU
	var rad: float = rng.randf_range(540.0, 660.0)
	for i in n:
		var pos: Vector2
		match id:
			"cluster":
				# 一团：同方向挤在一起，像一波小潮水
				var a := base_ang + rng.randf_range(-0.30, 0.30)
				pos = player.position + Vector2.from_angle(a) * rad + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 70.0)
			"arc":
				# 弧线：一条 50° 的弧压过来，横向铺开
				var a2 := base_ang + (float(i) / maxf(1.0, float(n - 1)) - 0.5) * 0.9
				pos = player.position + Vector2.from_angle(a2) * rad
			"ring":
				# 一圈：整圈合围，逼玩家选一个方向突出去
				var a3 := base_ang + TAU * float(i) / float(n)
				pos = player.position + Vector2.from_angle(a3) * rad
			_:
				pos = player.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(520.0, 660.0)
		if get_tree().get_nodes_in_group("enemy").size() >= MAX_ENEMIES:
			return
		_spawn_enemy_at(pos)


func _spawn_enemy(forced: String = "") -> void:
	var ang: float = rng.randf() * TAU
	_spawn_enemy_at(player.position + Vector2.from_angle(ang) * rng.randf_range(520.0, 660.0), forced)


func _spawn_enemy_at(pos: Vector2, forced: String = "") -> void:
	var kind := forced if forced != "" else _pick_kind()
	var kd: Dictionary = ENEMY_KINDS[kind]
	var e = Node2D.new()
	e.set_script(load("res://scripts/enemy.gd"))
	e.add_to_group("enemy")
	e.position = pos
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
		var mo := _weapon_mods(w)
		var iv := float(w["interval"]) * float(mo["iv"])
		w["fire_t"] = float(w["fire_t"]) + delta
		if float(w["fire_t"]) < iv:
			continue
		var rng_d := float(w["range"]) + float(mo["range"])
		var tg := int(w["targets"])
		if tg > 0:
			tg += int(mo["targets"])
		var targets := _targets_for(w, rng_d, tg)
		# 环绕刃不需要目标：空转一圈也照常烧弹药
		if targets.is_empty() and String(w["id"]) != "blade":
			w["fire_t"] = minf(float(w["fire_t"]), iv)
			continue
		w["fire_t"] = float(w["fire_t"]) - iv
		var dmg := _shot_power_of(w)
		# 镭射：对同一目标连续命中叠倍率，换目标归零（方案 §2.7）
		if String(w["id"]) == "beam" and not targets.is_empty():
			var tid := int(targets[0].get_instance_id())
			if int(w.get("ramp_id", 0)) == tid:
				w["ramp"] = minf(float(w.get("ramp", 0.0)) + 0.06, 1.20 + float(mo["ramp_cap"]))
			else:
				w["ramp"] = 0.0
				w["ramp_id"] = tid
			dmg *= 1.0 + float(w["ramp"])
		# 时序核：每发连击 +4%，断连（超过 1.2 秒没开火）或换目标就重置
		if float(mo["combo"]) > 0.0:
			if float(w.get("combo_t", -99.0)) + 1.2 < elapsed:
				w["combo"] = 0
			w["combo"] = mini(int(w.get("combo", 0)) + 1, 10)
			w["combo_t"] = elapsed
			dmg *= 1.0 + float(mo["combo"]) * float(int(w["combo"]))
		# 消耗次数：每次开火每个模块 -1（与目标数无关 → 高射速 = 高消耗）
		var burn := float(mo["burn"])
		var sl: Array = w["slots"]
		for i in sl.size():
			var m = sl[i]
			if m == null:
				continue
			m["left"] = float(m["left"]) - burn
			if float(m["left"]) <= 0.0:
				sl[i] = null
				_refill(i, w)
		var hits := float(targets.size())
		var per: float = dmg * (1.0 + 0.1 * (hits - 1.0)) / maxf(1.0, hits)
		# 榴弹炮：主目标吃满，不叠多目标折扣（溅射在下面单独结算）
		if String(w["id"]) == "grenade":
			per = dmg
		var dealt := 0.0
		for e in targets:
			if not is_instance_valid(e):
				continue
			var d: float = per
			if float(mo["elite"]) > 0.0 and String(e.kind) in ["charger", "rock"]:
				d *= 1.0 + float(mo["elite"])
			# 实际打掉的血量（不超过剩余血量），否则溢出伤害会把实测 DPS 撑高
			dealt += minf(d, maxf(float(e.hp), 0.0))
			e.hp = float(e.hp) - d
			e.hit = 0.18
			if e.hp <= 0.0:
				_kill(e)
		# 贯穿：主目标身后 120px 内最近的敌人再吃 60%（贯穿弹每层多穿一个）
		var pierce := int(mo["pierce"])
		if pierce > 0:
			var dir := player.position.direction_to(targets[0].position)
			var from: Vector2 = targets[0].position
			var extra := _pierce_targets(from, dir, pierce, targets)
			for e in extra:
				if not is_instance_valid(e):
					continue
				var d2: float = per * 0.6
				dealt += minf(d2, maxf(float(e.hp), 0.0))
				e.hp = float(e.hp) - d2
				e.hit = 0.18
				if e.hp <= 0.0:
					_kill(e)
		# 榴弹炮：命中点周围 (90 + blast) 内的其他敌人吃 60%
		if String(w["id"]) == "grenade" and not targets.is_empty():
			var c0: Vector2 = targets[0].position
			var br := 90.0 + float(mo["blast"])
			for e in get_tree().get_nodes_in_group("enemy"):
				if not is_instance_valid(e) or e in targets:
					continue
				if e.position.distance_to(c0) > br:
					continue
				var ds: float = dmg * 0.60
				dealt += minf(ds, maxf(float(e.hp), 0.0))
				e.hp = float(e.hp) - ds
				e.hit = 0.18
				if e.hp <= 0.0:
					_kill(e)
			blast_fx.append({"p": c0, "r": br, "t": 0.18})
		_log_damage(w, dealt)
		_add_shot(targets, w)


## 贯穿的追加目标：从中弹点沿弹道方向再往前 120px 内的最近敌人
func _pierce_targets(from: Vector2, dir: Vector2, n: int, already: Array) -> Array:
	var cand: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e in already:
			continue
		var rel: Vector2 = e.position - from
		if rel.length() > 120.0:
			continue
		if rel.dot(dir) <= 0.0:  # 只穿「前方」，不往回打
			continue
		cand.append({"e": e, "d": rel.length()})
	cand.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
	var out: Array = []
	for i in mini(n, cand.size()):
		out.append(cand[i]["e"])
	return out


## 搜寻目标：最近优先；targets < 0 表示范围内全部
## 目标选择：支持 prefer（方案 §2.6/§2.7）
##   "shooter,charger" → 先按优先种类过滤，再按距离
##   "highest_hp"      → 按血量降序（镭射锁死精英，杂兵抢不走光束）
func _targets_for(w: Dictionary, r: float, n: int) -> Array:
	var pref := String(WEAPONS[w["id"]].get("prefer", ""))
	if pref == "":
		return _targets_in_range(r, n)
	var cand: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = e.position.distance_to(player.position)
		if d <= r:
			cand.append({"e": e, "d": d})
	if pref == "highest_hp":
		cand.sort_custom(func(a, b): return float(a["e"].hp) > float(b["e"].hp))
	else:
		var kinds := pref.split(",")
		cand.sort_custom(func(a, b):
			var pa := 0 if String(a["e"].kind) in kinds else 1
			var pb := 0 if String(b["e"].kind) in kinds else 1
			if pa != pb:
				return pa < pb
			return float(a["d"]) < float(b["d"]))
	var out: Array = []
	if n < 0:
		for c in cand:
			out.append(c["e"])
	else:
		for i in mini(n, cand.size()):
			out.append(cand[i]["e"])
	return out


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
	# 榴弹爆炸：短暂扩散的橙色环
	for b in blast_fx:
		var k2: float = clampf(float(b["t"]) / 0.18, 0.0, 1.0)
		draw_circle(b["p"], float(b["r"]), Color(1.0, 0.55, 0.22, 0.10 * k2))
		draw_arc(b["p"], float(b["r"]) * (1.25 - 0.25 * k2), 0.0, TAU, 40, Color(1.0, 0.62, 0.28, 0.55 * k2), 2.0, true)
	# 环绕刃：贴着玩家转的弧（每把刀一个相位）
	for w in weapons:
		if String(w["id"]) != "blade" or not bool(w["enabled"]):
			continue
		var rad := float(WEAPONS["blade"]["range"]) + float(_weapon_mods(w)["blade"])
		var ph := float(w.get("blade_ph", 0.0))
		for b in 2:
			var a0 := ph + float(b) * PI
			draw_arc(player.position, rad, a0, a0 + 1.5, 18, Color(0.82, 0.94, 0.45, 0.75), 4.0, true)


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
	if rng.randf() < DROP_CHANCE + 0.04 * float(_bl("drop")):
		_spawn_pickup(e.position, "base")
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


## 宝箱品质权重表（方案 §9.2）：白2 / 绿3 / 蓝4 / 紫5 / 金6 槽，按波次加权
## 这是「宝箱」唯一的品质来源，不再有第二个人往回改它
func _chest_quality() -> int:
	var rows := [
		[55, 35, 10, 0, 0],    # 1–5
		[30, 42, 24, 4, 0],    # 6–10
		[10, 35, 40, 14, 1],   # 11–15
		[0, 20, 40, 32, 8],    # 16–20
		[0, 10, 30, 42, 18],   # 21+
	]
	var idx := 0
	if wave >= 21:
		idx = 4
	elif wave >= 16:
		idx = 3
	elif wave >= 11:
		idx = 2
	elif wave >= 6:
		idx = 1
	var w: Array = rows[idx]
	var total := 0
	for v in w:
		total += int(v)
	var roll := rng.randi() % total
	var acc := 0
	for i in w.size():
		acc += int(w[i])
		if roll < acc:
			return i + 1
	return 1


func _chest_to_modules() -> void:
	var t := "add" if wave >= 12 else "base"
	for k in 2:
		_spawn_pickup(player.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30.0, 50.0), t)


## 开箱：优先给新武器；背包满了就给一包模块
func grant_chest(from_chest: bool = false) -> void:
	if from_chest:
		last_chest_t = elapsed
	# 测平衡时最多留 3 把枪：背包是武器与装置共享的，枪占满了就再也造不出装置（合成直接停摆）
	if bot and weapons.size() >= 3:
		_chest_to_modules()
		return
	if backpack_cap >= 0 and _backpack_used() >= backpack_cap:
		var t := "add" if wave >= 12 else "base"
		for k in 2:
			_spawn_pickup(player.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30.0, 50.0), t)
		return
	var pool: Array = START_POOL.duplicate()
	# 狙击枪不适合当开局武器（单发/低射速，一个人清不动），只从宝箱里出
	pool.append("sniper")
	if wave >= 4:
		pool.append("beam")
	if wave >= 5:
		pool.append("grenade")
	if wave >= 6:
		pool.append("blade")
	if wave >= 8:
		pool.append("laser")
	var id: String = pool[rng.randi() % pool.size()]
	var q := _chest_quality()
	var w := _make_weapon(id, q)
	w["slots"][0] = _new_module("base")
	weapons.append(w)
	# 不自动切到新武器：切过去会把「合成目标」和「当前编辑」拆成两把枪，两边都喂不饱
	_refresh_hud()


func _spawn_pickup(pos: Vector2, mid: String) -> void:
	var p = Node2D.new()
	p.set_script(load("res://scripts/pickup.gd"))
	p.add_to_group("pickup")
	p.position = pos
	p.mid = mid
	p.tier = int(MODULES[mid]["tier"])
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
		var dmg: float = CONTACT_DPS * pow(0.92, float(_bl("contact"))) * touching * delta
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
		var t := _damage_reward_id()
		# 掉在玩家脚边，能看见它被吸走，反馈比直接进背包好
		var n := _damage_reward_count()
		for k in n:
			_spawn_pickup(player.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(38.0, 58.0), t)


## 补偿只给「能产出的」模块：增幅自身 0 出力，当补偿发等于发了个空槽
func _damage_reward_id() -> String:
	if wave >= 12:
		return "add"
	return "base"


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


## 全部模块 id（含 base；MOD_ORDER 是「可合成」的配方顺序，不含 base）
func _ids_all() -> Array:
	return ["base"] + MOD_ORDER


func _inv_str() -> String:
	var parts: Array = []
	for k in _ids_all():
		if _inv(k) > 0:
			parts.append(String(MODULES[k]["name"]) + str(_inv(k)))
	return " ".join(parts)


## ---- 库存：按模块 id 计数（同阶不同配方是不同的东西，不能再按 tier 合并）----
func _inv(mid: String) -> int:
	return int(inventory.get(mid, 0))


func _add_inv(mid: String, n: int) -> void:
	inventory[mid] = maxi(0, _inv(mid) + n)


func _take_inv(mid: String, n: int) -> void:
	inventory[mid] = maxi(0, _inv(mid) - n)


func _cycle_recipe(d: int) -> void:
	recipe_sel = posmod(recipe_sel + d, MOD_ORDER.size())
	_refresh_build()


func _inv_total() -> int:
	var n := 0
	for k in inventory:
		n += int(inventory[k])
	return n


func _all_total() -> int:
	return _inv_total() + _count_filled()


func _inv_tier(t: int) -> int:
	var n := 0
	for k in inventory:
		if int(MODULES[k]["tier"]) == t:
			n += int(inventory[k])
	return n


## 某阶在「库存 + 板面」里的总量（配方按阶吃料：特化件也算同阶任意模块）
func _count_tier(t: int) -> int:
	var n := _inv_tier(t)
	for m in weapon.slots:
		if m != null and int(m["tier"]) == t:
			n += 1
	return n


## 从槽位里取该阶中寿命最少的模块（顺手把快报废的先花掉）
func _take_from_slots(t: int) -> bool:
	var idx := -1
	var best := 2.0
	for i in weapon.slots.size():
		var m = weapon.slots[i]
		if m != null and int(m["tier"]) == t:
			var f: float = float(m["left"]) / float(MODULES[String(m["id"])]["uses"])
			if f < best:
				best = f
				idx = i
	if idx < 0:
		return false
	weapon.slots[idx] = null
	return true


## 按阶扣料：优先扣库存里数量最多的那种，扣完再动板面
func _take_tier(t: int, n: int, prefer_slots: bool = false) -> void:
	var left := n
	if prefer_slots:
		while left > 0 and _take_from_slots(t):
			left -= 1
	while left > 0:
		var best := ""
		var best_n := 0
		for k in _ids_all():
			if int(MODULES[k]["tier"]) != t:
				continue
			if _inv(k) > best_n:
				best_n = _inv(k)
				best = k
		if best == "":
			break
		_add_inv(best, -1)
		left -= 1
	while left > 0 and _take_from_slots(t):
		left -= 1


## 整板出力（不含武器基础值，只用于互相比较）
func _board_total(w = null) -> float:
	var s := 0.0
	for v in _slot_out(null, w):
		s += v
	return s


## 库存里还有货的 id
func _stocked_ids() -> Array:
	var out: Array = []
	for k in _ids_all():
		if _inv(k) > 0:
			out.append(k)
	return out


## DEBUG
func _refill(i: int, w = null) -> void:
	var ww: Dictionary = weapon if w == null else w
	var sl: Array = ww["slots"]
	var best_id := ""
	# 起点是 0：出力为 0 的模块（增幅单独放着）不许占格子，否则板上会周期性地被增幅填满又烧空
	var best_v := 0.0
	for k in _stocked_ids():
		sl[i] = _new_module(k)
		var v := _board_total(ww)
		sl[i] = null
		if v > best_v:
			best_v = v
			best_id = k
	if best_id != "":
		_add_inv(best_id, -1)
		sl[i] = _new_module(best_id)


## 把一个模块装进电路板。
## 规则：统一按「装完后整板出力最高」挑位子，而且必须**严格高于当前**才装，
## 否则留在库存（旧规则「替换最低阶」会把喂加法的 T1 全换掉，最后板上全是互相吃不到的加法）
## 合成产物往「槽位最多的那把武器」上装：否则宝箱一给白武器（2 格），
## 后续所有产物都会挤进小板上（实测会把总 DPS 从 1500 压到 150）
func _board_weapon() -> Dictionary:
	var best: Dictionary = weapon
	for w in weapons:
		if (w["slots"] as Array).size() > (best["slots"] as Array).size():
			best = w
	return best


func _install(mid: String) -> void:
	var w := _board_weapon()
	var sl: Array = w["slots"]
	# 增幅是「支撑件」：板上一旦有载体（共振）且支撑已经 2 个，就攒在库存里当共振的料
	if mid == "amp" and _installed_count(4) >= 1 and _installed_id("amp") >= 2:
		_add_inv(mid, 1)
		return
	var now := _board_total(w)
	var best := -1
	var best_v := now + 0.001
	for i in sl.size():
		var m = sl[i]
		sl[i] = _new_module(mid)
		var v := _board_total(w)
		sl[i] = m
		if v > best_v:
			best_v = v
			best = i
	if best >= 0:
		sl[best] = _new_module(mid)

		pass
		return
	_add_inv(mid, 1)


func level_cost() -> int:
	return int(round(LEVEL_COST_BASE * pow(LEVEL_COST_GROWTH, level - 1)))


## 升级只吃库存（槽位是工作区，不能被顺手拆掉）——「多余的基础模块」才拿去升级
func try_level() -> bool:
	var cost := level_cost()
	if _inv_total() < cost:
		return false
	var left := cost
	for k in _ids_all():
		if left <= 0:
			break
		var take: int = mini(left, _inv(k))
		if take > 0:
			_add_inv(k, -take)
			left -= take
	if left > 0:
		return false
	level += 1
	_roll_offer()
	_open_pick()
	return true


## buff 层数
func _bl(id: String) -> int:
	return int(buffs.get(id, 0))


## 抽 4 张卡：3 张 buff（攻击/经济/生存各 1）+ 1 张配方卡
func _roll_offer() -> void:
	offer.clear()
	reroll_used = false
	var cats := ["atk", "eco", "sur"]
	for c in cats:
		var pool: Array = []
		for id in BUFFS:
			var d: Dictionary = BUFFS[id]
			if String(d["cat"]) != c:
				continue
			if _bl(id) >= int(d["max"]):
				continue
			if String(d["rar"]) == "gold" and level <= 4:
				continue
			pool.append(id)
		if pool.is_empty():
			pool = ["rate", "drop", "hp"]
		var pick: String = String(pool[rng.randi_range(0, pool.size() - 1)])
		offer.append({"kind": "buff", "id": pick})
	offer.append(_roll_recipe_card())


## 配方卡：从已解锁的配方里抽一个（特化配方只在拥有对应武器时进池）
func _roll_recipe_card() -> Dictionary:
	var pool: Array = []
	for mid in MOD_ORDER:
		var d: Dictionary = MODULES[mid]
		var bind := String(d.get("bind", ""))
		if bind != "":
			var has := false
			for w in weapons:
				if String(w["id"]) == bind:
					has = true
			if not has:
				continue
		if level < int(CRAFT_UNLOCK.get(mid, 99)) - 3:
			continue
		pool.append(mid)
	if pool.is_empty():
		pool = ["add"]
	var mid2: String = String(pool[rng.randi_range(0, pool.size() - 1)])
	return {"kind": "recipe", "id": mid2}


func _open_pick() -> void:
	picking = true
	pick_wait = 0.0
	_paint_offer()


func _paint_offer() -> void:
	if pick_root == null:
		return
	for c in pick_root.get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.07, 0.88)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	pick_root.add_child(bg)
	var w_card := 250.0
	var gap := 18.0
	var total := 4.0 * w_card + 3.0 * gap
	var x0 := (1280.0 - total) * 0.5
	var title := _label(pick_root, Vector2(x0, 118), 28, Color(0.95, 0.93, 0.86))
	title.text = "升级！点卡片 或 按 1–4 选择"
	var sub := _label(pick_root, Vector2(x0, 158), 17, Color(0.72, 0.78, 0.88))
	sub.text = ("配方卡可以按 T 换成第 4 张 buff" % level) if not reroll_used else "配方卡已经换过了"
	for i in offer.size():
		var card: Dictionary = offer[i]
		var col := Color(0.55, 0.58, 0.66)
		var nm := ""
		var ds := ""
		if String(card["kind"]) == "buff":
			var d: Dictionary = BUFFS[String(card["id"])]
			nm = "%s  Lv%d→%d" % [String(d["name"]), _bl(String(card["id"])), _bl(String(card["id"])) + 1]
			ds = String(d["desc"])
			var r := String(d["rar"])
			col = Color(0.62, 0.86, 1.0) if r == "blue" else (Color(1.0, 0.84, 0.35) if r == "gold" else Color(0.82, 0.84, 0.90))
		else:
			var d2: Dictionary = MODULES[String(card["id"])]
			nm = "配方 · %s" % String(d2["name"])
			ds = "立刻获得 1 个（%d 阶）" % int(d2["tier"])
			col = Color(0.55, 0.95, 0.72)
		var btn := Button.new()
		btn.position = Vector2(x0 + float(i) * (w_card + gap), 200)
		btn.size = Vector2(w_card, 210)
		btn.text = "%d   %s\n\n%s" % [i + 1, nm, ds]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", col)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.11, 0.15, 0.98)
		sb.border_color = col
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 12
		btn.add_theme_stylebox_override("normal", sb)
		var sh := sb.duplicate() as StyleBoxFlat
		sh.bg_color = Color(0.18, 0.20, 0.26, 0.99)
		sh.border_color = Color(1, 1, 1)
		btn.add_theme_stylebox_override("hover", sh)
		btn.add_theme_stylebox_override("pressed", sh)
		btn.add_theme_stylebox_override("focus", sh)
		pick_root.add_child(btn)
		btn.pressed.connect(_take_card.bind(i))


func _close_pick() -> void:
	picking = false
	if pick_root != null:
		for c in pick_root.get_children():
			c.queue_free()


## 领第 i 张卡
func _take_card(i: int) -> void:
	if i < 0 or i >= offer.size():
		return
	var card: Dictionary = offer[i]
	var id := String(card["id"])
	if String(card["kind"]) == "buff":
		buffs[id] = _bl(id) + 1
		if id == "hp":
			max_hp += 15.0
			hp = minf(max_hp, hp + 15.0)
	else:
		_add_inv(id, 1 + int(level / 12))
	_close_pick()
	_refresh_hud()


## 把配方卡 reroll 成第 4 张 buff（每级一次）
func _reroll_recipe() -> void:
	if reroll_used or picking == false or offer.size() < 4:
		return
	if String(offer[3]["kind"]) != "recipe":
		return
	var used := {}
	for c in offer:
		if String(c["kind"]) == "buff":
			used[String(c["id"])] = true
	var pool: Array = []
	for id in BUFFS:
		if used.has(id):
			continue
		if _bl(id) >= int(BUFFS[id]["max"]):
			continue
		pool.append(id)
	if pool.is_empty():
		return
	offer[3] = {"kind": "buff", "id": String(pool[rng.randi_range(0, pool.size() - 1)])}
	reroll_used = true
	_paint_offer()


## 该配方当前能不能开：绑定武器、解锁等级、材料
func recipe_state(mid: String) -> Dictionary:
	var d: Dictionary = MODULES[mid]
	var t := int(d["tier"])
	var need_lv := int(CRAFT_UNLOCK.get(mid, 99))
	var bind := String(d.get("bind", ""))
	var has_bind := bind == ""
	if bind != "":
		for w in weapons:
			if String(w["id"]) == bind:
				has_bind = true
	var cost := int(CRAFT_COST[t])
	var have := _inv_tier(t - 1)
	var st := "可合成"
	var ok := true
	if not has_bind:
		ok = false
		st = "需要%s" % String(WEAPONS[bind]["name"])
	elif level < need_lv:
		ok = false
		st = "解锁于 Lv%d" % need_lv
	elif have < cost:
		ok = false
		st = "需 %d 个 %d 阶料" % [cost, t - 1]
	return {"ok": ok, "state": st, "cost": cost, "tier": t, "level": need_lv}


## 合成吃「库存」（槽位是工作区，绝不能被合成顺手拆掉）。
## 有空闲装置才能开工，产物在 _craft_tick 到点后进板子。
## mid = "" 表示自动选配方。
func try_craft(mid: String = "") -> bool:
	var idx := _idle_device()
	if idx < 0:
		return false
	if mid == "":
		mid = _auto_recipe()
	if mid == "" or not MODULES.has(mid):
		return false
	var st := recipe_state(mid)
	if not bool(st["ok"]):
		return false
	var t := int(st["tier"])
	_take_tier(t - 1, int(st["cost"]))
	var dur := float(CRAFT_TIME[t]) * pow(0.90, float(_bl("craft")))
	devices[idx]["kind"] = mid
	devices[idx]["total"] = dur
	devices[idx]["left"] = dur
	return true


func _auto_recipe() -> String:
	# 板子没满 → 先拿加法把格子垫起来；满了 → 先攒增幅，够 2 个立刻换共振
	var empty := 0
	var sl: Array = _board_weapon()["slots"]
	for i in sl.size():
		if sl[i] == null:
			empty += 1
	if empty > 0 and bool(recipe_state("add")["ok"]):
		return "add"
	if bool(recipe_state("reson")["ok"]):
		return "reson"
	if bool(recipe_state("amp")["ok"]):
		return "amp"
	# 剩下的余料：从高阶往低阶找一件能做的
	for mid in ["tempo", "overload", "coolant", "breaker", "calib", "pierce", "recycle",
			"temper", "edge", "light", "extend", "add"]:
		if bool(recipe_state(mid)["ok"]):
			return mid
	return ""


func _installed_count(t: int) -> int:
	var n := 0
	for m in _board_weapon()["slots"]:
		if m != null and int(m["tier"]) == t:
			n += 1
	return n


func _installed_id(mid: String) -> int:
	var n := 0
	for m in _board_weapon()["slots"]:
		if m != null and String(m["id"]) == mid:
			n += 1
	return n


func add_module(mid: String) -> void:
	var sl: Array = _board_weapon()["slots"]
	for i in sl.size():
		if sl[i] == null:
			sl[i] = _new_module(mid)
			return
	_add_inv(mid, 1)


## 总理论 DPS：所有启用武器之和（按板面实装模块算）
func cur_dps() -> float:
	var s := 0.0
	for w in weapons:
		if bool(w["enabled"]):
			s += _weapon_dps(w)
	return s


## 总实测 DPS：最近 5 秒真实伤害之和（HUD 主指标）
func cur_actual_dps() -> float:
	var s := 0.0
	for w in weapons:
		if bool(w["enabled"]):
			s += _actual_dps(w)
	return s


## 总弹药消耗/秒：每把启用武器各自按「每次开火每个模块 -1」累加
func cur_burn() -> float:
	var b := 0.0
	for w in weapons:
		if not bool(w["enabled"]):
			continue
		var mo := _weapon_mods(w)
		var iv := float(w["interval"]) * float(mo["iv"])
		var burn := float(mo["burn"])
		for m in w["slots"]:
			if m != null:
				b += burn / (float(MODULES[String(m["id"])]["uses"]) * iv)
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
	hud_ammo.text = "DPS 实测 %5.1f / 理论 %5.1f    净弹药 %s%.2f/s    库存 %d    槽位 %d/%d" % [
		cur_actual_dps(), cur_dps(), sign_s, net, _inv_total(),
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


## 左侧武器栏：每把武器一行，显示开关状态与「实测 DPS / 理论 DPS」
## 实测 > 理论 通常是多目标溢出或溅射；实测 << 理论 通常是没目标空转或弹药断档
func _refresh_weapon_panel() -> void:
	if wpanel == null:
		return
	var s := ""
	for i in weapons.size():
		var w: Dictionary = weapons[i]
		var kd: Dictionary = WEAPONS[w["id"]]
		var on: bool = bool(w["enabled"])
		var mark := "▸" if i == sel else " "
		var actual := _actual_dps(w) if on else 0.0
		var theory := _theory_dps(w)
		var state := "[开]" if on else "[关]"
		s += "%s%d %s %s %s  %s  实测 %5.1f / 理论 %5.1f\n" % [
			mark, i + 1, state, str(kd["name"]), QUALITY_NAME[int(w["quality"])],
			("%d槽" % (w["slots"] as Array).size()), actual, theory
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
	var inv_parts: Array = []
	for k in _ids_all():
		if _inv(k) > 0:
			inv_parts.append("%s %d" % [String(MODULES[k]["name"]), _inv(k)])
	if inv_parts.is_empty():
		inv_parts.append("空")
	info.append("库存    " + "    ".join(inv_parts))
	info.append("受击补偿    +%d 个模块（每 %d HP 补 1 个）" % [
		modules_from_damage, int(DAMAGE_PER_MODULE)
	])
	info.append("等级 %d  →  %d     需要 %d 个模块     [U]" % [
		level, level + 1, level_cost()
	])
	info.append("配方   [Q]/[E] 切换    [C] 合成选中    装置 %d 台（空闲 %d）" % [
		devices.size(), devices.size() - _busy_devices()
	])
	# 只显示 8 行窗口：配方有 20 个，全列会顶出屏幕
	var first := maxi(0, mini(recipe_sel - 3, MOD_ORDER.size() - 8))
	for i in range(first, mini(MOD_ORDER.size(), first + 8)):
		var mid: String = MOD_ORDER[i]
		var st := recipe_state(mid)
		var t := int(st["tier"])
		var mark := "▸" if i == recipe_sel else " "
		info.append("  %s %-6s %d×%d阶  %4.0fs  %s" % [
			mark, String(MODULES[mid]["name"]), int(st["cost"]), t - 1,
			float(CRAFT_TIME[t]) * pow(0.90, float(_bl("craft"))), String(st["state"])
		])
	if devices.size() < DEVICE_MAX:
		info.append("    [X] 造装置  需要 %d 个基础模块" % device_cost())
	else:
		info.append("    [X] 装置已满（%d 台）" % devices.size())
	info.append("")
	info.append("净弹药 %+.2f/s     实测 DPS %.1f     理论 DPS %.1f" % [
		cur_drop() - cur_burn(), cur_actual_dps(), cur_dps()
	])
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
			var col: Color = MODULES[String(m["id"])]["color"]
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
			name_l.text = String(MODULES[String(m["id"])]["name"])
			name_l.add_theme_color_override("font_color", MODULES[String(m["id"])]["color"])
		panel.add_child(name_l)

		var out_l := Label.new()
		out_l.position = Vector2(0, 31)
		out_l.size = Vector2(cell, 22)
		out_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		out_l.add_theme_font_size_override("font_size", 15)
		out_l.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
		if m == null:
			out_l.text = "—"
		elif _cls(m) == "boost":
			# 增幅不产出，显示「每次给每个邻居加多少 × 给几个邻居」
			var fed := 0
			for j in _neighbors(i):
				var nb = weapon.slots[j]
				if nb != null and _cls(nb) != "boost":
					fed += 1
			out_l.text = "→%.0f×%d" % [float(MODULES[String(m["id"])]["boost"]), fed]
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
