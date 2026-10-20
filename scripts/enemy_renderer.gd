extends Node2D
## 集中渲染：一个 CanvasItem 画完场上全部敌人（docs/plan-v4.md §4.2 A）。
## 敌人节点只跑逻辑、不再 `_draw` / `queue_redraw`；这里按世界坐标直接画，
## 并跳过镜头外的敌人（400 只时通常一半以上在屏外，白画纯属浪费）。
## 造型必须与旧 enemy.gd::_draw 完全一致（runner 三角 / charger 六边形 / shooter 三角 + 枪口 /
## rock 内圈 / 血条），改动请同时看 V5 前后截图对比。

const Perf := preload("res://scripts/systems/perf.gd")
const Enemy := preload("res://scripts/enemy.gd")

## 由 game.gd 在 `_make_enemy_renderer()` 里赋值为 Game 自己
var game: Node = null
## 上一帧实际画出的敌人数（镜头内），perftest / F3 用
var drawn := 0


func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	if game == null:
		return
	var ct: Transform2D = get_viewport().get_canvas_transform()
	var inv := ct.affine_inverse()
	var a := inv * Vector2.ZERO
	var b := inv * get_viewport_rect().size
	var world := Rect2(a, b - a).abs().grow(48.0)
	var list: Array = game.enemies
	drawn = 0
	for i in list.size():
		var e = list[i]
		if not is_instance_valid(e):
			continue
		if not world.has_point(e.position):
			continue
		drawn += 1
		_draw_one(e)
	Perf.draw_usec += Time.get_ticks_usec() - t0


func _draw_one(e: Node2D) -> void:
	draw_set_transform(e.position, 0.0, Vector2.ONE)
	var frac := clampf(e.hp / maxf(e.max_hp, 0.001), 0.0, 1.0)
	var body: Color = (e.body_color as Color).lerp(Color(1.0, 0.86, 0.55), 1.0 - frac)
	if e.hit > 0.0:
		body = body.lerp(Color(1, 1, 1), clampf(e.hit / 0.18, 0.0, 1.0) * 0.85)
	var r: float = e.radius * (1.0 + e.hit * 0.6)

	if e.telegraph > 0.0:
		# 预兆：只画半透明轮廓 + 一圈收缩光环（出生保护期，玩家有 1~2 秒可以改方向）
		var ta := 0.30 + 0.45 * clampf(1.0 - e.telegraph / 2.1, 0.0, 1.0)
		draw_circle(Vector2.ZERO, r, Color(e.body_color.r, e.body_color.g, e.body_color.b, ta * 0.45))
		draw_arc(Vector2.ZERO, r + 4.0, 0.0, TAU, 24, Color(1.0, 0.35, 0.35, ta), 2.5, true)
		draw_arc(Vector2.ZERO, r * (1.0 + e.telegraph * 1.6), 0.0, TAU, 24,
			Color(1.0, 0.5, 0.5, ta * 0.7), 2.0, true)
		return

	var kind := String(e.kind)
	var facing: Vector2 = e.facing
	if kind == "runner":
		# 尖头三角：一眼能看出它冲得快
		draw_colored_polygon(PackedVector2Array([
			facing * r * 1.6,
			facing.rotated(2.4) * r,
			facing.rotated(-2.4) * r,
		]), body)
		draw_circle(Vector2.ZERO, r * 0.5, body.darkened(0.25))
	elif kind == "charger":
		# 六边形精英 + 蓄力时的红色瞄准线
		var pts := PackedVector2Array()
		for i in 6:
			pts.append(Vector2.from_angle(TAU * i / 6.0 + e.hpth) * r)
		draw_colored_polygon(pts, body)
		draw_arc(Vector2.ZERO, r * 1.12, 0.0, TAU, 24, Color(1, 0.85, 0.4, 0.9), 2.5, true)
		if e.windup > 0.0:
			var k: float = 1.0 - e.windup / Enemy.CHARGE_WINDUP
			draw_line(Vector2.ZERO, facing * 520.0, Color(1.0, 0.25, 0.25, 0.25 + 0.55 * k), 2.0 + 3.0 * k)
		if e.stun > 0.0:
			draw_arc(Vector2.ZERO, r * 1.5, 0.0, TAU * (e.stun / Enemy.CHARGE_STUN), 20, Color(0.5, 0.8, 1.0, 0.8), 2.0, true)
	elif kind == "shooter":
		var pts2 := PackedVector2Array()
		for i in 3:
			pts2.append(Vector2.from_angle(-PI * 0.5 + TAU * i / 3.0) * r)
		draw_colored_polygon(pts2, body)
		if e.windup > 0.0:
			var k2: float = 1.0 - e.windup / Enemy.SHOOT_WINDUP
			draw_circle(facing * (r + 6.0), 3.0 + 4.0 * k2, Color(1.0, 0.9, 0.4, 0.9))
	else:
		draw_circle(Vector2.ZERO, r, body)
		if kind == "rock":
			draw_arc(Vector2.ZERO, r * 0.72, 0.0, TAU, 18, body.lightened(0.35), 2.5, true)

	# 重装变种：2px 高亮描边，和普通怪一眼分开（形状/半径/速度都跟模板一致，只靠颜色区分）
	if String(e.variant) == "brute":
		draw_arc(Vector2.ZERO, r + 2.5, 0.0, TAU, 28, Color(1.0, 0.88, 0.94, 0.95), 2.0, true)

	# 高密度 LOD：>220 只时不画纯装饰的小内点（每只 1 次 draw），
	# 400 只时这一项就占约 3ms —— 画面此时已经是一团，内点看不出来（docs/plan-v4.md §4.3 draw≤4ms）
	if kind != "charger" and kind != "shooter" and game.enemies.size() <= 220:
		draw_circle(Vector2.from_angle(e.hpth) * e.radius * 0.45, e.radius * 0.3, Color(0.12, 0.04, 0.07, 0.55))
	if frac < 0.999:
		var w: float = e.radius * 2.2
		draw_rect(Rect2(-w * 0.5, -e.radius - 8.0, w, 3.0), Color(0.0, 0.0, 0.0, 0.55))
		draw_rect(Rect2(-w * 0.5, -e.radius - 8.0, w * frac, 3.0), Color(0.55, 1.0, 0.62))
