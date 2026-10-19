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
const UIKit := preload("res://scripts/ui_kit.gd")
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
const SPAWN_GROWTH := 1.190
const MAX_ENEMIES := 560
## 生成半径必须落在**镜头视野之外**：zoom 0.62 时半个屏幕是 1032×580，
## 对角约 1184，所以 >1200 才能保证任何角度都在屏幕外，让敌人「走」进来而不是凭空出现
const SPAWN_R_MIN := 1220.0
const SPAWN_R_MAX := 1400.0
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
	# bulwark：慢速高血量「墙」，专在玩家前方生成逼走位（docs/plan-v3.md §3）
	"bulwark": {"speed": 46.0, "hp_mult": 4.20, "radius": 22.0, "color": Color(0.44, 0.72, 0.62)},
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
var shot_chest := false
var hold_pick := false
var pick_pre := false
var click_test := false
var ct2 := 0.0
var click_done := false
var chest_test := false
var ct_t := 0.0
var ct_opened := false
var ct_taken := false
var pick_delay := 0.0
var pick_wait := 0.0
var start_force := ""
var hud_stat: Label = null
var dbg_root: Control = null
var dbg_text: Label = null
var dbg_on := false
var seed_used := 0
var vis_enemy := 0
var build_close_btn: Button = null
var build_back_btn: Button = null
var uitest := false
var uitest_step := 0
var drag_test := false
var drag_demo := false
# --- bulwark（前方撞墙怪）---
var bulwark_t := 10.0
var last_move_dir := Vector2.RIGHT
var prev_ppos := Vector2.ZERO
var dt_step := 0
var tab := 0
var tab_bar: Control = null
var tab_body: Control = null
var tab_btns: Array = []
var hand_mid := ""
var autoplan := false
var noautoplan := false
var god := false
var cheat_arg := ""
var plan_fix_t := 0.0
var dev_pick_for := -1
var no_auto_craft := false
# --- 鼠标拖拽（构筑屏）---
var drag := {}
var drag_layer: Control = null
var drag_ghost: Panel = null
var drag_label: Label = null
var drag_hl: Panel = null
var drag_hint: Label = null
var recycle_btn: Button = null
var slot_rects: Array = []
var slot_panels: Array = []
var inv_rows: Array = []
var plan_missing_demo := false
var dbg_acc := 0.0
var _pick_from_build := false
var pick_mode := "level"
var chest_offer: Array = []
var pending_weapon: Dictionary = {}
var pending_chest := 0
var frame_ms := 0.0
var frame_ms_max := 0.0
var enemy_ms := 0.0
var roll_test := false
var swarm_test := false
var ws_done := false
var _cam_pos := Vector2.ZERO
var _cam: Camera2D = null
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
		elif a == "shotdbg":
			dbg_on = true
		elif a == "shotbuild":
			shot_build = true
		elif a.begins_with("seed="):
			seed_used = int(a.substr(5))
		elif a.begins_with("start="):
			start_force = a.substr(6)
		elif a.begins_with("pickdelay="):
			pick_delay = float(a.substr(10))
		elif a == "rolltest":
			roll_test = true
		elif a.begins_with("cheat="):
			cheat_arg = a.substr(6)
		elif a == "autoplan":
			autoplan = true
			noautoplan = false
		elif a.begins_with("devpick="):
			dev_pick_for = int(a.substr(8))
			tab = 2
		elif a == "noautocraft":
			no_auto_craft = true
		elif a == "noautoplan":
			autoplan = false
			noautoplan = true
		elif a.begins_with("tab="):
			tab = int(a.substr(4))
		elif a == "planmissing":
			plan_missing_demo = true
		elif a == "dragdemo":
			drag_demo = true
		elif a == "dragtest":
			drag_test = true
		elif a == "uitest":
			uitest = true
		elif a == "swarmtest":
			swarm_test = true
		elif a == "chesttest":
			chest_test = true
		elif a == "clicktest":
			click_test = true
			hold_pick = true
		elif a == "holdpick":
			hold_pick = true
		elif a == "shotchest":
			shot_chest = true
		elif a == "shotpick":
			shot_pick = true
		elif a == "shotbot":
			shot_bot = true
			bot = true
		elif a.begins_with("ff="):
			ff = float(a.substr(3))
	# 任何自测/截图模式都自动选卡（默认 0.5 秒后选第一张），免得机器人卡在选卡界面上；
	# holdpick 可以强制保留界面（拍图用），pickdelay=<秒> 可以改等待时间
	if (playtest or bot or shot_bot or shot_pick or shot_chest) and pick_delay <= 0.0:
		pick_delay = 0.5
	# bot 默认开着「自动配置方案」：它不会自己去拖模块，得让补料规则替它决定每格放什么
	if bot and not noautoplan:
		autoplan = true
	if playtest:
		# 无头模拟按实时速度跑太慢，放大时间步（步长变粗，数值平衡够用）
		Engine.time_scale = 8.0
		Engine.max_fps = 0
	if seed_used != 0:
		rng.seed = seed_used
	else:
		rng.randomize()
		seed_used = rng.seed
	var start_id: String = START_POOL[rng.randi() % START_POOL.size()]
	if seed_used == 0:
		seed_used = rng.seed
	if roll_test:
		_run_rolltest()
		get_tree().quit()
		return
	if bot:
		start_id = "smg"  # 测平衡时固定武器，免得随机开局把两次结果拉不开
	if start_force != "":
		start_id = start_force
	weapons.append(_make_weapon(start_id, 3))
	_use_weapon(0)
	for i in weapon.slots.size():
		weapon.slots[i] = _new_module("base")
		weapon.plan[i] = "base"  # 开局满板基础模块，方案也一起登记，之后烧完会自动补
	_add_inv("base", 2)
	devices.append(_new_device())
	_make_player()
	_make_hud()
	if plan_missing_demo:
		for i in weapon.slots.size():
			weapon.slots[i] = null
			weapon.plan[i] = "reson"
	if cheat_arg != "":
		_apply_cheats(cheat_arg)
	# bot / playtest 默认把所有装置设成自动，等价于旧版「装置一直在干活」的行为
	if (playtest or bot) and not no_auto_craft:
		_sync_device_auto(true)
	_refresh_hud()
	_test_banner()



# --- 作弊码（debug 用） ---------------------------------------------------------
# CLI: -- "cheat=rich,god,level,wave=15"（逗号分隔，可叠加）
# 快捷键（任何时候）：F5 无敌开/关　F6 +100 基础　F7 等级 +5　F8 时间 +40s　F9 全套武器
func _apply_cheats(spec: String) -> void:
	for raw in spec.split(",", false):
		var item := raw.strip_edges()
		if item == "":
			continue
		var kv := item.split("=", true, 1)
		var key := kv[0]
		var val := int(kv[1]) if kv.size() > 1 else 0
		match key:
			"rich":
				_add_inv("base", 500)
				print("[cheat] +500 基础模块")
			"modules":
				for k in MOD_ORDER:
					_add_inv(String(k), 20)
				_add_inv("base", 300)
				print("[cheat] 每种模块 +20，基础 +300")
			"god":
				god = true
				print("[cheat] 无敌开")
			"level":
				level = maxi(level, 25 if val <= 0 else val)
				print("[cheat] 等级 = %d" % level)
			"wave":
				elapsed = maxf(0.0, float(val - 1) * WAVE_SEC)
				wave = maxi(1, val)
				print("[cheat] 跳到第 %d 波（elapsed=%.0f）" % [wave, elapsed])
			"weapons":
				_give_all_weapons()
				print("[cheat] 发全套武器，背包 %d" % weapons.size())
			"devices":
				var n: int = maxi(1, val if val > 0 else 5)
				for i in n:
					devices.append(_new_device())
				print("[cheat] 装置 +%d（共 %d 台）" % [n, devices.size()])
			"hp":
				max_hp = 9999.0
				hp = max_hp
				print("[cheat] HP 拉满")
			_:
				print("[cheat] 未知作弊码：%s" % key)


func _give_all_weapons() -> void:
	for id in ["pistol", "smg", "shotgun", "sniper", "beam", "grenade", "blade", "laser"]:
		if weapons.size() >= 12:
			break
		var w := _make_weapon(String(id), 5)
		weapons.append(w)
	_refresh_hud()


func _cheat_key(k: int) -> bool:
	match k:
		KEY_F5:
			god = not god
			print("[cheat] 无敌 %s" % ("开" if god else "关"))
		KEY_F6:
			_add_inv("base", 100)
			print("[cheat] +100 基础模块（库存 %d）" % _inv("base"))
		KEY_F7:
			level += 5
			print("[cheat] 等级 +5 → %d" % level)
		KEY_F8:
			elapsed += WAVE_SEC
			print("[cheat] 时间 +40s（wave 自动推进）")
		KEY_F9:
			_give_all_weapons()
			print("[cheat] 发全套武器，背包 %d" % weapons.size())
		_:
			return false
	_pass()
	return true


# --- 测试日志 ---------------------------------------------------------------
# 每次自测都在 stdout 打一对 [TEST] 行：start 说明这次测的是什么配置，end 说明结果。
# 目的：跑完不用回头翻参数，日志本身就是「测试内容 + 效果」的记录（也会同步到 docs/testlog.md）。
func _test_banner() -> void:
	var mode := "normal"
	if playtest:
		mode = "playtest"
	elif bot:
		mode = "bot"
	elif shot_path != "":
		mode = "shot"
	if mode == "normal" and cheat_arg == "":
		return
	print("[TEST] start mode=%s seed=%d bot=%s autoplan=%s cheat=%s pt=%.0f pickdelay=%.2f start=%s tab=%d" % [
		mode, absi(seed_used) % 1000000000, str(bot), str(autoplan),
		("—" if cheat_arg == "" else cheat_arg), pt_limit, pick_delay, start_force, tab])


func _test_end(reason: String) -> void:
	if not (playtest or bot or shot_path != "" or cheat_arg != ""):
		return
	print("[TEST] end reason=%s t=%.0f wave=%d lvl=%d kills=%d dps=%.1f need=%.1f weapons=%d inv=%d dead=%s" % [
		reason, elapsed, wave, level, kills_total, cur_actual_dps(),
		_spawn_rate() * _wave_hp() * _plan_avg_mult(), weapons.size(), _inv_total(), str(dead)])



## 自动配置方案要对「所有武器」生效：bot 每 4 秒会换一把正在编辑的枪，
## 只填当前选中那把的话，其余枪永远空着（面板上就是 slot=2/4）
func _auto_plan_all() -> void:
	var keep := sel
	for i in weapons.size():
		sel = i
		_auto_plan_fill()
	sel = keep

