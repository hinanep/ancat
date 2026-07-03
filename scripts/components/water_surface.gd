@tool
extends Polygon2D

## 水面表现参数：集中控制 shader 的颜色、波浪与风格化阈值。
## 浅水/表层颜色
@export var color_surface: Color = Color(0.25, 0.71, 0.96, 1.0):
	set(value):
		_color_surface = value
	get:
		return _color_surface

## 深水颜色
@export var color_depth: Color = Color(0.08, 0.35, 0.70, 1.0):
	set(value):
		_color_depth = value
	get:
		return _color_depth

## 浪沫颜色
@export var color_foam: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		_color_foam = value
	get:
		return _color_foam

## 波浪振幅
@export var wave_amplitude: float = 5.0:
	set(value):
		_wave_amplitude = max(value, 0.0)
		_baseWaveAmplitude = _wave_amplitude
	get:
		return _wave_amplitude

## 波浪频率
@export var wave_frequency: float = 3.0:
	set(value):
		_wave_frequency = max(value, 0.0)
		_baseWaveFrequency = _wave_frequency
	get:
		return _wave_frequency

## 波浪速度
@export var wave_speed: float = 2.5:
	set(value):
		_wave_speed = max(value, 0.0)
		_baseWaveSpeed = _wave_speed
	get:
		return _wave_speed

## 基础左右流速（>0 右移，<0 左移）
@export var lateral_flow_speed: float = 0.0:
	set(value):
		_lateral_flow_speed = value
		_baseLateralFlowSpeed = value
	get:
		return _lateral_flow_speed

## 深水阈值
@export var depth_threshold: float = 0.1:
	set(value):
		_depth_threshold = clampf(value, 0.0, 1.0)
	get:
		return _depth_threshold

## 浪沫厚度
@export var foam_thickness: float = 0.02:
	set(value):
		_foam_thickness = clampf(value, 0.0, 1.0)
	get:
		return _foam_thickness

## 参数过渡速度（越大越快）
@export var transition_speed: float = 3.0:
	set(value):
		_transition_speed = max(value, 0.01)
	get:
		return _transition_speed

## 风暴振幅峰值
@export var storm_peak_wave_amplitude: float = 20.0
## 风暴速度峰值
@export var storm_peak_wave_speed: float = 2.0
## 风暴频率峰值
@export var storm_peak_wave_frequency: float = 1.5
## 风暴阶段左右流速绝对值
@export var storm_flow_speed: float = 0.3
## 流速每秒最大变化量
@export var flow_speed_max_change_per_sec: float = 0.08

var _color_surface: Color = Color(0.25, 0.71, 0.96, 1.0)
var _color_depth: Color = Color(0.08, 0.35, 0.70, 1.0)
var _color_foam: Color = Color(1.0, 1.0, 1.0, 1.0)
var _wave_amplitude: float = 5.0
var _wave_frequency: float = 3.0
var _wave_speed: float = 2.5
var _lateral_flow_speed: float = 0.0
var _depth_threshold: float = 0.1
var _foam_thickness: float = 0.02
var _transition_speed: float = 3.0

var _current_color_surface: Color = Color(0.25, 0.71, 0.96, 1.0)
var _current_color_depth: Color = Color(0.08, 0.35, 0.70, 1.0)
var _current_color_foam: Color = Color(1.0, 1.0, 1.0, 1.0)
var _current_wave_amplitude: float = 5.0
var _current_wave_frequency: float = 3.0
var _current_wave_speed: float = 2.5
var _current_lateral_flow_speed: float = 0.0
var _current_depth_threshold: float = 0.1
var _current_foam_thickness: float = 0.02
var _target_lateral_flow_speed: float = 0.0

var _baseWaveAmplitude: float = 5.0
var _baseWaveFrequency: float = 3.0
var _baseWaveSpeed: float = 2.5
var _baseLateralFlowSpeed: float = 0.0
var _stormBlendTarget: float = 0.0
var _stormBlendCurrent: float = 0.0
var _stormDirection: float = 1.0
var _warningDurationSec: float = 60.0
var _warningElapsedSec: float = 0.0
var _recoverDurationSec: float = 3.0
var _recoverRemainingSec: float = 0.0
var _stormPhase: String = 'idle'


## 初始化时将所有导出变量同步到材质。
## @return void
func _ready() -> void:
	_baseWaveAmplitude = _wave_amplitude
	_baseWaveFrequency = _wave_frequency
	_baseWaveSpeed = _wave_speed
	_baseLateralFlowSpeed = _lateral_flow_speed
	_current_color_surface = _color_surface
	_current_color_depth = _color_depth
	_current_color_foam = _color_foam
	_current_wave_amplitude = _wave_amplitude
	_current_wave_frequency = _wave_frequency
	_current_wave_speed = _wave_speed
	_current_lateral_flow_speed = _lateral_flow_speed
	_target_lateral_flow_speed = _lateral_flow_speed
	_current_depth_threshold = _depth_threshold
	_current_foam_thickness = _foam_thickness
	_sync_all_shader_params()
	EventBus.subscribe(_on_event)


## 退出时取消事件订阅。
## @return void
func _exit_tree() -> void:
	EventBus.unsubscribe(_on_event)


