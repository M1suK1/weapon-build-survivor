extends Node2D
## 敌人：直线追击玩家。hp / max_hp / speed / kind / radius / body_color 由 game.gd 生成后赋值。

var hp := 4.0
var max_hp := 4.0
var speed := 100.0
var radius := 13.0
var kind := "flood"
var body_color := Color(0.92, 0.30, 0.34)
var hpth := 0.0
var hit := 0.0
var facing := Vector2.RIGHT
## 命中玩家的冷却（避免同一只怪每帧啃血）
var touch_cd := 0.0


func _ready() -> void:
	hpth = randf() * TAU


func _physics_process(delta: float) -> void:
	hit = maxf(0.0, hit - delta)
	touch_cd = maxf(0.0, touch_cd - delta)
	var p = get_tree().get_first_node_in_group("player")
	if p != null:
		var d: Vector2 = p.position - position
		if d.length() > 1.0:
			facing = d.normalized()
			position += facing * speed * delta
	queue_redraw()


func _draw() -> void:
	var frac := clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)
	var body := body_color.lerp(Color(1.0, 0.86, 0.55), 1.0 - frac)
	if hit > 0.0:
		body = body.lerp(Color(1, 1, 1), clampf(hit / 0.18, 0.0, 1.0) * 0.85)
	var r := radius * (1.0 + hit * 0.6)
	# 疾行者画成尖头三角（一眼能看出它冲得快），其余还是圆
	if kind == "runner":
		var dir := facing
		draw_colored_polygon(PackedVector2Array([
			dir * r * 1.6,
			dir.rotated(2.4) * r,
			dir.rotated(-2.4) * r,
		]), body)
		draw_circle(Vector2.ZERO, r * 0.5, body.darkened(0.25))
	else:
		draw_circle(Vector2.ZERO, r, body)
		if kind == "rock":
			# 磐石：外圈硬壳
			draw_arc(Vector2.ZERO, r * 0.72, 0.0, TAU, 18, body.lightened(0.35), 2.5, true)
	draw_circle(Vector2.from_angle(hpth) * radius * 0.45, radius * 0.3, Color(0.12, 0.04, 0.07, 0.55))
	if frac < 0.999:
		var w := radius * 2.2
		draw_rect(Rect2(-w * 0.5, -radius - 8.0, w, 3.0), Color(0.0, 0.0, 0.0, 0.55))
		draw_rect(Rect2(-w * 0.5, -radius - 8.0, w * frac, 3.0), Color(0.55, 1.0, 0.62))
