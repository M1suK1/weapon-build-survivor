extends RefCounted
## 升级四选一的 buff 池（纯数据，零逻辑）。
##
## 谁在用：`scripts/game.gd` 的 `_roll_offer()`（抽卡）、`_apply_card()`（生效）、
## `_weapon_mods()` / `_new_module()` / `device_cost()` / `try_craft()`（读层数）。
## 规则文档：`docs/reference.md` §4。
##
## 字段：cat = atk 攻击 / eco 经济 / sur 生存（每级三类各抽 1 张）
##       rar = white / blue / gold（稀有度只影响权重，不影响强度上限）
##       max = 层数上限；layers 存在 `buff_lv[id]`
const BUFFS := {
	"pierce": {"name": "穿透", "cat": "atk", "rar": "blue", "max": 3, "desc": "主目标身后 120px 内最近敌人吃 60%"},
	"elite": {"name": "破甲", "cat": "atk", "rar": "blue", "max": 4, "desc": "对冲刺精英与磐石 +25% 伤害"},
	"rate": {"name": "攻速", "cat": "atk", "rar": "white", "max": 8, "desc": "开火间隔 ×0.92"},
	"power": {"name": "强化", "cat": "atk", "rar": "white", "max": 6, "desc": "伤害倍率 ×1.10"},
	"range": {"name": "射程", "cat": "atk", "rar": "white", "max": 4, "desc": "射程 +60"},
	"target": {"name": "多目标", "cat": "atk", "rar": "gold", "max": 3, "desc": "每把武器目标数 +1"},
	"drop": {"name": "掉落", "cat": "eco", "rar": "white", "max": 6, "desc": "敌人掉落率 +0.04"},
	"uses": {"name": "耐久", "cat": "eco", "rar": "white", "max": 5, "desc": "新模块寿命 ×1.08"},
	"craft": {"name": "工艺", "cat": "eco", "rar": "blue", "max": 5, "desc": "合成时间 ×0.90"},
	"device": {"name": "降本", "cat": "eco", "rar": "blue", "max": 4, "desc": "装置造价 ×0.92"},
	"hp": {"name": "体魄", "cat": "sur", "rar": "white", "max": 6, "desc": "最大 HP +15，立即回血"},
	"contact": {"name": "护甲", "cat": "sur", "rar": "white", "max": 5, "desc": "接触伤害 ×0.92"},
	"regen": {"name": "恢复", "cat": "sur", "rar": "blue", "max": 4, "desc": "脱战回血 +0.5/s"},
	"iframe": {"name": "闪避", "cat": "sur", "rar": "gold", "max": 3, "desc": "受击无敌帧 +0.10s"},
}
