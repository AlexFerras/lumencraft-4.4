extends Control

# Trello Reporting Tool - by Raffaele Picca: twitter.com/MV_Raffa

# You need to get a key and generate a token by visiting this website (And you need to be logged in with the correct account):
# https://trello.com/app-key
var trello_key := "a1103bbc0d87e91875f865b8b7b498d0"
var trello_token := "7b4663fba6e3dd9da8223cff2aa9a99e648e428365c8f23b39d2d9382f917c37"
var key_and_token = "?key=" + trello_key + "&token=" + trello_token

# to find the trello list id, the easiest way is to look up your Trello board, create the list you want to use, add a card, 
# click on the card and add ".json" to the url in the top
# you can then search for idList" - string behind that is the list_id below.
var list_id := "61e542a419801b1cba1d399f"
var locked: bool

# if you don't want to use labels, just leave this dictionary empty, you can add as many labels as you need by just expanding the library
# to find out the label ids, use the same way as with the list ids. look for the label ids in the Trello json.
var trello_labels = {
	0 : { 
		"label_trello_id": "61f28ca3b0e6b82fab396230",
		"label_description": "Bug Report"
	},
	1 : {
		"label_trello_id": "61f28cb25e06607f081dd9a1",
		"label_description": "Feature suggestion"
	},
	2 : {
		"label_trello_id": "61f28cca82e6d63081f5c76a",
		"label_description": "Balance issue"
	},
	3 : {
		"label_trello_id": "61f28cb7629c433d7bf46c8a",
		"label_description": "Typo"
	}
}

var current_card_hash := 0
var current_card_id := ""

var screenshot: Image

@onready var http = HTTPClient.new()
@onready var http_req = $HTTPRequest
@onready var short_text = $"%Title"
@onready var long_text = $"%Description"
@onready var send_button = $"%Send"
@onready var cancel_button = $"%Cancel"
@onready var screenshot_button = $"%Screenshot"
@onready var screenshot_button2 = $"%Screenshot2"

enum tasks {IDLE, CREATE_CARD, GET_CARD_ID, ADD_LABEL}
var task = tasks.IDLE
var description: PackedStringArray
var body: PackedByteArray
var using_joypad: bool
var label_group: ButtonGroup

func _ready():
	for i in trello_labels.size():
		var label: Button = $"%Labels".get_child(i)
		label.small_text = trello_labels[i].label_description
		
		if not label_group:
			label_group = label.group
	
	using_joypad = Utils.is_using_joypad()

func _on_HTTPRequest_request_completed(_result, response_code, _headers, body):
	if task == tasks.CREATE_CARD:
#		print_debug("CREATE_CARD -> " + str(response_code))
		get_card_id()
		return
	
	elif task == tasks.GET_CARD_ID and current_card_id == "":
