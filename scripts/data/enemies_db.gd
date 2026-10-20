extends RefCounted
## 敌人与刷怪数据表（纯数据，零逻辑）。
##
## 谁在用：`scripts/game.gd` 的刷怪 / 波次 / 编队 / 精英 / bulwark / 掉落，
## 以及 `scripts/enemy.gd`（只读 `hp_mult` / `speed` / `radius` / `color` 这类字段）。
## 规则文档：`docs/reference.md` §2。

const WAVE_SEC := 40.0

## 敌人血量 = HP_BASE × HP_GROWTH^(wave−1)，12 波后再乘一层加速项（"武器成型后要更快变难"）。
const HP_BASE := 1.80
const HP_GROWTH := 1.118
const HP_LATE_WAVE := 12
const HP_LATE_GROWTH := 1.045

## 刷怪速率 = SPAWN_BASE × SPAWN_GROWTH^wave × 编成系数（指数，密度是爽感的主要来源）。
## 密度上限 = 基础速率 × SPAWN_CAP_MULT，避免速度快的波次把屏幕直接刷成墙。
const SPAWN_BASE := 1.20
const SPAWN_GROWTH := 1.190
const SPAWN_CAP_MULT := 1.8
const MAX_ENEMIES := 400

## 生成半径必须落在**镜头视野之外**：zoom 0.62 时半个屏幕是 1032×580，
## 对角约 1184，所以 >1200 才能保证任何角度都在屏幕外，让敌人「走」进来而不是凭空出现
const SPAWN_R_MIN := 1220.0
const SPAWN_R_MAX := 1400.0

## 接触伤害：每只每秒多少，最多同时 CROWD_CAP 只结算
const CONTACT_DPS := 2.2
const CROWD_CAP := 6

## 掉落：每杀多少个基础模块（再按该敌人的血量倍率加权，见 `_kill()`）
const DROP_CHANCE := 0.30
## 宝箱保底：这么多秒内场上没宝箱就补一个
const CHEST_GUARANTEE := 90.0

## 精英：wave 4 首只，之后每 6 波保证一只；同屏上限 3
const ELITE_FIRST_WAVE := 4
const ELITE_EVERY := 6
const ELITE_MAX := 3
const SHOOTER_MAX := 5

## 敌人种类：hp_mult = (100 / 速度)^1.5 —— 速度越快血越少。
## 以后加新怪直接套这个公式，不用一张张手调。
const ENEMY_KINDS := {
	"flood": {"speed": 100.0, "hp_mult": 1.00, "radius": 13.0, "color": Color(0.92, 0.30, 0.34)},
	"runner": {"speed": 205.0, "hp_mult": 0.45, "radius": 9.0, "color": Color(1.00, 0.70, 0.26)},
	"rock": {"speed": 52.0, "hp_mult": 2.67, "radius": 19.0, "color": Color(0.56, 0.46, 0.86)},
	"shooter": {"speed": 70.0, "hp_mult": 1.71, "radius": 12.0, "color": Color(0.62, 0.86, 1.00)},
	# 精英血量是手设的 9.0（不套公式：它靠冲刺而非堆血量制造威胁）
	"charger": {"speed": 78.0, "hp_mult": 9.00, "radius": 20.0, "color": Color(1.00, 0.36, 0.42)},
	# bulwark：慢速高血量「墙」，专在玩家前方生成逼走位（docs/plan-v3.md §3）
	"bulwark": {"speed": 46.0, "hp_mult": 4.20, "radius": 22.0, "color": Color(0.44, 0.72, 0.62)},
}

## 波次编成：coeff = 总血量预算系数（1.0 = 涌潮基准），kinds = 相对权重。
## 每 5 波循环一次，所以玩家能从「这波怪变多了/变硬了」读出编成变化。
const WAVE_PLANS := [
	{"name": "涌潮", "coeff": 1.00, "kinds": {"flood": 1.0}},
	{"name": "混编", "coeff": 0.80, "kinds": {"flood": 5.0, "runner": 3.0, "shooter": 2.0}},
	{"name": "疾行", "coeff": 1.40, "kinds": {"runner": 1.0}},
	{"name": "磐石", "coeff": 0.60, "kinds": {"rock": 1.0}},
	{"name": "混编", "coeff": 0.80, "kinds": {"flood": 4.0, "rock": 2.0, "runner": 2.0, "shooter": 1.0}},
]

## 生成编队：单点 / 一团 / 弧线 / 一圈。同样的人数，排布不同，压迫感完全不同。
## w = 权重，min/max = 一次出几只，wave = 从第几波开始进入池子。
const PATTERNS := [
	{"id": "single", "w": 46, "min": 1, "max": 1, "wave": 1},
	{"id": "cluster", "w": 28, "min": 4, "max": 7, "wave": 2},
	{"id": "arc", "w": 18, "min": 6, "max": 9, "wave": 4},
	{"id": "ring", "w": 16, "min": 10, "max": 14, "wave": 6},
]
