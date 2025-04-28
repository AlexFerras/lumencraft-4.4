@tool
extends EditorObject

func _init_data():
	defaults.message = ""

func _configure(editor):
	var label := Label.new()
	label.text = "Message"
	editor.add_object_setting(label)
	
	var textedit := TextEdit.new()
	textedit.wrap_enabled = true
	textedit.connect("text_changed", Callable(self, "on_message_changed").bind(textedit))
	textedit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textedit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.add_object_setting(textedit)
	textedit.text = object_data.message

func on_message_changed(edit: TextEdit):
	object_data.message = edit.text
	emit_signal("data_changed")
