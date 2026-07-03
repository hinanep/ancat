@tool
class_name Cabin
extends Node2D

## 船舱节点：提供墙体、门洞、地板打洞与邻居共享逻辑。

const WORLD_LAYER: int = 1
const EPSILON: float = 1.0
const SEAM_OVERLAP: float = 1.0

var _cabin_width: float = 320.0
var _cabin_height: float = 240.0
var _wall_thickness: float = 16.0
var _door_height: float = 120.0
var _left_door_open: bool = false
var _right_door_open: bool = false
var _floor_hole_position: float = 0.0
var _floor_hole_size: float = 0.0
var _recalculate_neighbors: bool = false

@export var cabin_width: float:
	get:
		return _as_float(_cabin_width, 320.0)
	set(value):
		_set_cabin_size(_as_float(value, 320.0), _as_float(_cabin_height, 240.0), _as_float(_wall_thickness, 16.0))

@export var cabin_height: float:
	get:
		return _as_float(_cabin_height, 240.0)
	set(value):
		_set_cabin_size(_as_float(_cabin_width, 320.0), _as_float(value, 240.0), _as_float(_wall_thickness, 16.0))

@export var wall_thickness: float:
	get:
		return _as_float(_wall_thickness, 16.0)
	set(value):
		_set_cabin_size(_as_float(_cabin_width, 320.0), _as_float(_cabin_height, 240.0), _as_float(value, 16.0))

@export var door_height: float:
	get:
		return _as_float(_door_height, 120.0)
	set(value):
		_door_height = max(_as_float(value, 120.0), 0.0)
		_rebuild_all()

@export var left_door_open: bool:
	get:
		return _as_bool(_left_door_open, false)
	set(value):
		_left_door_open = _as_bool(value, false)
		_rebuild_all()

@export var right_door_open: bool:
	get:
		return _as_bool(_right_door_open, false)
	set(value):
		_right_door_open = _as_bool(value, false)
		_rebuild_all()

@export var floor_hole_position: float:
	get:
		return _as_float(_floor_hole_position, 0.0)
	set(value):
		_floor_hole_position = max(_as_float(value, 0.0), 0.0)
		_rebuild_all()

@export var floor_hole_size: float:
	get:
		return _as_float(_floor_hole_size, 0.0)
	set(value):
		_floor_hole_size = max(_as_float(value, 0.0), 0.0)
		_rebuild_all()

@export var recalculate_neighbors: bool:
	get:
		return _as_bool(_recalculate_neighbors, false)
	set(value):
		_recalculate_neighbors = _as_bool(value, false)
		if _recalculate_neighbors:
			_coordinate_neighbors()
		_recalculate_neighbors = false

signal door_state_changed(side: String, is_open: bool)


func _as_float(value, fallback: float) -> float:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


func _as_bool(value, fallback: bool) -> bool:
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	return fallback

var _has_neighbor_left: bool = false
var _has_neighbor_right: bool = false
var _has_neighbor_top: bool = false
var _has_neighbor_bottom: bool = false

var _left_wall_visual: ColorRect
var _right_wall_visual: ColorRect
var _floor_left_visual: ColorRect
var _floor_right_visual: ColorRect
var _ceiling_visual: ColorRect

var _left_wall_body: StaticBody2D
var _right_wall_body: StaticBody2D
var _floor_body: StaticBody2D

var _left_wall_shape: CollisionShape2D
var _right_wall_shape: CollisionShape2D
var _floor_left_shape: CollisionShape2D
var _floor_right_shape: CollisionShape2D


## 初始化：加入 cabin 分组并在下一帧做邻居协调。
## @return void
func _ready() -> void:
	add_to_group('cabin')
	_cache_nodes()
	call_deferred('_coordinate_neighbors')


## 对外 API：打开左门。
## @return void
func open_left_door() -> void:
	if left_door_open:
		return
	left_door_open = true
	door_state_changed.emit('left', true)
	_rebuild_all()


