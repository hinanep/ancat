extends CharacterBody2D

## 角色控制参数
## @moveSpeed 水平移动速度（像素/秒）
## @jumpVelocity 起跳初速度（向上为负）
## @gravityScale 重力缩放倍率
## @slopeMoveScale 坡度对水平移动的加减速影响系数
## @anchorCount 手中锚数量（决定可并行勾取数量）
## @hookMoveBoundsMargin 拉拽时船内边界安全边距（像素）
@export var moveSpeed: float = 240.0
@export var jumpVelocity: float = -420.0
@export var gravityScale: float = 1.0
@export var slopeMoveScale: float = 0.45
@export var anchorCount: int = 1
@export var hookMoveBoundsMargin: float = 12.0
@export var footstepIntervalSec: float = 0.35

var _scaleX: float = 1.0
var _lastFacingDir: float = 1.0
var _anchorPullActive: bool = false
var _anchorPullTarget: Vector2 = Vector2.ZERO
var _anchorPullSpeed: float = 0.0
var _anchorCollisionDisabled: bool = false
var _savedCollisionLayer: int = 0
var _savedCollisionMask: int = 0
var _footstepCooldownSec: float = 0.0

var current_cabin_name: String = ''
var current_cabin_path: NodePath = NodePath('')

const _AGENT_DEBUG_LOG_PATH: String = 'C:/Users/nep/Desktop/mao/debug-43bc79.log'
const _AGENT_DEBUG_SESSION_ID: String = '43bc79'
const _AGENT_DEBUG_RUN_ID: String = 'wall-gap-pre'

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
	_update_current_cabin()
	_footstepCooldownSec = max(_footstepCooldownSec - delta, 0.0)
	if _anchorPullActive:
		_process_anchor_pull(delta)
		return

	var gravity: float = ProjectSettings.get_setting('physics/2d/default_gravity', 980.0)

	if not is_on_floor():
		velocity.y += gravity * gravityScale * delta

	var horizontalInput: float = Input.get_axis('ui_left', 'ui_right')
	var slopeFactor: float = 1.0 + sin(_ship_tilt_rad()) * horizontalInput * slopeMoveScale
	velocity.x = horizontalInput * moveSpeed * slopeFactor
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
	_try_play_footstep(horizontalInput)


## 开始锚拉拽移动。
## @param targetGlobal 目标点（全局坐标）
## @param pullSpeed 拉拽速度
## @param disableCollision 是否关闭碰撞
## @return void
func begin_anchor_pull(targetGlobal: Vector2, pullSpeed: float, disableCollision: bool) -> void:
	_anchorPullActive = true
	_anchorPullTarget = targetGlobal
	_anchorPullSpeed = max(pullSpeed, 1.0)
	#region agent log
	_agent_debug_emit(
		'H3',
		'TestPlayerController.gd:begin_anchor_pull',
		'anchor pull started',
		{
			'playerPos': {'x': global_position.x, 'y': global_position.y},
			'pullTarget': {'x': targetGlobal.x, 'y': targetGlobal.y}
		}
	)
	#endregion
	if disableCollision and not _anchorCollisionDisabled:
		_savedCollisionLayer = collision_layer
		_savedCollisionMask = collision_mask
		collision_layer = 0
		collision_mask = 0
		_anchorCollisionDisabled = true


## 停止锚拉拽并恢复常规移动状态。
## @return void
func end_anchor_pull() -> void:
	_anchorPullActive = false
	_anchorPullSpeed = 0.0
	velocity = Vector2.ZERO
	if _anchorCollisionDisabled:
		collision_layer = _savedCollisionLayer
		collision_mask = _savedCollisionMask
		_anchorCollisionDisabled = false


## 锚拉拽阶段的玩家移动。
## @param delta 物理帧间隔（秒）
## @return void
func _process_anchor_pull(delta: float) -> void:
	var toTarget: Vector2 = _anchorPullTarget - global_position
	var stepLen: float = _anchorPullSpeed * delta
	if toTarget.length() <= max(stepLen, 0.001):
		global_position = _anchorPullTarget
		_finalize_anchor_pull_position()
		end_anchor_pull()
		return
	var moveVec: Vector2 = toTarget.normalized() * stepLen
	if _anchorCollisionDisabled:
		global_position += moveVec
		velocity = Vector2.ZERO
		return
	velocity = moveVec / max(delta, 0.0001)
	move_and_slide()


