extends Node

## 阶段目标管理器：监听金币变化，达标时填满鱼缸、授予船体稳定时间并广播事件。
## @stageGoals 阶段目标金额列表（升序排列）
## @finalGoal 最终胜利目标金额
## @stabilityDurationSec 每次达标授予的稳定时长（秒）
@export var stageGoals: Array[int] = [1000, 2000, 5000]
@export var finalGoal: int = 10000
@export var stabilityDurationSec: float = 180.0

var _reachedStages: Array[int] = []


## 初始化并订阅金币变化事件。
## @return void
func _ready() -> void:
	EventBus.subscribe(_on_event)


## 退出时取消订阅。
## @return void
func _exit_tree() -> void:
	EventBus.unsubscribe(_on_event)


## 获取下一个未达成的阶段目标金额。
## @return int
func get_next_goal() -> int:
	for goal in stageGoals:
		if not _reachedStages.has(goal):
			return goal
	return finalGoal


## 接收事件总线消息。
## @param eventType 事件类型
## @param data 事件数据
## @return void
func _on_event(eventType: EventBus.EventType, data: Dictionary) -> void:
	if eventType != EventBus.EventType.COIN_CHANGED:
		return
	var gold: int = int(data.get('gold', 0))
	_check_milestones(gold)


## 检查是否有新的阶段目标被达成。
## @param gold 当前金币数
## @return void
func _check_milestones(gold: int) -> void:
	for goal in stageGoals:
		if _reachedStages.has(goal):
			continue
		if gold >= goal:
			_on_stage_reached(goal, gold)
	if gold >= finalGoal and not _reachedStages.has(finalGoal):
		_reachedStages.append(finalGoal)
		EventBus.emit(EventBus.EventType.GAME_WON, {'gold': gold})


## 阶段达标处理：填满鱼缸、授予稳定时间、播放音效、广播事件。
## @param goal 达成的目标金额
## @param gold 当前金币数
## @return void
func _on_stage_reached(goal: int, gold: int) -> void:
	_reachedStages.append(goal)
	_fill_all_fish_tanks()
	EventBus.emit(EventBus.EventType.STABILITY_GRANTED, {
		'duration_seconds': stabilityDurationSec
	})
	AudioManager.play_sfx(ResPath.AUDIO.PROGRESS_COMPLETE)
	EventBus.emit(EventBus.EventType.STAGE_GOAL_REACHED, {
		'goal': goal,
		'gold': gold,
		'next_goal': get_next_goal()
	})


## 填满所有鱼缸。
## @return void
func _fill_all_fish_tanks() -> void:
	for node in get_tree().get_nodes_in_group('Interactable'):
		if node != null and node.has_method('fill_to_max'):
			node.call('fill_to_max')
