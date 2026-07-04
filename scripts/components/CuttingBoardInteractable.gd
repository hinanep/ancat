extends InteractableBase

## 菜板交互：生鱼入板后即时可取生鱼片。
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
	var board: Node = get_parent()
	if board == null or not board.has_method('has_food'):
		return false
	if item.is_in_group(cookableGroupName) and not board.call('has_food'):
		return true
	if item.is_in_group(plateGroupName) and board.call('has_food') and board.call('is_cooked'):
		return true
	return false


## 处理交互成功逻辑。
## @param player 玩家节点
## @param item 携带物
## @param anchorController 锚控制器
func _on_item_valid(player: Node, item: Node, anchorController: Node) -> void:
	var _unusedPlayer: Node = player
	var _unusedAnchor: Node = anchorController
	var board: Node = get_parent()
	if board == null:
		return
	if item.is_in_group(cookableGroupName):
		board.call('add_food', item)
		_log_interact('food added to cutting board')
		return
	if item.is_in_group(plateGroupName):
		var food: Node2D = board.call('take_food')
		if food == null:
			return
		food.queue_free()
		if item.has_method('set_food_type'):
			item.call('set_food_type', FoodConfig.FoodType.SASHIMI)
		if item.has_method('apply_food_texture'):
			item.call('apply_food_texture')
		_log_interact('sashimi served to plate')


## 控制是否消耗携带物。
## @param item 携带物
## @return bool
func _consume_carried_on_item_valid(item: Node) -> bool:
	if item == null:
		return true
	if item.is_in_group(plateGroupName):
		return false
	return true
