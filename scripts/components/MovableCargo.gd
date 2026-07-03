extends CharacterBody2D

## 可移动物体参数：控制自主滑动与舱室归属维护。
## 是否启用自主移动（关闭后停止自主移动）。
@export var enable_auto_move: bool = true
## 重力加速度（像素/秒^2），开启自主移动时始终生效。
@export var gravity_accel: float = 980.0
## 摩擦系数（越大越不容易滑动）。
@export var friction_coefficient: float = 42.0
## 倾斜驱动强度（重力沿斜面分量缩放）。
@export var slide_accel_scale: float = 520.0
## 最大横向滑动速度（像素/秒）。
@export var max_slide_speed: float = 140.0
## 舱室分组名（默认 Cabin）。
@export var cabin_group_name: StringName = 'Cabin'
## 调试输出开关。
@export var debug_movable_log: bool = false

var current_cabin_name: String = ''
var current_cabin_path: NodePath = NodePath('')

var _slide_speed: float = 0.0
var _current_cabin: Cabin
var _cabins: Array[Cabin] = []
var _anchor_deployed_cabin_path: NodePath = NodePath('')
var _isHooked: bool = false
var _isCarried: bool = false
var _carrier: Node2D
var _carryOffset: Vector2 = Vector2.ZERO
var _collisionIgnored: bool = false
var _savedCollisionLayer: int = 0
var _savedCollisionMask: int = 0
var _savedAutoMove: bool = true


## 初始化并定位初始舱室归属。
## @return void
func _ready() -> void:
	add_to_group('Hitable')
	_refresh_cabins()
	_update_current_cabin_by_position()
	EventBus.subscribe(_on_event)


## 退出时取消事件订阅。
## @return void
func _exit_tree() -> void:
	EventBus.unsubscribe(_on_event)


## 每物理帧更新移动与舱室归属。
## @param delta 帧间隔（秒）
## @return void
func _physics_process(delta: float) -> void:
	if _isCarried and _carrier != null:
		global_position = _carrier.global_position + _carryOffset
		velocity = Vector2.ZERO
		_update_current_cabin_by_position()
		return

	_refresh_cabins_if_needed()
	_update_current_cabin_by_position()
	if _is_frozen_by_anchor():
		_slide_speed = 0.0
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not enable_auto_move:
		_slide_speed = 0.0
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_update_slide(delta)
	velocity.y += max(gravity_accel, 0.0) * delta
	move_and_slide()
	_update_current_cabin_by_position()


## 标记为被锚勾取状态。
## @param byAnchor 锚控制器
## @return void
func set_hooked(byAnchor: Node) -> void:
	if byAnchor != null and not _isHooked:
		_savedAutoMove = enable_auto_move
		enable_auto_move = false
	_isHooked = byAnchor != null
	_isCarried = false
	_carrier = null
	_set_collision_ignored(_isHooked)


## 标记为被玩家携带状态。
## @param byPlayer 玩家节点
## @param carryOffset 携带偏移
## @return void
func set_carried(byPlayer: Node2D, carryOffset: Vector2) -> void:
	if byPlayer != null:
		enable_auto_move = false
	_isCarried = byPlayer != null
	_isHooked = false
	_carrier = byPlayer
	_carryOffset = carryOffset
	velocity = Vector2.ZERO
	_set_collision_ignored(_isCarried)


## 从携带/勾取状态回到世界动态状态。
## @return void
func drop_to_world() -> void:
	_isHooked = false
	_isCarried = false
	_carrier = null
	enable_auto_move = _savedAutoMove
	_set_collision_ignored(false)


## 刷新舱室缓存。
## @return void
func _refresh_cabins() -> void:
	_cabins.clear()
	for node in get_tree().get_nodes_in_group(cabin_group_name):
		if node is Cabin:
			_cabins.append(node as Cabin)


## 在缓存为空时补刷新，避免运行时动态创建导致失效。
## @return void
func _refresh_cabins_if_needed() -> void:
	if _cabins.is_empty():
		_refresh_cabins()