## bot 专用：方案里写的模块补不上时（库存没有那个 id，或那个 id 只能靠合成），
## 每 2 秒允许把缺料格子的方案改写成「当前库存里整板增益最大」的 id。
## 玩家侧不开这个开关：玩家要的是「我摆的方案永远生效」，缺料就红着提示，绝不偷偷换。
func _auto_plan_fix(delta: float) -> void:
	plan_fix_t += delta
	if plan_fix_t < 2.0:
		return
	plan_fix_t = 0.0
	var keep := sel
	for wi in weapons.size():
		_use_weapon(wi)
		for i in _missing_cells():
			var want := String(weapon.plan[i])
			if want != "" and _inv(want) > 0:
				_refill(i)  # 有料就直接补，不改方案
				continue
			var best_id := ""
			var best_v := _board_total(weapon)
			for k in _stocked_ids():
				weapon.slots[i] = _new_module(k)
				var v := _board_total(weapon)
				weapon.slots[i] = null
				if v > best_v + 0.0001:
					best_v = v
					best_id = k
			if best_id == "":
				continue
			weapon.plan[i] = best_id
			_add_inv(best_id, -1)
			weapon.slots[i] = _new_module(best_id)
	_use_weapon(keep)

## 模块寿命带 ±15% 抖动：否则同一批装上去的模块会同时烧光，DPS 出现断崖
func _new_module(mid: String) -> Dictionary:
	var d: Dictionary = MODULES[mid]
	var u := float(d["uses"]) * rng.randf_range(0.85, 1.15) * pow(1.08, float(_bl("uses")))
	return {"id": mid, "tier": int(d["tier"]), "left": u, "max": u}


func _new_device() -> Dictionary:
	return {"kind": "", "left": 0.0, "total": 0.0, "auto": false, "paid": []}


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
		# kind 是模块 id 字符串（"" = 空闲）。写成 int(kind) 会得到 0，把在干活的装置当成空闲。
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
	var nd := _new_device()
	# bot / playtest 里新装置默认开机自动，否则平衡测试会因为「装置没人管」而失真
	nd["auto"] = (playtest or bot) and not no_auto_craft
	devices.append(nd)
	return true


## 一键把自动开关同步到所有装置（bot 用）
func _sync_device_auto(on: bool) -> void:
	for d in devices:
		d["auto"] = on


func _make_player() -> void:
	player = Node2D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.name = "Player"
	player.add_to_group("player")
	# 世界里的东西都要能被 get_tree().paused 停住（Game 自己是 ALWAYS，子节点默认会继承）
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	var cam := Camera2D.new()
	# 不开平滑：Godot 4.7 里 Camera2D 的 position smoothing 会和 zoom 打架，
	# 偶尔把 screen_center 算成 NaN → 整个世界凭空消失（实测 t=520 全黑）
	cam.position_smoothing_enabled = false
	# 视野缩放：刷怪半径 540–660，不缩小镜头的话敌人全在屏幕外，看不到「一圈合围」
	cam.zoom = Vector2(0.62, 0.62)
	player.add_child(cam)
	cam.make_current()
	_cam = cam


