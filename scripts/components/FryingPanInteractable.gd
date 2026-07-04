extends InteractableBase

## 煎锅交互：生鱼入锅，完成后盘子取煎鱼。
## @cookableGroupName 可烹饪组
## @plateGroupName 盘子组
@export var cookableGroupName: StringName = 'Cookable'
@export var plateGroupName: StringName = 'Plate'


## 判定可交互物。
## @param item 候选物品
## @return bool
func _is_item_valid(item: Node) -> bool:
	if item == null:
		return false
	var pan: Node = get_parent()
	if pan == null or not pan.has_method('has_food'):
		return false
	if item.is_in_group(cookableGroupName) and not pan.call('has_food'):
		return true
	if item.is_in_group(plateGroupName) and pan.call('has_food') and pan.call('is_cooked'):
		return true
	return false


## 处理交互成功逻辑。
## @param player 玩家节点
## @param item 携带物
## @param anchorController 锚控制器
func _on_item_valid(player: Node, item: Node, anchorController: Node) -> void:
	var _unusedPlayer: Node = player
	var _unusedAnchor: Node = anchorController
	var pan: Node = get_parent()
	if pan == null:
		return
	if item.is_in_group(cookableGroupName):
		pan.call('add_food', item)
		_log_interact('food added to frying pan')
		return
	if item.is_in_group(plateGroupName):
		var food: Node2D = pan.call('take_food')
		if food == null:
			return
		food.queue_free()
		if item.has_method('set_food_type'):
			item.call('set_food_type', FoodConfig.FoodType.FRIED_FISH)
		if item.has_method('apply_food_texture'):
			item.call('apply_food_texture')
		_log_interact('fried fish served to plate')


## 控制是否消耗携带物。
## @param item 携带物
## @return bool
func _consume_carried_on_item_valid(item: Node) -> bool:
	if item == null:
		return true
	if item.is_in_group(plateGroupName):
		return false
	return true
