extends Node

## 阶段目标管理器：监听金币变化，达到最终目标时广播胜利事件。
## @finalGoal 最终胜利目标金额
@export var finalGoal: int = 10000

var _gameWon: bool = false


## 初始化并订阅金币变化事件。
## @return void
func _ready() -> void:
	EventBus.subscribe(_on_event)


## 退出时取消订阅。
## @return void
func _exit_tree() -> void:
	EventBus.unsubscribe(_on_event)


## 接收事件总线消息。
## @param eventType 事件类型
## @param data 事件数据
## @return void
func _on_event(eventType: EventBus.EventType, data: Dictionary) -> void:
	if eventType != EventBus.EventType.COIN_CHANGED:
		return
	var gold: int = int(data.get('gold', 0))
	_check_final_goal(gold)


## 检查是否达到最终胜利目标。
## @param gold 当前金币数
## @return void
func _check_final_goal(gold: int) -> void:
	if _gameWon:
		return
	if gold < finalGoal:
		return
	_gameWon = true
	EventBus.emit(EventBus.EventType.GAME_WON, {'gold': gold})
