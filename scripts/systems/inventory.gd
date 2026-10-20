extends RefCounted
## 模块库存（纯逻辑，不碰 UI，也不认识武器）。
##
## 设计要点：库存按**模块 id** 计数，不按阶合并 —— 同阶的「加法 / 锋锐刃 / 轻质弹链」
## 是完全不同的东西，合并了就分不清玩家到底攒了什么（配方卡、特化件都依赖这一点）。
##
## 谁在用：`scripts/game.gd`（掉落、合成扣料、升级扣料、构筑屏）。
## 相关规则：`docs/reference.md` §3（模块）与 §4（配方成本）。

const ModDB := preload("res://scripts/data/modules_db.gd")

## id -> 数量。只通过本类的方法改，避免出现负数。
var counts := {}


func of(id: String) -> int:
	return int(counts.get(id, 0))


func has(id: String, n: int = 1) -> bool:
	return of(id) >= n


## n > 0 加、n < 0 扣（负数走 take，避免「写了扣料却什么也没发生」）。
## 历史上 add() 只收正数，而 scripts/game.gd 有 7 处用 `_add_inv(x, -n)` 扣料，
## 于是升级/合成全都不扣库存（v7 §1 修的就是这个）。
func add(id: String, n: int = 1) -> void:
	if n < 0:
		take(id, -n)
		return
	if n == 0:
		return
	counts[id] = of(id) + n


## 扣掉 n 个，返回实际扣掉的数量（库存不够就扣光，不会出现负数）。
func take(id: String, n: int = 1) -> int:
	if n <= 0:
		return 0
	var got: int = mini(of(id), n)
	counts[id] = of(id) - got
	if int(counts[id]) == 0:
		counts.erase(id)
	return got


func total() -> int:
	var n := 0
	for k in counts:
		n += int(counts[k])
	return n


## 某一阶（1–4）的模块总数
func of_tier(t: int) -> int:
	var n := 0
	for k in counts:
		if int(ModDB.MODULES[k]["tier"]) == t:
			n += int(counts[k])
	return n


## 有货的 id，按「先基础、再按配方顺序」排，供 UI 与自动配板使用
func stocked_ids() -> Array:
	var out: Array = []
	for k in (["base"] + ModDB.MOD_ORDER):
		if of(String(k)) > 0:
			out.append(String(k))
	return out


## 同类里库存最多的那个 id（合成扣料用：优先消耗堆积最多的）
func richest_of_tier(t: int) -> String:
	var best := ""
	var best_n := 0
	for k in (["base"] + ModDB.MOD_ORDER):
		if int(ModDB.MODULES[k]["tier"]) != t:
			continue
		var n := of(String(k))
		if n > best_n:
			best = String(k)
			best_n = n
	return best


## HUD/自测台用的一行摘要，例如 "基础12 加法3"
func describe() -> String:
	var parts: Array = []
	for k in (["base"] + ModDB.MOD_ORDER):
		if of(String(k)) > 0:
			parts.append(String(ModDB.MODULES[k]["name"]) + str(of(String(k))))
	return " ".join(parts)


func clear() -> void:
	counts.clear()
