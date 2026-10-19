# 代码整理方案 v1（拆分 game.gd）

> 状态：**等你确认后执行**。代码未动。基线 `3df58bd`。

## 0. 现状

| 文件 | 行数 | 说明 |
| --- | --- | --- |
| `scripts/game.gd` | **4178** | 192 个函数、175 个常量/变量，什么都干 |
| `scripts/enemy.gd` | 198 | 敌人状态机（已拆，OK） |
| `scripts/ui_kit.gd` | 110 | 控件工厂（已拆，OK） |
| `scripts/player.gd` / `pickup.gd` / `chest.gd` / `bullet.gd` | 32–57 | 小节点（OK） |

`game.gd` 现在同时承担 9 件事：数据表、库存、电路板、合成装置、战斗结算、刷怪、武器生成与随机、宝箱、全部 UI（HUD / 构筑屏 / 拖拽 / 选卡 / 调试面板）、自测台。

**为什么必须拆**：改一个数值要在 4000 行里找；UI 与逻辑互相调用（`_refill` 里改 plan、`_install` 里写 UI 刷新）；想单测某个系统只能跑整局；每次改动都怕碰坏别的。

函数按域统计（按前缀归类）：

| 域 | 函数数 |
| --- | --- |
| UI（HUD / 构筑屏 / 拖拽 / 选卡 / 调试） | 40 |
| 电路板 + 模块（含方案） | 23 |
| 敌人 / 刷怪 / 掉落 | 17 |
| 合成装置 | 17 |
| 战斗结算 | 14 |
| 武器生成 / 宝箱 | 14 |
| 库存 | 10 |
| 主循环 / 工具 / 其它 | 57 |

## 1. 目标结构

```
scripts/
  game.gd            # 编排器：只留 ~350 行（节点、主循环、暂停、输入分发、接线）
  data/              # 纯数据表，零逻辑，改数值只来这里
    modules_db.gd
    weapons_db.gd
    enemies_db.gd
    buffs_db.gd
  systems/           # 纯逻辑，不碰 UI（可以 headless 单测）
    inventory.gd
    board.gd
    crafting.gd
    combat.gd
    enemies.gd
    weapons.gd
    chests.gd
    progress.gd
  ui/                # 只负责画和接事件
    hud.gd
    build_screen.gd
    drag_layer.gd
    pick_screen.gd
    debug_panel.gd
  debug/
    testbench.gd     # playtest / bot / cheat / CLI 解析 / [TEST] 日志
```

依赖方向**单向**：`data ← systems ← ui ← game`。`systems/` 里任何文件都不允许 `preload` 或引用 `ui/`；需要通知 UI 时由 `game.gd` 统一刷新（或发信号）。

## 2. 各文件职责边界

| 文件 | 负责 | 明确不负责 |
| --- | --- | --- |
| `data/modules_db.gd` | `MODULES` / `MOD_ORDER` / `CORE_ORDER` / `CRAFT_COST` / `CRAFT_TIME` / `CRAFT_UNLOCK` / 配方文案 | 任何计算 |
| `data/weapons_db.gd` | `WEAPONS` / `QUALITY_*` / `LAYOUTS` / `QM` / `ROLL_P` / `START_POOL` | 生成武器 |
| `data/enemies_db.gd` | `ENEMY_KINDS` / `WAVE_PLANS` / `PATTERNS` / 生成半径常量 | 刷怪逻辑 |
| `data/buffs_db.gd` | `BUFFS` 14 条 | 抽卡逻辑 |
| `systems/inventory.gd` | `inventory` / `crafted` 的增删查、`_inv_str` | 装到板子上 |
| `systems/board.gd` | `slots` / `plan`、拓扑（相邻 / 半径）、`_slot_out` 四步结算、`install` / `refill` / `place_at` / `uninstall` / `swap` / `auto_plan*` / 缺料 | 渲染格子 |
| `systems/crafting.gd` | 装置数组、`try_craft` / `recipe_state` / `cancel` / 自动开关 / 造价 | 进度条绘制 |
| `systems/combat.gd` | `_fire`、目标选择（含 prefer / 穿透 / 榴弹溅射 / 环形刃 / 镭射 ramp）、伤害结算、实测 DPS 滚动窗口、`_weapon_mods` 汇总 | 死亡奖励、掉落 |
| `systems/enemies.gd` | 刷怪预算 / 编队 / bulwark / 波次推进 / 接触伤害 / 回收 | 掉落与宝箱 |
| `systems/weapons.gd` | `_make_weapon` / 品质 / 布局随机 / 数值随机 / 分值 / 理论 DPS | 开火 |
| `systems/chests.gd` | 宝箱生成、掉落池、品质权重、背包满的替换判定 | 选卡界面 |
| `systems/progress.gd` | 等级 / 升级成本 / buff 层数 / 抽卡池 / 应用卡片效果 | 卡片绘制 |
| `ui/*` | 各屏的构建与刷新、鼠标/键盘事件、拖拽视觉 | 改游戏数值（只调 systems 的公开方法） |
| `debug/testbench.gd` | CLI 参数、作弊码、bot 决策、`[TEST]` 日志、`rolltest` / `boardtest` / `dragtest` | 游戏规则 |
| `game.gd` | `_ready` 装配、`_physics_process` 主循环顺序、暂停与界面栈、输入分发、`_die` / 重开 | 任何具体规则 |

