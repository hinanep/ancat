extends InteractableBase

## 餐桌交互参数：定义可接收物品类型与交互日志。
## 可接收的物品标签列表。
@export var acceptedTags: PackedStringArray = PackedStringArray(['food'])

## 物品合法性判定：仅接受白名单标签。
## @param item 候选物品
## @return bool
func _is_item_valid(item: Node) -> bool:
	if item == null:
		return false
	var tag: String = _resolve_item_tag(item)
	if tag.is_empty():
		return false
	for accepted in acceptedTags:
		if tag == accepted:
			return true
	return false


## 物品合法时立即完成交付消费。
## @param player 玩家节点
## @param item 携带物品
## @param anchorController 锚控制器
## @return void
func _on_item_valid(player: Node, item: Node, anchorController: Node) -> void:
	var _unusedPlayer: Node = player
	var _unusedAnchorController: Node = anchorController
	_consume_item(item)
	_log_interact('interact success: item delivered')
