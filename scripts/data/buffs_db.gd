extends RefCounted
## buff 表（docs/plan-v5.md §9）：24 个族 × 4 个品质 = 96 条独立变体，每条各自 1→10 级。
##
## 为什么按族拆：旧表一条 buff 只有一个「层数」，抽到三次就满了，后 20 级全是垃圾卡。
## 现在同族的白/蓝/紫/金是四条互不干扰的线：各自升级、各自封顶 MAX_LEVEL，
## 抽卡时同一次三张卡是同一个品质（§9.4 权重表），品质越高每级量越大。
##
## 字段：
##   name    族名（卡面显示「族名·品质」）
##   cat     atk / eco / sur
##   kind    mul（乘法倍率，cap 是最大幅度）| add（加法累计）| int（到阈值 +1 次）
##   per     {品质: 每级效果量}；mul 族是每级比例，add 族是绝对值
##   cap     连续量幅度上限（mul 族夹 |1-m|，add 族夹总量）
##   thr     int 族的解锁阈值（品质: 到第几级 +1）
##   tpl     文案模板（带 % 的按「每级量 × scale」填，不带 % 的直接追加阈值说明）
##   scale   文案放大倍数（默认 100，即按百分比写）
##   per_desc {品质: 额外说明}（可选，给 int 族的附带连续量用）
##
## 结算入口在 scripts/game.gd：_buff_mul / _buff_sum / _buff_int（读点末尾统一夹取）。

const TIERS := ["white", "blue", "violet", "gold"]
const TIER_NAME := {"white": "白", "blue": "蓝", "violet": "紫", "gold": "金"}
const TIER_RAR := {"white": "white", "blue": "blue", "violet": "violet", "gold": "gold"}
const CAT_NAME := {"atk": "攻击", "eco": "经济", "sur": "生存"}
const MAX_LEVEL := 10

const FAMILIES := {
	# ---- 攻击 ----
	"rate": {
		"name": "攻速", "cat": "atk", "kind": "mul",
		"per": {"white": -0.006, "blue": -0.008, "violet": -0.010, "gold": -0.013},
		"cap": 0.45, "tpl": "开火间隔 -%.1f%%",
	},
	"power": {
		"name": "威力", "cat": "atk", "kind": "mul",
		"per": {"white": 0.008, "blue": 0.010, "violet": 0.012, "gold": 0.016},
		"cap": 0.80, "tpl": "伤害 +%.1f%%",
	},
	"range": {
		"name": "射程", "cat": "atk", "kind": "add",
		"per": {"white": 4.0, "blue": 5.0, "violet": 6.0, "gold": 8.0},
		"cap": 200.0, "scale": 1.0, "tpl": "射程 +%.0f",
	},
	"target": {
		"name": "目标", "cat": "atk", "kind": "int",
		"thr": {"white": 10, "blue": 8, "violet": 6, "gold": 4},
		"per": {"white": 0.005, "blue": 0.005, "violet": 0.005, "gold": 0.005},
		"per_desc": {
			"white": "伤害 +0.5%/级", "blue": "伤害 +0.5%/级",
			"violet": "伤害 +0.5%/级", "gold": "伤害 +0.5%/级",
		},
		"tpl": "多打 1 个目标",
	},
	"pierce": {
		"name": "穿透", "cat": "atk", "kind": "int",
		"thr": {"white": 10, "blue": 8, "violet": 6, "gold": 4},
		"tpl": "穿透 +1",
	},
	"elite": {
		"name": "破甲", "cat": "atk", "kind": "add",
		"per": {"white": 0.02, "blue": 0.025, "violet": 0.03, "gold": 0.04},
		"cap": 2.0, "tpl": "精英伤害 +%.1f%%",
	},
	"petal": {
		"name": "扇叶", "cat": "atk", "kind": "int",
		"thr": {"white": 10, "blue": 8, "violet": 6, "gold": 4},
		"per": {"white": 0.0, "blue": 0.0, "violet": 0.0, "gold": 0.02},
		"per_desc": {"gold": "扇宽 +0.02"},
		"tpl": "环绕刃 +1 片扇叶",
	},
	"ricochet": {
		"name": "弹射", "cat": "atk", "kind": "int",
		"thr": {"white": 10, "blue": 8, "violet": 6, "gold": 4},
		"tpl": "弹射 +1 跳",
	},
	"blast": {
		"name": "爆破", "cat": "atk", "kind": "add",
		"per": {"white": 0.010, "blue": 0.0125, "violet": 0.015, "gold": 0.020},
		"cap": 0.80, "tpl": "爆炸半径 +%.1f%%",
	},
	"combo": {
		"name": "连击", "cat": "atk", "kind": "add",
		"per": {"white": 0.006, "blue": 0.008, "violet": 0.010, "gold": 0.013},
		"cap": 0.60, "tpl": "连击每层 +%.1f%%",
	},

	# ---- 经济 ----
	"drop": {
		"name": "掉落", "cat": "eco", "kind": "add",
		"per": {"white": 0.020, "blue": 0.025, "violet": 0.030, "gold": 0.040},
		"cap": 1.0, "tpl": "击杀掉落率 +%.1f%%",
	},
	"uses": {
		"name": "耐久", "cat": "eco", "kind": "add",
		"per": {"white": 0.020, "blue": 0.025, "violet": 0.030, "gold": 0.040},
		"cap": 1.0, "tpl": "模块寿命 +%.1f%%",
	},
	"craft": {
		"name": "工艺", "cat": "eco", "kind": "mul",
		"per": {"white": -0.015, "blue": -0.020, "violet": -0.025, "gold": -0.030},
		"cap": 0.50, "tpl": "合成时间 -%.1f%%",
	},
	"device": {
		"name": "装置", "cat": "eco", "kind": "mul",
		"per": {"white": -0.015, "blue": -0.020, "violet": -0.025, "gold": -0.030},
		"cap": 0.50, "tpl": "装置成本 -%.1f%%",
	},
	"salvage": {
		"name": "回收", "cat": "eco", "kind": "add",
		"per": {"white": 0.020, "blue": 0.030, "violet": 0.040, "gold": 0.050},
		"cap": 0.60, "tpl": "拆卸返还基础料 +%.1f%%",
	},
	"refine": {
		"name": "精炼", "cat": "eco", "kind": "add",
		"per": {"white": 0.015, "blue": 0.020, "violet": 0.025, "gold": 0.030},
		"cap": 0.60, "tpl": "合成多出 1 个的概率 +%.1f%%",
	},

	# ---- 生存 ----
	"hp": {
		"name": "体魄", "cat": "sur", "kind": "add",
		"per": {"white": 0.030, "blue": 0.040, "violet": 0.050, "gold": 0.060},
		"cap": 0.60, "tpl": "最大生命 +%.1f%%",
	},
	"armor": {
		"name": "护甲", "cat": "sur", "kind": "add",
		"per": {"white": 0.010, "blue": 0.0125, "violet": 0.015, "gold": 0.020},
		"cap": 0.60, "tpl": "受到伤害 -%.1f%%",
	},
	"regen": {
		"name": "回复", "cat": "sur", "kind": "add",
		"per": {"white": 0.10, "blue": 0.15, "violet": 0.20, "gold": 0.30},
		"cap": 8.0, "scale": 1.0, "tpl": "脱战回血 +%.2f/s",
	},
	"dodge": {
		"name": "闪避", "cat": "sur", "kind": "add",
		"per": {"white": 0.010, "blue": 0.0125, "violet": 0.015, "gold": 0.020},
		"cap": 0.50, "tpl": "闪避率 +%.1f%%",
	},
	"move": {
		"name": "疾行", "cat": "sur", "kind": "mul",
		"per": {"white": 0.015, "blue": 0.020, "violet": 0.025, "gold": 0.030},
		"cap": 0.60, "tpl": "移速 +%.1f%%",
	},
	"pickup": {
		"name": "磁场", "cat": "sur", "kind": "add",
		"per": {"white": 5.0, "blue": 6.0, "violet": 8.0, "gold": 10.0},
		"cap": 400.0, "scale": 1.0, "tpl": "拾取半径 +%.0f",
	},
	"shield": {
		"name": "护盾", "cat": "sur", "kind": "int",
		"thr": {"white": 10, "blue": 8, "violet": 6, "gold": 4},
		"per": {"white": 0.40, "blue": 0.50, "violet": 0.60, "gold": 0.80},
		"per_desc": {
			"white": "冷却 -0.4s/级", "blue": "冷却 -0.5s/级",
			"violet": "冷却 -0.6s/级", "gold": "冷却 -0.8s/级",
		},
		"tpl": "挡下 1 次伤害",
	},
	"revive": {
		"name": "复生", "cat": "sur", "kind": "int",
		"thr": {"white": 10, "blue": 8, "violet": 6, "gold": 4},
		"tpl": "阵亡后原地复活 1 次",
	},
}