## 更新斜面横向滑动（受重力分量、摩擦与限速控制）。
## @param delta 帧间隔（秒）
## @return void
func _update_slide(delta: float) -> void:
	var tiltRad: float = _ship_tilt_rad()
	var gravityFactor: float = max(gravity_accel, 0.0) / 980.0
	var slopeAccel: float = sin(tiltRad) * slide_accel_scale * gravityFactor
	_slide_speed += slopeAccel * delta
	_slide_speed = move_toward(_slide_speed, 0.0, max(friction_coefficient, 0.0) * delta)
	_slide_speed = clampf(_slide_speed, -max_slide_speed, max_slide_speed)
	# 只考虑横向滑动；竖向始终由重力加速度驱动。
	velocity.x = _slide_speed


## 通过当前位置更新所属舱室。
## @return void
func _update_current_cabin_by_position() -> void:
	var candidate: Cabin = _find_cabin_containing(global_position)
	if candidate != null:
		_set_current_cabin(candidate)
		return
	_current_cabin = null
	current_cabin_name = ''
	current_cabin_path = NodePath('')


## 设置当前舱室并同步公开归属字段。
## @param cabin 舱室节点
## @return void
func _set_current_cabin(cabin: Cabin) -> void:
	if _current_cabin == cabin:
		return
	_current_cabin = cabin
	current_cabin_name = String(cabin.name)
	current_cabin_path = cabin.get_path()
	_debug_log('switch_cabin => %s' % current_cabin_name)


## 检查点是否位于指定舱室内部。
## @param cabin 舱室节点
## @param pointGlobal 全局坐标
## @return bool
func _is_point_inside_cabin(cabin: Cabin, pointGlobal: Vector2) -> bool:
	var localPos: Vector2 = cabin.to_local(pointGlobal)
	var width: float = _as_float(cabin.get('cabin_width'), 320.0)
	var height: float = _as_float(cabin.get('cabin_height'), 240.0)
	var halfW: float = width * 0.5 - 1.0
	var halfH: float = height * 0.5 - 1.0
	return localPos.x >= -halfW and localPos.x <= halfW and localPos.y >= -halfH and localPos.y <= halfH


## 根据全局点查找所在舱室。
## @param pointGlobal 全局坐标
## @return Cabin
func _find_cabin_containing(pointGlobal: Vector2) -> Cabin:
	for cabin in _cabins:
		if _is_point_inside_cabin(cabin, pointGlobal):
			return cabin
	return null


## 读取船体当前倾斜角（弧度）。
## @return float
func _ship_tilt_rad() -> float:
	if get_parent() is Node2D:
		return (get_parent() as Node2D).rotation
	return 0.0


## 安全转换为 float。
## @param value 任意值
## @param fallback 默认值
## @return float
func _as_float(value: Variant, fallback: float) -> float:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


## 设置/恢复碰撞开关（用于勾取回收时避免被阻挡）。
## @param ignored 是否忽略碰撞
## @return void
func _set_collision_ignored(ignored: bool) -> void:
	if ignored and not _collisionIgnored:
		_savedCollisionLayer = collision_layer
		_savedCollisionMask = collision_mask
		collision_layer = 0
		collision_mask = 0
		_collisionIgnored = true
		return
	if (not ignored) and _collisionIgnored:
		collision_layer = _savedCollisionLayer
		collision_mask = _savedCollisionMask
		_collisionIgnored = false


## 处理锚事件：仅冻结锚所在舱室中的可动物体。
## @param eventType 事件类型
## @param data 事件数据
## @return void
func _on_event(eventType: EventBus.EventType, data: Dictionary) -> void:
	match eventType:
		EventBus.EventType.ANCHOR_DEPLOYED:
			var cabinPathText: String = String(data.get('cabin_path', ''))
			_anchor_deployed_cabin_path = NodePath(cabinPathText)
		EventBus.EventType.ANCHOR_RETRIEVED:
			_anchor_deployed_cabin_path = NodePath('')
		_:
			pass


## 判断当前是否受“放下锚”冻结影响（仅锚所在舱室生效）。
## @return bool
func _is_frozen_by_anchor() -> bool:
	if _anchor_deployed_cabin_path == NodePath(''):
		return false
	if current_cabin_path == NodePath(''):
		return false
	return String(current_cabin_path) == String(_anchor_deployed_cabin_path)


## 输出调试日志。
## @param message 日志文本
## @return void
func _debug_log(message: String) -> void:
	if not debug_movable_log:
		return
	print('[MovableCargo] %s' % message)
