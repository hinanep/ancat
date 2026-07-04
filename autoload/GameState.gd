## GameState 全局游戏状态，管理运行时数据。
##
## 使用示例：
##   GameState.set_value("score", 100)
##   var score: int = GameState.get_value("score", 0)
##   GameState.reset()
extends Node

signal value_changed(key: StringName, new_value: Variant)

var _state: Dictionary = {}
const GOLD_KEY: StringName = &"gold"

## 设置全局状态值
func set_value(key: StringName, value: Variant) -> void:
	_state[key] = value
	value_changed.emit(key, value)

## 获取全局状态值（带默认值）
func get_value(key: StringName, default: Variant = null) -> Variant:
	return _state.get(key, default)

## 检查是否存在某 key
func has_value(key: StringName) -> bool:
	return _state.has(key)

## 删除某 key
func remove_value(key: StringName) -> void:
	_state.erase(key)

## 重置所有状态（新游戏时调用）
func reset() -> void:
	_state.clear()
	_state[GOLD_KEY] = 0
	print_debug("GameState: state reset")

## 导出为 Dictionary（供 SaveManager 使用）
func to_dict() -> Dictionary:
	return _state.duplicate()

## 从 Dictionary 导入（供 SaveManager 使用）
func from_dict(data: Dictionary) -> void:
	_state = data.duplicate()
	if not _state.has(GOLD_KEY):
		_state[GOLD_KEY] = 0
	print_debug("GameState: state loaded, keys=%s" % [_state.keys()])


## 增加金币并广播变化事件。
## @param amount 增加数量
## @return int
func add_gold(amount: int) -> int:
	var current: int = get_gold()
	var next: int = max(current + amount, 0)
	_state[GOLD_KEY] = next
	value_changed.emit(GOLD_KEY, next)
	EventBus.emit(EventBus.EventType.COIN_CHANGED, {'gold': next, 'delta': amount})
	return next


## 获取当前金币。
## @return int
func get_gold() -> int:
	return int(_state.get(GOLD_KEY, 0))
