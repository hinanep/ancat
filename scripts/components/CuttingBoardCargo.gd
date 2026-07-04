extends MovableCargo

## 可移动菜板：接收生鱼后即时处理为生鱼片，等待盘子取出。
## @foodPlacementOffset 食材显示偏移
@export var foodPlacementOffset: Vector2 = Vector2(0.0, -8.0)

var _foodNode: Node2D
var _hasSashimi: bool = false


## 初始化菜板。
func _ready() -> void:
	super._ready()
	add_to_group('CuttingBoard')


## 是否有食材。
## @return bool
func has_food() -> bool:
	return _foodNode != null and is_instance_valid(_foodNode)


## 菜板结果是否已可取出（即时完成）。
## @return bool
func is_cooked() -> bool:
	return _hasSashimi


## 放入食材并即时标记完成。
## @param food 食材节点
func add_food(food: Node2D) -> void:
	if _foodNode != null or food == null:
		return
	_foodNode = food
	_hasSashimi = true
	if food.has_method('drop_to_world'):
		food.call('drop_to_world')
	food.reparent(self)
	food.position = foodPlacementOffset
	food.set_process(false)
	food.set_physics_process(false)
	if food is CollisionObject2D:
		(food as CollisionObject2D).collision_layer = 0
		(food as CollisionObject2D).collision_mask = 0


## 取出结果并重置状态。
## @return Node2D
func take_food() -> Node2D:
	if _foodNode == null:
		return null
	var food: Node2D = _foodNode
	_foodNode = null
	_hasSashimi = false
	return food
