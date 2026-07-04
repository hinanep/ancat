extends Node

## 风暴时序参数：仅负责状态推进与事件广播。
## 两次风暴之间的间隔（秒）
@export var cycleIntervalSec: float = 300.0
## 预警时长（秒）
@export var warningDurationSec: float = 60.0
## 单次左右方向持续时长（秒）
@export var stormHalfCycleDurationSec: float = 30.0
## 最小方向段数
@export var stormHalfCyclesMin: int = 2
## 最大方向段数
@export var stormHalfCyclesMax: int = 6
## 最小倾斜角度（度）
@export var tiltMinDeg: float = 20.0
## 最大倾斜角度（度）
@export var tiltMaxDeg: float = 30.0
## 恢复时长（秒）
@export var recoverDurationSec: float = 3.0
## 是否输出调试日志
@export var debugStormLog: bool = false

enum StormState {
	IDLE,
	WARNING,
	STORM,
	RECOVER
}

var _state: StormState = StormState.IDLE
var _stateTimer: float = 0.0

var _stormHalfCyclesTotal: int = 0
var _stormHalfCyclesDone: int = 0
var _stormDirection: float = 1.0
var _stormTiltDeg: float = 0.0
var _recoverStartTiltDeg: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## 初始化状态机。
## @return void
func _ready() -> void:
	_rng.randomize()
	_enter_idle()
	_debug_log('ready')


## 每帧推进风暴时序。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	match _state:
		StormState.IDLE:
			_update_idle(delta)
		StormState.WARNING:
			_update_warning(delta)
		StormState.STORM:
			_update_storm(delta)
		StormState.RECOVER:
			_update_recover(delta)


## 进入空闲阶段。
## @return void
func _enter_idle() -> void:
	_state = StormState.IDLE
	_stateTimer = cycleIntervalSec
	_debug_log('enter IDLE timer=%s' % _stateTimer)


## 进入预警阶段并发送开始事件。
## @return void
func _enter_warning() -> void:
	_state = StormState.WARNING
	_stateTimer = warningDurationSec
	AudioManager.play_sfx(ResPath.AUDIO.STORM_WARNING)
	EventBus.emit(EventBus.EventType.STORM_WARNING_STARTED, {
		'remaining_seconds': int(ceil(_stateTimer)),
		'duration_seconds': warningDurationSec
	})
	_debug_log('enter WARNING timer=%s' % _stateTimer)


## 进入风暴阶段并发送开始事件。
## @return void
func _enter_storm() -> void:
	_state = StormState.STORM
	_stateTimer = stormHalfCycleDurationSec
	_stormHalfCyclesTotal = _rng.randi_range(stormHalfCyclesMin, stormHalfCyclesMax)
	_stormHalfCyclesDone = 0
	_stormDirection = -1.0 if _rng.randi_range(0, 1) == 0 else 1.0
	_stormTiltDeg = _rng.randf_range(tiltMinDeg, tiltMaxDeg)

	var totalStormSeconds: int = int(_stormHalfCyclesTotal * stormHalfCycleDurationSec)
	EventBus.emit(EventBus.EventType.STORM_STARTED, {
		'remaining_seconds': totalStormSeconds,
		'half_cycle_duration_seconds': stormHalfCycleDurationSec,
		'half_cycles_total': _stormHalfCyclesTotal,
		'direction': _stormDirection,
		'tilt_deg': _stormTiltDeg
	})
	_debug_log('enter STORM halfCycles=%s tilt=%s dir=%s' % [_stormHalfCyclesTotal, _stormTiltDeg, _stormDirection])


## 进入恢复阶段并发送恢复开始事件。
## @return void
func _enter_recover() -> void:
	_state = StormState.RECOVER
	_stateTimer = recoverDurationSec
	_recoverStartTiltDeg = _stormDirection * _stormTiltDeg
	EventBus.emit(EventBus.EventType.STORM_RECOVER_STARTED, {
		'duration_seconds': recoverDurationSec,
		'from_tilt_deg': _recoverStartTiltDeg
	})
	_debug_log('enter RECOVER timer=%s fromTilt=%s' % [_stateTimer, _recoverStartTiltDeg])


## 空闲阶段更新。
## @param delta 帧间隔（秒）
## @return void
func _update_idle(delta: float) -> void:
	_stateTimer -= delta
	if _stateTimer <= 0.0:
		_enter_warning()


## 预警阶段更新。
## @param delta 帧间隔（秒）
## @return void
func _update_warning(delta: float) -> void:
	_stateTimer -= delta

	if _stateTimer <= 0.0:
		_enter_storm()


## 风暴阶段更新：到点换向，结束后进入恢复。
## @param delta 帧间隔（秒）
## @return void
func _update_storm(delta: float) -> void:
	_stateTimer -= delta
	if _stateTimer > 0.0:
		return

	_stormHalfCyclesDone += 1
	if _stormHalfCyclesDone >= _stormHalfCyclesTotal:
		_enter_recover()
		return

	_stormDirection *= -1.0
	_stateTimer = stormHalfCycleDurationSec
	EventBus.emit(EventBus.EventType.STORM_DIRECTION_CHANGED, {
		'direction': _stormDirection,
		'tilt_deg': _stormTiltDeg
	})


## 恢复阶段更新，结束后广播风暴结束。
## @param delta 帧间隔（秒）
## @return void
func _update_recover(delta: float) -> void:
	_stateTimer -= delta
	if _stateTimer > 0.0:
		return

	EventBus.emit(EventBus.EventType.STORM_ENDED, {})
	_enter_idle()


## 打印调试日志。
## @param message 日志文本
## @return void
func _debug_log(message: String) -> void:
	if not debugStormLog:
		return
	print('[StormController] %s' % message)
