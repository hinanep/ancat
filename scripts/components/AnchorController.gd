extends Node2D

## 锚控制参数：发射、回收、勾取与放锚冻结。
## 锚最大长度（像素）。
@export var maxAnchorLength: float = 520.0
## 锚发射速度（像素/秒）。
@export var anchorLaunchSpeed: float = 700.0
## 锚回收速度（像素/秒）。
@export var retractSpeed: float = 780.0
## 拉玩家速度（像素/秒）。
@export var playerPullSpeed: float = 520.0
## 拉物体速度（像素/秒）。
@export var cargoPullSpeed: float = 420.0
## 同时可用锚数量。
@export var anchorCount: int = 1
## 地板命中允许的最高 Y 偏移（只允许同层或更高层）。
@export var floorHookMaxYOffset: float = 4.0
## 钩中地板后，玩家终点向上偏移（像素）。
@export var floorPullUpOffset: float = 36.0
## 玩家携带物体时头顶偏移。
@export var carryOffset: Vector2 = Vector2(0.0, -34.0)
## 调试日志开关。
@export var debug_anchor_log: bool = false

var _hooks: Array[Dictionary] = []
var _carriedCargo: Array[Node] = []
var _anchorDeployed: bool = false
var _deployedCabinPath: NodePath = NodePath('')
var _player: Node
var _line: Line2D
var _leftPressedPrev: bool = false
var _rightPressedPrev: bool = false


## 初始化缓存与可视链条。
## @return void
func _ready() -> void:
	_player = get_parent()
	_ensure_line()


## 每帧处理输入与回收逻辑。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	_update_line()
	if _player == null or not (_player is Node2D):
		return

	var leftPressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var rightPressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

	if leftPressed and not _leftPressedPrev:
		_fire_anchor()
	if not _hooks.is_empty():
		_update_retract(delta)

	if rightPressed and not _rightPressedPrev:
		_handle_right_click()

	_leftPressedPrev = leftPressed
	_rightPressedPrev = rightPressed


## 创建锚链可视节点。
## @return void
func _ensure_line() -> void:
	_line = Line2D.new()
	_line.width = 2.0
	_line.default_color = Color(0.95, 0.92, 0.78, 0.95)
	_line.z_index = 100
	add_child(_line)


## 更新锚链可视。
## @return void
func _update_line() -> void:
	if _line == null:
		return
	_line.clear_points()
	if _hooks.is_empty():
		return
	var origin: Vector2 = (_player as Node2D).global_position
	var hookPos: Vector2 = _hooks[0].get('pos', origin)
	_line.add_point(to_local(origin))
	_line.add_point(to_local(hookPos))


## 发射锚：终点尽量落在鼠标位置，超长才截断。
## @return void
func _fire_anchor() -> void:
	if _hooks.size() >= max(anchorCount, 1):
		return
	if not (_player is Node2D):
		return
	var origin: Vector2 = (_player as Node2D).global_position
	var mouseGlobal: Vector2 = get_global_mouse_position()
	var toMouse: Vector2 = mouseGlobal - origin
	var distanceToMouse: float = toMouse.length()
	if is_zero_approx(distanceToMouse):
		return
	var clampedDistance: float = min(distanceToMouse, maxAnchorLength)
	var endPos: Vector2 = origin + toMouse.normalized() * clampedDistance
	var hookData: Dictionary = {
		'state': 'launching',
		'pos': origin,
		'end_pos': endPos
	}
	_hooks.append(hookData)
	EventBus.emit(EventBus.EventType.ANCHOR_FIRED, {'from': origin, 'to': endPos})
	_debug_log('fire to %s' % endPos)


