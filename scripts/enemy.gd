extends Node2D
## 敌人：直线追击玩家。hp / max_hp / speed 由 game.gd 生成后赋值。

var hp := 4.0
var max_hp := 4.0
var speed := 100.0
var radius := 11.0
var hpth := 0.0
var hit := 0.0


func _ready() -> void:
	radius = randf_range(11.0, 15.0)
	hpth = randf() * TAU


func _physics_process(delta: float) -> void:
	hit = maxf(0.0, hit - delta)
	var p = get_tree().get_first_node_in_group("player")
	if p != null:
		var d: Vector2 = p.position - position
		if d.length() > 1.0:
			position += d.normalized() * speed * delta
	queue_redraw()


func _draw() -> void:
	var frac := clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)
	var body := Color(0.92, 0.30, 0.34).lerp(Color(1.0, 0.72, 0.30), 1.0 - frac)
	if hit > 0.0:
		body = body.lerp(Color(1, 1, 1), clampf(hit / 0.18, 0.0, 1.0) * 0.85)
	var r := radius * (1.0 + hit * 0.6)
	draw_circle(Vector2.ZERO, r, body)
	draw_circle(Vector2.from_angle(hpth) * radius * 0.45, radius * 0.32, Color(0.15, 0.05, 0.08, 0.55))
	if frac < 0.999:
		var w := radius * 2.2
		draw_rect(Rect2(-w * 0.5, -radius - 8.0, w, 3.0), Color(0.0, 0.0, 0.0, 0.55))
		draw_rect(Rect2(-w * 0.5, -radius - 8.0, w * frac, 3.0), Color(0.55, 1.0, 0.62))
