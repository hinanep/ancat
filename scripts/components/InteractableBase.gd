class_name InteractableBase
extends InteractRangeComponent

## 可交互基类参数：统一分组、交互协议与子类钩子接口。
## 交互分组名。
@export var interactableGroupName: StringName = 'Interactable'
## 调试日志开关。
@export var debugInteractLog: bool = true
## 日志前缀。
@export var interactLogPrefix: String = 'InteractableBase'
## 烹饪预览成品类型（-1 表示不启用）。
@export var cookPreviewFoodType: int = -1
## 烹饪预览气泡相对厨具父节点的偏移。
@export var cookPreviewOffset: Vector2 = Vector2(0.0, -28.0)

var _cookPreviewBubble: CookPreviewBubble
var _rightClickPromptBubble: Node2D


## 初始化：加入可交互组。
## @return void
func _ready() -> void:
	add_to_group(interactableGroupName)
	_setup_cook_preview_bubble()
	_bind_right_click_prompt_bubble()
	if _cookPreviewBubble != null:
		set_process(true)


## 每帧更新烹饪预览气泡显隐。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	var _unusedDelta: float = delta
	if _cookPreviewBubble != null:
		_update_cook_preview_bubble()


## 实例化并挂载烹饪预览气泡。
## @return void
func _setup_cook_preview_bubble() -> void:
	if cookPreviewFoodType < 0:
		return
	var parentNode: Node = get_parent()
	if parentNode == null:
		return
	var bubbleScene: PackedScene = ResPath.PROP_SCENES.COOK_PREVIEW_BUBBLE
	if bubbleScene == null:
		return
	var bubbleNode: Node = bubbleScene.instantiate()
	if bubbleNode == null or not (bubbleNode is CookPreviewBubble):
		return
	_cookPreviewBubble = bubbleNode as CookPreviewBubble
	_cookPreviewBubble.position = cookPreviewOffset
	_cookPreviewBubble.hide_preview()
	parentNode.add_child.call_deferred(_cookPreviewBubble)
	set_process(true)


## 绑定场景中预置的右键提示气泡。
## @return void
func _bind_right_click_prompt_bubble() -> void:
	_rightClickPromptBubble = get_node_or_null('RightClickPromptBubble') as Node2D
	if _rightClickPromptBubble == null:
		return
	if _rightClickPromptBubble.has_method('configure_interact'):
		_rightClickPromptBubble.call('configure_interact', self, _cookPreviewBubble)


## 根据玩家距离与携带物更新预览气泡。
## @return void
func _update_cook_preview_bubble() -> void:
	var anchorController: Node = get_tree().get_first_node_in_group('AnchorController')
	if anchorController == null:
		_cookPreviewBubble.hide_preview()
		return
	var playerNode: Node2D = null
	if anchorController.has_method('get_player_node'):
		playerNode = anchorController.call('get_player_node') as Node2D
	if playerNode == null:
		_cookPreviewBubble.hide_preview()
		return
	var radius: float = 200.0
	if anchorController.has_method('get_interact_radius'):
		radius = float(anchorController.call('get_interact_radius'))
	if global_position.distance_to(playerNode.global_position) > radius:
		_cookPreviewBubble.hide_preview()
		return
	if _is_parent_cooking():
		_cookPreviewBubble.hide_preview()
		return
	var carriedItem: Node = null
	if anchorController.has_method('get_top_carried_item'):
		carriedItem = anchorController.call('get_top_carried_item') as Node
	if carriedItem == null:
		_cookPreviewBubble.hide_preview()
		return
	var canPreview: bool = false
	if carriedItem.is_in_group('Cookable') or carriedItem.is_in_group('Plate'):
		canPreview = _is_item_valid(carriedItem)
	if not canPreview:
		_cookPreviewBubble.hide_preview()
		return
	_cookPreviewBubble.show_preview(cookPreviewFoodType)


## 判断当前状态下是否应显示右键交互提示。
## @param anchorController 锚控制器
## @param blockEmptyHandInteract 空手时是否存在可拾取物（拾取优先时传 true）
## @return bool
func should_show_right_click_prompt(anchorController: Node, blockEmptyHandInteract: bool) -> bool:
	if anchorController == null:
		return false
	var playerNode: Node2D = null
	if anchorController.has_method('get_player_node'):
		playerNode = anchorController.call('get_player_node') as Node2D
	if playerNode == null:
		return false
	var radius: float = 200.0
	if anchorController.has_method('get_interact_radius'):
		radius = float(anchorController.call('get_interact_radius'))
	if global_position.distance_to(playerNode.global_position) > radius:
		return false
	var promptRadius: float = 96.0
	if anchorController.has_method('get_prompt_radius'):
		promptRadius = float(anchorController.call('get_prompt_radius'))
	var promptCenter: Vector2 = global_position
	var parentNode: Node = get_parent()
	if parentNode is CharacterBody2D:
		promptCenter = (parentNode as Node2D).global_position
	var promptDistance: float = promptCenter.distance_to(playerNode.global_position)
	if promptDistance > max(promptRadius, 0.0):
		return false
	var carriedItem: Node = null
	if anchorController.has_method('get_top_carried_item'):
		carriedItem = anchorController.call('get_top_carried_item') as Node
	if not _can_interact_now(playerNode, carriedItem, anchorController):
		return false
	var itemValid: bool = _is_item_valid(carriedItem)
	var anchorValid: bool = _is_anchor_valid(anchorController)
	if not itemValid and not anchorValid:
		return false
	if carriedItem == null and blockEmptyHandInteract:
		return false
	return true


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
	if _is_parent_cooking():
		return false
	var _unusedPlayer: Node = player
	var _unusedItem: Node = item
	var _unusedAnchorController: Node = anchorController
	return true


## 父节点是否处于烹饪/处理中（锅、煎锅、菜板等通过 is_cooking 声明）。
## @return bool
func _is_parent_cooking() -> bool:
	var parentNode: Node = get_parent()
	if parentNode == null:
		return false
	if not parentNode.has_method('is_cooking'):
		return false
	return bool(parentNode.call('is_cooking'))


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


## 判断点击点是否进入交互范围（基于组件 Area2D）。
## @param clickGlobal 点击全局坐标
## @return bool
func is_click_in_interact_range(clickGlobal: Vector2) -> bool:
	return is_point_in_range(clickGlobal)
