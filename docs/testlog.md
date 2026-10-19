# 测试日志

每条记录四行：**命令 / 目的 / 关键输出 / 结论**。跑完即写，避免「这个数是怎么来的」回想不起来。
机器可读的一对 `[TEST] start …` / `[TEST] end …` 行由游戏自己打印，见 `docs/reference.md` §9.2。

---

## 2026-10-18 · U1 坐标自检（uitest）

- **命令**：`Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 -- uitest`
- **目的**：确认 `ui_kit` 做的 ×/← 按钮在 1280×720 下坐标是 1:1，合成鼠标点击能真的点到。
- **关键输出**：`viewport=(1280,720) content_scale=(1280,720) factor=1.00`、`close_rect=(1228,18,34,38)`、`after_click build_visible=false`
- **结论**：通过。同一条命令在 `--headless` 下会误报（`build_visible=true`），因为 headless 不派发 GUI 输入——点击类验证必须开窗口跑。

## 2026-10-18 · U3-1 电路板自检（boardtest）

- **命令**：`--headless --path . -- boardtest`
- **目的**：确认加了「槽位方案」之后，模块网络的结算顺序与数值完全没变（回归测试）。
- **关键输出**：`out=[40.5, 45.5, 0.0, 1.0, 5.0, 6.0]  power=100.0`，10 秒内每 0.5 秒恒定不变。
- **结论**：通过。方案层只是「补料来源」，不参与 `_slot_out()` 计算，所以数值零漂移。

## 2026-10-19 · U3-2 缺料提示（planmissing）

- **命令**：`--path . --resolution 1280x720 -- "shot=...u3_miss2.png" "shotat=8" shotbuild shotbot planmissing noautoplan ff=6`
- **目的**：验证「方案补不上时不降阶、只红框提示」这条规则在界面上真的能看到。
- **关键输出**：四格全部红框、格内文字 `缺 共振`；标题行 `缺料 4 格：共振 / 共振 / 共振 / 共振（攒够自动补上）`；`[TEST]` 行的 `miss=4`。
- **结论**：通过。截图存 `docs/screenshots/build-missing.png`。带 `autoplan` 时同样的场景会在 2 秒内被 `_auto_plan_fix()` 改写成库存里可装的 id（bot 专用）。

## 2026-10-19 · U3-3 900 秒平衡复测（pt=900，autoplan 开）

- **命令**：`--headless --path . -- playtest bot pt=900`
- **目的**：确认「槽位方案 + 自动配置方案」没有把 bot 的构筑能力改坏（对比 U3 之前的最好成绩 t≈896 / wave 23）。
- **关键输出**：`[TEST] start mode=playtest seed=907590879 bot=true autoplan=true`；全程 `slot=4/4 miss=0`（每一格的方案都补得上）；`[TEST] end reason=dead t=781 wave=20 lvl=28 kills=7477 dps=522.6 need=880.9 weapons=3 inv=336`。
- **结论**：通过，但与 U3 之前的 t≈896 基本同档（差 13%），说明蓝图系统本身不拖后腿。真正的死因是 **wave 19 起 `need` 跳到 955 而实测 DPS 只有 522**（缺口约 45%），同时库存涨到 336 个基础模块根本来不及合成 —— 瓶颈已经从「构筑能力」转移到「需求曲线的陡降点」和「经济溢出」，留给后面的数值 / 装置阶段处理。
## V1 装置指派

- 命令：`.\run.cmd`（人工）＋`godot --headless --path . -- playtest bot pt=90`
- 目的：确认装置能指定配方、进度条走完产出、取消能全额返还
- 关键输出：`dev=1/1`（装置在忙）、`crafted` 计数上升；`devpick=0` 截图里未解锁配方的「开始」按钮已压暗
- 结论：装置不再空转；`kind` 存的是模块 id 字符串，判定必须用 `String(d["kind"]) != ""`（用 int 会永远判成空闲）

## V2 鼠标拖拽

- 命令：`godot --path . --resolution 1280x720 -- dragtest "cheat=modules"`
- 目的：用真实鼠标事件验证「库存行 → 电路板格子」的拖放真的生效
- 关键输出：`DRAGTEST mid=add inv 20->19  slot1 {id:base} -> {id:add}  plan1=add`
- 结论：拖放、方案写入、库存扣减都对；**命中判定必须用事件坐标**（`get_global_transform_with_canvas().affine_inverse() * ev.position`），`get_local_mouse_position()` 读的是系统光标，压测时不会动，会永远落空

## V3 bulwark

- 命令：`godot --headless --path . -- playtest bot pt=180`
- 目的：确认前方撞墙怪会按 16 秒节奏生成，并且不会无限堆积
- 关键输出：`t= 90 … bw=2` / `t=140 … bw=3` / `t=170 … bw=3`（`bw=` 是 `_count_bulwark()`）
- 结论：生成与上限正常；截图 `docs/screenshots/bulwark.png` 能看到 0.9~2.1s 的依次浮现（半透明方块 + 红环）