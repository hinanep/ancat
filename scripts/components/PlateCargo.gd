extends MovableCargo

## 盘子：用于盛放烹饪完成的食物，加入 Plate 分组供锅识别。

func _ready() -> void:
	super._ready()
	add_to_group('Plate')
