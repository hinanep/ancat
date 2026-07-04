extends MovableCargo

## 可移动煎锅：放到炉子上后计时烹饪，支持盘子取出成品。
## @totalCookSec 煎制总时长（秒）
## @foodPlacementOffset 食材显示偏移
@export var totalCookSec: float = 20.0
@export var foodPlacementOffset: Vector2 = Vector2(0.0, -8.0)

var _foodNode: Node2D
var _isOnStove: bool = false
var _cookRemainingSec: float = 0.0
var _isCooked: bool = false

@onready var _cookProgressBar: ProgressBar = $CookProgressBar


## 初始化煎锅状态。
func _ready() -> void:
	super._ready()
	add_to_group('FryingPan')
	_cookProgressBar.visible = false
	_cookProgressBar.min_value = 0.0
	_cookProgressBar.max_value = 1.0
	_cookProgressBar.value = 0.0


## 每帧推进烹饪计时。
## @param delta 帧间隔（秒）
func _process(delta: float) -> void:
	if _foodNode == null or not is_instance_valid(_foodNode):
		_foodNode = null
		_cookProgressBar.visible = false
		return
	if not _isOnStove or _isCooked:
		return
	_cookRemainingSec = max(_cookRemainingSec - delta, 0.0)
	_update_progress_bar()
	if _cookRemainingSec <= 0.0:
		_isCooked = true
		_cookProgressBar.visible = false
		_debug_log('fried food ready')


## 设置是否在炉子上。
## @param value 是否在炉子上
func set_on_stove(value: bool) -> void:
	_isOnStove = value
	if value and _foodNode != null and not _isCooked:
		_cookProgressBar.visible = true
		_update_progress_bar()
	elif not value:
		_cookProgressBar.visible = false


## 是否有食材。
## @return bool
func has_food() -> bool:
	return _foodNode != null and is_instance_valid(_foodNode)


## 是否烹饪完成。
## @return bool
func is_cooked() -> bool:
	return _isCooked


## 放入食材并重置计时。
## @param food 食材节点
func add_food(food: Node2D) -> void:
	if _foodNode != null or food == null:
		return
	_foodNode = food
	_isCooked = false
	_cookRemainingSec = max(totalCookSec, 0.0)
	if food.has_method('drop_to_world'):
		food.call('drop_to_world')
	food.reparent(self)
	food.position = foodPlacementOffset
	food.set_process(false)
	food.set_physics_process(false)
	if food is CollisionObject2D:
		(food as CollisionObject2D).collision_layer = 0
		(food as CollisionObject2D).collision_mask = 0
	if _isOnStove:
		_cookProgressBar.visible = true
		_update_progress_bar()


## 取出食材并重置状态。
## @return Node2D
func take_food() -> Node2D:
	if _foodNode == null:
		return null
	var food: Node2D = _foodNode
	_foodNode = null
	_isCooked = false
	_cookRemainingSec = 0.0
	_cookProgressBar.visible = false
	return food


## 更新进度条。
func _update_progress_bar() -> void:
	if totalCookSec <= 0.0:
		_cookProgressBar.value = 1.0
		return
	_cookProgressBar.value = 1.0 - (_cookRemainingSec / totalCookSec)
