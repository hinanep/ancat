class_name InteractableBase
extends InteractRangeComponent

## 可交互基类参数：统一分组、交互协议与子类钩子接口。
## 交互分组名。
@export var interactableGroupName: StringName = 'Interactable'
## 调试日志开关。
@export var debugInteractLog: bool = true
## 日志前缀。
@export var interactLogPrefix: String = 'InteractableBase'


## 初始化：加入可交互组。
## @return void
func _ready() -> void:
	add_to_group(interactableGroupName)


## 统一扩展交互协议：先判物品，再判锚；都不合法则失败。
## @param player 玩家节点
## @param item 携带物品
## @param anchorController 锚控制器
## @return Dictionary
func try_interact_ex(player: Node, item: Node, anchorController: Node) -> Dictionary:
	if not _can_interact_now(player, item, anchorController):
		return _reject_interact()
	if _is_item_valid(item):
			_on_item_valid(player, item, anchorController)
		return _accept_interact(_consume_carried_on_item_valid(item))
	if _is_anchor_valid(anchorController):
		_on_anchor_valid(player, item, anchorController)
		return _accept_interact(_consume_carried_on_anchor_valid(anchorController))
	_on_interact_failed(player, item, anchorController)
	return _reject_interact()


## 统一成功返回体。
## @param consumeCarried 是否消耗携带物
## @return Dictionary
func _accept_interact(consumeCarried: bool) -> Dictionary:
	return {'accepted': true, 'consume_carried': consumeCarried}


## 统一失败返回体。
## @return Dictionary
func _reject_interact() -> Dictionary:
	return {'accepted': false, 'consume_carried': false}


## 交互前置校验钩子（子类按需重写）。
## @param player 玩家节点
## @param item 携带物品
## @param anchorController 锚控制器
## @return bool
func _can_interact_now(player: Node, item: Node, anchorController: Node) -> bool:
	var _unusedPlayer: Node = player
	var _unusedItem: Node = item
	var _unusedAnchorController: Node = anchorController
	return true


## 物品合法性判定（子类按需重写）。
## @param item 候选物品
## @return bool
func _is_item_valid(item: Node) -> bool:
	var _unusedItem: Node = item
	return false


## 锚合法性判定（子类按需重写）。
## @param anchorController 锚控制器
## @return bool
func _is_anchor_valid(anchorController: Node) -> bool:
	var _unusedAnchorController: Node = anchorController
	return false


## 物品合法时的处理钩子（子类按需重写）。
## @param player 玩家节点
## @param item 携带物品
## @param anchorController 锚控制器
## @return void
func _on_item_valid(player: Node, item: Node, anchorController: Node) -> void:
	var _unusedPlayer: Node = player
	var _unusedItem: Node = item
	var _unusedAnchorController: Node = anchorController


## 锚合法时的处理钩子（子类按需重写）。
## @param player 玩家节点
## @param item 携带物品
## @param anchorController 锚控制器
## @return void
func _on_anchor_valid(player: Node, item: Node, anchorController: Node) -> void:
	var _unusedPlayer: Node = player
	var _unusedItem: Node = item
	var _unusedAnchorController: Node = anchorController


## 交互失败时的处理钩子（子类按需重写）。
## @param player 玩家节点
## @param item 携带物品
## @param anchorController 锚控制器
## @return void
func _on_interact_failed(player: Node, item: Node, anchorController: Node) -> void:
	var _unusedPlayer: Node = player
	var _unusedItem: Node = item
	var _unusedAnchorController: Node = anchorController
	_log_interact('interact rejected: both item and anchor invalid')


## 物品合法时是否消耗携带物（子类可重写）。
## @param item 携带物品
## @return bool
func _consume_carried_on_item_valid(item: Node) -> bool:
	var _unusedItem: Node = item
	return true


## 锚合法时是否消耗携带物（子类可重写）。
## @param anchorController 锚控制器
## @return bool
func _consume_carried_on_anchor_valid(anchorController: Node) -> bool:
	var _unusedAnchorController: Node = anchorController
	return false


## 工具函数：立即消费物品。
## @param item 待消费物品
## @return void
func _consume_item(item: Node) -> void:
	if item == null or not is_instance_valid(item):
		return
	if item.has_method('consume_by_interactable'):
		item.call('consume_by_interactable', self)
	elif item is Node:
		(item as Node).queue_free()


## 解析物品标签（优先方法，其次字段）。
## @param item 候选物品
## @return String
func _resolve_item_tag(item: Node) -> String:
	if item == null:
		return ''
	if item.has_method('get_delivery_tag'):
		return String(item.call('get_delivery_tag'))
	var field: Variant = item.get('deliveryTag')
	if typeof(field) == TYPE_STRING:
		return String(field)
	return ''


## 输出交互日志。
## @param message 日志内容
## @return void
func _log_interact(message: String) -> void:
	if not debugInteractLog:
		return
	print('[%s] %s' % [interactLogPrefix, message])


## 调试日志写入。
## @param hypothesisId 假设编号
## @param location 位置
## @param message 消息
## @param data 数据
## @return void
func is_click_in_interact_range(clickGlobal: Vector2) -> bool:
	return is_point_in_range(clickGlobal)
