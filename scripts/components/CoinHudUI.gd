extends Label

## 金币 HUD：监听金币变化并刷新文本。
## @prefix 前缀文本
@export var prefix: String = '金币: '


## 初始化显示并订阅事件。
func _ready() -> void:
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
	if eventType != EventBus.EventType.COIN_CHANGED:
		return
	_refresh_text(int(data.get('gold', GameState.get_gold())))


## 刷新显示文本。
## @param value 金币值
func _refresh_text(value: int) -> void:
	text = '%s%d' % [prefix, max(value, 0)]
