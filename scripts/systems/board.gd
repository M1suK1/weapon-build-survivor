extends RefCounted
## 电路板拓扑（纯函数，不认识武器实例，也不认识 UI）。
##
## 玩法：一块电路板 = 若干格子摆成网格形状，格子之间的关系只有「相邻」和「距离」。
## 相邻 = 网格曼哈顿距离 1（上下左右）；斜角不算，所以直线是链、T/十字在中间形成枢纽。
## 加法的镜像只看相邻，共振只看相邻，脉冲类效果看「半径」。
##
## 谁在用：`scripts/game.gd` 的 `_slot_out()`（网络结算）、拖拽落点判定、构筑屏画连线。
## 规则文档：`docs/reference.md` §3（模块网络）。
##
## 所有函数都是「传入布局数组 layout: Array[Vector2i]，返回下标」的形式，
## 不持有任何状态，方便以后直接搬进 systems/board.gd 的单测里。


## 与 i 相邻（曼哈顿距离 1）的格子下标
static func neighbors(layout: Array, i: int) -> Array:
	var out: Array = []
	if i < 0 or i >= layout.size():
		return out
	var a: Vector2i = layout[i]
	for j in layout.size():
		if j == i:
			continue
		var b: Vector2i = layout[j]
		if absi(a.x - b.x) + absi(a.y - b.y) == 1:
			out.append(j)
	return out


## 半径 r 内（曼哈顿距离 ≤ r）的格子下标，不含自己
static func within(layout: Array, i: int, r: int) -> Array:
	var out: Array = []
	if i < 0 or i >= layout.size():
		return out
	var a: Vector2i = layout[i]
	for j in layout.size():
		if j == i:
			continue
		var b: Vector2i = layout[j]
		if absi(a.x - b.x) + absi(a.y - b.y) <= r:
			out.append(j)
	return out


## 布局的包围盒（构筑屏居中用）
static func bounds(layout: Array) -> Rect2i:
	if layout.is_empty():
		return Rect2i(0, 0, 0, 0)
	var lo: Vector2i = layout[0]
	var hi: Vector2i = layout[0]
	for p in layout:
		var v: Vector2i = p
		lo.x = mini(lo.x, v.x)
		lo.y = mini(lo.y, v.y)
		hi.x = maxi(hi.x, v.x)
		hi.y = maxi(hi.y, v.y)
	return Rect2i(lo, hi - lo + Vector2i(1, 1))
