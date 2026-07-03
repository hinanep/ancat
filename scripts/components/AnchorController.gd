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
## 后备锚数量（当玩家未提供 anchorCount 属性时使用）。
@export var fallbackAnchorCount: int = 1
## 右键交互检测半径（像素）。
@export var interactRadius: float = 40.0
## 右键拾取物体检测半径（像素）。
@export var pickupRadius: float = 52.0
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
var _lines: Array[Line2D] = []
var _leftPressedPrev: bool = false
var _rightPressedPrev: bool = false
var _lastAvailableAnchorCapacity: int = 1

const INTERACT_NO_TARGET: int = 0
const INTERACT_SUCCESS: int = 1
const INTERACT_REJECTED: int = 2


## 初始化缓存与可视链条。
## @return void
func _ready() -> void:
	_player = get_parent()
	_lastAvailableAnchorCapacity = _available_anchor_capacity()
	_ensure_lines()


## 每帧处理输入与回收逻辑。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	var availableCapacity: int = _available_anchor_capacity()
	if availableCapacity != _lastAvailableAnchorCapacity:
		_lastAvailableAnchorCapacity = availableCapacity
		_ensure_lines()
		while _hooks.size() > availableCapacity:
			_hooks.pop_back()
		while _carriedCargo.size() > availableCapacity:
			var cargo: Node = _carriedCargo.pop_back()
			if cargo != null and cargo.has_method('drop_to_world'):
				cargo.call('drop_to_world')

	_update_lines()
	if _player == null or not (_player is Node2D):
		return

	var leftPressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var rightPressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

	if leftPressed and not _leftPressedPrev:
		_fire_anchor()
	if not _hooks.is_empty():
		_update_hooks(delta)

	if rightPressed and not _rightPressedPrev:
		_handle_right_click()

	_leftPressedPrev = leftPressed
	_rightPressedPrev = rightPressed


## 创建锚链可视节点（按锚槽位创建）。
## @return void
func _ensure_lines() -> void:
	for line in _lines:
		if line != null:
			line.queue_free()
	_lines.clear()
	var count: int = _available_anchor_capacity()
	for i in range(count):
		var line: Line2D = Line2D.new()
		line.width = 2.0
		line.default_color = Color(0.95, 0.92, 0.78, 0.95)
		line.z_index = 100 + i
		add_child(line)
		_lines.append(line)


## 更新锚链可视（多锚并行）。
## @return void
func _update_lines() -> void:
	if _lines.is_empty():
		return
	for line in _lines:
		line.clear_points()
	if _hooks.is_empty() or not (_player is Node2D):
		return
	var origin: Vector2 = (_player as Node2D).global_position
	for i in range(min(_hooks.size(), _lines.size())):
		var hookPos: Vector2 = _hooks[i].get('pos', origin)
		_lines[i].add_point(to_local(origin))
		_lines[i].add_point(to_local(hookPos))


## 发射锚：终点尽量落在鼠标位置，超长才截断。
## @return void
func _fire_anchor() -> void:
	_ensure_lines()
	if _hooks.size() >= _available_anchor_capacity():
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


## 回收逻辑：并行更新所有活动锚。
## @param delta 帧间隔（秒）
## @return void
func _update_hooks(delta: float) -> void:
	for i in range(_hooks.size() - 1, -1, -1):
		_update_single_hook(i, delta)


## 更新单个锚状态。
## @param hookIndex 锚索引
## @param delta 帧间隔（秒）
## @return void
func _update_single_hook(hookIndex: int, delta: float) -> void:
	if hookIndex < 0 or hookIndex >= _hooks.size():
		return
	var hook: Dictionary = _hooks[hookIndex]
	var state: String = String(hook.get('state', 'flying_end'))
	if not (_player is Node2D):
		return
	var origin: Vector2 = (_player as Node2D).global_position
	var hookPos: Vector2 = hook.get('pos', origin)

	if state == 'launching':
		var launchTarget: Vector2 = hook.get('end_pos', hookPos)
		var launchNext: Vector2 = hookPos.move_toward(launchTarget, max(anchorLaunchSpeed, 1.0) * delta)
		hook['pos'] = launchNext
		_hooks[hookIndex] = hook
		if launchNext.distance_to(launchTarget) <= 2.0:
			hook['state'] = 'retracting'
			_hooks[hookIndex] = hook
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
					_hooks[hookIndex] = hook
					EventBus.emit(EventBus.EventType.ANCHOR_HIT_CARGO, {'node': String(cargo.get_path())})
					_debug_log('hook cargo %s' % cargo.name)
					return
			elif hitType == 'floor':
				var targetPos: Vector2 = hit.get('position', nextPos) - Vector2(0.0, max(floorPullUpOffset, 0.0))
				_start_player_pull(targetPos)
				_hooks.remove_at(hookIndex)
				EventBus.emit(EventBus.EventType.ANCHOR_HIT_FLOOR, {'target': targetPos})
				_debug_log('hook floor %s' % targetPos)
				return
		hook['pos'] = nextPos
		_hooks[hookIndex] = hook
		if nextPos.distance_to(origin) <= 6.0:
			_hooks.remove_at(hookIndex)
		return

	if state == 'hooked_cargo':
		var cargoNode: Node = hook.get('cargo', null)
		if cargoNode == null:
			_hooks.remove_at(hookIndex)
			return
		if not (cargoNode is Node2D):
			_hooks.remove_at(hookIndex)
			return
		var nextCargoPos: Vector2 = (cargoNode as Node2D).global_position.move_toward(origin + carryOffset, cargoPullSpeed * delta)
		(cargoNode as Node2D).global_position = nextCargoPos
		hook['pos'] = nextCargoPos
		_hooks[hookIndex] = hook
		if nextCargoPos.distance_to(origin + carryOffset) <= 8.0:
			if cargoNode.has_method('set_carried'):
				cargoNode.call('set_carried', _player, carryOffset)
			if not _carriedCargo.has(cargoNode) and _carriedCargo.size() < _current_anchor_capacity():
				_carriedCargo.append(cargoNode)
			_hooks.remove_at(hookIndex)


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
	var interactResult: int = _try_interact()
	if interactResult == INTERACT_SUCCESS or interactResult == INTERACT_REJECTED:
		return
	if _try_pickup_nearby_cargo():
		return
	if not _carriedCargo.is_empty():
		var cargo: Node = _carriedCargo.pop_back()
		if cargo.has_method('drop_to_world'):
			cargo.call('drop_to_world')
		if _player is Node2D and cargo is Node2D:
			(cargo as Node2D).global_position = (_player as Node2D).global_position + Vector2(18.0, 0.0)
		return
	_toggle_anchor_deploy()


