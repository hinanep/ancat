extends CharacterBody2D

## 角色控制参数
## @moveSpeed 水平移动速度（像素/秒）
## @jumpVelocity 起跳初速度（向上为负）
## @gravityScale 重力缩放倍率
@export var moveSpeed: float = 240.0
@export var jumpVelocity: float = -420.0
@export var gravityScale: float = 1.0

var _scaleX: float = 1.0
var _lastFacingDir: float = 1.0

@onready var _sprite: CanvasItem = $Sprite

## 初始化朝向：默认朝右，并记录可翻转最大缩放值。
## @return void
func _ready() -> void:
	if _sprite == null:
		return
	_scaleX = absf(_sprite.scale.x)
	if _scaleX <= 0.0:
		_scaleX = 1.0
	_sprite.scale.x = _scaleX
	_lastFacingDir = 1.0


## 每帧物理更新：处理重力、横向移动、跳跃与移动求解。
## @param delta 物理帧间隔（秒）
## @return void
func _physics_process(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting('physics/2d/default_gravity', 980.0)

	if not is_on_floor():
		velocity.y += gravity * gravityScale * delta

	var horizontalInput: float = Input.get_axis('ui_left', 'ui_right')
	velocity.x = horizontalInput * moveSpeed
	if _sprite != null:
		var speedDir: float = sign(velocity.x)
		if speedDir != 0.0:
			_lastFacingDir = speedDir
		var scaleDir: float = speedDir
		if scaleDir == 0.0:
			scaleDir = _lastFacingDir
		_sprite.scale.x = clampf(_sprite.scale.x + 0.2 * scaleDir, -_scaleX, _scaleX)

	if Input.is_action_just_pressed('ui_accept') and is_on_floor():
		velocity.y = jumpVelocity

	move_and_slide()