## 3. 共享状态的传递方式（要提前定，否则拆完更乱）

- **不放 autoload**：单例难单测，也容易变成第二个 `game.gd`。
- `game.gd` 持有 `state` 与各 system 实例，构造时把需要的依赖注入：
  `var board := Board.new(state, inv)`、`var combat := Combat.new(state, board, weapons)`。
- `state.gd`（纯数据）：`elapsed / wave / hp / max_hp / level / kills / rng / seed / backpack_cap / autoplan / cheat 开关`。
- 现在到处用的「`weapon` 是当前选中武器的别名」保留在 `game.gd`，system 内部一律显式收 `w: Dictionary` 参数（已经踩过 `sel = i` 不生效的坑）。
- UI 刷新：`systems` 改完数据后调 `game._refresh_all()`，不允许 system 直接改 Label。

## 4. 迁移顺序（每步都能跑、都能提交）

| 步 | 内容 | 预期行数 | 风险 |
| --- | --- | --- | --- |
| R1 | 抽 `data/*.gd` 四张表 | game.gd → ~3800 | 极低（只搬常量） |
| R2 | 抽 `inventory` + `board`（含 plan / 拖拽用的拓扑） | → ~3100 | 中（`weapon` 别名要显式传参） |
| R3 | 抽 `crafting`（装置 + 配方） | → ~2800 | 中 |
| R4 | 抽 `combat` | → ~2400 | 中高（结算顺序不能变） |
| R5 | 抽 `enemies` + `chests` | → ~2000 | 中 |
| R6 | 抽 `ui/`（hud → build → drag → pick → debug） | → ~900 | 高（回调多），**单独一步只做 UI** |
| R7 | 抽 `debug/testbench`，`game.gd` 收尾 | → ~350 | 低 |

**建议先只做 R1 + R2**：收益最大（数值集中 + 构筑逻辑可控），风险最低，做完就能看出还值不值得继续。

每步的固定验收（写进 `docs/testlog.md`）：

```powershell
# 1) 先解析预检（不吞 stderr）
& .\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --check-only --script res://scripts/game.gd 2>&1 | Select-String "Parse Error"
# 2) 数值回归：期望 out=[40.5, 45.5, 0.0, 1.0, 5.0, 6.0] power=100.0
& .\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . -- boardtest 2>$null
# 3) 行为回归：应跑到 t=300 不死，[TEST] end 的 dps/need 与上一步相差 < 10%
& .\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . -- playtest bot pt=300 2>$null
# 4) 视觉回归：构筑屏一张
& .\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 -- "shot=x.png" "shotat=30" shotbuild shotbot ff=25 2>$null
```

## 5. 已知的坑（拆的时候会再遇到）

1. `--headless --check-only` 下 `class_name` 不可见（要靠编辑器导入缓存）→ 统一用 `const X := preload("res://scripts/..."）`。
2. 带默认值 `null` 的参数**不能**标类型（`w: Dictionary = null` 会 Parse Error）→ 写 `w = null`。
3. `Dictionary` 取字段不能用 `:=` 推断类型（`var n := w.slots.size()` 报 cannot infer）→ 写 `var n: int = ...`。
4. PowerShell 单引号里的 `` `r`n `` 是字面量，批量替换会写坏文件 → 改动一律用 edit 工具。
5. 解析失败时 Godot 只往 stderr 打一行然后"正常退出"，`2>$null` 会把它藏掉，表现为"卡住"。

## 6. 收益与代价

**收益**：改数值只开 `data/`；单测某个系统不用跑整局；`systems/` 可复用（以后做元游戏 / 存档）；文件小到能一眼看完。

**代价**：一次性重构约 6 个提交、每步都要跑回归；跨系统调用会多一层参数传递（`w`、`state`），短期代码略啰嗦。

## 7. 待你拍板

1. **先做多少**：只做 R1+R2（推荐，半天）／一路做到 R7（两三天，中途不能加新功能）。
2. **要不要 Autoload**：我推荐不用，全部依赖注入（可单测）；如果你更想要 `Game.state` 这种全局快捷方式，我也可以留一个只读 facade。
3. **命名风格**：`snake_case` 文件名 + `PascalCase` 类名（推荐，贴 Godot 社区习惯）；还是沿用现在的全小写。
4. 拆的过程中发现的小 bug（比如 UI 和逻辑耦合导致的重复刷新）**顺手修还是记 todo 之后再修**？我倾向顺手修，但会单独提交。
