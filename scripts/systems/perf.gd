extends RefCounted

## 帧内耗时累加器（docs/plan-v4.md §4.1）
## 敌人 `_physics_process` / `_draw` 与 Game 的开火+接触各自把微秒加进来，
## Game 每帧读一次就清零，F3 面板显示的是指数平滑后的毫秒。
static var ai_usec := 0
static var draw_usec := 0
static var combat_usec := 0


static func reset() -> void:
	ai_usec = 0
	draw_usec = 0
	combat_usec = 0
