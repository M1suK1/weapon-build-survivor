# plan-v8 · 缺料补装 / 伤害账本 / 镭射锁定 / 通用配方

> 状态：**待实施**
> 依据：v7 实测反馈（2026-10-20，用户原文 5 条 + 「#写plan-v8然后push」）
> 基线：`weapon-build-survivor` @ `ad0801c`（v7 完成）。文内行号以该提交为准。
> 约束：本轮先只交计划并 push；实施时**不新增控制台命令**（v4 §1.2 的 14 条冻结），验收只跑 `--check-only` + 一次无头冒烟，不跑 playtest / 不出截图。

---

## 0. 需求对照表

| # | 用户原话（摘要） | 我理解的问题 | 本计划落点 |
|---|---|---|---|
| 1 | 缺料后没有相应模块会停止自动补充；装置缺料会清空选定配方。要求：缺料后只要造出符合的模块就放进武器；装置缺料停工、库存够了立刻复工 | ① 合成产物只进库存，没有回填「方案里等料」的格子 ② 装置没记住玩家选的配方，缺料即丢 | §2.2 缺料补装、§2.4 装置 `want` 重试 |
| 2 | 检查扇叶 buff，目前测试中没有生效 | 扇叶是「阈值型」整数族（白 5 / 蓝 4 / 紫 5 / 金 3 级才 +1 片），1–2 级完全不涨片，且卡面没把阈值说清 | §2.5 阈值降到 3/3/2/2 + 卡面/悬浮写「当前 N 片 · 还差几级」 |
| 3 | 增加显示武器上次造成的单次伤害；武器似乎没按预想实现（每个模块定期提供伤害，武器把伤害打出去），表现为激光环伤害极低 | **真 bug**：蓄能 `acc` 被钉死在 1.0，慢速武器每炮最多只能吃 1 个单位产出，40 秒一发的激光环丢掉 97.5% 的模块产出 | §2.1 蓄能账本（bank）、§2.3 激光环重标定、§2.7 上次伤害 |
| 4 | 镭射没有等当前目标死亡后再转移目标，同时需要增加射程 | `prefer: highest_hp` 每发重排，出现更高血敌人就换靶、`ramp` 归零；射程只有 380 | §2.4 锁定（`lock_id`）+ 射程 620 |
| 5 | 所有配方不要设为需要特定低阶才能合成，改成通用低阶 | `recipe_state` / `try_craft` 只吃 `prev` 那一个具体 id | §2.6 按阶吃料（`_inv_tier` / `_take_tier`） |
| 6 | #写plan-v8然后push | 交计划 + 把 42 个提交推上去 | §3 实施顺序 + §6 push 说明 |

---

## 1. 根因（都已读代码确认，不是猜）

### 1.1 激光环伤害极低 = 蓄能账本被钉死在 1.0（P0）

```gdscript
# scripts/game.gd:831（_process 里逐格推进）
m["acc"] = minf(1.0, float(m.get("acc", 1.0)) + delta / maxf(oiv, 0.05))

# scripts/game.gd:2716-2721（_slot_out）
if use_acc:
    out[i] = float(out[i]) * clampf(float(m.get("acc", 1.0)), 0.0, 1.0)

# scripts/game.gd:1398-1401（_fire 开火后清零）
for m in (w["slots"] as Array):
    if m != null:
        m["acc"] = 0.0
```

也就是说：**模块攒满 1 个单位就封顶，无论武器多久开一炮**。模块的 `out_iv` 是「多久产 1 个单位」，武器的 `interval` 才是「多久结算一次」，两者没解耦。

推演（3 个锋锐刃：`rate 2.8` / `out_iv 1.4s`，一块基础）：

| 武器 | 间隔 | 每炮吃到的模块产出 | 每炮伤害（×mul） | 稳态 DPS |
|---|---|---|---|---|
| 手枪 | 0.70s | 每格 `2.8 × 0.5`（acc 只攒到 0.5） | (1 + 4.2) × 1.00 = 5.2 | 7.4 |
| 激光环 | 40.0s | 每格 `2.8 × 1.0`（攒满就封顶，剩下 39 秒白攒） | (2 + 8.4) × 4.00 = 41.6 | **1.04** |
| 激光环（修好后） | 6.0s | 每格 `2.8 × 6/1.4 = 12` | (6 + 36) × mul | 见 §2.3 |

