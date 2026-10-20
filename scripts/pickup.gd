extends Node2D
## 掉落模块：先小幅弹开，再吸附向玩家。

var mid := "base"
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
	# 吸附半径吃「磁场」buff（plan-v5 §9.3 pickup 族）
	var g0 = get_tree().get_first_node_in_group("game")
	var magnet := 320.0
	if g0 != null and g0.has_method("pickup_radius"):
		magnet = float(g0.pickup_radius())
	if age > 0.3 and (dist < magnet or age > 1.8):
		velocity = velocity.lerp(to_p.normalized() * 460.0, 1.0 - exp(-7.0 * delta))
	position += velocity * delta
	queue_redraw()
	if dist < 22.0 and not collected:
		collected = true
		var g = get_tree().get_first_node_in_group("game")
		if g != null:
			g.add_module(String(mid))
		queue_free()


func _draw() -> void:
	var c := Color(0.56, 0.70, 1.0)
	match String(mid):
		"add": c = Color(0.49, 0.94, 0.66)
		"amp": c = Color(0.36, 0.88, 0.82)
		"reson": c = Color(1.0, 0.56, 0.64)
		_: c = Color(0.56, 0.70, 1.0)
	draw_circle(Vector2.ZERO, 7.0 + sin(age * 8.0) * 0.8, Color(c.r, c.g, c.b, 0.35))
	draw_circle(Vector2.ZERO, 5.0, c)
	draw_circle(Vector2.ZERO, 2.2, Color(1, 1, 1, 0.92))
