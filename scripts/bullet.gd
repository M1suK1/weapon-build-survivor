extends Node2D
## 射手子弹：直线飞行、命中玩家后消失。由 enemy.gd._fire_bullet() 生成。

const SPEED := 290.0
const DAMAGE := 5.0
const LIFE := 5.0
const RADIUS := 6.0

var dir := Vector2.RIGHT
var life := LIFE


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	position += dir * SPEED * delta
	var p = get_tree().get_first_node_in_group("player")
	if p != null and position.distance_to(p.position) < 16.0:
		if p.has_method("take_hit"):
			p.take_hit(DAMAGE, dir * 90.0)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade := clampf(life / 0.4, 0.0, 1.0)
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.78, 0.30, 0.9 * fade))
	draw_circle(Vector2.ZERO, RADIUS * 0.5, Color(1.0, 0.96, 0.80, fade))
	draw_line(Vector2.ZERO, -dir * 12.0, Color(1.0, 0.72, 0.25, 0.35 * fade), 3.0)