差距不是平衡问题，是**模型没实现**：用户说的「每个模块定期提供伤害、武器把伤害打出去」正是要每个模块把 `out_iv` 期间产出的东西**全部**攒着，等武器下一炮打出去。

### 1.2 缺料后不会补装

- `_craft_tick()`（`scripts/game.gd:3756-3760`）产物只走 `_add_inv(k, 1)`，**没有任何「回填方案」的动作**
- `_refill()`（`2888`）只在两种时机被调用：烧空（`_burn_slots` 里 `auto_fill` 为真）、玩家手动点格子
- 所以方案里「等一个锋锐刃」的格子会一直空着，直到手动装 —— 与用户预期相反

### 1.3 装置缺料就丢配方

- `_craft_tick()`（`3765-3768`）做完后：`try_craft(k)` 失败 → 退成 `try_craft("")`；两个都失败时，装置 dict 里没有「玩家选过什么」的记录，`kind` 已在 `3749` 清空
- 缺料期间装置每帧什么都不做，也不会在库存变化后重试
- `_new_device()`（`3645`）字段：`kind / left / total / auto / paid / lv`，没有 `want`

### 1.4 扇叶 buff「没生效」

- `_blade_petal_bonus()`（`1604`）→ `_buff_int("petal")`（`4002`），`_buff_int` 要求 `int(b["lv"]) >= thr`
- 阈值（`scripts/data/buffs_db.gd` 的 `petal` 族）：白 **5** / 蓝 **4** / 紫 **5** / 金 **3**
- 结论：**不是代码 bug**，是阈值定得太高 —— 玩家拿一两条 Lv1–2 的扇叶，片数一点不变；卡面只写「每 5 级 +1」，不直观
- 顺带确认：`_blade_petals()`（`1599`）、判定（`1623`）、渲染（`1684`）都真的走这个函数，上限 7 没错

### 1.5 镭射换靶

- `_targets_for()`（`1510`）对 `prefer: highest_hp` **每发重新排序**；`_fire()`（`1380-1386`）发现 `ramp_id` 变了就把 `ramp` 归零
- 结果：场上一出现血量更高的新敌人，镭射立刻跳靶、层数清零，永远叠不起来
- 射程 380（`scripts/data/weapons_db.gd:41`），比狙击 640 还近，不符合「持续光束」的定位

### 1.6 配方绑死具体低阶件

- `recipe_state()`（`3781-3795`）：`have := _inv(prev)`，只算 `prev` 这一种 id
- `try_craft()`（`3820-3831`）：只从 `_inv(prev)` 里扣 `need` 个
- 用户要的是「T3 吃任意 2 阶、T4 吃任意 3 阶」；`_take_tier()`（`2809`）其实还在（按阶扣料、优先库存），只是合成没用它

---

## 2. 方案

### 2.1 蓄能账本：模块产出攒到「够一炮」为止（P0）

**规则**：每个模块在 `out_iv` 秒里产 1 个单位；武器多久开火，就把这期间攒的**全部**打出去；攒的上限是 `iv / out_iv`（也就是「这一炮周期内最多能产多少」）。

```gdscript
# 上限按武器算，不再写死 1.0
func _bank_of(w: Dictionary, out_iv: float) -> float:
    var iv := _iv_of(w)
    return clampf(iv / maxf(out_iv, 0.05), 1.0, BANK_MAX)   # BANK_MAX = 12

# _process 推进
var bank := _bank_of(w, oiv)
m["acc"] = minf(bank, float(m.get("acc", 1.0)) + delta / maxf(oiv, 0.05))

# _slot_out：夹到 bank 而不是 1
out[i] *= clampf(float(m.get("acc", 1.0)), 0.0, _bank_of(ww, float(MODULES[id]["out_iv"])))
```