## 对外 API：关闭左门。
## @return void
func close_left_door() -> void:
	if not left_door_open:
		return
	left_door_open = false
	door_state_changed.emit('left', false)
	_rebuild_all()


## 对外 API：打开右门。
## @return void
func open_right_door() -> void:
	if right_door_open:
		return
	right_door_open = true
	door_state_changed.emit('right', true)
	_rebuild_all()


## 对外 API：关闭右门。
## @return void
func close_right_door() -> void:
	if not right_door_open:
		return
	right_door_open = false
	door_state_changed.emit('right', false)
	_rebuild_all()


## 邻居协调：扫描 cabin 分组并更新四向邻居标记。
## @return void
func _coordinate_neighbors() -> void:
	_has_neighbor_left = false
	_has_neighbor_right = false
	_has_neighbor_top = false
	_has_neighbor_bottom = false
	var cabin_width_value: float = _as_float(_cabin_width, 320.0)
	var cabin_height_value: float = _as_float(_cabin_height, 240.0)

	for node in get_tree().get_nodes_in_group('cabin'):
		if node == self:
			continue
		if not (node is Node2D):
			continue
		var other: Node2D = node as Node2D
		var dx: float = other.global_position.x - global_position.x
		var dy: float = other.global_position.y - global_position.y

		if abs(dy) <= EPSILON:
			if abs(dx - cabin_width_value) <= EPSILON:
				_has_neighbor_right = true
			elif abs(dx + cabin_width_value) <= EPSILON:
				_has_neighbor_left = true
		elif abs(dx) <= EPSILON:
			if abs(dy + cabin_height_value) <= EPSILON:
				_has_neighbor_top = true
			elif abs(dy - cabin_height_value) <= EPSILON:
				_has_neighbor_bottom = true

	_rebuild_all()


## 更新尺寸参数并触发重建。
## @param width 船舱宽度
## @param height 船舱高度
## @param thickness 墙体厚度
## @return void
func _set_cabin_size(width: float, height: float, thickness: float) -> void:
	_cabin_width = max(_as_float(width, 320.0), 64.0)
	_cabin_height = max(_as_float(height, 240.0), 64.0)
	_wall_thickness = clamp(_as_float(thickness, 16.0), 4.0, min(_cabin_width, _cabin_height) * 0.5)
	_door_height = min(max(_as_float(_door_height, 120.0), 0.0), _cabin_height)
	_rebuild_all()


## 重建入口：统一刷新视觉与碰撞。
## @return void
func _rebuild_all() -> void:
	if not is_inside_tree():
		return
	_cache_nodes()
	if not _nodes_ready():
		return
	_rebuild_side_walls()
	_rebuild_floor()
	_rebuild_ceiling()


## 缓存节点引用，避免重复路径查找。
## @return void
func _cache_nodes() -> void:
	_left_wall_visual = get_node_or_null('Visuals/LeftWall')
	_right_wall_visual = get_node_or_null('Visuals/RightWall')
	_floor_left_visual = get_node_or_null('Visuals/FloorLeft')
	_floor_right_visual = get_node_or_null('Visuals/FloorRight')
	_ceiling_visual = get_node_or_null('Visuals/Ceiling')

	_left_wall_body = get_node_or_null('Colliders/LeftWallBody')
	_right_wall_body = get_node_or_null('Colliders/RightWallBody')
	_floor_body = get_node_or_null('Colliders/FloorBody')

	_left_wall_shape = get_node_or_null('Colliders/LeftWallBody/CollisionShape2D')
	_right_wall_shape = get_node_or_null('Colliders/RightWallBody/CollisionShape2D')
	_floor_left_shape = get_node_or_null('Colliders/FloorBody/FloorLeftShape')
	_floor_right_shape = get_node_or_null('Colliders/FloorBody/FloorRightShape')


## 检查关键节点是否完整。
## @return bool 节点是否可用
func _nodes_ready() -> bool:
	return _left_wall_visual != null and _right_wall_visual != null and _floor_left_visual != null and _floor_right_visual != null and _ceiling_visual != null and _left_wall_body != null and _right_wall_body != null and _floor_body != null and _left_wall_shape != null and _right_wall_shape != null and _floor_left_shape != null and _floor_right_shape != null


