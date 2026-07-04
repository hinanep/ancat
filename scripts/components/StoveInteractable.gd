extends InteractableBase

## 锅炉交互逻辑：接受 Pot 分组锅放置，通过 Area2D 检测锅进出并驱动烹饪。
## @potGroupName 锅的 Godot 分组名
## @potPlacementOffset 锅放置在炉子上的位置偏移（相对于本节点全局位置）
@export var potGroupName: StringName = 'Pot'
@export var potPlacementOffset: Vector2 = Vector2(0.0, -20.0)

var _currentPot: Node2D


## 物品合法性判定：仅接受 Pot 分组且炉上无锅。
## @param item 候选物品
## @return bool
func _is_item_valid(item: Node) -> bool:
	if item == null:
		return false
	if not item.is_in_group(potGroupName):
		return false
	if _currentPot != null and is_instance_valid(_currentPot):
		_log_interact('stove already has a pot')
		return false
	return true


## 物品合法时将锅放到炉子上方。
## 调用 drop_to_world 恢复锅的物理状态，设置锅的全局位置到放置偏移处。
## @param player 玩家节点
## @param item 携带物品
## @param anchorController 锚控制器
func _on_item_valid(player: Node, item: Node, anchorController: Node) -> void:
	var _unusedPlayer: Node = player
	var _unusedAnchorController: Node = anchorController
	if item.has_method('drop_to_world'):
		item.call('drop_to_world')
	if item is Node2D:
		(item as Node2D).global_position = global_position + potPlacementOffset
	_log_interact('pot placed on stove')


## PotDetectionArea body_entered 信号回调：锅进入检测区域时通知锅开始烹饪。
## @param body 进入的物理体
func _on_pot_detection_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group(potGroupName):
		return
	if _currentPot != null and is_instance_valid(_currentPot):
		return
	_currentPot = body
	if body.has_method('set_on_stove'):
		body.call('set_on_stove', true)


## PotDetectionArea body_exited 信号回调：锅离开检测区域时通知锅暂停烹饪。
## @param body 离开的物理体
func _on_pot_detection_area_body_exited(body: Node2D) -> void:
	if body != _currentPot:
		return
	if is_instance_valid(_currentPot) and _currentPot.has_method('set_on_stove'):
		_currentPot.call('set_on_stove', false)
	_currentPot = null
