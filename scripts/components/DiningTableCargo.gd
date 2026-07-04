extends MovableCargo

## 可移动餐桌本体：负责物理滑动与基础配置。
## @isVipTable 是否VIP桌（供场景配置）
@export var isVipTable: bool = false


## 初始化餐桌基础状态。
func _ready() -> void:
	super._ready()
	deliveryTag = 'dining_table'