- `BANK_MAX := 12.0`：防止「间隔 40 秒、out_iv 0.6」的极端组合把一炮堆成核弹
- 开火后仍然 `acc = 0`
- 板面蓄能条改成显示 `acc / bank`（依旧是 0–100%），tooltip 加「这一格能攒 N 发」
- **稳态公式不变**（plan-v6 §7 模型 S 本来就是这么写的）：`DPS = Σ rate / max(iv, out_iv)`；本计划只是让实际结算和公式一致

### 2.2 缺料补装：产物一进库存就回填「方案里等着的格子」

新增：

```gdscript
## 库存里多了一个 mid，去把「方案里正好等它」的空格补上（plan-v8 §2.2）
## 只补 saved plan 匹配的空格；auto_fill 只管「烧空之后」那一档，不在这里
func _fill_wanted(mid: String) -> int
```

- 遍历 `weapons` → `slots[i] == null and _plan_saved_at(w, i) == mid` → 直接装、扣 1、`_toast("自动补上：%s → %d 号格")`
- 返回补了几格（0 就静默）
- 调用点（四处）：
  1. `_craft_tick()` 产物 `_add_inv(k, 1)` 之后
  2. `add_module()`（`2984`，地上拾取）
  3. `_abandon_chest()`（宝箱换的模块）
  4. `device_cancel()`（退款后，按退回的 id 逐个试）
- 只在**当前选中的武器**上补？不 —— 遍历所有武器（方案按武器存，补错武器才叫 bug）
- `auto_fill` 语义保持：只管烧空自动补料（D1 见 §5）

### 2.3 激光环重标定（配合 §2.1）

蓄能账本修好后，激光环 40 秒一发会把 bank 撑到 40（> `BANK_MAX` 12），仍然丢产出，所以间隔必须缩短：

| 项 | 旧 | 新 | 理由 |
|---|---|---|---|
| `interval` | 40.0 | **6.0** | bank = 6/1.0 = 6 ≤ 12，不丢产出 |
| `base` | 2.0 | **6.0** | 全屏武器的基础伤害要撑起节奏 |
| `mul` | 4.00 | **0.55** | 全屏 20 目标有 `1 + 0.1×19 = 2.9` 的多目标放大，mul 必须压回来 |
| `range` | 1600 | 1600 | 不变（全屏） |
| `targets` | -1 | -1 | 不变 |

预估（3 个锋锐刃 + 1 基础，20 个目标）：

```
单发 = (base + Σ rate × bank) × mul = (6 + 3×2.8×6) × 0.55 = 31.0
DPS  = 单发 / 6 × 2.9 = 15.0
对比手枪（2 目标）≈ 7.4，狙击（1 目标）≈ 4.5
```

- `mul` 还参与 §7 分值公式（`score = base×mul/interval × …`），改完必须跑 **`rolltest`**（静态自检，允许）确认同类型内 0 倒挂；如果 band 漂了，只调 `base` 与 `interval`、把 `mul` 留回 1.0 附近（D2）
- 激光充能 buff（`laser_iv`）按新间隔重看一遍：`-1.0/-1.4/-1.8/-2.4 秒每级`、cap 24 秒在新间隔下太猛，改成 `-0.25/-0.35/-0.5/-0.7 秒每级`、cap `4.8 秒`、下限 `1.2 秒`

### 2.4 镭射：锁死当前目标 + 射程 620

```gdscript
# weapon dict 新增
"lock_id": 0

# _fire 里选靶处（替换 _targets_for 的调用结果）
var locked: Node2D = null
if int(w.get("lock_id", 0)) != 0:
    var cand = instance_from_id(int(w["lock_id"]))
    if is_instance_valid(cand) and float(cand.hp) > 0.0 and cand.position.distance_to(player.position) <= rng_d:
        locked = cand
if locked == null:
    var ts := _targets_for(w, rng_d, tg)
    locked = ts[0] if not ts.is_empty() else null
    w["lock_id"] = int(locked.get_instance_id()) if locked != null else 0
```