## 回收逻辑：先命中回收线第一个合法目标，再执行拉拽。
## @param delta 帧间隔（秒）
## @return void
func _update_retract(delta: float) -> void:
	if _hooks.is_empty():
		return
	var hook: Dictionary = _hooks[0]
	var state: String = String(hook.get('state', 'flying_end'))
	if not (_player is Node2D):
		return
	var origin: Vector2 = (_player as Node2D).global_position
	var hookPos: Vector2 = hook.get('pos', origin)

	if state == 'launching':
		var launchTarget: Vector2 = hook.get('end_pos', hookPos)
		var launchNext: Vector2 = hookPos.move_toward(launchTarget, max(anchorLaunchSpeed, 1.0) * delta)
		hook['pos'] = launchNext
		_hooks[0] = hook
		if launchNext.distance_to(launchTarget) <= 2.0:
			hook['state'] = 'retracting'
			_hooks[0] = hook
		return

	if state == 'retracting':
		var nextPos: Vector2 = hookPos.move_toward(origin, retractSpeed * delta)
		var hit: Dictionary = _find_first_valid_hit(nextPos, hookPos)
		if not hit.is_empty():
			var hitType: String = String(hit.get('type', ''))
			if hitType == 'cargo':
				var cargo: Node = hit.get('cargo', null)
				if cargo != null and cargo.has_method('set_hooked'):
					cargo.call('set_hooked', self)
					hook['state'] = 'hooked_cargo'
					hook['cargo'] = cargo
					hook['pos'] = hit.get('position', (cargo as Node2D).global_position if cargo is Node2D else position)
					_hooks[0] = hook
					EventBus.emit(EventBus.EventType.ANCHOR_HIT_CARGO, {'node': String(cargo.get_path())})
					_debug_log('hook cargo %s' % cargo.name)
					return
			elif hitType == 'floor':
				var targetPos: Vector2 = hit.get('position', nextPos) - Vector2(0.0, max(floorPullUpOffset, 0.0))
				if _player.has_method('begin_anchor_pull'):
					_player.call('begin_anchor_pull', targetPos, playerPullSpeed, true)
				_hooks.clear()
				EventBus.emit(EventBus.EventType.ANCHOR_HIT_FLOOR, {'target': targetPos})
				_debug_log('hook floor %s' % targetPos)
				return
		hook['pos'] = nextPos
		_hooks[0] = hook
		if nextPos.distance_to(origin) <= 6.0:
			_hooks.clear()
		return

	if state == 'hooked_cargo':
		var cargoNode: Node = hook.get('cargo', null)
		if cargoNode == null:
			_hooks.clear()
			return
		if not (cargoNode is Node2D):
			_hooks.clear()
			return
		var nextCargoPos: Vector2 = (cargoNode as Node2D).global_position.move_toward(origin + carryOffset, cargoPullSpeed * delta)
		(cargoNode as Node2D).global_position = nextCargoPos
		hook['pos'] = nextCargoPos
		_hooks[0] = hook
		if nextCargoPos.distance_to(origin + carryOffset) <= 8.0:
			if cargoNode.has_method('set_carried'):
				cargoNode.call('set_carried', _player, carryOffset)
			if not _carriedCargo.has(cargoNode):
				_carriedCargo.append(cargoNode)
			_hooks.clear()


## 左键松开时释放非携带态锚。
## @return void
func _release_all_hooks() -> void:
	if _hooks.is_empty():
		return
	for hook in _hooks:
		var cargoNode: Node = hook.get('cargo', null)
		if cargoNode != null and not _carriedCargo.has(cargoNode) and cargoNode.has_method('drop_to_world'):
			cargoNode.call('drop_to_world')
	_hooks.clear()


## 右键：优先交互（占位）> 物体 > 锚放置/回收。
## @return void
func _handle_right_click() -> void:
	if _try_interact():
		return
	if not _carriedCargo.is_empty():
		var cargo: Node = _carriedCargo.pop_back()
		if cargo.has_method('drop_to_world'):
			cargo.call('drop_to_world')
		if _player is Node2D and cargo is Node2D:
			(cargo as Node2D).global_position = (_player as Node2D).global_position + Vector2(18.0, 0.0)
		return
	_toggle_anchor_deploy()


## 占位：交互优先逻辑（后续接真实 Interactable）。
## @return bool
func _try_interact() -> bool:
	return false


## 切换放锚状态：仅冻结锚所在舱室。
## @return void
func _toggle_anchor_deploy() -> void:
	if not _anchorDeployed:
		var cabinPath: NodePath = NodePath('')
		if _player != null:
			var propValue: Variant = _player.get('current_cabin_path')
			if typeof(propValue) == TYPE_NODE_PATH:
				cabinPath = propValue as NodePath
		if cabinPath == NodePath(''):
			return
		_anchorDeployed = true
		_deployedCabinPath = cabinPath
		EventBus.emit(EventBus.EventType.ANCHOR_DEPLOYED, {'cabin_path': String(cabinPath)})
		_debug_log('deploy anchor @%s' % String(cabinPath))
		return
	_anchorDeployed = false
	_deployedCabinPath = NodePath('')
	EventBus.emit(EventBus.EventType.ANCHOR_RETRIEVED, {})
	_debug_log('retrieve anchor')


## 查找回收线段上的第一个合法命中（Hitable组CharacterBody2D或地板）。
## @param fromPos 线段起点
## @param toPos 线段终点
## @return Dictionary
func _find_first_valid_hit(fromPos: Vector2, toPos: Vector2) -> Dictionary:
	var space := get_world_2d().direct_space_state
	var excludes: Array[RID] = []
	var maxLoops: int = 16
	for _i in range(maxLoops):
		var query := PhysicsRayQueryParameters2D.create(fromPos, toPos)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = excludes
		var result: Dictionary = space.intersect_ray(query)
		if result.is_empty():
			return {}

		var collider: Object = result.get('collider', null)
		var position: Vector2 = result.get('position', fromPos)
		if collider is CharacterBody2D:
			var body: CharacterBody2D = collider as CharacterBody2D
			if body.is_in_group('Hitable'):
				return {'type': 'cargo', 'cargo': body, 'position': position}
		elif collider is TileMapLayer:
			if _player is Node2D and position.y <= (_player as Node2D).global_position.y + floorHookMaxYOffset:
				return {'type': 'floor', 'position': position}

		var colliderRid: RID = result.get('rid', RID())
		if colliderRid.is_valid():
			excludes.append(colliderRid)
		else:
			return {}
	return {}


## 调试日志输出。
## @param message 日志内容
## @return void
func _debug_log(message: String) -> void:
	if not debug_anchor_log:
		return
	print('[AnchorController] %s' % message)