## 刷新玩家当前所属舱室信息。
## @return void
func _update_current_cabin() -> void:
	current_cabin_name = ''
	current_cabin_path = NodePath('')
	for node in get_tree().get_nodes_in_group('Cabin'):
		if not (node is Cabin):
			continue
		var cabin: Cabin = node as Cabin
		if _is_inside_cabin(cabin, global_position):
			current_cabin_name = String(cabin.name)
			current_cabin_path = cabin.get_path()
			return


## 判断点是否在舱室包围范围内。
## @param cabin 舱室
## @param pointGlobal 全局点
## @return bool
func _is_inside_cabin(cabin: Cabin, pointGlobal: Vector2) -> bool:
	var localPos: Vector2 = cabin.to_local(pointGlobal)
	var width: float = float(cabin.get('cabin_width'))
	var height: float = float(cabin.get('cabin_height'))
	var halfW: float = width * 0.5
	var halfH: float = height * 0.5
	return localPos.x >= -halfW and localPos.x <= halfW and localPos.y >= -halfH and localPos.y <= halfH


## 读取船体当前倾斜角。
## @return float
func _ship_tilt_rad() -> float:
	if get_parent() is Node2D:
		return (get_parent() as Node2D).rotation
	return 0.0


## 将玩家位置限制在船舱整体范围内（主要用于锚拉拽阶段防出界）。
## @return void
func _clamp_to_ship_bounds() -> void:
	if _anchorPullActive:
		return
	if not (get_parent() is Node2D):
		return
	var parentNode: Node2D = get_parent() as Node2D
	var minX: float = INF
	var maxX: float = -INF
	var minY: float = INF
	var maxY: float = -INF
	var foundAny: bool = false

	for node in get_tree().get_nodes_in_group('Cabin'):
		if not (node is Cabin):
			continue
		var cabin: Cabin = node as Cabin
		if cabin.get_parent() != parentNode:
			continue
		var width: float = float(cabin.get('cabin_width')) * absf(cabin.scale.x)
		var height: float = float(cabin.get('cabin_height')) * absf(cabin.scale.y)
		var halfW: float = width * 0.5
		var halfH: float = height * 0.5
		var left: float = cabin.position.x - halfW
		var right: float = cabin.position.x + halfW
		var top: float = cabin.position.y - halfH
		var bottom: float = cabin.position.y + halfH
		minX = min(minX, left)
		maxX = max(maxX, right)
		minY = min(minY, top)
		maxY = max(maxY, bottom)
		foundAny = true

	if not foundAny:
		return
	var margin: float = max(hookMoveBoundsMargin, 0.0)
	position.x = clampf(position.x, minX + margin, maxX - margin)
	position.y = clampf(position.y, minY + margin, maxY - margin)


