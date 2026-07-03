extends Node2D

## 锚槽位 UI 参数：显示总槽位与已消耗槽位灰显状态。
## 锚控制器路径。
@export var anchorControllerPath: NodePath
## 槽位起始位置（相对当前节点）。
@export var slotsStartOffset: Vector2 = Vector2(0.0, 0.0)
## 槽位间距（像素）。
@export var slotSpacingX: float = 26.0
## 槽位图标场景（默认使用放置锚实体图标）。
@export var slotIconScene: PackedScene = preload('res://scenes/props/AnchorPlaced.tscn')
## 正常槽位颜色。
@export var slotNormalColor: Color = Color(1.0, 1.0, 1.0, 1.0)
## 已消耗槽位颜色。
@export var slotConsumedColor: Color = Color(0.45, 0.45, 0.45, 1.0)

var _anchorController: Node
var _slotIcons: Array[Node2D] = []
var _totalSlots: int = 0
var _consumedSlots: int = 0


## 初始化：绑定锚控制器并构建初始槽位。
## @return void
func _ready() -> void:
	_resolve_anchor_controller()
	_rebuild_slots()
	_refresh_slot_colors()


## 解析锚控制器并连接状态信号。
## @return void
func _resolve_anchor_controller() -> void:
	if anchorControllerPath != NodePath(''):
		_anchorController = get_node_or_null(anchorControllerPath)
	if _anchorController == null:
		return
	if _anchorController.has_signal('slot_state_changed'):
		_anchorController.connect('slot_state_changed', _on_slot_state_changed)
	if _anchorController.has_method('current_slot_total'):
		_totalSlots = int(_anchorController.call('current_slot_total'))
	if _anchorController.has_method('current_slot_consumed'):
		_consumedSlots = int(_anchorController.call('current_slot_consumed'))


## 处理槽位状态变化事件。
## @param totalSlots 总槽位
## @param consumedSlots 已消耗槽位
## @return void
func _on_slot_state_changed(totalSlots: int, consumedSlots: int) -> void:
	_totalSlots = max(totalSlots, 0)
	_consumedSlots = clampi(consumedSlots, 0, _totalSlots)
	_rebuild_slots()
	_refresh_slot_colors()


## 按当前总槽位重建图标节点。
## @return void
func _rebuild_slots() -> void:
	while _slotIcons.size() > _totalSlots:
		var last: Node2D = _slotIcons.pop_back()
		if last != null and is_instance_valid(last):
			last.queue_free()
	while _slotIcons.size() < _totalSlots:
		var icon: Node2D = _instantiate_slot_icon()
		add_child(icon)
		_slotIcons.append(icon)
	for i in range(_slotIcons.size()):
		_slotIcons[i].position = slotsStartOffset + Vector2(float(i) * slotSpacingX, 0.0)


## 更新槽位颜色：已消耗槽位显示灰色。
## @return void
func _refresh_slot_colors() -> void:
	for i in range(_slotIcons.size()):
		if i < _consumedSlots:
			_slotIcons[i].modulate = slotConsumedColor
		else:
			_slotIcons[i].modulate = slotNormalColor


## 实例化单个槽位图标。
## @return Node2D
func _instantiate_slot_icon() -> Node2D:
	if slotIconScene != null:
		var node: Node2D = slotIconScene.instantiate() as Node2D
		if node != null:
			node.scale = Vector2(0.75, 0.75)
			return node
	return Node2D.new()
