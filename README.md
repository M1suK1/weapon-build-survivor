# Weapon Build Survivor

类《吸血鬼幸存者》的增量游戏：战斗靠走位与自动脉冲开火，成长靠**把模块插进武器电路板**。

## 现在能玩到什么

- 自动脉冲开火：射程内**所有**敌人一起吃一次伤害，无目标不开火、不消耗模块次数
- 模块即弹药：每次开火抽干插槽里每个模块 1 次使用次数，用完消失
- 武器基础伤害：不吃模块次数，模块烧光时 DPS 不归零，仍有底伤害
- 受击补偿：每损失 8 HP 补 1 个模块（掉在脚边被吸走），挨打反哺构筑
- 电路板：武器品质决定槽位数量与**连接方式**（直线 / T / 十字 / 双排），相邻槽位互相影响
- 模块网络：加法镜像相邻低阶模块、阵列镜像半径 2 内的低阶模块、共振给相邻同名模块 +50%
- 合成与升级：2 个同阶库存模块合成 1 个高阶；消耗库存模块升级，升级解锁合成配方
- 波次推进：每 40s 一波，敌人 HP 与刷怪率同步上涨；品质在 12/20 波提升，自动扩容槽位

## 运行

需要 Godot 4.7+。本项目自带便携版：`.tools/godot/Godot_v4.7.2-stable_win64.exe`（首次 clone 需自行下载）。

```powershell
# 直接运行
.\.tools\godot\Godot_v4.7.2-stable_win64.exe --path .

# 无头平衡自测（bot 自动构筑，8 倍速）
.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . -- playtest bot pt=900

# 截图（迭代视觉用）
.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --path . -- "shot=G:/tmp/a.png" "shotat=30" shotbuild
```

> Windows 下若报 `Could not create directory: 'user://logs'`，先设 `$env:APPDATA = (Get-Location).Path + "\.tools\appdata"`；`Failed to read the root certificate store` 是无害噪音，`2>$null` 掉即可。

## 操作

| 键 | 作用 |
| --- | --- |
| WASD / 方向键 | 移动 |
| TAB | 打开/关闭构筑界面（暂停游戏） |
| U | 升级（消耗库存模块） |
| C | 合成（2 个同阶库存 → 1 个高阶） |
| R | 重开 |

## 目录

```
docs/design.md      设计文档（含数值标定过程与结论）
tasks/plan.md       实现计划与里程碑
scripts/game.gd     主控：刷怪/开火/掉落/构筑/HUD
scripts/player.gd   玩家移动
scripts/enemy.gd    敌人追击与受击表现
scripts/pickup.gd   模块掉落与吸附
sim/economy_sim.gd  无头经济模拟（M0 数值标定用）
```

## 数值

当前为「宽松成长」v1，见 `docs/design.md` §2.5。核心公式：

- 敌人 HP `4 × 1.115^(wave−1)`，刷怪 `1.10 + 0.035 × wave`
- 模块：T1 基础 rate 1.0 / 20 次，T2 加法 3.0 / 24，T3 阵列 9.0 / 28，T4 共振 27.0 / 34
- 升级消耗 `3 × 1.18^(level−1)` 个模块
- 武器品质：蓝 4 槽（T 型）→ 12 波紫 5 槽（十字）→ 20 波金 6 槽（双排）

## 还没做

- 多武器、词条、精英怪与宝箱掉落新武器
- 元游戏（工坊等级、跨局保留）
- 音效与粒子
