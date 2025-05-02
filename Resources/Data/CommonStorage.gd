extends TextDatabase

var ids: Array
var need_extra_check: Array

func convert_item_id(id: String) -> int:
	var new_id: int = ids.find(id)
	assert(new_id >= 0, "Nieprawidłowe ID przedmiotu: " + id)
	return new_id

func validate_requirement(req: String):
	if Engine.is_editor_hint():
		return
	
	assert(req is String)
	assert(req.count(":") == 1)
	
	var type: String = req.get_slice(":", 0)
	var data: String = req.get_slice(":", 1)
	
	match type:
		"technology":
			assert(data in Const.Technology, "Nieprawidłowa technologia: " + data)
		"building":
			need_extra_check.append(data)
		"reactor_lvl":
			assert(data.is_valid_int(), "Zły numer lol")
		"turret":
			assert(data.is_empty())
		_:
			assert(false, "Nieprawidłowe wymaganie: " + type)