## 变体 id：族名 + 双下划线 + 品质（"rate__gold"）
static func vid(fam: String, q: String) -> String:
	return fam + "__" + q


## 展开成扁平表：96 条变体，id → 卡面/说明/数值。game.gd 的 BUFFS 就是这份。
static func expand() -> Dictionary:
	var out := {}
	for fam in FAMILIES:
		var f: Dictionary = FAMILIES[fam]
		for q in TIERS:
			var d := {
				"id": vid(fam, q),
				"fam": fam,
				"fam_name": String(f["name"]),
				"q": q,
				"tier": TIERS.find(q),
				"cat": String(f["cat"]),
				"cat_name": String(CAT_NAME.get(String(f["cat"]), String(f["cat"]))),
				"name": "%s·%s" % [String(f["name"]), String(TIER_NAME[q])],
				"rar": String(TIER_RAR[q]),
				"color": _tier_color(q),
				"max": MAX_LEVEL,
				"kind": String(f["kind"]),
				"per": float(f["per"].get(q, 0.0)),
				"cap": float(f.get("cap", 0.0)),
				"thr": int(f["thr"].get(q, 99)) if f.has("thr") else 0,
				"desc": _desc(f, q),
			}
			out[d["id"]] = d
	return out


static func _desc(f: Dictionary, q: String) -> String:
	var kind := String(f["kind"])
	var per := float(f["per"].get(q, 0.0))
	var pd := String(f.get("per_desc", {}).get(q, ""))
	if kind == "int":
		var s := String(f["tpl"])
		var thr := int(f["thr"].get(q, 99))
		s += "（Lv%d 解锁）" % thr
		if pd != "":
			s += " · " + pd
		return s
	var sc := float(f.get("scale", 100.0))
	return String(f["tpl"]) % (absf(per) * sc)


static func _tier_color(q: String) -> Color:
	match q:
		"blue": return Color(0.62, 0.86, 1.0)
		"violet": return Color(0.78, 0.68, 1.0)
		"gold": return Color(1.0, 0.84, 0.35)
		_: return Color(0.82, 0.84, 0.90)