- 只对 `beam` 生效（其它武器保持每发重选，尤其狙击的 `prefer` 是为了打远处精英）
- `ramp` 归零条件从「`ramp_id` 变了」改成「`lock_id` 变了」——锁死期间层数一路叠到 `ramp_max`
- 射程 `380 → 620`（`scripts/data/weapons_db.gd:41`），与「持续光束」定位一致；光束渲染自动跟 `rng_d`，不用改
- 目标死亡 / 出射程 / 被移除 → 下一发自然重选（`is_instance_valid` + `hp > 0` 两个条件）

### 2.5 扇叶：阈值降下来 + 把「还差几级」写出来

| 品质 | 旧阈值 | 新阈值 |
|---|---|---|
| 白 | 5 | **3** |
| 蓝 | 4 | **3** |
| 紫 | 5 | **2** |
| 金 | 3 | **2** |

- `_blade_petals()` 上限 7 不变（4 条变体最多 +4 片）
- 卡面（`_paint_offer`）与悬浮（`_buff_tip_data`）：整数族加一行 `当前 %d 片 · 下一片 Lv%d`
- 构筑屏 Buff 页：整数族第二行小字前缀改 `Lv%d 起 → 当前 %d`
- 板面槽位 tooltip（`_slot_tip_data`）里环刃那格写 `扇叶 5/7`

### 2.6 配方改成「通用低阶」

- 新增 `_inv_tier(t: int) -> int`：扫库存，按 `MODULES[id]["tier"]` 求和
- `recipe_state()`：`have := _inv_tier(t - 1)`（T2 就是 tier 1 = base），文案改 `需 %d 个第 %d 阶模块（库存 %d）`
- `try_craft()`：用 `_take_tier(t - 1, need, false)` 扣料（**只扣库存，绝不动板面**），`paid` 记录实际扣掉的 id 数组；数量不足直接失败（`recipe_state` 已经先挡了）
- `prev` 字段**保留**，但只用于两件事：科技树前沿（`_recipe_frontier`）与 tooltip 的「本族上一件」提示
- 解锁语义不变：前置没解锁 → 这张配方卡不出（`_recipe_frontier` 逻辑不动）
- UI：配方页行文本从 `2×锋锐刃` 改成 `2×第2阶`；tooltip 的消耗行同步

### 2.7 「上次伤害」显示（debug 用）

- weapon dict 新增 `last_dmg` / `last_at` / `last_hits`，`_fire()` 结算完写：`w["last_dmg"] = dealt`、`w["last_at"] = elapsed`、`w["last_hits"] = targets.size()`
- 左侧武器栏（`_refresh_weapon_panel`，`4311`）行尾加 `上次 42.3`
- 构筑屏武器行（`_refresh_build`）加 `上次 42.3（3 目标）`
- 超过 5 秒没开火显示 `上次 --`（`elapsed - last_at > 5.0`）
- F3 面板（`_pt_log` 那套）加一列 `last=`
- 开关：默认开，`noautoplan` 之类的 CLI 不动它（纯显示，不新增命令）

---

## 3. 实施顺序（每步一次提交）

| 步骤 | 提交前缀 | 内容 | 依赖 |
|---|---|---|---|
| P1 | `feat(fill):` | §2.2 `_fill_wanted` + 四个调用点 | — |
| P2 | `feat(device):` | §2.4 装置 `want` + 空闲重试（缺料不停工、库存够立刻复工） | — |
| P3 | `refactor(craft):` | §2.6 通用低阶（`_inv_tier` / `_take_tier` / 文案） | — |
| P4 | `fix(buff):` | §2.5 扇叶阈值 + 卡面/悬浮/Buff 页/槽位 tooltip 的「当前 N 片」 | — |
| P5 | `feat(dmg):` | §2.1 `_bank_of` + `acc` 上限 + 蓄能条显示 | — |
| P6 | `feat(weapon):` | §2.3 激光环重标定 + `laser_iv` 重标 + §2.4 镭射锁定/射程 + §2.7 上次伤害 | P5 |
| P7 | `docs:` | reference / README / testlog / 本文件状态与提交号 | 全部 |
| P8 | `push` | `git push -u origin superpowers/v5-modules-buffs`（见 §6） | 全部 |

