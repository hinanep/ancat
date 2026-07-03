extends Node2D

## 船体浮动参数：用于控制整体上下浮动与轻微摇摆。
## @floatAmplitudeY 上下浮动幅度（像素）
## @floatFrequencyHz 上下浮动频率（Hz）
## @rollAmplitudeDeg 摇摆角度幅度（度）
## @rollFrequencyHz 摇摆频率（Hz）
## @phaseOffset 相位偏移（秒）
@export var floatAmplitudeY: float = 5.0
@export var floatFrequencyHz: float = 0.28
@export var rollAmplitudeDeg: float = 1.8
@export var rollFrequencyHz: float = 0.22
@export var phaseOffset: float = 0.0

var _basePosition: Vector2 = Vector2.ZERO
var _baseRotation: float = 0.0
var _elapsed: float = 0.0


## 记录初始姿态，作为浮动基准。
## @return void
func _ready() -> void:
	_basePosition = position
	_baseRotation = rotation


## 每帧更新浮动与摇摆效果。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	_elapsed += delta
	var waveTime: float = _elapsed + phaseOffset
	var yWave: float = sin(TAU * floatFrequencyHz * waveTime)
	var rollWave: float = sin(TAU * rollFrequencyHz * waveTime + 0.9)

	position.y = _basePosition.y + yWave * floatAmplitudeY
	rotation = _baseRotation + deg_to_rad(rollWave * rollAmplitudeDeg)