## 重建左右墙：共享优先于门，门只打开墙体下半段。
## @return void
func _rebuild_side_walls() -> void:
	_rebuild_one_side_wall(true)
	_rebuild_one_side_wall(false)


## 重建单侧墙体视觉与碰撞。
## @param is_left 是否左侧
## @return void
func _rebuild_one_side_wall(is_left: bool) -> void:
	var cabin_width_value: float = _as_float(_cabin_width, 320.0)
	var cabin_height_value: float = _as_float(_cabin_height, 240.0)
	var wall_thickness_value: float = _as_float(_wall_thickness, 16.0)
	var door_height_value: float = _as_float(_door_height, 120.0)
	var left_x: float = -cabin_width_value * 0.5
	var right_x: float = cabin_width_value * 0.5
	var top_y: float = -cabin_height_value * 0.5
	var has_neighbor: bool = _has_neighbor_at((-cabin_width_value) if is_left else cabin_width_value, 0.0)
	var door_open: bool = left_door_open if is_left else right_door_open
	var is_owned_side: bool = not has_neighbor if is_left else true

	var visual: ColorRect = _left_wall_visual if is_left else _right_wall_visual
	var body: StaticBody2D = _left_wall_body if is_left else _right_wall_body
	var shape_node: CollisionShape2D = _left_wall_shape if is_left else _right_wall_shape

	if not is_owned_side:
		_set_side_wall_disabled(visual, body, shape_node)
		return

	var wall_x: float = left_x if is_left else right_x - wall_thickness_value
	var wall_top_y: float = top_y
	var render_height: float = cabin_height_value

	if door_open:
		render_height = max(cabin_height_value - min(door_height_value, cabin_height_value), 0.0)

	if render_height <= 0.0:
		_set_side_wall_disabled(visual, body, shape_node)
		return

	visual.visible = true
	visual.position = Vector2(wall_x, wall_top_y)
	visual.size = Vector2(wall_thickness_value, render_height)

	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	shape_node.disabled = false
	if shape_node.shape == null or not (shape_node.shape is RectangleShape2D):
		shape_node.shape = RectangleShape2D.new()
	var shape: RectangleShape2D = shape_node.shape as RectangleShape2D
	shape.size = Vector2(wall_thickness_value, render_height)
	shape_node.position = Vector2(wall_x + wall_thickness_value * 0.5, wall_top_y + render_height * 0.5)


## 关闭侧墙显示与碰撞。
## @param visual 侧墙视觉节点
## @param body 侧墙物理体
## @param shape_node 侧墙碰撞形状节点
## @return void
func _set_side_wall_disabled(visual: ColorRect, body: StaticBody2D, shape_node: CollisionShape2D) -> void:
	visual.visible = false
	body.collision_layer = 0
	body.collision_mask = 0
	shape_node.disabled = true


