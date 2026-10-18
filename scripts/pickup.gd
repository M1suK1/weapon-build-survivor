extends Node2D
## 掉落模块：先小幅弹开，再吸附向玩家。

var tier := 1
var age := 0.0
var velocity := Vector2.ZERO
var collected := false


func _ready() -> void:
	velocity = Vector2.from_angle(randf() * TAU) * randf_range(30.0, 70.0)


func _physics_process(delta: float) -> void:
	age += delta
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		queue_free()
		return
	var to_p: Vector2 = p.position - position
	var dist: float = to_p.length()
	if age > 0.3 and (dist < 320.0 or age > 1.8):
		velocity = velocity.lerp(to_p.normalized() * 460.0, 1.0 - exp(-7.0 * delta))
	position += velocity * delta
	queue_redraw()
	if dist < 22.0 and not collected:
		collected = true
		var g = get_tree().get_first_node_in_group("game")
		if g != null:
			g.add_module(tier)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0 + sin(age * 8.0) * 0.8, Color(0.56, 0.70, 1.0, 0.35))
	draw_circle(Vector2.ZERO, 5.0, Color(0.56, 0.70, 1.0))
	draw_circle(Vector2.ZERO, 2.2, Color(1, 1, 1, 0.92))
