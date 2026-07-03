extends Control

## 风暴预警UI：角落警示图标与倒计时控制。
## 警示文案
@export var warningText: String = 'STORM INCOMING'

## 风暴进行中文案
@export var stormingText: String = 'Storm Coming!'

@onready var _warningLabel: Label = $Panel/Content/WarningLabel
@onready var _countdownLabel: Label = $Panel/Content/CountdownLabel

var _countdownSeconds: float = 0.0
var _countdownActive: bool = false


## 订阅风暴事件并初始化隐藏。
## @return void
func _ready() -> void:
	visible = false
	EventBus.subscribe(_on_event)


## 退出时取消事件订阅。
## @return void
func _exit_tree() -> void:
	EventBus.unsubscribe(_on_event)


## 本地倒计时更新（不依赖 controller tick 事件）。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	if not _countdownActive:
		return

	_countdownSeconds = max(_countdownSeconds - delta, 0.0)
	update_countdown(int(ceil(_countdownSeconds)))


## 显示预警 UI。
## @param secondsRemaining 剩余秒数
## @param message 文案（为空时使用默认文案）
## @return void
func show_warning(secondsRemaining: int, message: String = '') -> void:
	visible = true
	_countdownActive = true
	_countdownSeconds = max(float(secondsRemaining), 0.0)
	_warningLabel.text = warningText if message.is_empty() else message
	update_countdown(secondsRemaining)


## 更新倒计时文本。
## @param secondsRemaining 剩余秒数
## @return void
func update_countdown(secondsRemaining: int) -> void:
	_countdownLabel.text = '%ss' % max(secondsRemaining, 0)


## 隐藏预警 UI。
## @return void
func hide_warning() -> void:
	_countdownActive = false
	_countdownSeconds = 0.0
	visible = false


## 处理 EventBus 风暴事件。
## @param eventType 事件类型
## @param data 事件数据
## @return void
func _on_event(eventType: EventBus.EventType, data: Dictionary) -> void:
	match eventType:
		EventBus.EventType.STORM_WARNING_STARTED:
			show_warning(int(data.get('remaining_seconds', 0)), warningText)
		EventBus.EventType.STORM_STARTED:
			show_warning(int(data.get('remaining_seconds', 0)), stormingText)
		EventBus.EventType.STORM_RECOVER_STARTED:
			hide_warning()
		EventBus.EventType.STORM_ENDED:
			hide_warning()
		_:
			pass
