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
## 多物体携带时的横向间距（像素）。
@export var carrySpacingX: float = 20.0
## 玩家可同时携带的最大物体数。
@export var maxCarryCount: int = 1
## 放置锚实体预制体。
@export var deployedAnchorScene: PackedScene = preload('res://scenes/props/AnchorPlaced.tscn')
## 回收锚时，鼠标到锚实体的最大命中半径（像素）。
@export var retrieveAnchorClickRadius: float = 18.0
## 回收锚时，玩家到锚实体的最大距离（像素）。
@export var retrieveAnchorPlayerRange: float = 72.0
## 调试日志开关。
@export var debug_anchor_log: bool = true

var _hooks: Array[Dictionary] = []
var _carriedCargo: Array[Node] = []
var _deployedCabinPaths: Array[NodePath] = []
var _deployedAnchorNodesByCabin: Dictionary = {}
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
	_debug_log('ready: player=%s capacity=%d' % [_player.name if _player != null else 'null', _lastAvailableAnchorCapacity])


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
					if cargo.has_method('can_be_hooked') and not bool(cargo.call('can_be_hooked')):
						pass
					else:
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
		var perHookOffset: Vector2 = carryOffset + Vector2((float(hookIndex) - float(_hooks.size() - 1) * 0.5) * carrySpacingX, 0.0)
		var hookTargetPos: Vector2 = origin + perHookOffset
		var nextCargoPos: Vector2 = (cargoNode as Node2D).global_position.move_toward(hookTargetPos, cargoPullSpeed * delta)
		(cargoNode as Node2D).global_position = nextCargoPos
		hook['pos'] = nextCargoPos
		_hooks[hookIndex] = hook
		if nextCargoPos.distance_to(hookTargetPos) <= 8.0:
			if _can_carry_more():
				if cargoNode.has_method('set_carried'):
					var carrySlot: int = _carriedCargo.size()
					cargoNode.call('set_carried', _player, _carry_offset_for_slot(carrySlot, carrySlot + 1))
				if not _carriedCargo.has(cargoNode):
					_carriedCargo.append(cargoNode)
					_refresh_carried_offsets()
			else:
				if cargoNode.has_method('drop_to_world'):
					cargoNode.call('drop_to_world')
				if _player is Node2D and cargoNode is Node2D:
					(cargoNode as Node2D).global_position = (_player as Node2D).global_position + Vector2(18.0, 0.0)
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
	_debug_log('right click trigger: hooks=%d carried=%d deployed=%d' % [_hooks.size(), _carriedCargo.size(), _deployedCabinPaths.size()])
	var interactResult: int = _try_interact()
	if interactResult == INTERACT_SUCCESS or interactResult == INTERACT_REJECTED:
		_debug_log('right click end by interact, result=%d' % interactResult)
		return
	if _try_pickup_nearby_cargo():
		_debug_log('right click end by pickup')
		return
	if not _carriedCargo.is_empty():
		var cargo: Node = _carriedCargo.pop_back()
		if cargo.has_method('drop_to_world'):
			cargo.call('drop_to_world')
		if _player is Node2D and cargo is Node2D:
			(cargo as Node2D).global_position = (_player as Node2D).global_position + Vector2(18.0, 0.0)
		_refresh_carried_offsets()
		_debug_log('right click drop carried cargo=%s' % cargo.name)
		return
	if _try_retrieve_deployed_anchor_at_mouse():
		_debug_log('right click end by retrieve deployed anchor')
		return
	_debug_log('right click enter deploy toggle')
	_toggle_anchor_deploy()


## 交互优先逻辑：有交互物时仅处理交互分支。
## @return int 0=无目标 1=成功 2=拒绝
func _try_interact() -> int:
	if _player == null or not (_player is Node2D):
		_debug_log('interact skip: player invalid')
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
		_debug_log('interact no target in radius=%.1f' % interactRadius)
		return INTERACT_NO_TARGET

	var carriedItem: Node = null
	if not _carriedCargo.is_empty():
		carriedItem = _carriedCargo[_carriedCargo.size() - 1]

	if bestTarget.has_method('try_interact'):
		var accepted: bool = bool(bestTarget.call('try_interact', _player, carriedItem))
		if accepted:
			if carriedItem != null:
				_carriedCargo.erase(carriedItem)
			_debug_log('interact accepted by %s' % bestTarget.name)
			return INTERACT_SUCCESS
		_debug_log('interact rejected by %s' % bestTarget.name)
		return INTERACT_REJECTED
	_debug_log('interact target has no try_interact: %s' % bestTarget.name)
	return INTERACT_REJECTED


