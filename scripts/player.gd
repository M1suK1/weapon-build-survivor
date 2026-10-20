extends Node2D
## 玩家：WASD / 方向键移动，视觉为白色圆 + 蓝色内核。
## knock 是外部（冲刺精英）给的一次性推力，按指数衰减。

const SPEED := 230.0

var facing := Vector2.RIGHT
var knock := Vector2.ZERO
## 无敌帧（被子弹/冲撞打中后的短暂免疫），由 game.gd 设置
var invuln := 0.0
## 引用 game，读移速倍率（plan-v5 §9.3 move 族）
var game: Node = null


func _ready() -> void:
	game = get_tree().get_first_node_in_group("game")


func _move_mult() -> float:
	if game != null and game.has_method("move_mult"):
		return float(game.move_mult())
	return 1.0


func _physics_process(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
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
		position += dir * SPEED * _move_mult() * delta
	if knock.length() > 1.0:
		position += knock * delta
		knock = knock.lerp(Vector2.ZERO, clampf(delta * 7.0, 0.0, 1.0))
	else:
		knock = Vector2.ZERO
	queue_redraw()


func add_knock(push: Vector2) -> void:
	knock = push


## 被子弹 / 冲刺打中：无敌帧内免疫，返回是否真的吃到了伤害
func take_hit(dmg: float, push: Vector2) -> bool:
	if invuln > 0.0:
		return false
	var g = get_tree().get_first_node_in_group("game")
	if g == null or not g.has_method("hurt_player"):
		return false
	invuln = 0.45
	g.hurt_player(dmg, push)
	return true


func _draw() -> void:
	# 无敌帧时闪白，给「刚才挨打了」一个明确反馈
	var a := 0.55 if invuln > 0.0 and fmod(invuln, 0.12) < 0.06 else 1.0
	draw_circle(Vector2.ZERO, 17.0, Color(0.99, 0.98, 0.95, 0.95 * a))
	draw_circle(Vector2.ZERO, 12.0, Color(0.25, 0.55, 1.0, a))
	draw_circle(facing * 9.0, 3.5, Color(0.9, 0.97, 1.0, a))
