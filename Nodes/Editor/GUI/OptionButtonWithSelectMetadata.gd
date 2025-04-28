extends OptionButton

func select_metadata(metadata):
	var h = hash(metadata)
	for i in get_item_count():
		if hash(get_item_metadata(i)) == h:
			select(i)
			emit_signal("item_selected", i)
			return