## 锚拉拽结束时，将玩家锁定到最近舱室的合法位置。
## @return void
func _finalize_anchor_pull_position() -> void:
	var margin: float = max(hookMoveBoundsMargin, 0.0)
	var posBefore: Vector2 = global_position
	var pullTarget: Vector2 = _anchorPullTarget
	var targetCabin: Cabin = _find_nearest_cabin_to_point(global_position)
	if targetCabin == null:
		#region agent log
		_agent_debug_emit(
			'H5',
			'TestPlayerController.gd:_finalize_anchor_pull_position',
			'finalize skipped no cabin',
			{
				'posBefore': {'x': posBefore.x, 'y': posBefore.y},
				'pullTarget': {'x': pullTarget.x, 'y': pullTarget.y}
			}
		)
		#endregion
		return
	var inBoundsAny: bool = _find_cabin_for_interior_clamp(global_position, false) != null
	var inInteriorAny: bool = _find_cabin_for_interior_clamp(global_position, true) != null
	var branch: String = 'bounds'
	if inBoundsAny:
		global_position = targetCabin.clamp_global_to_bounds(global_position, margin)
	else:
		branch = 'interior'
		global_position = targetCabin.clamp_global_to_interior(global_position, margin)
	var pullTargetCabin: Cabin = _find_nearest_cabin_to_point(pullTarget)
	#region agent log
	_agent_debug_emit(
		'H2',
		'TestPlayerController.gd:_finalize_anchor_pull_position',
		'anchor pull finalized',
		{
			'posBefore': {'x': posBefore.x, 'y': posBefore.y},
			'posAfter': {'x': global_position.x, 'y': global_position.y},
			'pullTarget': {'x': pullTarget.x, 'y': pullTarget.y},
			'targetDistToPullTarget': posBefore.distance_to(pullTarget),
			'branch': branch,
			'inBoundsAnyBefore': inBoundsAny,
			'inInteriorAnyBefore': inInteriorAny,
			'finalizeCabinPath': String(targetCabin.get_path()),
			'pullTargetCabinPath': String(pullTargetCabin.get_path()) if pullTargetCabin != null else '',
			'cabinMismatch': pullTargetCabin != null and targetCabin != pullTargetCabin,
			'afterInBounds': targetCabin.contains_bounds_point(global_position),
			'afterInInterior': targetCabin.contains_interior_point(global_position),
			'isOnFloorAfter': is_on_floor()
		}
	)
	#endregion


## 查找距指定点最近的舱室（按 clamp 到外壳 bounds 后的距离）。
## @param pointGlobal 全局坐标
## @return Cabin
func _find_nearest_cabin_to_point(pointGlobal: Vector2) -> Cabin:
	var bestCabin: Cabin = null
	var bestDistSq: float = INF
	for node in get_tree().get_nodes_in_group('Cabin'):
		if not (node is Cabin):
			continue
		var cabin: Cabin = node as Cabin
		var clamped: Vector2 = cabin.clamp_global_to_bounds(pointGlobal, 0.0)
		var distSq: float = pointGlobal.distance_squared_to(clamped)
		if distSq < bestDistSq:
			bestDistSq = distSq
			bestCabin = cabin
	return bestCabin


## 查找用于内区 clamp 的舱室。
## @param pointGlobal 全局坐标
## @param requireInterior 是否要求点在地板内区
## @return Cabin
func _find_cabin_for_interior_clamp(pointGlobal: Vector2, requireInterior: bool) -> Cabin:
	for node in get_tree().get_nodes_in_group('Cabin'):
		if not (node is Cabin):
			continue
		var cabin: Cabin = node as Cabin
		if requireInterior:
			if cabin.contains_interior_point(pointGlobal):
				return cabin
		elif cabin.contains_bounds_point(pointGlobal):
			return cabin
	return null


## 调试日志写入。
## @param hypothesisId 假设编号
## @param location 位置
## @param message 消息
## @param data 数据
## @return void
func _agent_debug_emit(hypothesisId: String, location: String, message: String, data: Dictionary) -> void:
	var payload: Dictionary = {
		'sessionId': _AGENT_DEBUG_SESSION_ID,
		'runId': _AGENT_DEBUG_RUN_ID,
		'hypothesisId': hypothesisId,
		'location': location,
		'message': message,
		'data': data,
		'timestamp': Time.get_unix_time_from_system() * 1000.0
	}
	var file: FileAccess = null
	if FileAccess.file_exists(_AGENT_DEBUG_LOG_PATH):
		file = FileAccess.open(_AGENT_DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	else:
		file = FileAccess.open(_AGENT_DEBUG_LOG_PATH, FileAccess.WRITE_READ)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(payload))


## 按移动状态与地面状态播放脚步声。
## @param horizontalInput 水平输入
## @return void
func _try_play_footstep(horizontalInput: float) -> void:
	if not is_on_floor():
		return
	if is_zero_approx(horizontalInput):
		return
	if _footstepCooldownSec > 0.0:
		return
	_footstepCooldownSec = max(footstepIntervalSec, 0.1)
	AudioManager.play_sfx_random(ResPath.AUDIO.FOOTSTEP_WOOD)
