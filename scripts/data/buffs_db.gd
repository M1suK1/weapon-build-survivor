extends RefCounted
## buff 表（docs/plan-v7.md §4）：25 个族 × 4 个品质 = 100 条独立变体，每条各自 1→10 级。
##
## v7 关键变化：**品质不再只是同一个效果的 4 档数字，而是结构不同的一组效果（fx）**。
##   白 = 1 条效果，量小
##   蓝 = 1 条效果，量中
##   紫 = 主效果 + 1 条邻族副效果（开始改变构筑方向）
##   金 = 主效果最大 + 1 条邻族副效果
## 所以「攻速·紫」除了减间隔还会加射程，「爆破·金」除了半径还会加连击。
##
## 字段：
##   name    族名（卡面显示「族名·品质」）
##   cat     atk / eco / sur
##   kind    mul（乘法倍率）| add（加法累计）| int（到阈值 +1 次）
##   grades  {品质: {fx: [{k: 效果键, v: 每级量}], thr?: int 族到第几级 +1}}
##   cap     连续量幅度上限（只对 mul 族用）
##
## 结算入口在 scripts/game.gd：_buff_mul / _buff_sum / _buff_int（读点末尾统一夹取）。
## 效果键就是族名；副效果写的是**邻族的键**，因此同一个键会累加多个变体的贡献。

const TIERS := ["white", "blue", "violet", "gold"]
const TIER_NAME := {"white": "白", "blue": "蓝", "violet": "紫", "gold": "金"}
const TIER_RAR := {"white": "white", "blue": "blue", "violet": "violet", "gold": "gold"}
const CAT_NAME := {"atk": "攻击", "eco": "经济", "sur": "生存"}
const MAX_LEVEL := 10

## 乘法族（_buff_mul）的幅度上限：读点据此夹取，防止无限叠
const CAPS := {
	"rate": 0.45, "power": 0.80, "craft": 0.50, "device": 0.50, "move": 0.60,
}

## 整数族（到阈值才 +1）的效果键：这类条目只由 _buff_int 读，连续量汇总必须跳过；
## 但同一变体上挂的**副效果**（连续量，比如「目标·紫」的伤害）要照常算进去。
const INT_KEYS := ["target", "pierce", "petal", "ricochet", "shield", "revive"]