## 右键拾取附近可勾取物体（优先于放锚）。
## @return bool
func _try_pickup_nearby_cargo() -> bool:
	if _player == null or not (_player is Node2D):
		_debug_log('pickup skip: player invalid')
		return false
	if not _can_carry_more():
		_debug_log('pickup blocked: carry full size=%d limit=%d' % [_carriedCargo.size(), max(maxCarryCount, 1)])
		return false
	if _carriedCargo.size() >= _available_anchor_capacity():
		_debug_log('pickup blocked: anchor capacity full carried=%d available=%d' % [_carriedCargo.size(), _available_anchor_capacity()])
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
		_debug_log('pickup no cargo in radius=%.1f' % pickupRadius)
		return false
	if bestNode.has_method('set_carried'):
		bestNode.call('set_carried', _player, _carry_offset_for_slot(_carriedCargo.size(), _carriedCargo.size() + 1))
		_carriedCargo.append(bestNode)
		_refresh_carried_offsets()
		_debug_log('pickup success: %s' % bestNode.name)
		return true
	_debug_log('pickup failed: target has no set_carried %s' % bestNode.name)
	return false


## 切换放锚状态：仅冻结锚所在舱室。
## @return void
func _toggle_anchor_deploy() -> void:
	var totalCapacity: int = _current_anchor_capacity()
	var cabinPath: NodePath = _resolve_player_cabin_path()
	if cabinPath == NodePath(''):
		_debug_log('deploy blocked: player not in cabin')
		return
	var cabinPathText: String = String(cabinPath)
	_debug_log('deploy toggle at cabin=%s totalCapacity=%d' % [cabinPathText, totalCapacity])
	for deployedPath in _deployedCabinPaths:
		if String(deployedPath) == cabinPathText:
			_debug_log('deploy blocked: already deployed in cabin=%s' % cabinPathText)
			return
	var inUseCount: int = _hooks.size() + _carriedCargo.size() + _deployedCabinPaths.size()
	if inUseCount + 1 > totalCapacity:
		_debug_log('deploy blocked: no free anchor inUse=%d total=%d' % [inUseCount, totalCapacity])
		return
	_deployedCabinPaths.append(cabinPath)
	_add_deployed_anchor_visual(cabinPathText)
	EventBus.emit(EventBus.EventType.ANCHOR_DEPLOYED, {'cabin_path': cabinPathText})
	_debug_log('deploy anchor @%s total=%d' % [cabinPathText, _deployedCabinPaths.size()])
	_lastAvailableAnchorCapacity = _available_anchor_capacity()
	_ensure_lines()


## 开始玩家锚拉拽。
## @param targetPos 目标点
## @return void
func _start_player_pull(targetPos: Vector2) -> void:
	if _player != null and _player.has_method('begin_anchor_pull'):
		_player.call('begin_anchor_pull', targetPos, playerPullSpeed, true)


## 计算携带槽位偏移，让多物体分散跟随。
## @param slotIndex 槽位索引
## @param totalCount 总携带数量
## @return Vector2
func _carry_offset_for_slot(slotIndex: int, totalCount: int) -> Vector2:
	var center: float = (float(totalCount) - 1.0) * 0.5
	return carryOffset + Vector2((float(slotIndex) - center) * carrySpacingX, 0.0)


## 重新分配当前携带物体的站位偏移。
## @return void
func _refresh_carried_offsets() -> void:
	var total: int = _carriedCargo.size()
	for i in range(total):
		var cargo: Node = _carriedCargo[i]
		if cargo == null:
			continue
		if cargo.has_method('set_carried'):
			cargo.call('set_carried', _player, _carry_offset_for_slot(i, total))


## 判断是否还能继续携带物体。
## @return bool
func _can_carry_more() -> bool:
	var carryLimit: int = max(maxCarryCount, 1)
	return _carriedCargo.size() < carryLimit


## 根据玩家当前位置解析所在舱室路径，避免依赖外部状态更新时间。
## @return NodePath
func _resolve_player_cabin_path() -> NodePath:
	if _player == null or not (_player is Node2D):
		_debug_log('resolve cabin failed: player invalid')
		return NodePath('')
	var playerPos: Vector2 = (_player as Node2D).global_position
	for node in get_tree().get_nodes_in_group('Cabin'):
		if not (node is Cabin):
			continue
		var cabin: Cabin = node as Cabin
		if _is_point_inside_cabin(cabin, playerPos):
			_debug_log('resolve cabin success: %s' % String(cabin.get_path()))
			return cabin.get_path()
	_debug_log('resolve cabin failed: no cabin contains player pos=%s' % str(playerPos))
	return NodePath('')


