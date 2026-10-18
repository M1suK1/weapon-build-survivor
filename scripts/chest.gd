extends Node2D
## 宝箱：地图上随机放置 / 精英掉落 / 每波结束有概率出现。
## 玩家走到附近即开启，获得一把随机武器（或一包模块）。

var opened := false
var bob := 0.0
var glow := 0.0
var life := 45.0


func _ready() -> void:
	bob = randf() * TAU


func _physics_process(delta: float) -> void:
	bob += delta * 2.4
	glow = 0.5 + 0.5 * sin(bob)
	# 没人捡就自己消失，免得满地图宝箱把后续刷新挤爆
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var p = get_tree().get_first_node_in_group("player")
	if p != null and not opened and position.distance_to(p.position) < 30.0:
		opened = true
		var g = get_tree().get_first_node_in_group("game")
		if g != null and g.has_method("grant_chest"):
			g.grant_chest(true)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var c := Color(1.0, 0.82, 0.35)
	draw_circle(Vector2.ZERO, 26.0 + 5.0 * glow, Color(c.r, c.g, c.b, 0.10 + 0.10 * glow))
	draw_rect(Rect2(-13.0, -10.0, 26.0, 20.0), Color(0.55, 0.38, 0.16))
	draw_rect(Rect2(-13.0, -10.0, 26.0, 7.0), c.darkened(0.15))
	draw_rect(Rect2(-13.0, -10.0, 26.0, 20.0), Color(1.0, 0.9, 0.6, 0.85), false, 2.0)
	draw_rect(Rect2(-3.0, -2.0, 6.0, 6.0), c)