const FAMILIES := {
	# ---------------- 攻击 ----------------
	"rate": {
		"name": "攻速", "cat": "atk", "kind": "mul", "cap": 0.45,
		"grades": {
			"white": {"fx": [{"k": "rate", "v": -0.040}]},
			"blue": {"fx": [{"k": "rate", "v": -0.060}]},
			"violet": {"fx": [{"k": "rate", "v": -0.080}, {"k": "range", "v": 2.0}]},
			"gold": {"fx": [{"k": "rate", "v": -0.110}, {"k": "combo", "v": 0.010}]},
		},
	},
	"power": {
		"name": "威力", "cat": "atk", "kind": "mul", "cap": 0.80,
		"grades": {
			"white": {"fx": [{"k": "power", "v": 0.050}]},
			"blue": {"fx": [{"k": "power", "v": 0.070}]},
			"violet": {"fx": [{"k": "power", "v": 0.090}, {"k": "elite", "v": 0.020}]},
			"gold": {"fx": [{"k": "power", "v": 0.120}]},
		},
	},
	"range": {
		"name": "射程", "cat": "atk", "kind": "add",
		"grades": {
			"white": {"fx": [{"k": "range", "v": 12.0}]},
			"blue": {"fx": [{"k": "range", "v": 18.0}]},
			"violet": {"fx": [{"k": "range", "v": 24.0}, {"k": "power", "v": 0.040}]},
			"gold": {"fx": [{"k": "range", "v": 32.0}]},
		},
	},
	"target": {
		"name": "目标", "cat": "atk", "kind": "int",
		"grades": {
			"white": {"thr": 5, "fx": [{"k": "target", "v": 1}]},
			"blue": {"thr": 4, "fx": [{"k": "target", "v": 1}]},
			"violet": {"thr": 5, "fx": [{"k": "target", "v": 1}, {"k": "power", "v": 0.040}]},
			"gold": {"thr": 3, "fx": [{"k": "target", "v": 1}, {"k": "range", "v": 4.0}]},
		},
	},
	"pierce": {
		"name": "穿透", "cat": "atk", "kind": "int",
		"grades": {
			"white": {"thr": 5, "fx": [{"k": "pierce", "v": 1}]},
			"blue": {"thr": 4, "fx": [{"k": "pierce", "v": 1}]},
			"violet": {"thr": 5, "fx": [{"k": "pierce", "v": 1}, {"k": "power", "v": 0.020}]},
			"gold": {"thr": 3, "fx": [{"k": "pierce", "v": 1}]},
		},
	},
	"elite": {
		"name": "破甲", "cat": "atk", "kind": "add",
		"grades": {
			"white": {"fx": [{"k": "elite", "v": 0.040}]},
			"blue": {"fx": [{"k": "elite", "v": 0.060}]},
			"violet": {"fx": [{"k": "elite", "v": 0.080}, {"k": "power", "v": 0.020}]},
			"gold": {"fx": [{"k": "elite", "v": 0.110}]},
		},
	},
	"petal": {
		"name": "扇叶", "cat": "atk", "kind": "int",
		"grades": {
			"white": {"thr": 5, "fx": [{"k": "petal", "v": 1}]},
			"blue": {"thr": 4, "fx": [{"k": "petal", "v": 1}]},
			"violet": {"thr": 5, "fx": [{"k": "petal", "v": 1}, {"k": "petal_arc", "v": 0.02}]},
			"gold": {"thr": 3, "fx": [{"k": "petal", "v": 1}]},
		},
	},
	"ricochet": {
		"name": "弹射", "cat": "atk", "kind": "int",
		"grades": {
			"white": {"thr": 5, "fx": [{"k": "ricochet", "v": 1}]},
			"blue": {"thr": 4, "fx": [{"k": "ricochet", "v": 1}]},
			"violet": {"thr": 5, "fx": [{"k": "ricochet", "v": 1}, {"k": "blast", "v": 0.030}]},
			"gold": {"thr": 3, "fx": [{"k": "ricochet", "v": 1}]},
		},
	},
	"blast": {
		"name": "爆破", "cat": "atk", "kind": "add",
		"grades": {
			"white": {"fx": [{"k": "blast", "v": 0.040}]},
			"blue": {"fx": [{"k": "blast", "v": 0.060}]},
			"violet": {"fx": [{"k": "blast", "v": 0.080}, {"k": "combo", "v": 0.010}]},
			"gold": {"fx": [{"k": "blast", "v": 0.110}]},
		},
	},
	"combo": {
		"name": "连击", "cat": "atk", "kind": "add",
		"grades": {
			"white": {"fx": [{"k": "combo", "v": 0.020}]},
			"blue": {"fx": [{"k": "combo", "v": 0.030}]},
			"violet": {"fx": [{"k": "combo", "v": 0.040}, {"k": "power", "v": 0.020}]},
			"gold": {"fx": [{"k": "combo", "v": 0.050}]},
		},
	},
	"laser_iv": {
		"name": "激光充能", "cat": "atk", "kind": "add",
		"grades": {
			"white": {"fx": [{"k": "laser_iv", "v": -1.0}]},
			"blue": {"fx": [{"k": "laser_iv", "v": -1.4}]},
			"violet": {"fx": [{"k": "laser_iv", "v": -1.8}, {"k": "range", "v": 10.0}]},
			"gold": {"fx": [{"k": "laser_iv", "v": -2.4}]},
		},
	},

	# ---------------- 经济 ----------------
	"drop": {
		"name": "掉落", "cat": "eco", "kind": "add",
		"grades": {
			"white": {"fx": [{"k": "drop", "v": 0.025}]},
			"blue": {"fx": [{"k": "drop", "v": 0.040}]},
			"violet": {"fx": [{"k": "drop", "v": 0.055}, {"k": "salvage", "v": 0.020}]},
			"gold": {"fx": [{"k": "drop", "v": 0.080}]},
		},
	},
	"uses": {
		"name": "耐久", "cat": "eco", "kind": "add",
		"grades": {
			"white": {"fx": [{"k": "uses", "v": 0.040}]},
			"blue": {"fx": [{"k": "uses", "v": 0.060}]},
			"violet": {"fx": [{"k": "uses", "v": 0.080}, {"k": "craft", "v": -0.020}]},
			"gold": {"fx": [{"k": "uses", "v": 0.110}]},
		},
	},
	"craft": {
		"name": "工艺", "cat": "eco", "kind": "mul", "cap": 0.50,
		"grades": {
			"white": {"fx": [{"k": "craft", "v": -0.015}]},
			"blue": {"fx": [{"k": "craft", "v": -0.022}]},
			"violet": {"fx": [{"k": "craft", "v": -0.030}, {"k": "refine", "v": 0.020}]},
			"gold": {"fx": [{"k": "craft", "v": -0.042}]},
		},
	},
	"device": {
		"name": "装置", "cat": "eco", "kind": "mul", "cap": 0.50,
		"grades": {
			"white": {"fx": [{"k": "device", "v": -0.015}]},
			"blue": {"fx": [{"k": "device", "v": -0.025}]},
			"violet": {"fx": [{"k": "device", "v": -0.035}, {"k": "craft", "v": -0.010}]},
			"gold": {"fx": [{"k": "device", "v": -0.050}]},
		},
	},
	"salvage": {
		"name": "回收", "cat": "eco", "kind": "add",
		"grades": {
			"white": {"fx": [{"k": "salvage", "v": 0.020}]},
			"blue": {"fx": [{"k": "salvage", "v": 0.030}]},
			"violet": {"fx": [{"k": "salvage", "v": 0.040}, {"k": "drop", "v": 0.020}]},
			"gold": {"fx": [{"k": "salvage", "v": 0.060}]},
		},
	},
	"refine": {
		"name": "精炼", "cat": "eco", "kind": "add",
		"grades": {
			"white": {"fx": [{"k": "refine", "v": 0.015}]},
			"blue": {"fx": [{"k": "refine", "v": 0.025}]},
			"violet": {"fx": [{"k": "refine", "v": 0.035}, {"k": "craft", "v": -0.010}]},
			"gold": {"fx": [{"k": "refine", "v": 0.050}]},
		},
	},

	# ---------------- 生存 ----------------
	"hp": {
		"name": "体魄", "cat": "sur", "kind": "add",
		"grades": {
			"white": {"fx": [{"k": "hp", "v": 0.025}]},
			"blue": {"fx": [{"k": "hp", "v": 0.035}]},
			"violet": {"fx": [{"k": "hp", "v": 0.050}, {"k": "regen", "v": 0.05}]},
			"gold": {"fx": [{"k": "hp", "v": 0.070}]},
		},
	},
	"armor": {
		"name": "护甲", "cat": "sur", "kind": "add",
		"grades": {
			"white": {"fx": [{"k": "armor", "v": 0.010}]},
			"blue": {"fx": [{"k": "armor", "v": 0.015}]},
			"violet": {"fx": [{"k": "armor", "v": 0.020}, {"k": "hp", "v": 0.010}]},
			"gold": {"fx": [{"k": "armor", "v": 0.028}]},
		},
	},
	"regen": {
		"name": "回复", "cat": "sur", "kind": "add",
		"grades": {
			"white": {"fx": [{"k": "regen", "v": 0.08}]},
			"blue": {"fx": [{"k": "regen", "v": 0.12}]},
			"violet": {"fx": [{"k": "regen", "v": 0.18}, {"k": "hp", "v": 0.010}]},
			"gold": {"fx": [{"k": "regen", "v": 0.25}]},
		},
	},
	"dodge": {
		"name": "闪避", "cat": "sur", "kind": "add",
		"grades": {
			"white": {"fx": [{"k": "dodge", "v": 0.008}]},
			"blue": {"fx": [{"k": "dodge", "v": 0.012}]},
			"violet": {"fx": [{"k": "dodge", "v": 0.016}, {"k": "move", "v": 0.010}]},
			"gold": {"fx": [{"k": "dodge", "v": 0.022}]},
		},
	},
	"move": {
		"name": "疾行", "cat": "sur", "kind": "mul", "cap": 0.60,
		"grades": {
			"white": {"fx": [{"k": "move", "v": 0.012}]},
			"blue": {"fx": [{"k": "move", "v": 0.018}]},
			"violet": {"fx": [{"k": "move", "v": 0.024}, {"k": "dodge", "v": 0.005}]},
			"gold": {"fx": [{"k": "move", "v": 0.032}]},
		},
	},
	"pickup": {
		"name": "磁场", "cat": "sur", "kind": "add",
		"grades": {
			"white": {"fx": [{"k": "pickup", "v": 4.0}]},
			"blue": {"fx": [{"k": "pickup", "v": 6.0}]},
			"violet": {"fx": [{"k": "pickup", "v": 8.0}, {"k": "move", "v": 0.010}]},
			"gold": {"fx": [{"k": "pickup", "v": 12.0}]},
		},
	},
	"shield": {
		"name": "护盾", "cat": "sur", "kind": "int",
		"grades": {
			"white": {"thr": 10, "fx": [{"k": "shield", "v": 1}]},
			"blue": {"thr": 8, "fx": [{"k": "shield", "v": 1}]},
			"violet": {"thr": 7, "fx": [{"k": "shield", "v": 1}, {"k": "armor", "v": 0.010}]},
			"gold": {"thr": 5, "fx": [{"k": "shield", "v": 1}]},
		},
	},
	"revive": {
		"name": "复生", "cat": "sur", "kind": "int",
		"grades": {
			"white": {"thr": 10, "fx": [{"k": "revive", "v": 1}]},
			"blue": {"thr": 8, "fx": [{"k": "revive", "v": 1}]},
			"violet": {"thr": 7, "fx": [{"k": "revive", "v": 1}, {"k": "hp", "v": 0.020}]},
			"gold": {"thr": 5, "fx": [{"k": "revive", "v": 1}]},
		},
	},
}