每步验收：`cmd /c ".\.tools\godot\Godot_v4.7.2-stable_win64.exe --headless --path . --check-only --script res://scripts/game.gd & echo EXIT=%ERRORLEVEL%"` → `EXIT=0`；P5/P6 额外跑一次 `--headless --quit-after 3` 看 `DATA OK  buff=100  modules=24  INV OK`；P6 跑 `rolltest` 确认分值 0 倒挂。

---

## 4. 手测清单（交人工）

1. **缺料补装**：武器方案里留一格「锋锐刃」→ 手动合成一个锋锐刃 → 产物应当**直接进那一格**，不是躺在库存里
2. **装置重试**：选定一个缺料的配方 → 装置显示停工但不丢配方 → 凑够料后**自动开工**（不用再点一次）
3. **扇叶**：拿「扇叶·白」到 Lv3，板面环刃应当从 3 片变 4 片；卡面能看到「当前 3 片 · 下一片 Lv3」
4. **蓄能**：给手枪装 3 个锋锐刃，秒伤应明显高于空板；换激光环打同类怪，单发伤害应当是两位数以上（旧版个位数）
5. **镭射**：对着一个目标持续输出，旁边出现更高血的新怪时**不换靶**；目标死了才换；射程 620 能打到更远
6. **通用配方**：T3 配方（例如过载核）应当吃掉**任意** 2 阶模块 2 个（加法、贯穿弹都行），而不是只认锋锐刃
7. **上次伤害**：左侧武器栏/构筑屏应当显示每把枪上一炮打了多少

---

## 5. 风险与待拍板

**R1（蓄能账本会让所有武器变强）**：`bank` 修好后，慢枪终于吃到全部模块产出，整体 DPS 会上升一截（尤其狙击 2.5s、榴弹 1.6s）。这是**修 bug** 不是加强；如果整体过强，先调敌人血量（`HP_BASE`）而不是再压模块。

**R2（激光环重标定牵动分值系统）**：`mul` 从 4.0 掉到 0.55，`score` 会跟着变。必须跑 `rolltest`；band 漂了就按 D2 退回「只改 base/interval」。

**R3（通用低阶会加速科技树）**：以前 T3 必须攒「同族 T2」，现在任意 2 阶都行，合成速度明显变快。观察点：10 波前能不能做出第一件 T4；太快就抬 `CRAFT_COST`（T3 2→3、T4 2→3）。

**R4（镭射锁死可能变成站桩）**：锁定后不会自动转火，怪堆里可能一直打同一个残血精英。如果实测手感差，加一条「锁定目标血量低于 15% 时允许换靶」。

**待拍板**：

- **D1**：缺料补装是**只补 saved plan 的空格**（推荐，方案是玩家的明确意图），还是也受 `auto_fill` 开关限制？——推荐前者。
- **D2**：激光环新数值 `interval 6 / base 6 / mul 0.55` 是否接受？如果 `rolltest` 倒挂，允许把 `mul` 拉回 `1.0` 并同步重算 `P0`。
- **D3**：扇叶阈值 `3/3/2/2` 是否够快？还想更快就改 `2/2/1/1`（金 Lv1 就 +1 片）。
- **D4**：镭射射程 `620` 是否合适（当前狙击 640）？也可以给 700 做「最远」。

---

## 6. push 说明

- 分支：`superpowers/v5-modules-buffs`（v4 基线 `cfc07e1` 之后共 42 个提交）
- 目标：`git push -u origin superpowers/v5-modules-buffs`
- 注意：`main` 当前也领先 `origin/main` 11 个提交（v4 那批没推过），本计划只推功能分支，不动 `main`；需要合并时另开 PR 或本地 `git checkout main && git merge --ff-only superpowers/v5-modules-buffs`
- 若 push 因凭证失败（本机 `credential.helper=manager` 且没有缓存 token，会报 `SEC_E_NO_CREDENTIALS`），需要先在本机 `git push` 一次完成登录，或提供 PAT。