## 重建地板：始终保留地板优先，支持挖洞。
## @return void
func _rebuild_floor() -> void:
	var cabin_width_value: float = _as_float(_cabin_width, 320.0)
	var cabin_height_value: float = _as_float(_cabin_height, 240.0)
	var wall_thickness_value: float = _as_float(_wall_thickness, 16.0)
	var hole_position_value: float = _as_float(_floor_hole_position, 0.0)
	var hole_size_value: float = _as_float(_floor_hole_size, 0.0)
	var left_x: float = -cabin_width_value * 0.5
	var right_x: float = cabin_width_value * 0.5
	var bottom_y: float = cabin_height_value * 0.5

	var floor_span_start: float = left_x - SEAM_OVERLAP
	var floor_span_end: float = right_x + SEAM_OVERLAP
	var available_width: float = max(floor_span_end - floor_span_start, 0.0)
	var floor_y: float = bottom_y - wall_thickness_value

	if available_width <= 0.0:
		_floor_left_visual.visible = false
		_floor_right_visual.visible = false
		_floor_left_shape.disabled = true
		_floor_right_shape.disabled = true
		_floor_body.collision_layer = 0
		_floor_body.collision_mask = 0
		return

	_floor_body.collision_layer = WORLD_LAYER
	_floor_body.collision_mask = 0

	var hole_size: float = clamp(hole_size_value, 0.0, available_width)
	var hole_anchor: float = left_x + wall_thickness_value + hole_position_value
	var hole_start: float = clamp(hole_anchor, floor_span_start, floor_span_end)
	var hole_end: float = clamp(hole_start + hole_size, floor_span_start, floor_span_end)

	if hole_size <= 0.0 or hole_end <= hole_start:
		_set_floor_segment(_floor_left_visual, _floor_left_shape, floor_span_start, floor_y, available_width)
		_floor_right_visual.visible = false
		_floor_right_shape.disabled = true
		return

	var left_width: float = max(hole_start - floor_span_start, 0.0)
	var right_width: float = max(floor_span_end - hole_end, 0.0)

	if left_width > 0.0:
		_set_floor_segment(_floor_left_visual, _floor_left_shape, floor_span_start, floor_y, left_width)
	else:
		_floor_left_visual.visible = false
		_floor_left_shape.disabled = true

	if right_width > 0.0:
		_set_floor_segment(_floor_right_visual, _floor_right_shape, hole_end, floor_y, right_width)
	else:
		_floor_right_visual.visible = false
		_floor_right_shape.disabled = true


## 设置单段地板视觉与碰撞。
## @param visual 地板视觉节点
## @param shape_node 地板碰撞节点
## @param start_x 段起点 X
## @param floor_y 地板顶部 Y
## @param width 段宽度
## @return void
func _set_floor_segment(visual: ColorRect, shape_node: CollisionShape2D, start_x: float, floor_y: float, width: float) -> void:
	var wall_thickness_value: float = _as_float(_wall_thickness, 16.0)

	visual.visible = true
	visual.position = Vector2(start_x, floor_y)
	visual.size = Vector2(width, wall_thickness_value)

	shape_node.disabled = false
	if shape_node.shape == null or not (shape_node.shape is RectangleShape2D):
		shape_node.shape = RectangleShape2D.new()
	var shape: RectangleShape2D = shape_node.shape as RectangleShape2D
	shape.size = Vector2(width, wall_thickness_value)
	shape_node.position = Vector2(start_x + width * 0.5, floor_y + wall_thickness_value * 0.5)


## 重建天花板：仅视觉，无碰撞；有上邻居时隐藏。
## @return void
func _rebuild_ceiling() -> void:
	var cabin_width_value: float = _as_float(_cabin_width, 320.0)
	var cabin_height_value: float = _as_float(_cabin_height, 240.0)
	var wall_thickness_value: float = _as_float(_wall_thickness, 16.0)
	var ceiling_start_x: float = -cabin_width_value * 0.5 - SEAM_OVERLAP
	var ceiling_start_y: float = -cabin_height_value * 0.5 - wall_thickness_value
	var ceiling_width: float = max(cabin_width_value + SEAM_OVERLAP * 2.0, 0.0)
	var has_top_neighbor: bool = _has_neighbor_at(0.0, -cabin_height_value)

	_ceiling_visual.position = Vector2(ceiling_start_x, ceiling_start_y)
	_ceiling_visual.size = Vector2(ceiling_width, wall_thickness_value)

	_ceiling_visual.visible = not has_top_neighbor


func _has_neighbor_at(offset_x: float, offset_y: float) -> bool:
	for node in get_tree().get_nodes_in_group('cabin'):
		if node == self:
			continue
		if not (node is Node2D):
			continue
		var other: Node2D = node as Node2D
		var dx: float = other.global_position.x - global_position.x
		var dy: float = other.global_position.y - global_position.y
		if abs(dx - offset_x) <= EPSILON and abs(dy - offset_y) <= EPSILON:
			return true
	return false