#		print_debug("GET_CARD_ID -> " + str(response_code))
		Utils.log_message("Sending feedback.")
		if Utils.game:
			Utils.game.endgame_log()
		
		var response = body.get_string_from_utf8()
		if response.is_empty():
			finish(false)
			return
		
		var test_json_conv = JSON.new()
		test_json_conv.parse(response)
		var dict_result = test_json_conv.get_data()
		for i in dict_result:
			if str(current_card_hash) in i.desc:
				current_card_id = i.id
				add_label_to_card()
				
				var file:FileAccess = Utils.safe_open(Utils.FILE, Save.CONFIG_PATH, FileAccess.READ)
				if file:
					add_attachment("Config", "Config.tres", "text/plain", file.get_as_text().to_ascii_buffer())
					file.close()
				
				var dir:DirAccess = Utils.safe_open(Utils.DIR, "user://logs")
				if dir:
					var j = 1
					
					dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
					var f := dir.get_next()
					while not f.is_empty():
						if f.get_extension() == "log":
							file = Utils.safe_open(Utils.File, dir.get_current_dir().path_join(f), FileAccess.READ)
							if file:
								add_attachment("Log " + str(j), f, "text/plain", file.get_as_text().to_ascii_buffer())
								file.close()
								j += 1
						
						f = dir.get_next()
				
				if screenshot:
					screenshot.flip_y()
					
					if screenshot.get_width() > 1920 or screenshot.get_height() > 1080:
						screenshot.shrink_x2()
					
					add_attachment("Screenshot", "Screenshot.png", "image/png", screenshot.save_png_to_buffer())
				
				if Utils.game:
					Save.save_game("Report", true)
					await Save.saved
					dir = Utils.safe_open(Utils.DIR, "user://Saves/Report")
					if dir:
						dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
						var f := dir.get_next()
						while not f.is_empty():
							file = FileAccess.open(dir.get_current_dir().path_join(f), FileAccess.READ)
							if not file:
								continue
							
							if f.get_extension() == "lcsave":
								add_attachment("Save", "report.lcsave", "application/octet-stream", file.get_buffer(file.get_length()))
							elif f == "data.tres":
								add_attachment("Save data", "data.tres", "text/plain", file.get_as_text().to_ascii_buffer())
							elif f == "campaign_progress.tres":
								add_attachment("Campaign", "campaign_progress.tres", "text/plain", file.get_as_text().to_ascii_buffer())
							
							file.close()
							dir.remove(f)
							f = dir.get_next()
				
				finish(true)
				
				return
	
	elif task == tasks.ADD_LABEL:
#		print_debug("ADD_LABEL -> " + str(response_code))
		pass

func _on_Send_pressed():
	locked = true
	create_card()
	show_feedback()
	send_button.disabled = true
	screenshot_button.disabled = true
	screenshot_button2.disabled = true

func get_card_id():
	task = tasks.GET_CARD_ID
	var query = str("https://api.trello.com/1/lists/", list_id, "/cards", key_and_token)
	http_req.request(query, [], true, HTTPClient.METHOD_GET)

func create_card():
	task = tasks.CREATE_CARD
	
	current_card_hash = str(str(OS.get_unique_id()) + str(Time.get_ticks_msec()) + str(Time.get_datetime_dict_from_system()) ).hash()
	var current_card_title = short_text.text
	
	description.append(long_text.text)
	description.append("___")
	add_description_metadata("Report ID", current_card_hash)
	add_description_metadata("Operating System", OS.get_name())
	add_description_metadata("Game Version", str(load("res://Tools/version.gd").VERSION, " ", Utils.get_version_suffix()))
	if SteamAPI.active:
		add_description_metadata("Steam Status", "Online" if SteamAPI.initialized else "Offline")
	
	add_description_newline()
	
	add_description_metadata("Controls", "Joypad" if using_joypad else "Keyboard")
	for i in Input.get_connected_joypads():
		add_description_metadata("Joypad %s" % i, Input.get_joy_name(i))
	
	for i in DisplayServer.get_screen_count():
		add_description_metadata("Screen %s" % (i + 1), "Size: %s, refresh rate: %s" % [DisplayServer.screen_get_size(i), DisplayServer.screen_get_refresh_rate(i)])
	add_description_metadata("Current screen", get_window().current_screen + 1)
	
	add_description_newline()
	
	if is_instance_valid(Utils.game):
		add_description_metadata("Map", Save.current_map)
		add_description_metadata("Time", "%02d:%02d:%02d" % [Save.game_time / 3600, Save.game_time / 60 % 60, Save.game_time % 60])
	
	var query = "https://api.trello.com/1/cards" + key_and_token
	query += "&idList=" + list_id
	query += "&name=" + current_card_title.uri_encode()
	query += "&desc=" + "\n".join(description).uri_encode()
	query += "&pos=top"
	
	http_req.request(query, [], true, HTTPClient.METHOD_POST)

func add_label_to_card():
	task = tasks.ADD_LABEL
	var type = label_group.get_pressed_button().get_index()
	var query = "https://api.trello.com/1/cards/"+current_card_id+"/idLabels" + key_and_token + "&value=" + trello_labels[type].label_trello_id
	http_req.request(query, [], true, HTTPClient.METHOD_POST)

