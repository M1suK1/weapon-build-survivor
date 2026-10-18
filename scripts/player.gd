extends Node2D
## 玩家：WASD / 方向键移动，视觉为白色圆 + 蓝色内核。

const SPEED := 230.0

var facing := Vector2.RIGHT


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir.length() > 0.0:
		dir = dir.normalized()
		facing = dir
		position += dir * SPEED * delta
		queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 17.0, Color(0.99, 0.98, 0.95, 0.95))
	draw_circle(Vector2.ZERO, 12.0, Color(0.25, 0.55, 1.0))
	draw_circle(facing * 9.0, 3.5, Color(0.9, 0.97, 1.0))
