## GameState 全局游戏状态，管理运行时数据。
##
## 使用示例：
##   GameState.set_value("score", 100)
##   var score: int = GameState.get_value("score", 0)
##   GameState.reset()
extends RefCounted

signal value_changed(key: StringName, new_value: Variant)

var _state: Dictionary = {}

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
	print_debug("GameState: state reset")

## 导出为 Dictionary（供 SaveManager 使用）
func to_dict() -> Dictionary:
	return _state.duplicate()

## 从 Dictionary 导入（供 SaveManager 使用）
func from_dict(data: Dictionary) -> void:
	_state = data.duplicate()
	print_debug("GameState: state loaded, keys=%s" % [_state.keys()])
