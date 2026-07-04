extends Label

## 金币 HUD：监听金币与阶段目标变化，显示 "当前金币/阶段目标" 格式。
## @stageGoals 阶段目标金额列表（需与 StageGoalManager 一致）
## @finalGoal 最终目标金额
@export var stageGoals: Array[int] = [1000, 2000, 5000]
@export var finalGoal: int = 10000

var _nextGoal: int = 1000


## 初始化显示并订阅事件。
func _ready() -> void:
	_nextGoal = _resolve_initial_goal()
	_refresh_text(GameState.get_gold())
	EventBus.subscribe(_on_event)
	GameState.value_changed.connect(_on_value_changed)


## 退出时取消订阅。
func _exit_tree() -> void:
	EventBus.unsubscribe(_on_event)
	if GameState.value_changed.is_connected(_on_value_changed):
		GameState.value_changed.disconnect(_on_value_changed)


## 处理 GameState 变化。
## @param key 键
## @param newValue 值
func _on_value_changed(key: StringName, newValue: Variant) -> void:
	if String(key) != 'gold':
		return
	_refresh_text(int(newValue))


## 处理事件总线变化。
## @param eventType 事件类型
## @param data 数据
func _on_event(eventType: EventBus.EventType, data: Dictionary) -> void:
	if eventType == EventBus.EventType.COIN_CHANGED:
		_refresh_text(int(data.get('gold', GameState.get_gold())))
		return
	if eventType == EventBus.EventType.STAGE_GOAL_REACHED:
		_nextGoal = int(data.get('next_goal', _nextGoal))
		_refresh_text(GameState.get_gold())


## 刷新显示文本。
## @param value 金币值
func _refresh_text(value: int) -> void:
	text = '%d/%d' % [max(value, 0), _nextGoal]


## 根据当前金币计算初始目标（用于中途加载场景时恢复正确显示）。
## @return int
func _resolve_initial_goal() -> int:
	var gold: int = GameState.get_gold()
	for goal in stageGoals:
		if gold < goal:
			return goal
	return finalGoal