## 变体 id：族名 + 双下划线 + 品质（"rate__gold"）
static func vid(fam: String, q: String) -> String:
	return fam + "__" + q


## 展开成扁平表：100 条变体，id → 卡面/说明/效果。game.gd 的 BUFFS 就是这份。
static func expand() -> Dictionary:
	var out := {}
	for fam in FAMILIES:
		var f: Dictionary = FAMILIES[fam]
		var grades: Dictionary = f.get("grades", {})
		for q in TIERS:
			var g: Dictionary = grades.get(q, {})
			# 取不到就空着：曾经在这里无条件 f["per"] 导致整表炸掉、升级卡全空
			var fx: Array = []
			for e in (g.get("fx", []) as Array):
				fx.append({"k": String(e["k"]), "v": float(e["v"])})
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
				"fx": fx,
				"cap": float(f.get("cap", 0.0)),
				"thr": int(g.get("thr", 0)),
				"desc": _desc(g),
			}
			out[d["id"]] = d
	return out


## 一条效果翻成人话（按效果键，不是按族：副效果写的是邻族的键）
static func fx_text(k: String, v: float) -> String:
	var pct := absf(v) * 100.0
	match k:
		"rate": return "开火间隔 −%.1f%%" % pct
		"power": return "伤害 +%.1f%%" % pct
		"range": return "射程 +%.0f" % v
		"target": return "目标 +%d" % int(v)
		"pierce": return "穿透 +%d" % int(v)
		"elite": return "精英伤害 +%.1f%%" % pct
		"petal": return "扇叶 +%d" % int(v)
		"petal_arc": return "扇宽 +%.2f" % v
		"ricochet": return "弹射 +%d 跳" % int(v)
		"blast": return "爆炸半径 +%.1f%%" % pct
		"combo": return "连击每层 +%.1f%%" % pct
		"laser_iv": return "激光间隔 −%.1fs" % absf(v)
		"drop": return "掉落率 +%.1f%%" % pct
		"uses": return "模块寿命 +%.1f%%" % pct
		"craft": return "合成时间 −%.1f%%" % pct
		"device": return "装置成本 −%.1f%%" % pct
		"salvage": return "拆卸回收 +%.1f%%" % pct
		"refine": return "精炼多出 +%.1f%%" % pct
		"hp": return "最大生命 +%.1f%%" % pct
		"armor": return "受到伤害 −%.1f%%" % pct
		"regen": return "回血 +%.2f/s" % v
		"dodge": return "闪避 +%.1f%%" % pct
		"move": return "移速 +%.1f%%" % pct
		"pickup": return "拾取半径 +%.0f" % v
		"shield": return "挡下 1 次伤害"
		"revive": return "阵亡后复活 1 次"
	return k


## 一条变体的效果文案：整数族带解锁等级，副效果同一行用 · 连起来
static func _desc(g: Dictionary) -> String:
	var parts: Array = []
	var thr := int(g.get("thr", 0))
	if thr > 0:
		parts.append("Lv%d 解锁" % thr)
	for e in (g.get("fx", []) as Array):
		parts.append(fx_text(String(e["k"]), float(e["v"])))
	return " · ".join(parts)


static func _tier_color(q: String) -> Color:
	match q:
		"blue": return Color(0.62, 0.86, 1.0)
		"violet": return Color(0.78, 0.68, 1.0)
		"gold": return Color(1.0, 0.84, 0.35)
		_: return Color(0.82, 0.84, 0.90)
