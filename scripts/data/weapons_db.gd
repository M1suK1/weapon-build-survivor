extends RefCounted
## 武器数据表（纯数据，零逻辑）。
##
## 谁在用：`scripts/game.gd` 的 `_make_weapon` / `_roll_weapon` / `_set_quality_of` / HUD 左栏。
## 相关规则文档：`docs/reference.md` §1（武器）与 §7（随机数值）。
##
## 一张武器表的三个「资源轴」：射程 / 开火间隔 / 目标数。模块输出最终都要过这三个轴，
## 所以改任何一个都会连带改变弹药效率（burn = 每发扣 1 次使用次数）。

## 武器品质 = 电路板布局模板（槽位数量 + 基础连接方式）。
## 注意：实际布局是 `_gen_layout()` 用基础网络积木随机拼出来的，这里只是「几格」的基准形状。
## 相邻 = 网格曼哈顿距离 1，所以直线是链、T/十字/双排会在中间形成枢纽（枢纽吃到的邻居更多）。
const LAYOUTS := {
	1: [Vector2i(0, 0), Vector2i(1, 0)],
	2: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	3: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
	4: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, -1), Vector2i(1, 1)],
	5: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
}

const QUALITY_NAME := {1: "白", 2: "绿", 3: "蓝", 4: "紫", 5: "金"}

## 波次 → 品质：开局蓝（4 槽），12 波紫（5 槽），20 波金（6 槽）
const QUALITY_SCHEDULE := {12: 4, 20: 5}

## 武器自带基础伤害：不吃模块次数，模块烧光时留一条底（否则 DPS 直接归零 = 必死）
const QUALITY_BASE := {1: 0.5, 2: 0.8, 3: 1.0, 4: 1.5, 5: 2.0}

## 武器种类：射程 / 间隔 / 目标数 是三种不同的资源。
## 冲锋枪：高射速换弹药消耗；霰弹枪：多目标换单体伤害；狙击枪：长射程低消耗换出手频率。
## targets = -1 表示「范围内全部敌人」（激光环的清场定位）；prefer 见 `_targets_for()`：
##   "highest_hp"  只锁范围内血量最高的那个（镭射靠持续打同一个目标叠倍率）
##   "shooter,charger" 优先打这些种类（狙击枪点名后排与精英）
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

# --- 随机数值（方案 v2.8 §17）--------------------------------------------------
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
