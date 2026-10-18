extends Node2D
## 敌人：直线追击玩家。hp / max_hp / speed / kind / radius / body_color 由 game.gd 生成后赋值。
##
## 行为按 kind 分：
##   flood  —— 直冲
##   runner —— 直冲（更快更脆，画成尖头三角）
##   rock   —— 直冲（慢而硬）
##   shooter—— 保持 240~320 距离放风筝，每 2.6s 抬手 0.35s 后打一发子弹
##   charger—— 距玩家 ≤420 时蓄力 0.9s（画红线）→ 780px/s 冲刺 0.35s → 硬直 1.1s

const SHOOT_MIN := 140.0
const SHOOT_MAX := 190.0
const SHOOT_CD := 3.2
const SHOOT_WINDUP := 0.35
const CHARGE_RANGE := 420.0
const CHARGE_WINDUP := 0.9
const CHARGE_SPEED := 780.0
const CHARGE_TIME := 0.35
const CHARGE_CD := 4.0
const CHARGE_STUN := 1.1
const CHARGE_DAMAGE := 24.0

var hp := 4.0
var max_hp := 4.0
var speed := 100.0
var radius := 13.0
var kind := "flood"
var body_color := Color(0.92, 0.30, 0.34)
var hp_mult := 1.0  # 该种类的血量倍率：掉落量与它成正比（血厚 = 掉得多）
var hpth := 0.0
var hit := 0.0
var _p: Node2D = null
var orbit_dir := 1.0
var hold_bias := 0.0
var _g: Node = null
var facing := Vector2.RIGHT

## 通用计时
var shoot_t := 0.0
var windup := 0.0
var charge_t := 0.0
var charge_cd := 0.0
var stun := 0.0
var dash_dir := Vector2.RIGHT
var dash_t := 0.0


func _ready() -> void:
	hpth = randf() * TAU
	shoot_t = randf() * SHOOT_CD
	charge_cd = randf_range(1.0, 3.0)
	orbit_dir = 1.0 if randf() < 0.5 else -1.0
	# 每只怪站的距离不同，几十只才会围成一圈「有厚度」的包围圈，而不是挤成一个点
	hold_bias = randf_range(0.0, 52.0)


func _physics_process(delta: float) -> void:
	hit = maxf(0.0, hit - delta)
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		queue_redraw()
		return
	var to_p: Vector2 = p.position - position
	var dist := to_p.length()
	if dist > 1.0:
		facing = to_p / dist

	if kind == "charger":
		_charger_step(delta, p, dist)
	elif kind == "shooter":
		_shooter_step(delta, dist)
	else:
		position += facing * speed * delta
	queue_redraw()


func _charger_step(delta: float, p: Node2D, dist: float) -> void:
	charge_cd = maxf(0.0, charge_cd - delta)
	stun = maxf(0.0, stun - delta)
	if stun > 0.0:
		return
	if dash_t > 0.0:
		dash_t -= delta
		position += dash_dir * CHARGE_SPEED * delta
		if p.position.distance_to(position) < 30.0:
			_try_dash_hit(p)
		return
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			dash_dir = facing
			dash_t = CHARGE_TIME
			charge_cd = CHARGE_CD
		return
	if dist <= CHARGE_RANGE and charge_cd <= 0.0:
		windup = CHARGE_WINDUP
		return
	position += facing * speed * delta


func _try_dash_hit(p: Node2D) -> void:
	if p.has_method("take_hit"):
		if p.take_hit(CHARGE_DAMAGE, dash_dir.normalized() * 420.0):
			dash_t = 0.0
			stun = CHARGE_STUN


func _shooter_step(delta: float, dist: float) -> void:
	shoot_t = maxf(0.0, shoot_t - delta)
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			_fire_bullet()
			shoot_t = SHOOT_CD
		return
	if dist < SHOOT_MIN:
		position -= facing * speed * delta
	elif dist > SHOOT_MAX:
		position += facing * speed * delta
	else:
		# 在射程带里侧移，避免完全静止（也别一直贴着玩家）
		position += facing.rotated(PI * 0.5) * speed * 0.45 * delta
	if shoot_t <= 0.0 and dist <= SHOOT_MAX + 80.0:
		windup = SHOOT_WINDUP


func _fire_bullet() -> void:
	var game = _g if is_instance_valid(_g) else get_tree().get_first_node_in_group("game")
	_g = game
	if game == null:
		return
	var b = Node2D.new()
	b.set_script(load("res://scripts/bullet.gd"))
	b.process_mode = Node.PROCESS_MODE_PAUSABLE
	b.position = position + facing * (radius + 6.0)
	b.dir = facing
	b.add_to_group("bullet")
	game.add_child(b)


func _draw() -> void:
	var frac := clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)
	var body := body_color.lerp(Color(1.0, 0.86, 0.55), 1.0 - frac)
	if hit > 0.0:
		body = body.lerp(Color(1, 1, 1), clampf(hit / 0.18, 0.0, 1.0) * 0.85)
	var r := radius * (1.0 + hit * 0.6)

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
			pts.append(Vector2.from_angle(TAU * i / 6.0 + hpth) * r)
		draw_colored_polygon(pts, body)
		draw_arc(Vector2.ZERO, r * 1.12, 0.0, TAU, 24, Color(1, 0.85, 0.4, 0.9), 2.5, true)
		if windup > 0.0:
			var k: float = 1.0 - windup / CHARGE_WINDUP
			draw_line(Vector2.ZERO, facing * 520.0, Color(1.0, 0.25, 0.25, 0.25 + 0.55 * k), 2.0 + 3.0 * k)
		if stun > 0.0:
			draw_arc(Vector2.ZERO, r * 1.5, 0.0, TAU * (stun / CHARGE_STUN), 20, Color(0.5, 0.8, 1.0, 0.8), 2.0, true)
	elif kind == "shooter":
		var pts2 := PackedVector2Array()
		for i in 3:
			pts2.append(Vector2.from_angle(-PI * 0.5 + TAU * i / 3.0) * r)
		draw_colored_polygon(pts2, body)
		if windup > 0.0:
			var k2: float = 1.0 - windup / SHOOT_WINDUP
			draw_circle(facing * (r + 6.0), 3.0 + 4.0 * k2, Color(1.0, 0.9, 0.4, 0.9))
	else:
		draw_circle(Vector2.ZERO, r, body)
		if kind == "rock":
			draw_arc(Vector2.ZERO, r * 0.72, 0.0, TAU, 18, body.lightened(0.35), 2.5, true)

	if kind != "charger" and kind != "shooter":
		draw_circle(Vector2.from_angle(hpth) * radius * 0.45, radius * 0.3, Color(0.12, 0.04, 0.07, 0.55))
	if frac < 0.999:
		var w := radius * 2.2
		draw_rect(Rect2(-w * 0.5, -radius - 8.0, w, 3.0), Color(0.0, 0.0, 0.0, 0.55))
		draw_rect(Rect2(-w * 0.5, -radius - 8.0, w * frac, 3.0), Color(0.55, 1.0, 0.62))
