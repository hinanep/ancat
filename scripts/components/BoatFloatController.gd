extends Node2D

## 船体浮动参数：用于控制整体上下浮动与轻微摇摆。
## 上下浮动幅度（像素）
@export var floatAmplitudeY: float = 5.0
## 上下浮动频率（Hz）
@export var floatFrequencyHz: float = 0.28
## 摇摆角度幅度（度）
@export var rollAmplitudeDeg: float = 1.8
## 摇摆频率（Hz）
@export var rollFrequencyHz: float = 0.22
## 相位偏移（秒）
@export var phaseOffset: float = 0.0
## 风暴额外上下振动幅度（像素）
@export var stormExtraFloatAmplitudeY: float = 2.2
## 风暴额外上下振动频率（Hz）
@export var stormExtraFloatFrequencyHz: float = 0.9
## 风暴额外振动混合速度（每秒）
@export var stormExtraFloatBlendSpeed: float = 0.8
## 主体边缘安全距离（像素）
@export var screenSafeMarginPx: float = 28.0
## 风暴开始时每秒最大倾斜变化量（度）
@export var stormStartTiltLerpSpeedDeg: float = 12.0
## 风暴阶段每秒最大倾斜变化量（度）
@export var stormTiltLerpSpeedDeg: float = 18.0
## 恢复阶段每秒最大倾斜变化量（度）
@export var stormRecoverTiltMaxChangeDegPerSec: float = 10.0

var _basePosition: Vector2 = Vector2.ZERO
var _baseRotation: float = 0.0
var _elapsed: float = 0.0
var _stormTiltDegCurrent: float = 0.0
var _stormTiltDegTarget: float = 0.0
var _stormTiltFollowSpeedDeg: float = 30.0
var _stormRecoverSpeedDeg: float = 30.0
var _stormExtraFloatBlend: float = 0.0
var _stormActive: bool = false


## 记录初始姿态，作为浮动基准。
## @return void
func _ready() -> void:
	_basePosition = position
	_baseRotation = rotation
	EventBus.subscribe(_on_event)


## 退出时取消事件订阅。
## @return void
func _exit_tree() -> void:
	EventBus.unsubscribe(_on_event)


## 每帧更新浮动与摇摆效果。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	_elapsed += delta
	var waveTime: float = _elapsed + phaseOffset
	var yWave: float = sin(TAU * floatFrequencyHz * waveTime)
	var stormWave: float = sin(TAU * stormExtraFloatFrequencyHz * waveTime + 1.8)
	var rollWave: float = sin(TAU * rollFrequencyHz * waveTime + 0.9)
	var targetStormBlend: float = 1.0 if _stormActive else 0.0
	_stormExtraFloatBlend = move_toward(_stormExtraFloatBlend, targetStormBlend, max(stormExtraFloatBlendSpeed, 0.01) * delta)
	var currentLerpSpeed: float = _stormRecoverSpeedDeg if _stormTiltDegTarget == 0.0 else _stormTiltFollowSpeedDeg
	_stormTiltDegCurrent = move_toward(_stormTiltDegCurrent, _stormTiltDegTarget, currentLerpSpeed * delta)

	position.y = _basePosition.y + yWave * floatAmplitudeY + stormWave * stormExtraFloatAmplitudeY * _stormExtraFloatBlend
	rotation = _baseRotation + deg_to_rad(rollWave * rollAmplitudeDeg + _stormTiltDegCurrent)
	_clamp_to_screen()


## 响应风暴事件，更新目标倾斜角。
## @param eventType 事件类型
## @param data 事件数据
## @return void
func _on_event(eventType: EventBus.EventType, data: Dictionary) -> void:
	match eventType:
		EventBus.EventType.STORM_STARTED:
			var direction: float = _as_float(data.get('direction', 1.0), 1.0)
			var tiltDeg: float = _as_float(data.get('tilt_deg', 20.0), 20.0)
			_stormActive = true
			_stormTiltDegTarget = direction * tiltDeg
			_stormTiltFollowSpeedDeg = max(stormStartTiltLerpSpeedDeg, 1.0)
			_stormRecoverSpeedDeg = max(stormRecoverTiltMaxChangeDegPerSec, 1.0)
		EventBus.EventType.STORM_DIRECTION_CHANGED:
			var direction: float = _as_float(data.get('direction', 1.0), 1.0)
			var tiltDeg: float = _as_float(data.get('tilt_deg', 20.0), 20.0)
			_stormActive = true
			_stormTiltDegTarget = direction * tiltDeg
			_stormTiltFollowSpeedDeg = max(stormTiltLerpSpeedDeg, 1.0)
			_stormRecoverSpeedDeg = max(stormRecoverTiltMaxChangeDegPerSec, 1.0)
		EventBus.EventType.STORM_RECOVER_STARTED:
			_stormActive = false
			_stormRecoverSpeedDeg = max(stormRecoverTiltMaxChangeDegPerSec, 1.0)
			_stormTiltDegTarget = 0.0
		EventBus.EventType.STORM_ENDED:
			_stormActive = false
			_stormTiltDegTarget = 0.0
			_stormTiltFollowSpeedDeg = max(stormTiltLerpSpeedDeg, 1.0)
			_stormRecoverSpeedDeg = max(stormRecoverTiltMaxChangeDegPerSec, 1.0)
		_:
			pass


## 安全转换为 float。
## @param value 任意值
## @param fallback 默认值
## @return float
func _as_float(value: Variant, fallback: float) -> float:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


## 将主体位置限制在当前相机可视范围内。
## @return void
func _clamp_to_screen() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return

	var viewportSize: Vector2 = get_viewport_rect().size
	var halfView: Vector2 = viewportSize * 0.5 * camera.zoom
	var margin: float = max(screenSafeMarginPx, 0.0)
	var minX: float = camera.global_position.x - halfView.x + margin
	var maxX: float = camera.global_position.x + halfView.x - margin
	var minY: float = camera.global_position.y - halfView.y + margin
	var maxY: float = camera.global_position.y + halfView.y - margin

	global_position.x = clampf(global_position.x, minX, maxX)
	global_position.y = clampf(global_position.y, minY, maxY)
