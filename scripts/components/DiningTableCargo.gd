extends MovableCargo

## 可移动餐桌本体：负责物理滑动与基础配置。
## @isVipTable 是否VIP桌（供场景配置）
@export var isVipTable: bool = false


## 初始化餐桌基础状态。
func _ready() -> void:
	super._ready()
	deliveryTag = 'dining_table'


## 锚勾取回调：仅在有顾客就座时播放猫叫。
## @param byAnchor 锚控制器
## @return void
func set_hooked(byAnchor: Node) -> void:
	super.set_hooked(byAnchor)
	if not _has_seated_customer():
		return
	AudioManager.play_sfx_random(ResPath.AUDIO.CAT_MEOW)


## 舱室切换回调：仅在餐桌载客且向下换层时播放猫叫。
## @param cabin 新舱室
## @return void
func _set_current_cabin(cabin: Cabin) -> void:
	var oldCabin: Cabin = _current_cabin
	super._set_current_cabin(cabin)
	if oldCabin == null or cabin == null:
		return
	if oldCabin == cabin:
		return
	if not _has_seated_customer():
		return
	if cabin.global_position.y <= oldCabin.global_position.y:
		return
	AudioManager.play_sfx_random(ResPath.AUDIO.CAT_MEOW)


## 检查桌上是否有顾客就座。
## @return bool
func _has_seated_customer() -> bool:
	var interactable: Node = get_node_or_null('InteractRangeComponent')
	if interactable == null:
		return false
	if not interactable.has_method('is_seat_free'):
		return false
	return not bool(interactable.call('is_seat_free'))


## 餐桌不使用 MovableCargo 拾取提示，仅由 InteractRangeComponent 控制交互提示。
## @return void
func _bind_right_click_prompt_bubble() -> void:
	_rightClickPromptBubble = get_node_or_null('RightClickPromptBubble') as Node2D
	if _rightClickPromptBubble == null:
		return
	if _rightClickPromptBubble.has_method('hide_prompt'):
		_rightClickPromptBubble.call('hide_prompt')
	_rightClickPromptBubble.set_process(false)
