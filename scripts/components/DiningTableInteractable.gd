extends InteractableBase

## 就餐桌交互：管理落座顾客与按需求交付食物。
## @seatOffset 座位偏移（相对桌子）
## @isVipTable 是否VIP桌
@export var seatOffset: Vector2 = Vector2(0.0, -18.0)
@export var isVipTable: bool = false
@export var plateGroupName: StringName = 'Plate'

var _seatedCustomer: Node
var _lastServeAccepted: bool = false

const PLATE_SCENE: PackedScene = preload('res://scenes/props/PlateCargo.tscn')


## 初始化：加入就餐桌分组（顾客据此搜索）。
func _ready() -> void:
	super._ready()
	add_to_group('DiningTable')


## 查询座位是否空闲。
## @return bool
func is_seat_free() -> bool:
	return _seatedCustomer == null or not is_instance_valid(_seatedCustomer)


## 获取座位全局坐标。
## @return Vector2
func get_seat_global_position() -> Vector2:
	var tableRoot: Node = get_parent()
	var marker: Node2D = null
	if tableRoot != null:
		marker = tableRoot.get_node_or_null('SeatMarker') as Node2D
	if marker != null:
		return marker.global_position
	return global_position + seatOffset


## 顾客占座。
## @param customer 顾客节点
## @return bool
func seat_customer(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false
	if not is_seat_free():
		return false
	_seatedCustomer = customer
	if customer is Node2D:
		(customer as Node2D).global_position = get_seat_global_position()
		var tableRoot: Node = get_parent()
		if tableRoot != null:
			customer.reparent(tableRoot)
		else:
			customer.reparent(self)
	EventBus.emit(EventBus.EventType.CUSTOMER_SEATED, {'table': String(get_path())})
	return true


## 顾客离座。
## @param customer 顾客节点（可选，仅匹配当前顾客时清空）
## @return void
func unseat_customer(customer: Node = null) -> void:
	if _seatedCustomer == null:
		return
	if customer != null and customer != _seatedCustomer:
		return
	_seatedCustomer = null


## 物品合法性判定：有顾客且食物匹配任一未满足需求。
## @param item 候选物品
## @return bool
func _is_item_valid(item: Node) -> bool:
	if item == null:
		return false
	if is_seat_free():
		return false
	var foodType: int = _resolve_item_food_type(item)
	if foodType == -1:
		return false
	if not _seatedCustomer.has_method('get_unmet_demands'):
		return false
	var unmet: Array[int] = _seatedCustomer.call('get_unmet_demands')
	return unmet.has(foodType)


## 交付成功时尝试满足顾客需求。
## @param player 玩家节点
## @param item 携带物
## @param anchorController 锚控制器
func _on_item_valid(player: Node, item: Node, anchorController: Node) -> void:
	var _unusedPlayer: Node = player
	var _unusedAnchor: Node = anchorController
	_lastServeAccepted = false
	if is_seat_free():
		return
	var foodType: int = _resolve_item_food_type(item)
	if foodType == -1:
		return
	if not _seatedCustomer.has_method('try_serve_food'):
		return
	var accepted: bool = bool(_seatedCustomer.call('try_serve_food', foodType))
	if not accepted:
		return
	_lastServeAccepted = true
	if _seatedCustomer.has_method('is_satisfied') and bool(_seatedCustomer.call('is_satisfied')):
		_spawn_empty_plate_after_meal()
	EventBus.emit(EventBus.EventType.CUSTOMER_SERVED, {'table': String(get_path()), 'food_type': foodType})


## 决定是否消耗携带物。
## @param item 携带物
## @return bool
func _consume_carried_on_item_valid(item: Node) -> bool:
	if not _lastServeAccepted:
		return false
	if item == null:
		return false
	if item.is_in_group(plateGroupName):
		if item.has_method('clear_food'):
			item.call('clear_food')
		return false
	return true


## 解析物品携带的食物类型。
## @param item 候选物品
## @return int
func _resolve_item_food_type(item: Node) -> int:
	if item == null:
		return -1
	if item.has_method('get_food_type'):
		var value: Variant = item.call('get_food_type')
		if typeof(value) == TYPE_INT:
			return int(value)
	var tag: String = _resolve_item_tag(item)
	if tag == 'apple':
		return FoodConfig.FoodType.APPLE
	if tag == 'peach':
		return FoodConfig.FoodType.PEACH
	if tag == 'pear':
		return FoodConfig.FoodType.PEAR
	return -1


## 顾客吃完后在桌旁生成空盘（受全局上限限制）。
func _spawn_empty_plate_after_meal() -> void:
	if _current_plate_count() >= 8:
		return
	if PLATE_SCENE == null:
		return
	var plateNode: Node = PLATE_SCENE.instantiate()
	if plateNode == null:
		return
	get_tree().current_scene.add_child(plateNode)
	if plateNode is Node2D:
		(plateNode as Node2D).global_position = get_seat_global_position() + Vector2(18.0, 0.0)
	if plateNode.has_method('clear_food'):
		plateNode.call('clear_food')


## 统计当前场景中的盘子数量。
## @return int
func _current_plate_count() -> int:
	return get_tree().get_nodes_in_group('Plate').size()
