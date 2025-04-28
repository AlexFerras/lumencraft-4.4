extends OptionButton

func set_selected_metadata(metadata):
	for i in get_item_count():
		var meta = get_item_metadata(i)
		if typeof(meta) != typeof(metadata):
			continue
		
		if metadata is Dictionary:
			if "id" in meta: # item
				if meta.id == metadata.id and meta.get("data") == metadata.get("data"):
					selected = i
					return
		else:
			if metadata == meta:
				selected = i
				return