## 交互优先逻辑：有交互物时仅处理交互分支。
## @return int 0=无目标 1=成功 2=拒绝
func _try_interact() -> int:
	if _player == null or not (_player is Node2D):
		return INTERACT_NO_TARGET
	var origin: Vector2 = (_player as Node2D).global_position
	var bestTarget: Node2D
	var bestDist: float = INF
	for node in get_tree().get_nodes_in_group('Interactable'):
		if not (node is Node2D):
			continue
		var interactive: Node2D = node as Node2D
		var dist: float = interactive.global_position.distance_to(origin)
		if dist > max(interactRadius, 0.0):
			continue
		if dist < bestDist:
			bestDist = dist
			bestTarget = interactive
	if bestTarget == null:
		return INTERACT_NO_TARGET

	var carriedItem: Node = null
	if not _carriedCargo.is_empty():
		carriedItem = _carriedCargo[_carriedCargo.size() - 1]

	if bestTarget.has_method('try_interact'):
		var accepted: bool = bool(bestTarget.call('try_interact', _player, carriedItem))
		if accepted:
			if carriedItem != null:
				_carriedCargo.erase(carriedItem)
			return INTERACT_SUCCESS
		_debug_log('interact rejected by %s' % bestTarget.name)
		return INTERACT_REJECTED
	return INTERACT_REJECTED


## 右键拾取附近可勾取物体（优先于放锚）。
## @return bool
func _try_pickup_nearby_cargo() -> bool:
	if _player == null or not (_player is Node2D):
		return false
	if _carriedCargo.size() >= _available_anchor_capacity():
		return false
	var origin: Vector2 = (_player as Node2D).global_position
	var bestNode: Node2D
	var bestDist: float = INF
	for node in get_tree().get_nodes_in_group('Hitable'):
		if not (node is CharacterBody2D):
			continue
		if not (node is Node2D):
			continue
		var body: Node2D = node as Node2D
		var dist: float = body.global_position.distance_to(origin)
		if dist > max(pickupRadius, 0.0):
			continue
		if dist < bestDist:
			bestDist = dist
			bestNode = body
	if bestNode == null:
		return false
	if bestNode.has_method('set_carried'):
		bestNode.call('set_carried', _player, carryOffset)
		_carriedCargo.append(bestNode)
		return true
	return false


## 切换放锚状态：仅冻结锚所在舱室。
## @return void
func _toggle_anchor_deploy() -> void:
	if not _anchorDeployed:
		var totalCapacity: int = _current_anchor_capacity()
		var inUseCount: int = _hooks.size() + _carriedCargo.size()
		if inUseCount + 1 > totalCapacity:
			_debug_log('deploy blocked: no free anchor')
			return
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
		_lastAvailableAnchorCapacity = _available_anchor_capacity()
		_ensure_lines()
		return
	_anchorDeployed = false
	_deployedCabinPath = NodePath('')
	EventBus.emit(EventBus.EventType.ANCHOR_RETRIEVED, {})
	_debug_log('retrieve anchor')
	_lastAvailableAnchorCapacity = _available_anchor_capacity()
	_ensure_lines()


## 开始玩家锚拉拽。
## @param targetPos 目标点
## @return void
func _start_player_pull(targetPos: Vector2) -> void:
	if _player != null and _player.has_method('begin_anchor_pull'):
		_player.call('begin_anchor_pull', targetPos, playerPullSpeed, true)


## 获取当前锚并行容量（优先玩家手中锚数量）。
## @return int
func _current_anchor_capacity() -> int:
	if _player != null:
		var value: Variant = _player.get('anchorCount')
		if typeof(value) == TYPE_INT:
			return max(int(value), 1)
	return max(fallbackAnchorCount, 1)


## 获取当前可用锚容量（放下锚会占用1把）。
## @return int
func _available_anchor_capacity() -> int:
	var available: int = _current_anchor_capacity() - (1 if _anchorDeployed else 0)
	return max(available, 0)


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
