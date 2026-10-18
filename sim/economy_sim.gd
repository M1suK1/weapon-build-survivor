extends SceneTree
## M0 经济模型模拟器（无头）。验证「模块净弹药率」失败条件，并标定「宽松成长」常数。
## 运行：godot --headless --path . --script res://sim/economy_sim.gd
##
## 模型要点
## - 唯一货币 = 模块。升级吃 3 个模块；合成吃 2 个同阶模块换 1 个高阶。
## - 模块寿命 = uses × interval（开火次数用尽即销毁），所以「净弹药率 = 掉落率 − 燃烧率」
##   是真正的失败条件，而不是 HP。
## - 可持续上限（能压住的敌人 HP 天花板）≈ drop × rate × uses：每一阶都把天花板往上推。

const TOTAL_SEC := 1200.0
const DT := 0.25
const ALIVE_CAP := 60.0
const WAVE_SEC := 40.0
const SUPPLY_EVERY := 60.0
## 插槽由武器品质决定（用户原案），整局靠换武器增长：wave → 槽数
const SLOT_SCHEDULE := {12: 5, 20: 6}

const TIERS := {
	1: {"rate": 1.0, "uses": 20.0, "stored": 1.6, "name": "基础"},
	2: {"rate": 3.0, "uses": 24.0, "stored": 4.8, "name": "加法"},
	3: {"rate": 9.0, "uses": 28.0, "stored": 14.4, "name": "阵列"},
	4: {"rate": 27.0, "uses": 34.0, "stored": 43.2, "name": "共振"},
}

const INTERVAL := 1.0
const MUL := 1.0
const CRAFT_UNLOCK := {2: 4, 3: 10, 4: 18}
const LEVEL_COST_BASE := 3.0
const LEVEL_COST_GROWTH := 1.18

const PRESETS := {
	"tight":     {"hp_base": 4.0, "hp_growth": 1.112, "spawn0": 0.90, "spawn_grow": 0.020, "drop": 0.45},
	"mid":       {"hp_base": 4.0, "hp_growth": 1.110, "spawn0": 0.90, "spawn_grow": 0.020, "drop": 0.55},
	"loose":     {"hp_base": 4.0, "hp_growth": 1.108, "spawn0": 0.90, "spawn_grow": 0.020, "drop": 0.65},
	"veryloose": {"hp_base": 4.0, "hp_growth": 1.105, "spawn0": 0.90, "spawn_grow": 0.020, "drop": 0.75},
}

const SERIES := "loose"
var _series: Array = []


func _initialize() -> void:
	var results := {}
	for key in PRESETS.keys():
		# 多种子平均：单种子被 randf 抖动带偏 ±30% 末段余量，不能据此定数值
		var n := 5
		var agg := {"died": 0, "t_end": 0.0, "wave": 0.0, "level": 0.0, "dps": 0.0,
			"need": 0.0, "margin_end": 0.0, "cov": 0.0, "net_avg": 0.0, "net_min": 0.0,
			"stock_peak": 0.0, "starve_sec": 0.0, "m_min": 1.0, "m_max": 0.0}
		for s in n:
			seed(1000 + s * 7919)
			var r: Dictionary = _run(PRESETS[key], key == SERIES and s == 0)
			agg.died += 1 if r.died else 0
			for k in ["t_end", "wave", "level", "dps", "need", "margin_end", "cov",
					"net_avg", "net_min", "stock_peak", "starve_sec"]:
				agg[k] += float(r[k])
			agg.m_min = minf(agg.m_min, r.margin_end)
			agg.m_max = maxf(agg.m_max, r.margin_end)
		for k in ["t_end", "wave", "level", "dps", "need", "margin_end", "cov",
				"net_avg", "net_min", "stock_peak", "starve_sec"]:
			agg[k] /= float(n)
		results[key] = agg
	print("== M0 经济模拟（20 分钟，单武器 interval=1.0，每预设 5 种子平均） ==")
	print("预设\t通关率\t终波\t等级\t槽位\tDPS/需求\t末段余量(均/最小/最大)\t均覆盖\t净弹药均值\t库存峰")
	for key in PRESETS.keys():
		var a: Dictionary = results[key]
		print("%s\t%d/5\t%.0f\t%.0f\t%.0f\t%.0f/%.0f\t%.0f%% (%.0f~%.0f)\t%.0f%%\t%+.2f\t%.0f" % [
			key, 5 - a.died, a.wave, a.level, a.slots, a.dps, a.need,
			100.0 * a.margin_end, 100.0 * a.m_min, 100.0 * a.m_max,
			100.0 * a.cov, a.net_avg, a.stock_peak,
		])
	print("")
	print("t\twave\talive\tdps\tneed\tdrop\tnet\tlvl\tslots\ttier")
	for row in _series:
		print("%d\t%d\t%.0f\t%.0f\t%.0f\t%.2f\t%+.2f\t%d\t%d\t%d" % row)
	quit()


