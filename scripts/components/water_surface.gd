@tool
extends Polygon2D

## 水面表现参数：集中控制 shader 的颜色、波浪与风格化阈值。
## @color_surface 浅水/表层颜色
## @color_depth 深水颜色
## @color_foam 浪沫颜色
## @wave_amplitude 波浪振幅
## @wave_frequency 波浪频率
## @wave_speed 波浪速度
## @depth_threshold 深水阈值
## @foam_thickness 浪沫厚度
## @transition_speed 参数过渡速度（越大越快）
@export var color_surface: Color = Color(0.25, 0.71, 0.96, 1.0):
	set(value):
		_color_surface = value
	get:
		return _color_surface

@export var color_depth: Color = Color(0.08, 0.35, 0.70, 1.0):
	set(value):
		_color_depth = value
	get:
		return _color_depth

@export var color_foam: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		_color_foam = value
	get:
		return _color_foam

@export var wave_amplitude: float = 5.0:
	set(value):
		_wave_amplitude = max(value, 0.0)
	get:
		return _wave_amplitude

@export var wave_frequency: float = 3.0:
	set(value):
		_wave_frequency = max(value, 0.0)
	get:
		return _wave_frequency

@export var wave_speed: float = 2.5:
	set(value):
		_wave_speed = max(value, 0.0)
	get:
		return _wave_speed

@export var depth_threshold: float = 0.1:
	set(value):
		_depth_threshold = clampf(value, 0.0, 1.0)
	get:
		return _depth_threshold

@export var foam_thickness: float = 0.02:
	set(value):
		_foam_thickness = clampf(value, 0.0, 1.0)
	get:
		return _foam_thickness

@export var transition_speed: float = 3.0:
	set(value):
		_transition_speed = max(value, 0.01)
	get:
		return _transition_speed

var _color_surface: Color = Color(0.25, 0.71, 0.96, 1.0)
var _color_depth: Color = Color(0.08, 0.35, 0.70, 1.0)
var _color_foam: Color = Color(1.0, 1.0, 1.0, 1.0)
var _wave_amplitude: float = 5.0
var _wave_frequency: float = 3.0
var _wave_speed: float = 2.5
var _depth_threshold: float = 0.1
var _foam_thickness: float = 0.02
var _transition_speed: float = 3.0

var _current_color_surface: Color = Color(0.25, 0.71, 0.96, 1.0)
var _current_color_depth: Color = Color(0.08, 0.35, 0.70, 1.0)
var _current_color_foam: Color = Color(1.0, 1.0, 1.0, 1.0)
var _current_wave_amplitude: float = 5.0
var _current_wave_frequency: float = 3.0
var _current_wave_speed: float = 2.5
var _current_depth_threshold: float = 0.1
var _current_foam_thickness: float = 0.02


## 初始化时将所有导出变量同步到材质。
## @return void
func _ready() -> void:
	_current_color_surface = _color_surface
	_current_color_depth = _color_depth
	_current_color_foam = _color_foam
	_current_wave_amplitude = _wave_amplitude
	_current_wave_frequency = _wave_frequency
	_current_wave_speed = _wave_speed
	_current_depth_threshold = _depth_threshold
	_current_foam_thickness = _foam_thickness
	_sync_all_shader_params()


## 同步所有参数到 ShaderMaterial，避免编辑器初始状态不同步。
## @return void
func _sync_all_shader_params() -> void:
	_apply_shader_param('color_surface', _current_color_surface)
	_apply_shader_param('color_depth', _current_color_depth)
	_apply_shader_param('color_foam', _current_color_foam)
	_apply_shader_param('wave_amplitude', _current_wave_amplitude)
	_apply_shader_param('wave_frequency', _current_wave_frequency)
	_apply_shader_param('wave_speed', _current_wave_speed)
	_apply_shader_param('depth_threshold', _current_depth_threshold)
	_apply_shader_param('foam_thickness', _current_foam_thickness)


## 每帧平滑逼近目标参数，避免突变。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	var lerpWeight: float = clampf(delta * _transition_speed, 0.0, 1.0)
	_current_color_surface = _current_color_surface.lerp(_color_surface, lerpWeight)
	_current_color_depth = _current_color_depth.lerp(_color_depth, lerpWeight)
	_current_color_foam = _current_color_foam.lerp(_color_foam, lerpWeight)
	_current_wave_amplitude = lerpf(_current_wave_amplitude, _wave_amplitude, lerpWeight)
	_current_wave_frequency = lerpf(_current_wave_frequency, _wave_frequency, lerpWeight)
	_current_wave_speed = lerpf(_current_wave_speed, _wave_speed, lerpWeight)
	_current_depth_threshold = lerpf(_current_depth_threshold, _depth_threshold, lerpWeight)
	_current_foam_thickness = lerpf(_current_foam_thickness, _foam_thickness, lerpWeight)
	_sync_all_shader_params()


## 统一写入 shader 参数。
## @param key shader 参数名
## @param value 参数值
## @return void
func _apply_shader_param(key: String, value: Variant) -> void:
	var shaderMaterial: ShaderMaterial = material as ShaderMaterial
	if shaderMaterial == null:
		return
	shaderMaterial.set_shader_parameter(key, value)