## 判断点是否处于舱室内。
## @param cabin 舱室节点
## @param pointGlobal 全局坐标
## @return bool
func _is_point_inside_cabin(cabin: Cabin, pointGlobal: Vector2) -> bool:
	var localPos: Vector2 = cabin.to_local(pointGlobal)
	var width: float = float(cabin.get('cabin_width'))
	var height: float = float(cabin.get('cabin_height'))
	var halfW: float = width * 0.5
	var halfH: float = height * 0.5
	return localPos.x >= -halfW and localPos.x <= halfW and localPos.y >= -halfH and localPos.y <= halfH


## 添加放置锚可视实体。
## @param cabinPathText 舱室路径文本
## @return void
func _add_deployed_anchor_visual(cabinPathText: String) -> void:
	if _deployedAnchorNodesByCabin.has(cabinPathText):
		return
	if deployedAnchorScene == null:
		return
	var anchorNode: Node2D = deployedAnchorScene.instantiate() as Node2D
	if anchorNode == null:
		return
	var cabinNode: Node2D = get_node_or_null(NodePath(cabinPathText)) as Node2D
	if cabinNode != null:
		cabinNode.add_child(anchorNode)
		if _player is Node2D:
			anchorNode.global_position = (_player as Node2D).global_position
	else:
		add_child(anchorNode)
		if _player is Node2D:
			anchorNode.global_position = (_player as Node2D).global_position
	_deployedAnchorNodesByCabin[cabinPathText] = anchorNode


## 移除放置锚可视实体。
## @param cabinPathText 舱室路径文本
## @return void
func _remove_deployed_anchor_visual(cabinPathText: String) -> void:
	if not _deployedAnchorNodesByCabin.has(cabinPathText):
		return
	var anchorNode: Node = _deployedAnchorNodesByCabin[cabinPathText]
	_deployedAnchorNodesByCabin.erase(cabinPathText)
	if anchorNode != null and is_instance_valid(anchorNode):
		anchorNode.queue_free()


## 精确点击回收已放置锚：需点击到锚实体且玩家在附近。
## @return bool
func _try_retrieve_deployed_anchor_at_mouse() -> bool:
	if _player == null or not (_player is Node2D):
		return false
	if _deployedAnchorNodesByCabin.is_empty():
		return false
	var mousePos: Vector2 = get_global_mouse_position()
	var playerPos: Vector2 = (_player as Node2D).global_position
	var clickRadius: float = max(retrieveAnchorClickRadius, 1.0)
	var playerRange: float = max(retrieveAnchorPlayerRange, 1.0)
	var bestCabinPathText: String = ''
	var bestDist: float = INF
	for cabinPathText in _deployedAnchorNodesByCabin.keys():
		var anchorNode: Node2D = _deployedAnchorNodesByCabin[cabinPathText] as Node2D
		if anchorNode == null or not is_instance_valid(anchorNode):
			continue
		var clickDist: float = anchorNode.global_position.distance_to(mousePos)
		if clickDist > clickRadius:
			continue
		var playerDist: float = anchorNode.global_position.distance_to(playerPos)
		if playerDist > playerRange:
			continue
		if clickDist < bestDist:
			bestDist = clickDist
			bestCabinPathText = String(cabinPathText)
	if bestCabinPathText == '':
		_debug_log('retrieve miss: click not on anchor or player too far')
		return false
	_remove_deployed_anchor_by_cabin(bestCabinPathText)
	return true


## 按舱室路径回收已放置锚（含事件与容量刷新）。
## @param cabinPathText 舱室路径文本
## @return void
func _remove_deployed_anchor_by_cabin(cabinPathText: String) -> void:
	for i in range(_deployedCabinPaths.size() - 1, -1, -1):
		if String(_deployedCabinPaths[i]) == cabinPathText:
			_deployedCabinPaths.remove_at(i)
	_remove_deployed_anchor_visual(cabinPathText)
	EventBus.emit(EventBus.EventType.ANCHOR_RETRIEVED, {'cabin_path': cabinPathText})
	_debug_log('retrieve anchor @%s' % cabinPathText)
	_lastAvailableAnchorCapacity = _available_anchor_capacity()
	_ensure_lines()


## 获取当前锚并行容量（优先玩家手中锚数量）。
## @return int
func _current_anchor_capacity() -> int:
	if _player != null:
		var value: Variant = _player.get('anchorCount')
		if typeof(value) == TYPE_INT:
			return max(int(value), 1)
	return max(fallbackAnchorCount, 1)


## 获取当前可用锚容量（每一把放下锚都会占用1把）。
## @return int
func _available_anchor_capacity() -> int:
	var available: int = _current_anchor_capacity() - _deployedCabinPaths.size()
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