func _eff(tier: int) -> float:
	var m: Dictionary = TIERS[tier]
	return minf(m.rate, m.stored / INTERVAL)


func _level_cost(level: int) -> int:
	return int(round(LEVEL_COST_BASE * pow(LEVEL_COST_GROWTH, level - 1)))


func _count(slots: Array, stock: Dictionary, tier: int) -> int:
	var n: int = stock[tier]
	for s in slots:
		if s != null and s.tier == tier:
			n += 1
	return n


func _take(slots: Array, stock: Dictionary, tier: int, n: int) -> void:
	var left := n
	while left > 0 and stock[tier] > 0:
		stock[tier] -= 1
		left -= 1
	while left > 0:
		var best := -1
		var best_frac := 2.0
		for i in range(slots.size()):
			var s = slots[i]
			if s != null and s.tier == tier:
				var f: float = s.left / TIERS[tier].uses
				if f < best_frac:
					best_frac = f
					best = i
		if best < 0:
			return
		slots[best] = null
		left -= 1


func _stock_total(stock: Dictionary) -> int:
	return stock[1] + stock[2] + stock[3] + stock[4]


func _run(cfg: Dictionary, collect: bool) -> Dictionary:
	var stock := {1: 0, 2: 0, 3: 0, 4: 0}
	var slots: Array = []
	var level := 1
	var alive := 0.0
	var fire_t := 0.0
	var died := false
	var t_end := TOTAL_SEC
	var stock_peak := 0
	var net_sum := 0.0
	var net_min := 999.0
	var net_n := 0.0
	var cov_sum := 0.0
	var cov_n := 0.0
	var starve_sec := 0.0
	var drop_pool := 0.0
	var crafts := {2: 0, 3: 0, 4: 0}
	var last := {"wave": 1, "level": 1, "slots": 4, "dps": 0.0, "need": 0.0, "tier": 0}

	for i in 4:
		slots.append(null)
	slots[0] = {"tier": 1, "left": TIERS[1].uses}
	slots[1] = {"tier": 1, "left": TIERS[1].uses}

	for step in range(int(TOTAL_SEC / DT)):
		var t: float = step * DT
		var wave: int = maxi(1, int(t / WAVE_SEC) + 1)
		var hp: float = cfg.hp_base * pow(cfg.hp_growth, wave - 1)
		var spawn: float = cfg.spawn0 + wave * cfg.spawn_grow
		# 换武器 → 更多插槽（用户原案：品质决定槽数）
		if SLOT_SCHEDULE.has(wave) and slots.size() < SLOT_SCHEDULE[wave]:
			while slots.size() < SLOT_SCHEDULE[wave]:
				slots.append(null)

		var dps := 0.0
		var filled := 0
		var tier_sum := 0
		for s in slots:
			if s != null:
				filled += 1
				tier_sum += s.tier
				dps += _eff(s.tier) * MUL

		# 开火（无目标不开火 → 不燃烧：死亡螺旋保底）
		fire_t += DT
		if fire_t >= INTERVAL - 0.0001:
			fire_t = 0.0
			if alive > 0.5 and filled > 0:
				for i in range(slots.size()):
					var s = slots[i]
					if s != null:
						s.left -= 1.0
						if s.left <= 0.0:
							slots[i] = null

		alive = minf(alive + spawn * DT, ALIVE_CAP * 2.0)
		var kill: float = minf(dps / hp, alive / DT)
		alive = maxf(0.0, alive - kill * DT)

		drop_pool += kill * cfg.drop * DT
		if step > 0 and step % int(SUPPLY_EVERY / DT) == 0:
			stock[1] += 1 + int(wave / 6.0)
		while drop_pool >= 1.0:
			stock[1] += 1
			drop_pool -= 1.0

		var need: float = spawn * hp
		var burn := 0.0
		for s in slots:
			if s != null:
				burn += 1.0 / (TIERS[s.tier].uses * INTERVAL)
		var drop_rate: float = kill * cfg.drop
		var net: float = drop_rate - burn
		net_sum += net
		net_n += 1.0
		net_min = minf(net_min, net)
		if net < 0.0:
			starve_sec += DT
		stock_peak = maxi(stock_peak, _stock_total(stock))
		cov_sum += dps / maxf(need, 0.001)
		cov_n += 1.0

		# ---------- 构筑决策 ----------
		var want_up: bool = dps * 1.15 < need or net < 0.10
		var guard := 0
		var changed := true
		var filled_this_pass := 0
		while changed and guard < 40:
			guard += 1
			changed = false
			# A) 合成升阶（只为能做的最高阶攒料）
			var target := 0
			for tg in [4, 3, 2]:
				if level >= CRAFT_UNLOCK[tg] and _count(slots, stock, tg - 1) >= 2:
					target = tg
					break
			if target > 0 and want_up:
				_take(slots, stock, target - 1, 2)
				stock[target] += 1
				crafts[target] += 1
				changed = true
				continue
			# B) 空槽填充（最高阶优先，每次决策只补一个 → 寿命自然错开）
			if filled_this_pass < 1:
				for i in range(slots.size()):
					if slots[i] != null:
						continue
					for tier in [4, 3, 2, 1]:
						if stock[tier] > 0:
							stock[tier] -= 1
							slots[i] = {"tier": tier, "left": TIERS[tier].uses * randf_range(0.9, 1.1)}
							filled_this_pass += 1
							changed = true
							break
					if changed:
						break
			if changed:
				continue
			# C) 满槽：高阶库存替换寿命将尽的低阶模块
			for tier in [4, 3, 2, 1]:
				if stock[tier] <= 0:
					continue
				for i in range(slots.size()):
					var s = slots[i]
					if s == null or s.tier >= tier:
						continue
					if s.left / TIERS[s.tier].uses <= 0.55:
						stock[tier] -= 1
						slots[i] = {"tier": tier, "left": TIERS[tier].uses * randf_range(0.9, 1.1)}
						changed = true
						break
				if changed:
					break
			if changed:
				continue
			# D) 富余模块 → 升级（指数成本：越到后面越贵，逼玩家在「升级解锁配方」与
			#    「合成提即时 DPS」之间做取舍——这是本作真正的核心资源竞争）
			var cost := _level_cost(level)
			if not want_up and _stock_total(stock) >= cost:
				var pay := cost
				for tier in [1, 2, 3, 4]:
					while pay > 0 and stock[tier] > 0:
						stock[tier] -= 1
						pay -= 1
				if pay <= 0:
					level += 1
					changed = true

		last = {"wave": wave, "level": level, "slots": slots.size(), "dps": dps, "need": need,
				"tier": 0 if filled == 0 else int(round(10.0 * tier_sum / filled))}

		if collect and t > 0.0 and absf(fmod(t, 60.0)) < 0.001:
			_series.append([int(t), wave, alive, dps, need, drop_rate, net, level, slots.size(), last.tier])

		if alive > ALIVE_CAP:
			died = true
			t_end = t
			break

	return {
		"died": died, "t_end": t_end, "wave": last.wave, "level": last.level,
		"slots": last.slots, "dps": last.dps, "need": last.need,
		"margin_end": last.dps / maxf(last.need, 0.001),
		"cov": cov_sum / maxf(cov_n, 1.0), "net_avg": net_sum / maxf(net_n, 1.0),
		"net_min": net_min, "stock_peak": stock_peak, "starve_sec": starve_sec, "crafts": crafts,
	}