const BOUNDARY_START = "--GodotFileUploadBoundaryZ29kb3RmaWxl\r\n"

func add_attachment(title: String, file: String, type: String, data: PackedByteArray):
	# setup the header for sending attachments via multipart
	var headers = ["Content-Type: multipart/form-data; boundary=GodotFileUploadBoundaryZ29kb3RmaWxl"]
	var path = "/1/cards/"+ current_card_id +"/attachments"
	
	#http.connect_to_host("https://api.trello.com", -1, true, false)

	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(50)
	
	add_file(title, file, type, data)
	var err = http.request_raw(HTTPClient.METHOD_POST, path, headers, body)
	
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		if not OS.has_feature("web"):
			OS.delay_msec(50)
		else:
			await Engine.get_main_loop().process_frame

func add_file(title: String, file: String, type: String, data: PackedByteArray):
	body = PackedByteArray()
	add_to_body(BOUNDARY_START)
	add_to_body(str("Content-Disposition: form-data; name=\"key\"\r\n\r\n", trello_key, "\r\n"))
	add_to_body(BOUNDARY_START)
	add_to_body(str("Content-Disposition: form-data; name=\"token\"\r\n\r\n", trello_token, "\r\n"))
	add_to_body(BOUNDARY_START)
	add_to_body(str("Content-Disposition: form-data; name=\"name\"\r\n\r\n", title, "\r\n"))
	add_to_body(BOUNDARY_START)
	add_to_body("Content-Disposition: form-data; name=\"setCover\"\r\n\r\nfalse\r\n")
	add_to_body(BOUNDARY_START)
	add_to_body(str("Content-Disposition: form-data; name=\"file\"; filename=\"", file, "\"\r\nContent-Type: ", type, "\r\n\r\n"))
	body.append_array(data)
	add_to_body("\r\n--GodotFileUploadBoundaryZ29kb3RmaWxl--\r\n")

func add_to_body(what: String):
	body.append_array(what.to_ascii_buffer())

func show_feedback():
	#disable all input fields and show a short message about the current status
	send_button.hide()
	cancel_button.hide()
	short_text.editable = false
	long_text.readonly = true
	$"%Labels".hide()
	$"%Feedback".show()
	$"%Feedback".modulate = Color.WHITE
	$"%Feedback".text = "Your feedback is being sent..."

func _on_ShortDescEdit_text_changed(_new_text):
	update_send_button()

func _on_LongDescEdit_text_changed():
	update_send_button()

func update_send_button():
	# check if text is entered, if not, disable the send button
	send_button.disabled = (long_text.text == "" or short_text.text == "")

func take_screenshot() -> void:
	hide()
	$Timer.start()

func take_snapshot() -> void:
	screenshot = get_viewport().get_texture().get_data()
	var screenshot_texture := ImageTexture.new()
	screenshot_texture.create_from_image(screenshot)
	$"%ScreenshotPreview".texture = screenshot_texture
	show()

func add_description_newline():
	description.append("")

func add_description_metadata(field: String, data):
	description.append("**%s:** %s" % [field, data])

func exit() -> void:
	if not locked:
		queue_free()

func finish(success: bool):
	if success:
		$"%Feedback".modulate = Color.GREEN
		$"%Feedback".text = "Feedback sent successfully, thank you!"
	else:
		$"%Feedback".modulate = Color.RED
		$"%Feedback".text = "Failed to send feedback. Check your connection and try again."
		send_button.show()
		send_button.disabled = false
	
	cancel_button.show()
	cancel_button.text = "Close"
	locked = false

func text_edited(new_text := "") -> void:
	$"%Send".disabled = $"%Title".text.is_empty() or $"%Description".text.is_empty()

func pick_screenshot() -> void:
	$"%FileDialog".popup_centered_ratio()

func _on_FileDialog_file_selected(path: String) -> void:
	screenshot = Image.new()
	screenshot.load(path)
	screenshot.flip_y()
	var screenshot_texture := ImageTexture.new()
	screenshot_texture.create_from_image(screenshot)
	$"%ScreenshotPreview".texture = screenshot_texture