## 同步所有参数到 ShaderMaterial，避免编辑器初始状态不同步。
## @return void
func _sync_all_shader_params() -> void:
	_apply_shader_param('color_surface', _current_color_surface)
	_apply_shader_param('color_depth', _current_color_depth)
	_apply_shader_param('color_foam', _current_color_foam)
	_apply_shader_param('wave_amplitude', _current_wave_amplitude)
	_apply_shader_param('wave_frequency', _current_wave_frequency)
	_apply_shader_param('wave_speed', _current_wave_speed)
	_apply_shader_param('lateral_flow_speed', _current_lateral_flow_speed)
	_apply_shader_param('depth_threshold', _current_depth_threshold)
	_apply_shader_param('foam_thickness', _current_foam_thickness)


## 每帧平滑逼近目标参数，避免突变。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	_update_storm_targets(delta)
	var lerpWeight: float = clampf(delta * _transition_speed, 0.0, 1.0)
	_current_color_surface = _current_color_surface.lerp(_color_surface, lerpWeight)
	_current_color_depth = _current_color_depth.lerp(_color_depth, lerpWeight)
	_current_color_foam = _current_color_foam.lerp(_color_foam, lerpWeight)
	_current_wave_amplitude = lerpf(_current_wave_amplitude, _wave_amplitude, lerpWeight)
	_current_wave_frequency = lerpf(_current_wave_frequency, _wave_frequency, lerpWeight)
	_current_wave_speed = lerpf(_current_wave_speed, _wave_speed, lerpWeight)
	var flowLerpTarget: float = lerpf(_current_lateral_flow_speed, _target_lateral_flow_speed, lerpWeight)
	_current_lateral_flow_speed = move_toward(_current_lateral_flow_speed, flowLerpTarget, max(flow_speed_max_change_per_sec, 0.001) * delta)
	_current_depth_threshold = lerpf(_current_depth_threshold, _depth_threshold, lerpWeight)
	_current_foam_thickness = lerpf(_current_foam_thickness, _foam_thickness, lerpWeight)
	_sync_all_shader_params()


## 根据风暴阶段更新波浪目标值。
## @param delta 帧间隔（秒）
## @return void
func _update_storm_targets(delta: float) -> void:
	match _stormPhase:
		'warning':
			_warningElapsedSec += delta
			var warningProgress: float = clampf(_warningElapsedSec / max(_warningDurationSec, 0.001), 0.0, 1.0)
			_stormBlendTarget = warningProgress
		'storm':
			_stormBlendTarget = 1.0
		'recover':
			_recoverRemainingSec = max(_recoverRemainingSec - delta, 0.0)
			_stormBlendTarget = clampf(_recoverRemainingSec / max(_recoverDurationSec, 0.001), 0.0, 1.0)
		_:
			_stormBlendTarget = 0.0

	var blendLerpWeight: float = clampf(delta * _transition_speed, 0.0, 1.0)
	_stormBlendCurrent = lerpf(_stormBlendCurrent, _stormBlendTarget, blendLerpWeight)

	_wave_amplitude = lerpf(_baseWaveAmplitude, storm_peak_wave_amplitude, _stormBlendCurrent)
	_wave_speed = lerpf(_baseWaveSpeed, storm_peak_wave_speed, _stormBlendCurrent)
	_wave_frequency = lerpf(_baseWaveFrequency, storm_peak_wave_frequency, _stormBlendCurrent)
	var stormFlowTarget: float = absf(storm_flow_speed) * _stormDirection
	_target_lateral_flow_speed = lerpf(_baseLateralFlowSpeed, stormFlowTarget, _stormBlendCurrent)


## 统一写入 shader 参数。
## @param key shader 参数名
## @param value 参数值
## @return void
func _apply_shader_param(key: String, value: Variant) -> void:
	var shaderMaterial: ShaderMaterial = material as ShaderMaterial
	if shaderMaterial == null:
		return
	shaderMaterial.set_shader_parameter(key, value)


## 响应风暴事件，切换水面联动阶段。
## @param eventType 事件类型
## @param data 事件数据
## @return void
func _on_event(eventType: EventBus.EventType, data: Dictionary) -> void:
	match eventType:
		EventBus.EventType.STORM_WARNING_STARTED:
			_warningDurationSec = max(_as_float(data.get('duration_seconds', 60.0), 60.0), 0.001)
			_warningElapsedSec = 0.0
			_stormPhase = 'warning'
		EventBus.EventType.STORM_STARTED:
			_stormDirection = signf(_as_float(data.get('direction', 1.0), 1.0))
			if is_zero_approx(_stormDirection):
				_stormDirection = 1.0
			_stormPhase = 'storm'
		EventBus.EventType.STORM_DIRECTION_CHANGED:
			_stormDirection = signf(_as_float(data.get('direction', 1.0), 1.0))
			if is_zero_approx(_stormDirection):
				_stormDirection = 1.0
		EventBus.EventType.STORM_RECOVER_STARTED:
			_recoverDurationSec = max(_as_float(data.get('duration_seconds', 3.0), 3.0), 0.001)
			_recoverRemainingSec = _recoverDurationSec
			_stormPhase = 'recover'
		EventBus.EventType.STORM_ENDED:
			_stormPhase = 'idle'
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
