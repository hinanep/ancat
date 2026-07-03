extends Node2D

## 餐桌交互参数：定义可接收物品类型与交互日志。
## 可接收的物品标签列表。
@export var acceptedTags: PackedStringArray = PackedStringArray(['food'])
## 调试日志开关。
@export var debugInteractLog: bool = true


## 初始化：加入可交互分组。
## @return void
func _ready() -> void:
	add_to_group('Interactable')


## 判断物品是否可被当前餐桌接受。
## @param item 候选物品
## @return bool
func can_accept(item: Node) -> bool:
	if item == null:
		return false
	var tag: String = _resolve_item_tag(item)
	if tag.is_empty():
		return false
	for accepted in acceptedTags:
		if tag == accepted:
			return true
	return false


## 尝试交互：合法则消费物品，否则仅日志并返回失败。
## @param player 玩家节点
## @param item 手持物品
## @return bool
func try_interact(player: Node, item: Node) -> bool:
	if item == null:
		_log('interact rejected: no item')
		return false
	if not can_accept(item):
		_log('interact rejected: illegal item')
		return false

	if item.has_method('consume_by_interactable'):
		item.call('consume_by_interactable', self)
	elif item is Node:
		(item as Node).queue_free()
	_log('interact success: item delivered')
	return true


## 解析物品标签（优先方法，其次字段）。
## @param item 候选物品
## @return String
func _resolve_item_tag(item: Node) -> String:
	if item.has_method('get_delivery_tag'):
		return String(item.call('get_delivery_tag'))
	var field: Variant = item.get('deliveryTag')
	if typeof(field) == TYPE_STRING:
		return String(field)
	return ''


## 输出交互日志。
## @param message 日志内容
## @return void
func _log(message: String) -> void:
	if not debugInteractLog:
		return
	print('[TableInteractable] %s' % message)
