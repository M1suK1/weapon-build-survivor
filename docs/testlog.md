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
## V4 修复两条反馈

- 命令：`godot --headless --path . -- playtest bot pt=600`
- 目的：确认自测里「高级模块不再顶掉已装模块」，同时机器人不会因此退化成全基础模块
- 关键输出（修前）：`[TEST] end reason=limit t=400 wave=11 dps=35.0 need=44.7`
- 关键输出（修后）：`t=586 w=15 dps=237.2 need=169.6 lvl=22 slot=4/4 miss=0 [2233] dev=3/3`、`[TEST] end t=600 wave=16 lvl=23 dps=136.3 need=222.0`
- 结论：`_install` 在 autoplan/playtest/bot 下只填空槽；方案升级改成「寿命剩 25% 以下时才把 plan 改写成更高阶」，等烧空时由 `_refill` 按新方案补货 —— 既不顶掉模块，也不卡在 T1。另修 `_auto_plan_all` 用 `sel = i` 切武器无效（`weapon` 是别名，必须 `_use_weapon`）。
- 装置按钮：`buy_device()` 需要 `背包 < 6`，之前背包满时按钮看着能点其实无效；现在按钮禁用 + 红字说明原因，并提供「丢弃当前武器（腾格子）」。
## plan-v4 V1+V2 控制台

- 命令：`godot --headless --path . -- consoletest`（临时钩子，验证后已删）＋`-- playtest bot pt=20 "cheat=rich,devices=3,wave=3"`＋截图 `-- "shot=docs/screenshots/v4-console.png" "shotat=3" shotconsole`
- 目的：暂停来源集合、14 条命令、Tab 补全 / `;` 批量、CLI `cheat=` 改走同一套 `_cmd_*`
- 关键输出：`CT ok open_paused / build_stacks / close_keeps_build / all_closed_unpause / speed4 / speed_bad / god_toggle / give / weapon_sniper sniper / hp / spawn 0->2 / kill / unknown / help / tab help / batch / level20 / pick_closed lvl=20`；`[cheat] 获得 base ×500（库存 502）`、`[cheat] 装置 +3（共 4/8）`、`[cheat] 跳到第 3 波`
- 结论：暂停必须按来源计数（关控制台不能顺手把构筑屏的暂停也解除）；`cheat=level` 走 `_cmd_level([n, "quiet"])`，否则无头自测在 `_ready` 弹卡会把树暂停、机器人直接停摆。截图 `docs/screenshots/v4-console.png`。

## plan-v4 V3 升级按钮

- 命令：`-- uptest`（临时钩子，验证后已删）＋截图 `-- "shot=docs/screenshots/v4-upgrade.png" "shotat=3"`（灰态）与 `... v4-upgrade-on.png ... "cheat=rich"`（金态）
- 目的：左下角升级按钮的三态（金呼吸 + 红点 / 灰 + 进度 / 选卡时隐藏）、点击等同 `U`
- 关键输出：`UPTEST start inv=2 cost=3 level=1`、`UPTEST fail level=1 picking=false`、`UPTEST ok level=2 picking=true paused=true`、`UPTEST after level=2 picking=false paused=false`
- 结论：材料不足只抖不升；成功后立刻弹四选一（树暂停），选完恢复；`_refresh_hud` 末尾统一刷按钮，`_open_pick` / `_close_pick` 也各补一次，避免选卡期间按钮还挂着。截图 `docs/screenshots/v4-upgrade.png`、`v4-upgrade-on.png`。

## plan-v4 V4 四段耗时（测量）

- 命令：`-- perftest "cheat=god,wave=25" pt=22`（窗口模式，1280x720；`perftest` 是新增的压测出口，不算控制台命令）
- 目的：按 plan-v4 §4.1 把帧耗时拆成 AI / 绘制 / 战斗 / 其它，先量基线再决定优化力度
- 关键输出（指数平滑后的毫秒，`帧墙` = 相邻 `_process` 墙钟差）：
  - 300 只：`wall=12.1 ai=0.31 draw=3.05 combat=0.19 other=8.60`（≈83 FPS）
  - 447 只：`wall=17.8 ai=0.60 draw=7.13 combat=0.24 other=9.81`（≈56 FPS）
  - 527 只：`wall=56.0 ai=1.95 draw=24.54 combat=0.90 other=28.64`
  - 564 只：`wall=153.3 ai=5.77 draw=69.18 combat=0.60 other=77.77`（≈6.5 FPS）
