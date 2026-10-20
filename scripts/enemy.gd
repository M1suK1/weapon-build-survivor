extends Node2D
## 敌人：直线追击玩家。hp / max_hp / speed / kind / radius / body_color 由 game.gd 生成后赋值。
##
## 行为按 kind 分：
##   flood  —— 直冲
##   runner —— 直冲（更快更脆，画成尖头三角）
##   rock   —— 直冲（慢而硬）
##   shooter—— 保持 240~320 距离放风筝，每 2.6s 抬手 0.35s 后打一发子弹
##   charger—— 距玩家 ≤420 时蓄力 0.9s（画红线）→ 780px/s 冲刺 0.35s → 硬直 1.1s

const Perf := preload("res://scripts/systems/perf.gd")

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
const CHARGE_PREP := 0.15
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
var age := 0.0
## 出生预兆：>0 时冻结不动、只画半透明轮廓 + 收缩圆环（给精英冲刺的预备帧用）
var telegraph := 0.0
## 变种标记（docs/plan-v4.md §3.2）："" = 普通怪，"brute" = 重装（血量 ×8、单发上限 20%）
var variant := ""
## 单次命中上限：>0 时任何一次命中最多打掉这么多血（重装「至少 5 发」的硬保证）
var hit_cap := 0.0
## 环绕刃的每敌命中冷却（plan-v5 §7.2：0.25 秒内不被任何扇叶重复打）
var blade_cd := 0.0

## 通用计时
var shoot_t := 0.0
var windup := 0.0
var charge_t := 0.0
var charge_cd := 0.0
var stun := 0.0
var dash_dir := Vector2.RIGHT
var dash_t := 0.0
## 冲刺锁定（docs/plan-v4.md §6）：蓄力期间 dash_dir 跟随玩家，蓄力结束瞬间写死
var dash_dir_locked := Vector2.RIGHT
var locked := false
## 锁定到真正起步之间的预备帧（秒），留出侧移窗口
var prep := 0.0
var dash_tried := false
## 屏外降频分桶（0..3）
var _throttle_i := 0


func _ready() -> void:
	hpth = randf() * TAU
	shoot_t = randf() * SHOOT_CD
	charge_cd = randf_range(1.0, 3.0)
	orbit_dir = 1.0 if randf() < 0.5 else -1.0
	# 每只怪站的距离不同，几十只才会围成一圈「有厚度」的包围圈，而不是挤成一个点
	hold_bias = randf_range(0.0, 52.0)
	# 屏外降频分桶（docs/plan-v4.md §4.2 B）：按桶错开，避免同一帧全更新。
	# 用已有的 hpth 派生，不额外消耗 rng（同 seed 的刷怪/掉落序列保持可复现）
	_throttle_i = int(hpth / TAU * 4.0) % 4


func _physics_process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_step(delta)
	Perf.ai_usec += Time.get_ticks_usec() - t0


func _step(delta: float) -> void:
	hit = maxf(0.0, hit - delta)
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var to_p: Vector2 = p.position - position
	var dist := to_p.length()
	# 远处（>1600）每 4 个物理帧才走一步：它们离屏、追上来之前不影响观感
	if dist > 1600.0 and (Engine.get_physics_frames() + _throttle_i) % 4 != 0:
		return
	if dist > 1.0:
		facing = to_p / dist

	if kind == "charger":
		_charger_step(delta, p, dist)
	elif kind == "shooter":
		_shooter_step(delta, dist)
	else:
		position += facing * speed * delta


func _charger_step(delta: float, p: Node2D, dist: float) -> void:
	charge_cd = maxf(0.0, charge_cd - delta)
	stun = maxf(0.0, stun - delta)
	if stun > 0.0:
		return
	if dash_t > 0.0:
		if prep > 0.0:
			# 预备帧：原地不动，给玩家 0.15s 侧移（锁定到起步之间的公平窗口）
			prep = maxf(0.0, prep - delta)
			return
		var from: Vector2 = position
		dash_t -= delta
		position += dash_dir_locked * CHARGE_SPEED * delta
		if not dash_tried and _seg_hit(p.position, from, position):
			dash_tried = true
			_try_dash_hit(p)
		if dash_t <= 0.0:
			locked = false
		return
	if windup > 0.0:
		windup -= delta
		# 蓄力期间红线跟着玩家（警告），结束瞬间锁死方向
		dash_dir = facing
		if windup <= 0.0:
			dash_dir_locked = facing
			locked = true
			prep = CHARGE_PREP
			dash_t = CHARGE_TIME + CHARGE_PREP
			charge_cd = CHARGE_CD
			dash_tried = false
			_notify_dash_start()
		return
	if dist <= CHARGE_RANGE and charge_cd <= 0.0:
		windup = CHARGE_WINDUP
		locked = false
		return
	position += facing * speed * delta


## 线段命中判定：冲刺一帧可能跨过玩家，按「起点→终点」线段算距离
func _seg_hit(target: Vector2, from: Vector2, to: Vector2) -> bool:
	var ab: Vector2 = to - from
	var t := 0.0
	if ab.length_squared() > 0.0001:
		t = clampf((target - from).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return target.distance_to(from + ab * t) < radius + 12.0


func _try_dash_hit(p: Node2D) -> void:
	if p.has_method("take_hit"):
		if p.take_hit(CHARGE_DAMAGE, dash_dir_locked.normalized() * 420.0):
			dash_t = 0.0
			locked = false
			stun = CHARGE_STUN
			_notify_dash_hit()


func _game_node():
	var game = _g if is_instance_valid(_g) else get_tree().get_first_node_in_group("game")
	_g = game
	return game


func _notify_dash_start() -> void:
	var g = _game_node()
	if g != null and g.has_method("_on_dash_start"):
		g._on_dash_start()


func _notify_dash_hit() -> void:
	var g = _game_node()
	if g != null and g.has_method("_on_dash_hit"):
		g._on_dash_hit()


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