func _label(parent: Node, pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	# 卡片上的文字必须让点击穿透到 Button，否则点标题附近没反应
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	hud_stat = _label(layer, Vector2(742, 16), 16, Color(0.55, 0.6, 0.68))
	hud_tip = _label(layer, Vector2(18, 690), 16, Color(0.6, 0.65, 0.75))
	hud_tip.text = "WASD 移动   TAB 构筑   U 升级   Q/E 选配方  C 合成   X 造装置   1-9 选武器  F 开关   F3 调试   R 重开"

	wpanel = _label(layer, Vector2(18, 84), 17, Color(0.78, 0.86, 1.0))

	# F3 调试面板（默认关）
	dbg_root = Control.new()
	dbg_root.position = Vector2(836, 76)
	dbg_root.size = Vector2(424, 160)
	dbg_root.visible = dbg_on
	dbg_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dbg_root.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(dbg_root)
	var dbg_bg := Panel.new()
	dbg_bg.size = Vector2(424, 160)
	dbg_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dbgsb := StyleBoxFlat.new()
	dbgsb.bg_color = Color(0.03, 0.05, 0.09, 0.82)
	dbgsb.border_color = Color(0.35, 0.5, 0.75, 0.7)
	dbgsb.set_border_width_all(1)
	dbgsb.set_corner_radius_all(6)
	dbg_bg.add_theme_stylebox_override("panel", dbgsb)
	dbg_root.add_child(dbg_bg)
	dbg_text = _label(dbg_root, Vector2(12, 10), 15, Color(0.72, 0.86, 1.0))

	build_root = Control.new()
	build_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	build_root.visible = false
	build_root.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(build_root)

	pick_root = Control.new()
	pick_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	pick_root.size = Vector2(1280, 720)
	pick_root.mouse_filter = Control.MOUSE_FILTER_STOP
	# 选卡面板默认隐藏：以前这里常驻一层 0.86 的暗色，导致整局画面都像被暂停
	pick_root.visible = false
	# 整棵树被 paused 时，控件必须显式 ALWAYS 才能收到鼠标事件
	pick_root.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(pick_root)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	build_root.add_child(bg)

	# 构筑屏的统一返回入口：右上角 × 和左上角 ←，都走 _toggle_build
	build_close_btn = UIKit.close_button(build_root, _toggle_build, 18.0)
	build_back_btn = UIKit.back_button(build_root, "返回战斗", _toggle_build, Vector2(24, 14))

	build_text = Label.new()
	build_text.position = Vector2(80, 60)
	build_text.add_theme_font_size_override("font_size", 19)
	build_text.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	build_root.add_child(build_text)

	board_root = Control.new()
	board_root.position = Vector2(100, 185)
	build_root.add_child(board_root)

	# 卸载区：把电路板上的模块拖到这里 = 卸下退回库存（见 docs/plan-v3.md §1）
	recycle_btn = UIKit.button("⌫ 拖到此处卸下", Vector2(150, 40), UIKit.C_RED, 14)
	recycle_btn.position = Vector2(330, 640)
	recycle_btn.tooltip_text = "把电路板上的模块拖进来：卸下并退回库存，同时清空这一格的方案"
	build_root.add_child(recycle_btn)

	# 拖拽层：幽灵 + 落点高亮 + 出力预览（全部 IGNORE，不抢鼠标）
	drag_layer = Control.new()
	drag_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_layer.visible = false
	build_root.add_child(drag_layer)

	drag_ghost = Panel.new()
	drag_ghost.size = Vector2(210, 34)
	drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gsb := StyleBoxFlat.new()
	gsb.set_corner_radius_all(8)
	gsb.bg_color = Color(0.10, 0.13, 0.19, 0.94)
	gsb.set_border_width_all(2)
	gsb.border_color = UIKit.C_GOLD
	drag_ghost.add_theme_stylebox_override("panel", gsb)
	drag_label = Label.new()
	drag_label.position = Vector2(10, 6)
	drag_label.add_theme_font_size_override("font_size", 15)
	drag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_ghost.add_child(drag_label)
	drag_layer.add_child(drag_ghost)

	drag_hl = Panel.new()
	drag_hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_hl.visible = false
	drag_layer.add_child(drag_hl)

	drag_hint = Label.new()
	drag_hint.add_theme_font_size_override("font_size", 16)
	drag_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_layer.add_child(drag_hint)

	build_info = Label.new()
	build_info.position = Vector2(660, 168)
	build_info.add_theme_font_size_override("font_size", 16)
	build_info.add_theme_color_override("font_color", Color(0.82, 0.88, 0.98))
	build_root.add_child(build_info)

	# 右栏三标签页：库存 / 配方 / 装置（见 docs/plan-ui-v1.md §2.1）
	tab_bar = Control.new()
	tab_bar.position = Vector2(660, 248)
	build_root.add_child(tab_bar)
	var tab_names := ["库存", "配方", "装置"]
	for i in 3:
		var tb := UIKit.button(tab_names[i], Vector2(88, 30), UIKit.C_BLUE, 15)
		tb.position = Vector2(i * 96, 0)
		tb.pressed.connect(_set_tab.bind(i))
		tab_bar.add_child(tb)
		tab_btns.append(tb)
	tab_body = Control.new()
	tab_body.position = Vector2(660, 290)
	build_root.add_child(tab_body)

	flash = ColorRect.new()
	flash.color = Color(1, 0.2, 0.25, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)


func _input(event: InputEvent) -> void:
	# 拖拽优先：构筑屏里的按住-拖动-松开由这里独占（见 docs/plan-v3.md §1）
	if build_root != null and build_root.visible and not dead:
		if _drag_input(event):
			return
	# 统一返回：ESC / 鼠标右键 都能退出最上层的界面（选卡 -> 构筑）
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if not drag.is_empty():
			drag = {}
			_drag_clear()
			return
		if _close_topmost():
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _close_topmost():
			get_viewport().set_input_as_handled()
			return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	# 作弊键：F5 无敌 / F6 +100 基础 / F7 等级+5 / F8 时间+40s / F9 全套武器
	if k >= KEY_F5 and k <= KEY_F9 and _cheat_key(k):
		return
	if k == KEY_F3:
		dbg_on = not dbg_on
		if dbg_root != null:
			dbg_root.visible = dbg_on
		_refresh_dbg_panel(get_tree().get_nodes_in_group("enemy").size())
		return
	if picking:
		if k >= KEY_1 and k <= KEY_4:
			_take_card(k - KEY_1)
		elif k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER:
			_take_card(0)
		elif k == KEY_T and pick_mode == "level":
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
	# 选卡界面会把整棵树暂停，elapsed 不再推进 —— 快进和截图都必须先跳出这个状态，
	# 否则会永远停在「等 elapsed 到 ff / shotat」上（表现为界面卡死）
	if picking:
		ff = 0.0
		Engine.time_scale = 1.0
		if shot_path != "" and hold_pick:
			elapsed = shot_at
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
	# 选卡界面会冻结 elapsed，截图逻辑若还在等 shotat 就会永久挂住（holdpick 时才强制跳时间）
	if picking and shot_path != "" and hold_pick:
		elapsed = shot_at
	if shot_path == "" or shot_at < 0.0:
		return
	# 死了之后 elapsed 不再推进，如果还在等 shotat 就会永久挂住 —— 死亡即立刻拍
	if not dead:
		if elapsed < shot_at:
			if ff <= 0.0:
				shot_guard += delta
			if shot_guard > 600.0:
				print("shot guard timeout")
				get_tree().quit()
			return
	shot_at = -1.0
	Engine.time_scale = 1.0
	if picking and not hold_pick and (shot_bot or playtest or shot_chest or shot_pick or pick_delay > 0.0):
		_take_card(0)
	if shot_chest and not pick_pre and ff == 0.0:
		pick_pre = true
		if picking:
			_close_pick()  # 截图工具：让开箱面板优先，直接丢掉当前那张升级卡
		grant_chest(true)
	if shot_pick and not picking:
		_roll_offer()
		_open_pick()
	if shot_build and not build_root.visible:
		_toggle_build()
	if drag_demo and not dt_step:
		dt_step = 1
		await get_tree().process_frame
		await _dragdemo_pose()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	print("shot saved: %s" % shot_path)
	get_tree().quit()


func _push_btn(p: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = p
	ev.global_position = p
	get_viewport().push_input(ev)


## 拖拽演示：按下并拖到第 2 格上方但不松手，留着给截图用（幽灵 + 落点预览）
func _dragdemo_pose() -> void:
	tab = 0
	_refresh_build()
	await get_tree().process_frame
	if inv_rows.is_empty() or slot_rects.size() < 2:
		print("DRAGDEMO skip")
		return
	var row: Dictionary = inv_rows[0]
	for r in inv_rows:
		if String(r["mid"]) != "base":
			row = r
			break
	var from: Vector2 = (row["rect"] as Rect2).get_center()
	var to: Vector2 = (slot_rects[1] as Rect2).get_center() + Vector2(30, 26)
	_push_btn(from, true)
	var mm := InputEventMouseMotion.new()
	mm.position = to
	mm.global_position = to
	get_viewport().push_input(mm)
	print("DRAGDEMO active=%s mid=%s preview_shown=%s" % [str(drag.get("active", false)), String(row["mid"]), str(drag_hl.visible)])


## 拖拽自检：真鼠标事件把库存第一行拖到第 2 格，打印前后槽位内容
func _run_dragtest() -> void:
	_toggle_build()
	tab = 0
	_refresh_build()
	await get_tree().process_frame
	await get_tree().process_frame
	if inv_rows.is_empty() or slot_rects.size() < 2:
		print("DRAGTEST skip inv=%d slots=%d" % [inv_rows.size(), slot_rects.size()])
		get_tree().quit()
		return
	# 优先挑一个和当前槽位不同的模块，才能看出「真的换了 id」
	var row: Dictionary = inv_rows[0]
	for r in inv_rows:
		if String(r["mid"]) != String(weapon.slots[1]["id"]) if weapon.slots[1] != null else true:
			row = r
			break
	var mid := String(row["mid"])
	var from: Vector2 = (row["rect"] as Rect2).get_center()
	var to: Vector2 = (slot_rects[1] as Rect2).get_center()
	var before := str(weapon.slots[1])
	var inv_before := _inv(mid)
	_push_btn(from, true)
	var mm := InputEventMouseMotion.new()
	mm.position = to
	mm.global_position = to
	get_viewport().push_input(mm)
	_push_btn(to, false)
	print("DRAGTEST mid=%s inv %d->%d  slot1 %s -> %s  plan1=%s  active=%s" % [
		mid, inv_before, _inv(mid), before, str(weapon.slots[1]), str(weapon.plan[1]), str(drag.get("active", false))])
	get_tree().quit()


func _physics_process(delta: float) -> void:
	if drag_test and dt_step == 0 and not playtest:
		pass
	if drag_test and dt_step == 0:
		dt_step = 1
		_run_dragtest()
	# UI 底座自检：开构筑屏 → 打印坐标诊断 → 合成一次真实鼠标点击 → 看是否真点到 ×
	if uitest and uitest_step == 0:
		uitest_step = 1
		_toggle_build()
		print("UITEST " + UIKit.diag(self, build_root))
		print("UITEST vp=%s slot0_local=%s slot0_global=%s inv0=%s slots=%d inv_rows=%d" % [
			str(get_viewport().get_visible_rect().size),
			str(slot_rects[0]) if slot_rects.size() > 0 else "none",
			str((slot_panels[0] as Control).get_global_rect()) if slot_panels.size() > 0 else "none",
			str(inv_rows[0]["rect"]) if inv_rows.size() > 0 else "none",
			slot_rects.size(), inv_rows.size()])
		if build_close_btn != null:
			print("UITEST close_rect=%s visible_in_tree=%s" % [
				str(build_close_btn.get_global_rect()), str(build_close_btn.is_visible_in_tree())])
	elif uitest and uitest_step == 1:
		uitest_step = 2
		var c := Vector2(1140, 34)
		if build_close_btn != null:
			c = build_close_btn.get_global_rect().get_center()
		var dn := InputEventMouseButton.new()
		dn.button_index = MOUSE_BUTTON_LEFT
		dn.pressed = true
		dn.position = c
		dn.global_position = c
		get_viewport().push_input(dn)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = c
		up.global_position = c
		get_viewport().push_input(up)
		print("UITEST click_at=%s after_click build_visible=%s" % [str(c), str(build_root.visible)])
		get_tree().quit()
	if swarm_test and elapsed > 1.0 and not ws_done:
		ws_done = true
		for i in 120:
			var gx := (i % 12) - 6
			var gy := int(i / 12) - 5
			_spawn_enemy_at(player.position + Vector2(gx * 52.0, gy * 46.0))
	# 点击自检：开箱 -> 1 秒后向视口塞一个真实鼠标点击 -> 看卡片是否被响应
	if click_test:
		ct2 += delta
		if ct2 > 0.5 and not picking and not pick_pre:
			pick_pre = true
			grant_chest(true)
			print("CLICKTEST opened mode=%s cards=%d" % [pick_mode, chest_offer.size()])
		elif ct2 > 1.5 and picking and not click_done:
			click_done = true
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = Vector2(300, 360)
			ev.global_position = ev.position
			get_viewport().push_input(ev)
			var up := InputEventMouseButton.new()
			up.button_index = MOUSE_BUTTON_LEFT
			up.pressed = false
			up.position = ev.position
			up.global_position = ev.position
			get_viewport().push_input(up)
			var mv := InputEventMouseMotion.new()
			mv.position = ev.position
			mv.global_position = ev.position
			get_viewport().push_input(mv)
			var hov := get_viewport().gui_get_hovered_control()
			print("CLICKTEST hovered=%s pick_rect=%s" % [str(hov), str(pick_root.get_global_rect())])
		elif ct2 > 2.2 and click_done:
			print("CLICKTEST result picking=%s weapons=%d" % [str(picking), weapons.size()])
			get_tree().quit()
	# 开箱链路自检：开 → 选第 2 张 → 验证进背包
	if chest_test:
		ct_t += delta
		if ct_t > 0.5 and not ct_opened:
			ct_opened = true
			grant_chest(true)
			print("CHESTTEST opened mode=%s cards=%d" % [pick_mode, chest_offer.size()])
		elif ct_opened and picking and ct_t > 1.0 and not ct_taken:
			ct_taken = true
			_take_weapon_card(1)
			print("CHESTTEST taken weapons=%d backpack=%d/%d picking=%s" % [
				weapons.size(), _backpack_used(), backpack_cap, str(picking)])
		if ct_t > 1.6:
			print("CHESTTEST done weapons=%d picking=%s" % [weapons.size(), str(picking)])
			get_tree().quit()
	# 选卡时整棵树已 paused，但 Game 自己是 ALWAYS，所以要在这里单独推进倒计时
	if picking:
		pick_wait += delta
		if pick_delay > 0.0 and pick_wait > pick_delay and not hold_pick:
			_take_card(0)
		return
	if dead or get_tree().paused:
		return
	elapsed += delta
	var prev_wave := wave
	wave = int(elapsed / WAVE_SEC) + 1
	if wave != prev_wave:
		_on_wave_start()
	_bot_move(delta)
	# 记录玩家真实移动方向：bulwark 要生成在「玩家正在走的方向」前面堵路
	if player != null:
		var dp := player.position - prev_ppos
		if dp.length() > 0.5:
			last_move_dir = dp.normalized()
		prev_ppos = player.position
	_spawn(delta)
	_tick_bulwark(delta)
	_craft_tick(delta)
	if autoplan:
		_auto_plan_all()
		_auto_plan_fix(delta)
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
		_test_end("limit")
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
	# 每 ~4 秒把编辑目标切到「最空的那把枪」，让材料摊到各把武器上（否则全堆在第一把）
	if bot_ticks % 8 == 0:
		var pick_i := sel
		var best_n := 99
		for i in weapons.size():
			var n2 := 0
			for m2 in weapons[i]["slots"]:
				if m2 != null:
					n2 += 1
			if n2 < best_n:
				best_n = n2
				pick_i = i
		_use_weapon(pick_i)
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
	var bw: Dictionary = _board_weapon()
	for m in bw["slots"]:
		comp += "." if m == null else str(int(m.tier))
	var bfill := 0
	for m in bw["slots"]:
		if m != null:
			bfill += 1
	var bmiss := 0
	for i in (bw["plan"] as Array).size():
		if (bw["slots"] as Array)[i] == null and String((bw["plan"] as Array)[i]) != "":
			bmiss += 1
	print("t=%3d w=%2d hp=%3d dps=%5.1f need=%5.1f drop=%.2f burn=%.2f lvl=%2d slot=%d/%d miss=%d dev=%d/%d [%s] inv=[%s] c=%d/%d/%d/%d kills=%d dmg c%.0f/b%.0f/d%.0f alive=%d ppos=%.0f,%.0f cpos=%.0f,%.0f bw=%d" % [
		int(pt_t), wave, int(maxf(hp, 0.0)), cur_dps(), need,
		cur_drop(), cur_burn(), level, bfill, (bw["slots"] as Array).size(), bmiss,
		_busy_devices(), devices.size(), comp, _inv_str(),
		crafted.get("base", 0), crafted.get("add", 0), crafted.get("amp", 0), crafted.get("reson", 0), kills_total,
		float(dmg_src["contact"]), float(dmg_src["bullet"]), float(dmg_src["dash"]),
		get_tree().get_nodes_in_group("enemy").size(), player.position.x, player.position.y, _cam_pos.x, _cam_pos.y, _count_bulwark(),
	])


func _hud_tick(delta: float) -> void:
	if _cam != null:
		_cam_pos = _cam.get_screen_center_position()
	flash_t = maxf(0.0, flash_t - delta)
	if elapsed - last_hit_t > REGEN_DELAY:
		hp = minf(max_hp, hp + (REGEN_RATE + 0.5 * float(_bl("regen"))) * delta)
	# 构筑屏/死亡屏打开时不要红色受击遮罩，否则整个面板被染红
	flash.color = Color(1, 0.2, 0.25, 0.0 if (build_root.visible or dead) else minf(flash_t * 0.9, 0.26))
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
	_update_debug(delta)


## 调试统计：FPS / 敌人数 / 可见敌人数 / 帧耗时。
## 关闭 F3 面板时仍然维护常驻的那一小段（可见数 O(n) 遍历只在 0.25s 一次）
func _update_debug(delta: float) -> void:
	frame_ms = delta * 1000.0
	frame_ms_max = maxf(frame_ms_max * 0.97, frame_ms)
	dbg_acc += delta
	if dbg_acc < 0.25:
		return
	dbg_acc = 0.0
	var enemies := get_tree().get_nodes_in_group("enemy")
	var t0 := Time.get_ticks_usec()
	var ct: Transform2D = get_viewport().get_canvas_transform()
	var vis := 0
	for e in enemies:
		var p: Vector2 = ct * (e as Node2D).global_position
		if p.x >= 0.0 and p.y >= 0.0 and p.x <= 1280.0 and p.y <= 720.0:
			vis += 1
	vis_enemy = vis
	enemy_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	if hud_stat != null:
		hud_stat.text = "FPS %d · 敌 %d(可见 %d)" % [
			int(Engine.get_frames_per_second()), enemies.size(), vis]
	_refresh_dbg_panel(enemies.size())


func _refresh_dbg_panel(enemy_total: int) -> void:
	if dbg_text == null or not dbg_on:
		return
	dbg_text.text = "\n".join([
		"FPS %d   帧 %.1fms   峰 %.1fms" % [int(Engine.get_frames_per_second()), frame_ms, frame_ms_max],
		"敌人 %d   可见 %d   上限 %d   刷怪 %.2f/s" % [enemy_total, vis_enemy, MAX_ENEMIES, _spawn_rate()],
		"掉落 %d   子弹 %d   宝箱 %d" % [
			get_tree().get_nodes_in_group("pickup").size(),
			get_tree().get_nodes_in_group("bullet").size(),
			get_tree().get_nodes_in_group("chest").size()],
		"需求 %.1f   实测 %.1f   需求比 %s" % [
			_spawn_rate() * _wave_hp() * _plan_avg_mult(), cur_actual_dps(),
			"%.0f%%" % (100.0 * _spawn_rate() * _wave_hp() * _plan_avg_mult() / maxf(cur_actual_dps(), 1.0))],
		"敌人统计耗时 %.2fms" % enemy_ms,
		"波次 %d   时间 %s   种子 %d   击杀 %d" % [wave, _fmt_time(elapsed), absi(seed_used) % 1000000000, kills_total],
	])


## 波次血量：12 波之前走平缓曲线；之后额外乘 1.045/波 —— 这时玩家武器基本成型，
## 难度不提就会被碾压（曲线要追着玩家的构筑跑，而不是线性增长）
func _wave_hp() -> float:
	var late := maxf(0.0, float(wave - 12))
	return HP_BASE * pow(HP_GROWTH, wave - 1) * pow(1.045, late)


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
	# 数量优先：指数刷怪（1.20 × 1.19^波），血量只温和地涨，压力主要来自「人多」
	var base: float = SPAWN_BASE * pow(SPAWN_GROWTH, float(wave))
	var raw: float = base * float(_plan()["coeff"])
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
		"blast": 90.0, "ramp_max": 1.20,
		"score": 0.0, "p0": 0.0, "band": 1.0, "dr": {},
		# 槽位方案：每格记住「这一格该放什么模块 id」。寿命耗尽后按它自动补料，
		# 空字符串表示这一格没有方案（自动入槽才允许乱填）。
		"plan": [],
	}
	_set_quality_of(w, q)
	_roll_weapon(w)
	return w


# --- 武器随机数值（方案 v2.8 §17）------------------------------------------------
# 分值只在同种类内比较：P0(id) = 该类型的「蓝档 100 分」。
# 随机改的是「形状」（射程/间隔/基础/目标数/专属字段），总分用 mul 归一化钉回 band，
# 所以同类型同品级的两把一定强度相当、手感不同。
const QM := {1: 0.55, 2: 0.75, 3: 1.00, 4: 1.35, 5: 1.80}

# 每种武器自己的浮动幅度：r 射程 / i 间隔 / b 基础 / tg 目标+1 概率 / x 专属字段
const ROLL_P := {
	"pistol": {"r": 0.10, "i": 0.12, "b": 0.15, "tg": 0.12},
	"smg": {"r": 0.08, "i": 0.10, "b": 0.20, "tg": 0.0},
	"shotgun": {"r": 0.08, "i": 0.10, "b": 0.15, "tg": 0.0},
	"sniper": {"r": 0.12, "i": 0.08, "b": 0.18, "tg": 0.10},
	"beam": {"r": 0.10, "i": 0.08, "b": 0.15, "tg": 0.0, "x": 0.20},
	"grenade": {"r": 0.10, "i": 0.10, "b": 0.15, "tg": 0.0, "x": 0.15},
	"blade": {"r": 0.12, "i": 0.10, "b": 0.15, "tg": 0.0, "x": 0.12},
	"laser": {"r": 0.10, "i": 0.15, "b": 0.15, "tg": 0.0},
}


func _eff_targets(w: Dictionary) -> float:
	var id := String(w["id"])
	var t := int(w["targets"])
	if id == "grenade":
		return 1.0 + 0.6 * float(w.get("blast", 90.0)) / 90.0
	if id == "blade":
		return 3.0 * float(w["range"]) / 105.0
	if id == "laser":
		return 3.0
	if t < 0:
		return 3.0
	return float(mini(t, 5))


func _range_w(r: float) -> float:
	return 1.0 + clampf((r - 150.0) / 1500.0, 0.0, 0.5)


func weapon_score(w: Dictionary) -> float:
	var iv := maxf(float(w["interval"]), 0.05)
	return (float(w["base"]) * float(w["mul"]) / iv) * _eff_targets(w) * _range_w(float(w["range"]))


## 该类型的典型模板分（品质 3），代码现算，不写死表
func p0_of(id: String) -> float:
	var kd: Dictionary = WEAPONS[id]
	var w := {
		"id": id, "base": float(QUALITY_BASE[3]), "mul": float(kd["mul"]),
		"interval": float(kd["interval"]), "range": float(kd["range"]),
		"targets": int(kd["targets"]), "blast": 90.0,
	}
	return weapon_score(w)


func _roll_weapon(w: Dictionary) -> void:
	var id := String(w["id"])
	var rp: Dictionary = ROLL_P.get(id, {"r": 0.10, "i": 0.10, "b": 0.15, "tg": 0.0})
	var dr := {}
	var r0 := float(w["range"])
	var i0 := float(w["interval"])
	var b0 := float(w["base"])
	w["range"] = r0 * (1.0 + rng.randf_range(-float(rp["r"]), float(rp["r"])))
	w["interval"] = i0 * (1.0 + rng.randf_range(-float(rp["i"]), float(rp["i"])))
	w["base"] = b0 * (1.0 + rng.randf_range(-float(rp["b"]), float(rp["b"])))
	dr["range"] = float(w["range"]) / maxf(r0, 0.0001) - 1.0
	dr["interval"] = float(w["interval"]) / maxf(i0, 0.0001) - 1.0
	dr["base"] = float(w["base"]) / maxf(b0, 0.0001) - 1.0
	if float(rp.get("tg", 0.0)) > 0.0 and int(w["targets"]) > 0 and int(w["targets"]) < 6 \
			and rng.randf() < float(rp["tg"]):
		w["targets"] = int(w["targets"]) + 1
		dr["targets"] = 1.0
	if rp.has("x"):
		var x := float(rp["x"])
		if id == "grenade":
			w["blast"] = 90.0 * (1.0 + rng.randf_range(-x, x))
			dr["blast"] = float(w["blast"]) / 90.0 - 1.0
		elif id == "beam":
			w["ramp_max"] = 1.20 * (1.0 + rng.randf_range(-x, x))
			dr["ramp_max"] = float(w["ramp_max"]) / 1.20 - 1.0
		else:
			w["range"] = float(w["range"]) * (1.0 + rng.randf_range(-x, x))
			dr["range"] = float(w["range"]) / maxf(r0, 0.0001) - 1.0
	# 归一化：先把 mul 归 1 算分数，再反解 mul 让总分正好落在 band 上。
	# 归一化只能用 mul —— 它是唯一不改射程/射速/目标数的乘数，用别的会把武器性格抹平。
	var q := int(w["quality"])
	var p0 := p0_of(id)
	w["p0"] = p0
	w["band"] = p0 * float(QM[q]) * rng.randf_range(0.94, 1.06)
	w["mul"] = 1.0
	var sc := weapon_score(w)
	w["mul"] = clampf(float(w["band"]) / maxf(sc, 0.0001), 0.05, 40.0)
	w["score"] = weapon_score(w)
	w["dr"] = dr


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
	var plan: Array = w["plan"]
	while slots.size() < w["layout"].size():
		slots.append(null)
	while slots.size() > w["layout"].size():
		slots.pop_back()
	while plan.size() < slots.size():
		plan.append("")
	while plan.size() > slots.size():
		plan.pop_back()


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
		d["total"] = 0.0
		d["paid"] = []
		crafted[k] = int(crafted.get(k, 0)) + 1
		_install(k)
		# 「自动」装置做完立刻接下一个：先试同一个配方，材料不够就退回自动挑一个
		if bool(d.get("auto", false)):
			if not try_craft(k, devices.find(d)):
				try_craft("", devices.find(d))


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
	var rad: float = rng.randf_range(SPAWN_R_MIN, SPAWN_R_MAX)
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
				pos = player.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(SPAWN_R_MIN, SPAWN_R_MAX)
		if get_tree().get_nodes_in_group("enemy").size() >= MAX_ENEMIES:
			return
		_spawn_enemy_at(pos)


func _spawn_enemy(forced: String = "") -> void:
	var ang: float = rng.randf() * TAU
	_spawn_enemy_at(player.position + Vector2.from_angle(ang) * rng.randf_range(SPAWN_R_MIN, SPAWN_R_MAX), forced)


func _spawn_enemy_at(pos: Vector2, forced: String = "") -> Node2D:
	var kind := forced if forced != "" else _pick_kind()
	var kd: Dictionary = ENEMY_KINDS[kind]
	var e = Node2D.new()
	e.set_script(load("res://scripts/enemy.gd"))
	e.add_to_group("enemy")
	e.process_mode = Node.PROCESS_MODE_PAUSABLE
	e.position = pos
	e.kind = kind
	e.hp_mult = float(kd["hp_mult"])
	e.radius = float(kd["radius"])
	e.body_color = kd["color"]
	e.max_hp = _wave_hp() * float(kd["hp_mult"])
	e.hp = e.max_hp
	e.speed = float(kd["speed"]) * (1.0 + wave * 0.01)
	add_child(e)
	return e


## 同屏 bulwark 数量
func _count_bulwark() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if String(e.kind) == "bulwark":
			n += 1
	return n


## 每 16 秒在玩家「前进方向 ±50°」排一堵慢速高血量墙：往前走就会被撞上（docs/plan-v3.md §3.2）
func _tick_bulwark(delta: float) -> void:
	if wave >= 3:
		bulwark_t -= delta
		if bulwark_t <= 0.0:
			bulwark_t = 16.0
			_spawn_bulwark_arc()
	_recycle_bulwark()


func _spawn_bulwark_arc() -> void:
	var cap := mini(14, 2 + int(wave / 4.0))
	var n := mini(4, cap - _count_bulwark())
	if n <= 0:
		return
	var dir := last_move_dir
	if dir.length() < 0.1:
		dir = Vector2.from_angle(rng.randf() * TAU)
	var base_ang := dir.angle()
	for i in n:
		var a := base_ang + lerpf(-0.87, 0.87, (float(i) + 0.5) / float(n))
		var pos := player.position + Vector2.from_angle(a) * rng.randf_range(380.0, 460.0)
		var e := _spawn_enemy_at(pos, "bulwark")
		if e != null:
			# 依次浮现 0.9s / 1.5s / 2.1s …，像一堵墙慢慢立起来
			e.telegraph = 0.9 + 0.6 * float(i)


## 跑到玩家身后很远、又活得够久的 bulwark 直接回收，免得越积越多
func _recycle_bulwark() -> void:
	if int(elapsed * 2.0) % 4 != 0:
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if String(e.kind) != "bulwark":
			continue
		if float(e.age) > 6.0 and (e.position - player.position).dot(last_move_dir) < -1600.0:
			e.queue_free()


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
				w["ramp"] = minf(float(w.get("ramp", 0.0)) + 0.06, float(w.get("ramp_max", 1.20)) + float(mo["ramp_cap"]))
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
			var br := float(w.get("blast", 90.0)) + float(mo["blast"])
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
	# 掉落与血量成正比：血厚的敌人掉更多（平均值 = DROP_CHANCE，所以总产出不变，只是分配变公平）
	var chance := (DROP_CHANCE + 0.04 * float(_bl("drop"))) * float(e.hp_mult) / maxf(_plan_avg_mult(), 0.35)
	while chance >= 1.0:
		_spawn_pickup(e.position, "base")
		chance -= 1.0
	if rng.randf() < chance:
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
	c.process_mode = Node.PROCESS_MODE_PAUSABLE
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
func _chest_pool() -> Array:
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
	return pool


## 开箱：不再直接塞一把，而是给 4 个候选（各自独立滚品质/数值/网络），让玩家挑
func grant_chest(from_chest: bool = false) -> void:
	if from_chest:
		last_chest_t = elapsed
	# 测平衡时最多留 3 把枪：背包是武器与装置共享的，枪占满了就再也造不出装置（合成直接停摆）
	if bot and weapons.size() >= 3:
		_chest_to_modules()
		return
	if picking:
		pending_chest += 1
		return
	chest_offer.clear()
	var pool := _chest_pool()
	var used := {}
	var guard := 0
	while chest_offer.size() < 4 and guard < 80:
		guard += 1
		var id: String = String(pool[rng.randi() % pool.size()])
		if used.has(id) and pool.size() > 4:
			continue
		used[id] = true
		chest_offer.append(_make_weapon(id, _chest_quality()))
	pick_mode = "chest"
	_open_pick()


## 把选中的宝箱武器入包（背包满时先走「选一把替换」）
func _take_weapon_card(i: int) -> void:
	if i < 0 or i >= chest_offer.size():
		return
	pending_weapon = chest_offer[i]
	chest_offer.clear()
	if backpack_cap >= 0 and _backpack_used() >= backpack_cap:
		pick_mode = "replace"
		_paint_offer()
		return
	_adopt_weapon(pending_weapon)


func _adopt_weapon(w: Dictionary) -> void:
	# 新武器自带几块料，否则「宝箱给的新枪」永远只有 1 个基础模块，等于废铁
	var seeded := 1 + int(wave / 8)
	for i in mini(seeded, (w["slots"] as Array).size()):
		w["slots"][i] = _new_module("base" if i == 0 else ("add" if wave >= 10 else "base"))
	weapons.append(w)
	_use_weapon(weapons.size() - 1)
	pending_weapon = {}
	_close_pick()
	_refresh_hud()


func _replace_weapon(i: int) -> void:
	if i < 0 or i >= weapons.size() or pending_weapon.is_empty():
		return
	weapons.remove_at(i)
	if sel >= weapons.size():
		sel = maxi(0, weapons.size() - 1)
	_adopt_weapon(pending_weapon)


func _spawn_pickup(pos: Vector2, mid: String) -> void:
	var p = Node2D.new()
	p.set_script(load("res://scripts/pickup.gd"))
	p.add_to_group("pickup")
	p.process_mode = Node.PROCESS_MODE_PAUSABLE
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
		if not god:
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
	_test_end("dead")
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
	var plan: Array = ww["plan"]
	# 有方案的格子：只认方案里的 id，缺料就空着（绝不降阶替换），等库存补上再自动装回
	var want := String(plan[i]) if i < plan.size() else ""
	if want != "":
		if _inv(want) > 0:
			_add_inv(want, -1)
			sl[i] = _new_module(want)
		else:
			sl[i] = null
		return
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


func _install(mid: String, w = null) -> void:
	# 手动构筑（合成/升级/拾取）默认装到「当前选中的那把」，玩家按 1-9 切枪就能分别喂饱
	var ww: Dictionary = weapon if w == null else w
	var sl: Array = ww["slots"]
	# 增幅是「支撑件」：板上一旦有载体（共振）且支撑已经 2 个，就攒在库存里当共振的料
	if mid == "amp" and _installed_count(4) >= 1 and _installed_id("amp") >= 2:
		_add_inv(mid, 1)
		return
	var now := _board_total(ww)
	var best := -1
	var best_v := now + 0.001
	for i in sl.size():
		var m = sl[i]
		sl[i] = _new_module(mid)
		var v := _board_total(ww)
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
	if pick_mode != "chest" and pick_mode != "replace":
		pick_mode = "level"
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
	# 选卡时真的暂停整棵场景树：只靠 _physics_process 早退挡不住敌人自己的物理帧
	get_tree().paused = true
	# 两个全屏覆盖层不能同时开着：开选卡时先收起构筑屏，选完再放回来
	var was_build: bool = build_root != null and build_root.visible
	if was_build:
		_pick_from_build = true
		_toggle_build()
	picking = true
	pick_wait = 0.0
	pick_root.visible = true
	_paint_offer()
	_paint_pick_chrome()


func _paint_offer() -> void:
	if pick_root == null:
		return
	for c in pick_root.get_children():
		c.queue_free()
	if pick_mode == "chest":
		_paint_chest()
		return
	if pick_mode == "replace":
		_paint_replace()
		return
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
	sub.text = "配方卡可以按 T 换成第 4 张 buff" if not reroll_used else "配方卡已经换过了"
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


## 关掉最上层的界面。返回 true 表示这次输入被消费掉了。
## 优先级：选卡 > 构筑。升级四选一不允许跳过（必须选一张），所以吞掉输入但不关面板。
func _close_topmost() -> bool:
	if picking:
		if pick_mode == "level":
			return true
		_abort_pick()
		return true
	if build_root != null and build_root.visible:
		_toggle_build()
		return true
	return false


## 选卡面板的公共外框：右上角 ×。升级四选一必须选一张，所以不给关闭键。
func _paint_pick_chrome() -> void:
	if pick_root == null or pick_mode == "level":
		return
	UIKit.close_button(pick_root, _abort_pick, 18.0)


## 放弃当前面板（宝箱不拿、替换不换）
func _abort_pick() -> void:
	if not picking:
		return
	if pick_mode == "chest":
		chest_offer.clear()
	elif pick_mode == "replace":
		pending_weapon = {}
	_close_pick()


func _close_pick() -> void:
	picking = false
	if pick_root != null:
		pick_root.visible = false
	get_tree().paused = false
	pick_mode = "level"
	if pending_chest > 0 and not dead:
		pending_chest -= 1
		call_deferred("grant_chest")
	# 选卡前如果正在构筑，选完回到构筑屏（材料变了，正好让玩家继续操作）
	if not dead and build_root != null and not build_root.visible and _pick_from_build:
		_toggle_build()
	_pick_from_build = false
	if pick_root != null:
		for c in pick_root.get_children():
			c.queue_free()


## 领第 i 张卡
func _take_card(i: int) -> void:	# 宝箱面板走的是另一套数据（chest_offer），以前漏了这个分支，
	# 结果卡片点得动（button_down 有反应）但 pressed 永远落空、面板关不掉
	if pick_mode == "chest":
		_take_weapon_card(i)
		return
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
## 让某台装置开始做某个配方。idx = -1 表示「第一台空闲装置」。
## 返回 true 表示真的开工了（材料已扣）。
func try_craft(mid: String = "", idx: int = -1) -> bool:
	if idx < 0:
		idx = _idle_device()
	if idx < 0 or idx >= devices.size():
		return false
	if String(devices[idx]["kind"]) != "":
		return false
	if mid == "":
		mid = _auto_recipe()
	if mid == "" or not MODULES.has(mid):
		return false
	var st := recipe_state(mid)
	if not bool(st["ok"]):
		return false
	var t := int(st["tier"])
	var need := int(st["cost"])
	# 记录实际扣掉的模块 id，取消合成时按原样退还（种类可能混着，例如 2 个基础 1 个加法）
	var paid: Array = []
	for i in need:
		var got := _take_one_of_tier(t - 1)
		if got == "":
			break
		paid.append(got)
	if paid.size() < need:
		for p in paid:
			_add_inv(String(p), 1)
		return false
	var dur := float(CRAFT_TIME[t]) * pow(0.90, float(_bl("craft")))
	devices[idx]["kind"] = mid
	devices[idx]["total"] = dur
	devices[idx]["left"] = dur
	devices[idx]["paid"] = paid
	return true


## 从库存里取走一个指定阶的模块，返回它的 id（取不到返回 ""）
func _take_one_of_tier(t: int) -> String:
	var best := ""
	var best_n := 0
	for k in _ids_all():
		if int(MODULES[k]["tier"]) != t:
			continue
		if _inv(k) > best_n:
			best_n = _inv(k)
			best = String(k)
	if best == "":
		return ""
	_add_inv(best, -1)
	return best


## 取消某台装置的合成：材料全额退还
func device_cancel(idx: int) -> void:
	if idx < 0 or idx >= devices.size():
		return
	var paid: Array = devices[idx].get("paid", [])
	for p in paid:
		_add_inv(String(p), 1)
	devices[idx]["kind"] = ""
	devices[idx]["left"] = 0.0
	devices[idx]["total"] = 0.0
	devices[idx]["paid"] = []


func _auto_recipe() -> String:
	# 板子没满 → 先拿加法把格子垫起来；满了 → 先攒增幅，够 2 个立刻换共振
	var empty := 0
	var sl: Array = weapon["slots"]
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
	for m in weapon["slots"]:
		if m != null and int(m["tier"]) == t:
			n += 1
	return n


func _installed_id(mid: String) -> int:
	var n := 0
	for m in weapon["slots"]:
		if m != null and String(m["id"]) == mid:
			n += 1
	return n


func add_module(mid: String) -> void:
	var sl: Array = weapon["slots"]
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
		s += "%s%d %s %s %s  %s  实测 %5.1f / 理论 %5.1f   %.2f/%.2f\n" % [
			mark, i + 1, state, str(kd["name"]), QUALITY_NAME[int(w["quality"])],
			("%d槽" % (w["slots"] as Array).size()), actual, theory,
			float(w["score"]), float(w["p0"]) * float(QM[3])
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
	lines.append("构筑（暂停中）      TAB / ESC / 右键 / ← 返回")
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
	info.append("等级 %d  →  %d     需要 %d 个模块（库存 %d）" % [level, level + 1, level_cost(), _inv_total()])
	info.append("受击补偿 +%d     装置 %d 台（空闲 %d）     净弹药 %+.2f/s     实测 %.1f / 理论 %.1f" % [
		modules_from_damage, devices.size(), devices.size() - _busy_devices(),
		cur_drop() - cur_burn(), cur_actual_dps(), cur_dps()
	])
	var miss := _missing_cells()
	if hand_mid != "":
		info.append("手持 %s —— 点电路板格子放下（ESC 取消）" % String(MODULES[hand_mid]["name"]))
	elif miss.size() > 0:
		var mn: Array = []
		for i in miss:
			mn.append(String(MODULES[String(weapon.plan[i])]["name"]))
		info.append("缺料 %d 格：%s（攒够自动补上）" % [miss.size(), " / ".join(mn)])
	build_info.text = "\n".join(info)
	_rebuild_tab()
	_highlight_tab()


func _set_tab(i: int) -> void:
	tab = i
	_refresh_build()


func _highlight_tab() -> void:
	for i in tab_btns.size():
		(tab_btns[i] as Button).modulate = Color(1, 1, 1) if i == tab else Color(0.58, 0.63, 0.72)


## 右栏标签页内容。每次重建（行数不大，重建比增量更新简单可靠）
func _rebuild_tab() -> void:
	if tab_body == null:
		return
	for c in tab_body.get_children():
		c.queue_free()
	if tab == 0:
		_rebuild_tab_inv()
	elif tab == 1:
		_rebuild_tab_recipe()
	else:
		_rebuild_tab_device()


func _tab_row(y: float, text: String, col: Color, btn: String, cb: Callable, enabled := true, tip := "", btn2 := "", cb2 := Callable()) -> void:
	var chip := ColorRect.new()
	chip.color = col
	chip.position = Vector2(0, y + 8)
	chip.size = Vector2(10, 18)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_body.add_child(chip)
	var l := _label(tab_body, Vector2(20, y + 4), 15, UIKit.C_TEXT)
	l.text = text
	if btn2 != "":
		var b2 := UIKit.button(btn2, Vector2(58, 28), UIKit.C_GOLD, 14)
		b2.position = Vector2(456, y)
		b2.tooltip_text = "拿在手里，然后点电路板上的格子放下"
		b2.pressed.connect(cb2)
		tab_body.add_child(b2)
	if btn != "":
		var b := UIKit.button(btn, Vector2(66, 28), UIKit.C_GREEN if enabled else UIKit.C_DIM, 14)
		b.position = Vector2(524, y)
		b.disabled = not enabled
		if not enabled:
			b.modulate = Color(1, 1, 1, 0.45)  # 禁用态再压暗一档，一眼看出点不动
		if tip != "":
			b.tooltip_text = tip
		b.pressed.connect(cb)
		tab_body.add_child(b)


func _rebuild_tab_inv() -> void:
	var y := 0.0
	var any := false
	var rest := 0
	inv_rows.clear()
	for k in _ids_all():
		var mid := String(k)
		var n := _inv(mid)
		if n <= 0:
			continue
		any = true
		var d: Dictionary = MODULES[mid]
		if y >= 340.0:
			rest += 1
			continue
		_tab_row(y, "%s  ×%d      %d 阶    出力 %.1f    寿命 %d" % [
			String(d["name"]), n, int(d["tier"]), float(d["rate"]), int(d["uses"])
		], Color(d.get("color", Color(0.7, 0.75, 0.85))), "装入",
			_install_from_inv.bind(mid), true, "装到当前武器出力增益最大的那一格", "拿起", _pick_up.bind(mid))
		# 拖拽命中用：tab_body 局部坐标下的整行矩形（右侧按钮区会被 _over_inv_area 排除）
		inv_rows.append({'mid': mid, 'rect': Rect2(tab_body.position + Vector2(0, y), Vector2(360, 34))})
		y += 34.0
	if not any:
		_label(tab_body, Vector2(0, 6), 16, UIKit.C_DIM).text = "库存空：打怪掉落会先进这里"
	elif rest > 0:
		_label(tab_body, Vector2(0, y + 2), 15, UIKit.C_DIM).text = "还有 %d 种模块没显示（先合成/升级消化掉）" % rest


func _rebuild_tab_recipe() -> void:
	var y := 0.0
	var locked := 0
	for k in MOD_ORDER:
		var mid := String(k)
		var st := recipe_state(mid)
		var d: Dictionary = MODULES[mid]
		var t := int(d["tier"])
		var sec := float(CRAFT_TIME[t]) * pow(0.90, float(_bl("craft")))
		var ok := bool(st["ok"])
		if String(st["state"]).begins_with("解锁"):
			locked += 1
			continue
		_tab_row(y, "%s   %d×%d阶   %.0fs   %s" % [
			String(d["name"]), int(st["cost"]), t - 1, sec, String(st["state"])
		], Color(d.get("color", Color(0.7, 0.75, 0.85))), "合成",
			_craft_from_tab.bind(mid), ok, String(st["state"]))
		y += 34.0
		if y > 300.0:
			break
	if y == 0.0:
		_label(tab_body, Vector2(0, 6), 16, UIKit.C_DIM).text = "还没有解锁任何配方（升级会解锁）"
	if locked > 0:
		_label(tab_body, Vector2(0, y + 6), 14, UIKit.C_DIM).text = "还有 %d 个配方未解锁（等级不够 / 没有对应武器）" % locked


func _rebuild_tab_device() -> void:
	if dev_pick_for >= 0:
		_rebuild_device_pick()
		return
	var y := 0.0
	for i in devices.size():
		var dv: Dictionary = devices[i]
		var kind := String(dv["kind"])
		var busy := kind != ""
		var nm := String(MODULES[kind]["name"]) if MODULES.has(kind) else ""
		var txt := "装置 %d    空闲" % (i + 1)
		if busy:
			txt = "装置 %d    %s    %.1fs / %.1fs" % [i + 1, nm, float(dv["left"]), float(dv["total"])]
		var l := _label(tab_body, Vector2(0, y), 15, UIKit.C_GOLD if busy else UIKit.C_DIM)
		l.text = txt
		if busy:
			var bw := 330.0
			var bg := ColorRect.new()
			bg.color = Color(0.16, 0.18, 0.24)
			bg.position = Vector2(0, y + 22)
			bg.size = Vector2(bw, 6)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tab_body.add_child(bg)
			var total := maxf(float(dv["total"]), 0.01)
			var pct := clampf(1.0 - float(dv["left"]) / total, 0.0, 1.0)
			var fg := ColorRect.new()
			fg.color = UIKit.C_GOLD
			fg.position = Vector2(0, y + 22)
			fg.size = Vector2(bw * pct, 6)
			fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tab_body.add_child(fg)
		# 选配方 / 取消
		var act := UIKit.button("取消" if busy else "选配方", Vector2(78, 26),
			UIKit.C_RED if busy else UIKit.C_BLUE, 14)
		act.position = Vector2(340, y - 2)
		act.tooltip_text = "取消并全额退还材料" if busy else "给这台装置挑一个配方"
		if busy:
			act.pressed.connect(_cancel_device.bind(i))
		else:
			act.pressed.connect(_set_dev_pick.bind(i))
		tab_body.add_child(act)
		# 自动
		var au := bool(dv.get("auto", false))
		var ab := UIKit.button("自动 开" if au else "自动 关", Vector2(86, 26),
			UIKit.C_GREEN if au else UIKit.C_DIM, 14)
		ab.position = Vector2(426, y - 2)
		ab.tooltip_text = "做完自动接下一个配方（材料够的话）"
		ab.pressed.connect(_toggle_dev_auto.bind(i))
		tab_body.add_child(ab)
		y += 44.0
	var idle := devices.size() - _busy_devices()
	var auto_n := 0
	for d in devices:
		if bool(d.get("auto", false)):
			auto_n += 1
	var head := _label(tab_body, Vector2(0, y + 2), 13, UIKit.C_DIM)
	head.text = "共 %d 台 · 空闲 %d · 自动 %d" % [devices.size(), idle, auto_n]
	y += 26.0
	if devices.size() < DEVICE_MAX:
		_tab_row(y, "再造一台装置（需要 %d 个基础模块）" % device_cost(), UIKit.C_BLUE, "造",
			_buy_device_from_tab, _inv("base") >= device_cost(), "吃基础模块；装置越多并行合成越快")
	else:
		_label(tab_body, Vector2(0, y + 6), 14, UIKit.C_DIM).text = "装置已满（%d 台）" % DEVICE_MAX


## 装置页的二级列表：给某一台装置挑配方
func _rebuild_device_pick() -> void:
	var back := UIKit.back_button(tab_body, "返回装置列表", _set_dev_pick.bind(-1), Vector2(0, 0))
	back.tooltip_text = ""
	var t := _label(tab_body, Vector2(150, 6), 15, UIKit.C_GOLD)
	t.text = "装置 %d —— 选择配方" % (dev_pick_for + 1)
	var y := 44.0
	var shown := 0
	for k in MOD_ORDER:
		var mid := String(k)
		var d: Dictionary = MODULES[mid]
		if level < int(CRAFT_UNLOCK.get(mid, 99)) and not _has_weapon_bind(String(d.get("bind", ""))):
			continue
		var st := recipe_state(mid)
		var ok := bool(st["ok"])
		var cost := int(st["cost"])
		var tier := int(st["tier"])
		var secs := float(CRAFT_TIME[tier]) * pow(0.90, float(_bl("craft")))
		var txt := "%s   %d×%d 阶料 · %.0fs" % [String(d["name"]), cost, tier - 1, secs]
		if not ok:
			txt += "    " + String(st["state"])
		_tab_row(y, txt, Color(d.get("color", UIKit.C_TEXT)), "开始", _start_dev_recipe.bind(mid),
			ok, "材料不够或未解锁时不能开工")
		y += 30.0
		shown += 1
		if shown >= 11:
			break
	if shown == 0:
		_label(tab_body, Vector2(0, y), 14, UIKit.C_DIM).text = "还没有可用配方（升级解锁更多）"


func _has_weapon_bind(bind: String) -> bool:
	if bind == "":
		return true
	for w in weapons:
		if String(w["id"]) == bind:
			return true
	return false


func _set_dev_pick(i: int) -> void:
	dev_pick_for = i
	_refresh_build()


func _start_dev_recipe(mid: String) -> void:
	var idx := dev_pick_for
	dev_pick_for = -1
	if idx >= 0:
		try_craft(mid, idx)
	_refresh_build()


func _cancel_device(i: int) -> void:
	device_cancel(i)
	_refresh_build()


func _toggle_dev_auto(i: int) -> void:
	if i >= 0 and i < devices.size():
		devices[i]["auto"] = not bool(devices[i].get("auto", false))
		# 打开自动时如果它是空闲的，立刻开一单，不然玩家会以为开关没生效
		if bool(devices[i]["auto"]) and String(devices[i]["kind"]) == "":
			try_craft("", i)
	_refresh_build()


## 把某个模块拿在手里（下一步点格子放下）
func _pick_up(mid: String) -> void:
	hand_mid = mid
	_refresh_build()


func _craft_from_tab(mid: String) -> void:
	try_craft(mid)
	_refresh_build()


func _buy_device_from_tab() -> void:
	buy_device()
	_refresh_build()


## 从库存取出一个模块装进当前武器；装不下会自动退回库存（_install 的兜底）
func _install_from_inv(mid: String) -> void:
	if _inv(mid) <= 0:
		return
	_take_inv(mid, 1)
	_install(mid)
	_refresh_build()


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
	slot_rects.clear()
	slot_panels.clear()
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
		var want := String(weapon.plan[i]) if i < weapon.plan.size() else ""
		if m == null and want != "":
			# 有方案但缺料：红框，把「缺什么」写在格子上
			sb.border_color = UIKit.C_RED
			sb.bg_color = Color(0.35, 0.10, 0.12, 0.35)
		panel.add_theme_stylebox_override("panel", sb)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.tooltip_text = _slot_tip(i)
		panel.gui_input.connect(_on_slot_input.bind(i))
		board_root.add_child(panel)
		# 拖拽命中用：build_root 局部坐标下的格子矩形（board_root 是 build_root 的子节点）
		slot_rects.append(Rect2(board_root.position + panel.position, panel.size))
		slot_panels.append(panel)

		var name_l := Label.new()
		name_l.position = Vector2(0, 7)
		name_l.size = Vector2(cell, 24)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.add_theme_font_size_override("font_size", 16)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if m == null and want != "":
			name_l.text = "缺 %s" % String(MODULES[want]["name"])
			name_l.add_theme_color_override("font_color", UIKit.C_RED)
		elif m == null:
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
		out_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		use_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		use_l.text = "" if m == null else "%d/%d" % [int(m.left), int(m.max)]
		panel.add_child(use_l)


## 鼠标点格子：左键 = 放入手里的模块（或没拿东西时自动挑最优 / 按方案补料），右键 = 卸下
# --- 鼠标拖拽：按住 → 拖动 → 松开（docs/plan-v3.md §1）----------------------------
# 坐标全部用 build_root 的局部坐标（build_root.get_local_mouse_position()）：
# 之前踩过 pick_root.get_global_rect() 是 2560×1440（画布 2× 放大）的坑，用局部坐标就不需要补偿。

func _drag_input(ev: InputEvent) -> bool:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		# 必须用事件自带的坐标换算成 build_root 局部坐标：get_local_mouse_position() 读的是真实的系统光标，
		# 自检时用 push_input 塞进来的假事件不会移动光标，会导致命中判定永远落空
		var mp := build_root.get_global_transform_with_canvas().affine_inverse() * mb.position
		if mb.pressed:
			return _drag_begin(mp)
		if drag.is_empty():
			return false
		var active := bool(drag.get("active", false))
		if active:
			_drag_drop(mp)
		else:
			_drag_click_fallback()
		drag = {}
		_drag_clear()
		get_viewport().set_input_as_handled()
		return true
	if ev is InputEventMouseMotion and not drag.is_empty():
		var mm := ev as InputEventMouseMotion
		_drag_move(build_root.get_global_transform_with_canvas().affine_inverse() * mm.position)
		if bool(drag.get("active", false)):
			get_viewport().set_input_as_handled()
			return true
	return false


func _drag_begin(mp: Vector2) -> bool:
	var hit := _drag_hit(mp)
	if hit.is_empty():
		return false
	drag = {"src": hit["src"], "mid": hit["mid"], "from": int(hit["idx"]),
		"start": mp, "pos": mp, "active": false}
	return true


## 拖拽源：电路板上有模块的格子 > 库存行的文字区（避开右侧「拿起/装入」按钮）
func _drag_hit(mp: Vector2) -> Dictionary:
	var si := _slot_at(mp)
	if si >= 0:
		var m = weapon.slots[si]
		if m != null:
			return {"src": "slot", "mid": String(m["id"]), "idx": si}
		return {}
	if tab == 0:
		for r in inv_rows:
			if (r["rect"] as Rect2).has_point(mp):
				return {"src": "inv", "mid": String(r["mid"]), "idx": 0}
	return {}


func _slot_at(mp: Vector2) -> int:
	for i in slot_rects.size():
		if (slot_rects[i] as Rect2).has_point(mp):
			return i
	return -1


func _drag_move(mp: Vector2) -> void:
	drag["pos"] = mp
	if not bool(drag["active"]) and mp.distance_to(drag["start"] as Vector2) > 6.0:
		drag["active"] = true
		drag_layer.visible = true
		var mid := String(drag["mid"])
		var col: Color = MODULES[mid]["color"]
		drag_label.text = "▣ %s   ×%d" % [String(MODULES[mid]["name"]), _inv(mid)]
		drag_label.add_theme_color_override("font_color", col)
	if not bool(drag["active"]):
		return
	drag_ghost.position = mp + Vector2(14, 10)
	_drag_highlight(mp)


func _drag_highlight(mp: Vector2) -> void:
	var t := _slot_at(mp)
	var over_recycle := recycle_btn != null and recycle_btn.get_global_rect().has_point(get_global_mouse_position())
	drag_hint.position = Vector2(100, 150)
	if t >= 0:
		drag_hl.visible = true
		var r: Rect2 = slot_rects[t]
		drag_hl.position = r.position
		drag_hl.size = r.size
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(3)
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = UIKit.C_GOLD
		drag_hl.add_theme_stylebox_override("panel", sb)
		var ok := true
		if String(drag["src"]) == "inv" and _inv(String(drag["mid"])) <= 0:
			ok = false
		drag_hint.text = _drag_preview(t) if ok else "库存里已经没有这个模块了"
		drag_hint.add_theme_color_override("font_color", UIKit.C_GREEN if ok else UIKit.C_RED)
	elif over_recycle and String(drag["src"]) == "slot":
		drag_hl.visible = false
		drag_hint.text = "松手卸下：模块退回库存，这一格的方案也会清空"
		drag_hint.add_theme_color_override("font_color", UIKit.C_RED)
	else:
		drag_hl.visible = false
		drag_hint.text = "拖到电路板格子上放下（右键卸下，ESC 取消）"
		drag_hint.add_theme_color_override("font_color", UIKit.C_DIM)


## 落点预览：换完之后整板出力会变成多少（和 _board_total 同一套计算，所见即所得）
func _drag_preview(t: int) -> String:
	var now := _board_total(weapon)
	var sl: Array = weapon.slots.duplicate()
	if String(drag["src"]) == "slot":
		var from := int(drag["from"])
		var tmp = sl[from]
		sl[from] = sl[t]
		sl[t] = tmp
	else:
		sl[t] = _new_module(String(drag["mid"]))
	var after := _board_total_slots(sl, weapon)
	var d := after - now
	var pct := 0.0 if now <= 0.0 else d / now * 100.0
	return "整板出力 %.1f → %.1f   (%s%.0f%%)" % [now, after, "+" if d >= 0.0 else "", pct]


func _board_total_slots(sl: Array, w = null) -> float:
	var ww: Dictionary = weapon if w == null else w
	var total := 0.0
	for v in _slot_out(sl, ww):
		total += float(v)
	return total


func _drag_drop(mp: Vector2) -> void:
	var t := _slot_at(mp)
	var src := String(drag["src"])
	var from := int(drag["from"])
	var mid := String(drag["mid"])
	var over_recycle := recycle_btn != null and recycle_btn.get_global_rect().has_point(get_global_mouse_position())
	if t >= 0:
		if src == "inv":
			_place_at(t, mid)
		else:
			_swap_slots(from, t)
	elif src == "slot" and (over_recycle or _over_inv_area(mp)):
		_uninstall(from)
	_refresh_build()


func _over_inv_area(mp: Vector2) -> bool:
	if tab != 0 or tab_body == null:
		return false
	return Rect2(tab_body.position, Vector2(430, 340)).has_point(mp)


func _swap_slots(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0:
		return
	var sl: Array = weapon["slots"]
	var pl: Array = weapon["plan"]
	if a >= sl.size() or b >= sl.size():
		return
	var m = sl[a]
	var p = pl[a]
	sl[a] = sl[b]
	pl[a] = pl[b]
	sl[b] = m
	pl[b] = p


## 没拖动就松手 = 普通点击：交给原有的格子点击逻辑（空格子补料等）
func _drag_click_fallback() -> void:
	if String(drag["src"]) == "slot":
		var i := int(drag["from"])
		if String(weapon.plan[i]) != "" and weapon.slots[i] == null:
			_refill(i)
			_refresh_build()


func _drag_clear() -> void:
	if drag_layer != null:
		drag_layer.visible = false
	if drag_hl != null:
		drag_hl.visible = false
	if drag_hint != null:
		drag_hint.text = ""


func _on_slot_input(event: InputEvent, i: int) -> void:
	if not (event as InputEventMouseButton).pressed:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		_uninstall(i)
		_refresh_build()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if hand_mid != "":
		_place_at(i, hand_mid)
	elif String(weapon.plan[i]) != "" and weapon.slots[i] == null:
		_refill(i)  # 有方案但缺料：手动点一下等于「再试一次补料」
	else:
		_auto_place_best(i)
	_refresh_build()


## 把库存里的 mid 放进第 i 格，并登记成这一格的方案（方案 = 以后自动补料的目标）
func _place_at(i: int, mid: String) -> bool:
	var sl: Array = weapon["slots"]
	var plan: Array = weapon["plan"]
	if i < 0 or i >= sl.size() or not MODULES.has(mid) or _inv(mid) <= 0:
		hand_mid = ""
		return false
	_add_inv(mid, -1)
	if sl[i] != null:
		_add_inv(String(sl[i]["id"]), 1)  # 原有的退回库存，等于覆盖
	sl[i] = _new_module(mid)
	plan[i] = mid
	hand_mid = ""
	return true


## 卸下第 i 格：模块退回库存，方案清空
func _uninstall(i: int) -> void:
	var sl: Array = weapon["slots"]
	var plan: Array = weapon["plan"]
	if i < 0 or i >= sl.size():
		return
	if sl[i] != null:
		_add_inv(String(sl[i]["id"]), 1)
	sl[i] = null
	plan[i] = ""


## 空槽自动放一个「让整板出力涨最多」的模块，并把它的 id 记成方案
func _auto_place_best(i: int) -> bool:
	var sl: Array = weapon["slots"]
	var plan: Array = weapon["plan"]
	if i < 0 or i >= sl.size() or sl[i] != null:
		return false
	var best_id := ""
	var best_v := _board_total(weapon)
	for k in _stocked_ids():
		sl[i] = _new_module(k)
		var v := _board_total(weapon)
		sl[i] = null
		if v > best_v + 0.0001:
			best_v = v
			best_id = k
	if best_id == "":
		return false
	plan[i] = best_id
	_add_inv(best_id, -1)
	sl[i] = _new_module(best_id)
	return true


## 自动配置方案（bot 与懒人用）：所有「空格子 + 没方案」都按最优填一次，填完固化成方案
func _auto_plan_fill() -> void:
	var sl: Array = weapon["slots"]
	var plan: Array = weapon["plan"]
	for i in sl.size():
		if sl[i] == null and String(plan[i]) == "":
			_auto_place_best(i)


func _missing_cells(w = null) -> Array:
	var ww: Dictionary = weapon if w == null else w
	var out: Array = []
	var sl: Array = ww["slots"]
	var plan: Array = ww["plan"]
	for i in sl.size():
		if sl[i] == null and i < plan.size() and String(plan[i]) != "":
			out.append(i)
	return out


func _slot_tip(i: int) -> String:
	var parts: Array = ["槽 %d" % (i + 1)]
	var m = weapon.slots[i]
	if m != null:
		var d: Dictionary = MODULES[String(m["id"])]
		parts.append("%s · %d 阶 · 出力 %.1f · 剩余 %d/%d" % [
			String(d["name"]), int(d["tier"]), float(d["rate"]), int(m["left"]), int(m["max"])])
	else:
		parts.append("空")
	var want := String(weapon.plan[i]) if i < weapon.plan.size() else ""
	if want != "":
		parts.append("方案：%s%s" % [String(MODULES[want]["name"]),
			"" if _inv(want) > 0 else "（库存缺料，攒够自动补）"])
	parts.append("左键：装入手里的模块 / 自动补料　　右键：卸下")
	return "\n".join(parts)


## 随机掷数自检：每种武器 × 每个品级各掷 N 次，检查同类型内「低品级不会超过高品级」。
## 打印每档的分数区间与 mul 区间，便于判断归一化是否把倍率推到不合理的位置。
func _run_rolltest(n: int = 300) -> void:
	print("== 武器随机掷数自检（每种每档 %d 次） ==" % n)
	print("%-8s %-3s %8s %8s %8s %9s %9s" % ["类型", "档", "P0档分", "min", "max", "mul均", "倒挂"])
	var total_bad := 0
	var order := ["pistol", "smg", "shotgun", "sniper", "beam", "grenade", "blade", "laser"]
	for id in order:
		var p0 := p0_of(String(id))
		var prev_max := -1.0
		for q in range(1, 6):
			var lo := 1e9
			var hi := -1e9
			var mul_sum := 0.0
			for i in n:
				var w := _make_weapon(String(id), q)
				var sc := weapon_score(w)
				lo = minf(lo, sc)
				hi = maxf(hi, sc)
				mul_sum += float(w["mul"])
			var bad := 0
			if prev_max >= 0.0 and lo <= prev_max:
				bad = 1
				total_bad += 1
			prev_max = hi
			print("%-8s %-3d %8.2f %8.2f %8.2f %9.2f %9s" % [
				String(WEAPONS[id]["name"]) if q == 1 else "",
				q, p0 * float(QM[q]), lo, hi, mul_sum / float(n),
				"倒挂" if bad == 1 else "-"])
		print("")
	print("总倒挂次数 %d（必须为 0）" % total_bad)

## 品质色（宝箱卡与迷你电路板用）
func _qcol(q: int) -> Color:
	match q:
		1: return Color(0.85, 0.87, 0.92)
		2: return Color(0.55, 0.90, 0.60)
		3: return Color(0.45, 0.75, 1.00)
		4: return Color(0.76, 0.55, 1.00)
		_: return Color(1.00, 0.82, 0.35)


## 迷你电路板：和战斗里用同一个 layout，只是格子小
func _mini_board(layout: Array, col: Color, cell: float, gap: float) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var minx := 0
	var miny := 0
	var maxx := 0
	var maxy := 0
	for p in layout:
		minx = mini(minx, int(p.x))
		miny = mini(miny, int(p.y))
		maxx = maxi(maxx, int(p.x))
		maxy = maxi(maxy, int(p.y))
	var step := cell + gap
	root.size = Vector2((maxx - minx + 1) * step, (maxy - miny + 1) * step)
	for i in layout.size():
		for j in range(i + 1, layout.size()):
			var a: Vector2i = layout[i]
			var b: Vector2i = layout[j]
			if absi(a.x - b.x) + absi(a.y - b.y) != 1:
				continue
			var pa := Vector2((a.x - minx) * step + cell * 0.5, (a.y - miny) * step + cell * 0.5)
			var pb := Vector2((b.x - minx) * step + cell * 0.5, (b.y - miny) * step + cell * 0.5)
			var lk := ColorRect.new()
			lk.color = Color(col.r, col.g, col.b, 0.55)
			lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if absf(pa.x - pb.x) > 0.1:
				lk.size = Vector2(gap + 2.0, 3.0)
			else:
				lk.size = Vector2(3.0, gap + 2.0)
			lk.position = (pa + pb) * 0.5 - lk.size * 0.5
			root.add_child(lk)
	for p in layout:
		var panel := Panel.new()
		panel.position = Vector2((p.x - minx) * step, (p.y - miny) * step)
		panel.size = Vector2(cell, cell)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		sb.set_border_width_all(2)
		sb.bg_color = Color(col.r, col.g, col.b, 0.12)
		sb.border_color = col
		panel.add_theme_stylebox_override("panel", sb)
		root.add_child(panel)
	return root


func _paint_chest() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.07, 0.90)
	bg.size = Vector2(1280, 720)
	pick_root.add_child(bg)
	var w_card := 290.0
	var gap := 16.0
	var total := 4.0 * w_card + 3.0 * gap
	var x0 := (1280.0 - total) * 0.5
	var title := _label(pick_root, Vector2(x0, 86), 28, Color(0.98, 0.88, 0.55))
	title.text = "开箱！点卡片 或 按 1–4 选择武器"
	var sub := _label(pick_root, Vector2(x0, 126), 16, Color(0.72, 0.78, 0.88))
	sub.text = "每把的形状（射程/间隔/目标/网络）都不一样；分数只在同类型内比较"
	for i in chest_offer.size():
		var w: Dictionary = chest_offer[i]
		var q := int(w["quality"])
		var qc := _qcol(q)
		var btn := Button.new()
		btn.position = Vector2(x0 + float(i) * (w_card + gap), 152)
		btn.size = Vector2(w_card, 430)
		btn.text = ""
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.11, 0.15, 0.98)
		sb.border_color = qc
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		btn.add_theme_stylebox_override("normal", sb)
		var sh := sb.duplicate() as StyleBoxFlat
		sh.bg_color = Color(0.17, 0.19, 0.25, 0.99)
		sh.border_color = Color(1, 1, 1)
		btn.add_theme_stylebox_override("hover", sh)
		btn.add_theme_stylebox_override("pressed", sh)
		btn.add_theme_stylebox_override("focus", sh)
		btn.pressed.connect(_take_card.bind(i))
		pick_root.add_child(btn)

		var head := _label(btn, Vector2(14, 10), 19, qc)
		head.text = "%d   %s   %s" % [i + 1, QUALITY_NAME[q], String(WEAPONS[w["id"]]["name"])]
		var sl := _label(btn, Vector2(14, 40), 15, Color(0.75, 0.80, 0.88))
		sl.text = "%d 槽   %.2f / %.2f  (蓝档基准)" % [
			(w["slots"] as Array).size(), float(w["score"]), float(w["p0"]) * float(QM[3])]

		var mini := _mini_board(w["layout"], qc, 20.0, 8.0)
		mini.position = Vector2(14, 70)
		btn.add_child(mini)

		var dr: Dictionary = w["dr"]
		var lines: Array = []
		lines.append("射程   %d  (%+.0f%%)" % [int(w["range"]), 100.0 * float(dr.get("range", 0.0))])
		lines.append("间隔   %.2fs  (%+.0f%%)" % [float(w["interval"]), 100.0 * float(dr.get("interval", 0.0))])
		var tg := int(w["targets"])
		if dr.has("targets"):
			lines.append("目标   %s  (+1)" % ("全部" if tg < 0 else str(tg)))
		else:
			lines.append("目标   %s" % ("全部" if tg < 0 else str(tg)))
		lines.append("基础   %.2f  (%+.0f%%)" % [float(w["base"]), 100.0 * float(dr.get("base", 0.0))])
		lines.append("倍率   %.2f" % float(w["mul"]))
		if dr.has("blast"):
			lines.append("爆炸   %d  (%+.0f%%)" % [int(w["blast"]), 100.0 * float(dr["blast"])])
		if dr.has("ramp_max"):
			lines.append("连击上限  %.0f%%  (%+.0f%%)" % [
				100.0 * float(w["ramp_max"]), 100.0 * float(dr["ramp_max"])])
		var nl := _label(btn, Vector2(14, 210), 15, Color(0.86, 0.90, 0.96))
		nl.text = "\n".join(lines)
		var fl := _label(btn, Vector2(14, 388), 14, Color(0.62, 0.68, 0.78))
		fl.text = "背包 %d/%d" % [_backpack_used(), backpack_cap]


func _paint_replace() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.07, 0.92)
	bg.size = Vector2(1280, 720)
	pick_root.add_child(bg)
	var w := pending_weapon
	var qc := _qcol(int(w.get("quality", 3)))
	var title := _label(pick_root, Vector2(90, 60), 26, Color(0.98, 0.88, 0.55))
	title.text = "背包已满，选择要替换的武器"
	var sub := _label(pick_root, Vector2(90, 100), 16, Color(0.72, 0.78, 0.88))
	sub.text = "新武器：%s %s  %.2f / %.2f" % [
		QUALITY_NAME[int(w.get("quality", 3))], String(WEAPONS[w["id"]]["name"]),
		float(w.get("score", 0.0)), float(w.get("p0", 0.0)) * float(QM[3])]
	for i in weapons.size():
		var ow: Dictionary = weapons[i]
		var oq := int(ow["quality"])
		var col := _qcol(oq)
		var btn := Button.new()
		btn.position = Vector2(90, 150 + float(i) * 78)
		btn.size = Vector2(560, 64)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = "  %d   %s %s   %d 槽   实测 %.1f / 理论 %.1f   %.2f/%.2f" % [
			i + 1, QUALITY_NAME[oq], String(WEAPONS[ow["id"]]["name"]),
			(ow["slots"] as Array).size(), _actual_dps(ow), _theory_dps(ow),
			float(ow["score"]), float(ow["p0"]) * float(QM[3])]
		btn.add_theme_font_size_override("font_size", 17)
		btn.add_theme_color_override("font_color", col)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.11, 0.15, 0.98)
		sb.border_color = col
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 12
		btn.add_theme_stylebox_override("normal", sb)
		var sh := sb.duplicate() as StyleBoxFlat
		sh.bg_color = Color(0.18, 0.20, 0.26, 0.99)
		sh.border_color = Color(1, 1, 1)
		btn.add_theme_stylebox_override("hover", sh)
		btn.add_theme_stylebox_override("pressed", sh)
		btn.add_theme_stylebox_override("focus", sh)
		btn.pressed.connect(_replace_weapon.bind(i))
		pick_root.add_child(btn)
	var mini := _mini_board(w["layout"], qc, 22.0, 9.0)
	mini.position = Vector2(760, 160)
	pick_root.add_child(mini)