- 结论：AI / 战斗都不是瓶颈（合计 <7ms）；**绘制 + `其它`（每个敌人一个 CanvasItem 的重绘/合批开销）占 95%**，且随数量超线性恶化 —— §4.2 的「集中渲染 + 屏外剔除」是对的方向。另外 `enemies=564 > MAX_ENEMIES=560`，说明 bulwark 走 `_spawn_enemy_at` 绕过了上限（V6 删它时一并消失）。
- 截图：`docs/screenshots/v4-perf.png`（F3 面板新增「AI / 绘制 / 战斗 / 其它 / 帧墙」一行）。

## plan-v4 V5 性能优化（集中渲染 / 屏外降频 / 数组计数 / 上限 400）

- 命令：`-- perftest "cheat=god,wave=25" pt=25`（窗口 1280x720）＋`-- playtest bot pt=300`＋`-- boardtest`
- 目的：把 V4 量到的「绘制 + 每个敌人一个 CanvasItem 的重绘开销」压下去，并把同屏上限直接改成 400
- 改动：
  - 新增 `scripts/enemy_renderer.gd`：单个 `Node2D` 在 `_draw()` 里遍历 `game.enemies` 画完全部敌人与血条，并跳过镜头外（视口外扩 48px）的敌人；`enemy.gd` 删掉 `_draw` / 全部 `queue_redraw`
  - `enemy.gd`：距玩家 >1600 的敌人每 4 个物理帧才走一步，分桶用 `hpth` 派生（不额外消耗 rng，同 seed 可复现）
  - `game.gd`：维护 `var enemies: Array` + `kind_n` 计数（`_spawn_enemy_at` 登记、`_kill` 与 `tree_exiting` 双保险移除）；`_count_kind` / `_count_bulwark` 改读计数；所有 `get_nodes_in_group("enemy")` 换成本数组；榴弹溅射改遍历 `enemies.duplicate()`（循环里会 `_kill`）
  - `MAX_ENEMIES := 400`（`scripts/data/enemies_db.gd:21`），不做自适应
  - 高密度 LOD：>220 只时不画纯装饰的小内点（每只 1 次 draw，400 只时约 3ms）
- 关键输出（同一条 `PERF` 行：`enemies` = 场上总数，`drawn` = 镜头内实际画出的数量）：
  - 295 只（drawn 88）：`wall=10.0 ai=0.22 draw=1.48 combat=0.18 other=8.08`（≈100 FPS，撞到引擎 100 上限）
  - 373 只（drawn 147）：`wall=9.8 ai=0.23 draw=2.18 combat=0.10 other=7.24`
  - 400 只（drawn 215）：`wall=9.8 ai=0.32 draw=2.24 combat=0.04 other=7.16`
  - 400 只（drawn 400，全部挤在镜头内）：`wall=10.2 ai=0.27 draw=3.69 combat=0.05 other=6.18`（≈98 FPS）
  - 对照 V4 基线：564 只 `wall=153.3 draw=69.18 other=77.77`（≈6.5 FPS）；447 只 `wall=17.8 draw=7.13`
