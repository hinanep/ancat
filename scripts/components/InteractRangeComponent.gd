@tool
class_name InteractRangeComponent
extends Area2D

## 交互范围组件参数：统一交互层与范围判定。
## 是否输出调试日志。
@export var debugRangeLog: bool = false
## 交互区域形状类型（0=矩形，1=圆形）。
@export_enum('Rectangle', 'Circle') var rangeShapeType: int = 0:
	set(value):
		rangeShapeType = clampi(value, 0, 1)
		_apply_range_shape()
## 矩形交互区域尺寸。
@export var rangeRectSize: Vector2 = Vector2(64.0, 48.0):
	set(value):
		rangeRectSize = Vector2(max(value.x, 1.0), max(value.y, 1.0))
		_apply_range_shape()
## 圆形交互区域半径。
@export var rangeCircleRadius: float = 32.0:
	set(value):
		rangeCircleRadius = max(value, 1.0)
		_apply_range_shape()
## 交互区域偏移。
@export var rangeOffset: Vector2 = Vector2.ZERO:
	set(value):
		rangeOffset = value
		_apply_range_shape()

@onready var _shapeNode: CollisionShape2D = $CollisionShape2D


## 初始化交互区域参数到碰撞体。
## @return void
func _ready() -> void:
	_apply_range_shape()


## 判断全局点是否命中本交互范围。
## @param pointGlobal 全局坐标点
## @return bool
func is_point_in_range(pointGlobal: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = pointGlobal
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = collision_layer
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_point(query, 16)
	for hit in results:
		var collider: Object = hit.get('collider', null)
		if collider == self:
			return true
	return false


## 应用当前导出参数到交互碰撞体。
## @return void
func _apply_range_shape() -> void:
	if _shapeNode == null:
		return
	_shapeNode.position = rangeOffset
	if rangeShapeType == 1:
		var circleShape: CircleShape2D = _shapeNode.shape as CircleShape2D
		if circleShape == null:
			circleShape = CircleShape2D.new()
			_shapeNode.shape = circleShape
		circleShape.radius = max(rangeCircleRadius, 1.0)
		return
	var rectShape: RectangleShape2D = _shapeNode.shape as RectangleShape2D
	if rectShape == null:
		rectShape = RectangleShape2D.new()
		_shapeNode.shape = rectShape
	rectShape.size = Vector2(max(rangeRectSize.x, 1.0), max(rangeRectSize.y, 1.0))
