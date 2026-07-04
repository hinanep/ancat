## EventBus 全局事件总线，解耦跨模块事件通信。
##
## 新增事件步骤：
##   在 enum EventType 末尾添加新项即可（如 ENEMY_KILLED）
##
## 使用示例：
##   # 发射事件
##   EventBus.emit(EventBus.EventType.PLAYER_DIED, {"score": 100})
##   # 监听事件
##   EventBus.event_triggered.connect(_on_event)
extends Node

## 事件类型枚举（新增事件只需在此添加）
enum EventType {
	NONE,
	PLAYER_DIED,
	ENEMY_KILLED,
	LEVEL_COMPLETED,
	GAME_PAUSED,
	GAME_RESUMED,
	STORM_WARNING_STARTED,
	STORM_STARTED,
	STORM_DIRECTION_CHANGED,
	STORM_RECOVER_STARTED,
	STORM_ENDED,
	ANCHOR_DEPLOYED,
	ANCHOR_RETRIEVED,
	ANCHOR_FIRED,
	ANCHOR_HIT_CARGO,
	ANCHOR_HIT_FLOOR,
	CUSTOMER_SPAWNED,
	CUSTOMER_SEATED,
	CUSTOMER_SERVED,
	CUSTOMER_LEFT,
	COIN_CHANGED,
	STAGE_GOAL_REACHED,
	STABILITY_GRANTED,
	GAME_WON,
}

signal event_triggered(event_type: EventType, data: Dictionary)

## 日志开关：true 时每次 emit 都会在控制台打印事件名与数据
static var enable_log: bool = OS.is_debug_build()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## 发射全局事件
static func emit(event_type: EventType, data: Dictionary = {}) -> void:
	var bus: EventBus = Engine.get_main_loop().root.get_node_or_null("/root/EventBus") as EventBus
	if bus:
		if enable_log and event_type != EventType.NONE:
			if data.is_empty():
				print_rich("[color=cyan][EventBus][/color] %s" % event_type)
			else:
				print_rich("[color=cyan][EventBus][/color] %s → %s" % [event_type, data])
		bus.event_triggered.emit(event_type, data)

## 便捷：监听事件（连接 signal）
static func subscribe(callable: Callable) -> void:
	var bus: EventBus = Engine.get_main_loop().root.get_node_or_null("/root/EventBus") as EventBus
	if bus:
		bus.event_triggered.connect(callable)

## 便捷：取消监听
static func unsubscribe(callable: Callable) -> void:
	var bus: EventBus = Engine.get_main_loop().root.get_node_or_null("/root/EventBus") as EventBus
	if bus:
		bus.event_triggered.disconnect(callable)
