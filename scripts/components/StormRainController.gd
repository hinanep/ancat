extends Node2D

## 风暴雨粒子控制器：订阅 EventBus，控制 CPUParticles2D 开关、雨向与视口适配。

## 风暴期间目标强度（0–1，映射到粒子 amount）
@export var rainIntensity: float = 1.0
## 雨淡入时长（秒）
@export var fadeInSec: float = 0.8
## 雨淡出时长（秒）
@export var fadeOutSec: float = 1.5
## 相对垂直线的雨倾斜角（度）
@export var baseRainAngleDeg: float = 15.0
## 恢复阶段雨势比例
@export var recoverIntensityRatio: float = 0.3

@onready var _particles: CPUParticles2D = $RainParticles

var _baseAmount: int = 400
var _intensity: float = 0.0
var _stormDirection: float = 1.0
var _intensityTween: Tween


## 初始化粒子状态并订阅风暴事件。
## @return void
func _ready() -> void:
	if _particles == null:
		push_error('StormRainController: RainParticles node missing')
		return
	_baseAmount = maxi(_particles.amount, 1)
	_particles.emitting = false
	_intensity = 0.0
	_update_emission_rect()
	EventBus.subscribe(_on_event)


## 退出时取消事件订阅。
## @return void
func _exit_tree() -> void:
	EventBus.unsubscribe(_on_event)


## 每帧更新发射区域以适配视口与缩放，并跟随相机中心。
## @param _delta 帧间隔（秒）
## @return void
func _process(_delta: float) -> void:
	_sync_camera_position()
	_update_emission_rect()


## 将雨区对齐到当前相机中心（世界坐标）。
## @return void
func _sync_camera_position() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	global_position = camera.global_position


## 按相机 zoom 与父节点缩放设置矩形发射范围。
## @return void
func _update_emission_rect() -> void:
	if _particles == null:
		return
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	var viewportSize: Vector2 = get_viewport_rect().size
	var parentScale: Vector2 = get_parent().scale if get_parent() != null else Vector2.ONE
	var safeScale: Vector2 = Vector2(
		max(absf(parentScale.x), 0.001),
		max(absf(parentScale.y), 0.001)
	)
	var half: Vector2 = (viewportSize / camera.zoom) * 0.6 / safeScale
	_particles.emission_rect_extents = half


## 响应风暴事件，控制雨开关、强度与方向。
## @param event_type 事件类型
## @param data 事件数据
## @return void
func _on_event(event_type: EventBus.EventType, data: Dictionary) -> void:
	if _particles == null:
		return
	match event_type:
		EventBus.EventType.STORM_STARTED:
			_stormDirection = float(data.get('direction', 1.0))
			_apply_rain_direction(_stormDirection)
			_particles.emitting = true
			_fade_intensity(rainIntensity, fadeInSec)
		EventBus.EventType.STORM_DIRECTION_CHANGED:
			_stormDirection = float(data.get('direction', _stormDirection))
			_apply_rain_direction(_stormDirection)
		EventBus.EventType.STORM_RECOVER_STARTED:
			_fade_intensity(rainIntensity * recoverIntensityRatio, fadeOutSec * 0.5)
		EventBus.EventType.STORM_ENDED:
			_fade_intensity(0.0, fadeOutSec, true)


## 按风暴方向设置粒子 direction 与 gravity。
## @param direction 风暴方向（±1）
## @return void
func _apply_rain_direction(direction: float) -> void:
	var windX: float = direction * tan(deg_to_rad(baseRainAngleDeg))
	_particles.direction = Vector2(windX, 1.0).normalized()
	_particles.gravity = Vector2(windX * 200.0, 900.0)


## 将强度比例应用到 CPUParticles2D.amount（amount 最小为 1）。
## @param value 强度（0–1）
## @return void
func _apply_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	if _intensity <= 0.0:
		return
	_particles.amount = maxi(1, int(round(float(_baseAmount) * _intensity)))


## 缓动雨强度；目标为 0 时可停止发射。
## @param target 目标强度
## @param duration 时长（秒）
## @param stopEmittingOnZero 归零后是否停止 emitting
## @return void
func _fade_intensity(target: float, duration: float, stopEmittingOnZero: bool = false) -> void:
	if _intensityTween != null and _intensityTween.is_valid():
		_intensityTween.kill()
	var tweenDuration: float = max(duration, 0.0)
	if tweenDuration <= 0.0:
		_apply_intensity(target)
		if stopEmittingOnZero and target <= 0.0:
			_particles.emitting = false
		return
	_intensityTween = create_tween()
	_intensityTween.tween_method(_apply_intensity, _intensity, target, tweenDuration)
	if stopEmittingOnZero and target <= 0.0:
		_intensityTween.tween_callback(func() -> void:
			_particles.emitting = false
		)
