extends RefCounted
## 模块与合成数据表（纯数据，零逻辑）。
##
## 谁在用：`scripts/game.gd`（网络结算、构筑屏、装置、配方列表）。
## 改这里之前先看 `docs/reference.md` §3：模块的 rate/uses 是「弹药经济」的核心，
## 数值一动，`boardtest` 的期望输出（power=100.0）和 `playtest bot pt=300` 的曲线都会变。
##
## 字段说明：
##   tier  1–4 阶，决定配方成本（T2 吃 3 个基础，T3/T4 吃 2 个低一阶）与解锁等级。
##   rate  每发提供的输出值（0 = 不给输出，只做增益）。
##   uses  一个模块能撑多少次开火；寿命 = uses × 武器间隔。
##   cls   网络结算类型，见下。
##   bind  非空 = 武器专属模块，只在该武器板上生效，否则只剩 rate。
##
## cls 决定它在 `_slot_out()` 里怎么参与结算：
##   flat   老实给 rate（默认）
##   mirror 加法：把相邻「比自己低阶」的模块读数再镜像一份
##   boost  增幅：自身 0 出力，把 boost 加到相邻非 boost 模块的最终输出上
##   reson  共振：相邻同 cls 的模块基础值 +50%
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
## UI / 自动合成都按这个顺序遍历（不含 base：基础模块是原料，不是产物）
const MOD_ORDER := ["add", "amp", "reson", "edge", "temper", "light", "extend", "calib", "pierce",
	"breaker", "coolant", "recycle", "overload", "tempo", "multi", "belt", "spread", "focus", "charge", "blade"]
const CORE_ORDER := ["base", "add", "amp", "reson"]

## 合成装置：每台 = 1 个并行合成位。可反复制造，材料堆积就多做几台（变相缩短合成时间）。
## 开局免费 1 台，第 n 台的价钱 = 12 × 1.7^(n-2) 个基础模块，上限 8 台。
const DEVICE_COST_BASE := 12
const DEVICE_COST_GROWTH := 1.7
const DEVICE_MAX := 8