- 结论：`≤4ms` 达标（最坏 3.69ms），300/400 的 ≥55 / ≥45 FPS 都远超；`其它` 从 77.8ms 掉到 6~9ms，说明瓶颈确实是「每只敌人一个 CanvasItem」。`MAX_ENEMIES=400` 已生效（perftest 稳定 400，bulwark 额外 3~4 只绕过上限，V6 删它后归零）。
- **C（空间网格）未实施**：实测 `combat_ms` 稳定在 0.03~0.05ms（`_contact` 数到 6 只就 break，`_targets_in_range` 每次开火只跑一遍），网格收益低于测量噪声；等九武器长局里 combat 真的起来再做，避免为 0.05ms 加一套网格维护。
- 自测：`boardtest` → `BOARD set out=[40.5, 45.5, 0.0, 1.0, 5.0, 6.0] power=100.0`；`playtest bot pt=300` → `[TEST] end reason=limit t=300 wave=8 lvl=26 kills=793 dps=23.5 need=11.9 weapons=3 inv=373 dead=false`（与 V4 前 `kills=799 dps=24.1 inv=347` 同量级）。
- 截图：`docs/screenshots/v5-render.png`（同 seed 291927655 对照 V4 的 `v4-perf.png`：形状/颜色/血条一致）、`v5-crowd.png`（400 只密度）。

## plan-v4 V6 删 bulwark / 重装变种 brute / hit_cap

- 命令：`-- brutetest`（临时自检，验完删除）＋`--playtest bot pt=300`＋`-- boardtest`
- 改动：
  - 删 `ENEMY_KINDS["bulwark"]`、`bulwark_t/last_move_dir/prev_ppos`、`_tick_bulwark/_spawn_bulwark_arc/_count_bulwark/_recycle_bulwark`、`_pt_log` 的 `bw=`
  - 新 `variant = "brute"`：模板只从 `flood(100)/rock(52)/shooter(70)` 抽（生成时再查 `base_speed <= 120` 兜底），**只把血量 ×8**，速度/半径/伤害全都不动
  - `e.hit_cap = e.max_hp × 0.20`：所有命中走新的 `_apply_hit()` 单一入口（直击/贯穿/溅射同一套），保证至少 5 发；普通怪 `hit_cap == 0` 不受影响
  - 生成：wave ≥ 3 起每 20 秒 2–4 只，同屏上限 50，屏幕外 1220–1400 随机角，直线走向玩家、不回收
  - 颜色：模板色 `.lerp(Color(0.72,0.22,0.42), 0.55)` + 2px 近白描边（`enemy_renderer.gd`）
  - HUD 状态栏右侧「重装 N」，>30 只变红；F3 面板加「重装 N/50 · 单发上限 20% · 模板 …」
- 关键输出（临时自检 `BRUTETEST`）：
  - `tmpl=shooter in_pool=true base_speed=70.0 brute_speed=72.10 normal_speed=72.10 hp=30.78 want_hp=30.78 hit_cap=6.16 ratio=0.200 radius=12.0 normal_radius=12.0`
    → 与同波同模板的普通怪**速度/半径完全一致**，血量正好 ×8
  - `cap dealt=6.16 want=6.16 hp_left=24.62 alive=true`：一发 999999 也只掉 20%
  - `kills_in_hits=5`：连打上限正好 5 发死（10 倍伤害也是 5 发，已远超「≥5 发」的下界）
  - `hud_visible=true hud_text=重装 1 count=1`；`tick count=50 max_base_speed=100.0 over_cap=false`（连续 60 次 20 秒刷新 = 20 分钟，稳定卡在 50、模板最快 100）
- 生成上限的坑：重装**不看 `MAX_ENEMIES`**。第一版在 400 满员时 `break`，实测 wave 18 连一只重装都刷不出来；现在它是「超编」单位（50 自己管），总同屏可到 450。
- 自测：`boardtest` → `power=100.0`；`playtest bot pt=300` → `t=300 wave=8 lvl=28 kills=781 dps=14.2 need=11.9 inv=473 dead=false`（V5 时 `dps=23.5`：重装吃掉大量伤害，符合「打不死、堵路」的定位）。
- 截图：`docs/screenshots/v6-brute.png`（重装 3：玩家身边两个近白描边的大血牛）、`v6-brute-dbg.png`（F3 面板显示模板与上限）。
- 待观察（plan §9 风险）：抽到 shooter 模板的重装会风筝，和「拦路」定位相反；先留池观察，不好就砍成 flood/rock。
