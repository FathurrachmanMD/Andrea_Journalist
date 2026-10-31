extends Node2D

# Variabel Permainan
var time_left: int = 10
var evidence_collected: int = 0
var total_evidence: int = 4
var moral_score: int = 100
var current_floor: int = 3 # Mulai dari lantai 3 ke lantai 1
var game_started: bool = false

# Reference Node
onready var timer_node = $GameTimer
onready var timer_label = $HUD/TimerLabel
onready var evidence_label = $HUD/EvidenceLabel
onready var score_label = $HUD/ScoreLabel
onready var hint_button = $HUD/EmergencyHintButton
onready var evidence_container = $EvidenceContainer
onready var bgm_player = $BGMPlayer
onready var sfx_player = $SFXPlayer
onready var end_screen = $HUD/EndScreen
onready var status_label = $HUD/EndScreen/StatusLabel
onready var result_score_label = $HUD/EndScreen/ResultScoreLabel
onready var restart_button = $HUD/EndScreen/RestartButton
onready var notif_panel = $HUD/NotificationPanel
onready var notif_label = $HUD/NotificationPanel/NotificationLabel
onready var tween_node = $HUD/NotificationPanel/TweenNode

func _ready():
	update_hud()
	end_screen.hide()
	
	# Hubungkan sinyal tombol restart secara manual via kode
	if not restart_button.is_connected("pressed", self, "_on_RestartButton_pressed"):
		restart_button.connect("pressed", self, "_on_RestartButton_pressed")
	
	# JANGAN langsung jalankan timer & BGM di sini!
	# Tampilkan notifikasi minta pemain mengetuk layar
	show_notification("Press the Screen To Play!")

func _input(event):
	# Mendeteksi klik mouse atau sentuhan pertama pemain
	if not game_started and (event is InputEventMouseButton or event is InputEventScreenTouch):
		if event.pressed:
			start_game_session()

func start_game_session():
	game_started = true
	
	# Putar musik latar setelah interaksi pertama (aman dari pemblokiran browser)
	if not bgm_player.playing:
		bgm_player.play()
		
	# Jalankan timer permainan
	timer_node.wait_time = 1.0
	if not timer_node.is_connected("timeout", self, "_on_second_passed"):
		timer_node.connect("timeout", self, "_on_second_passed")
	timer_node.start()
	
	# Inisialisasi bukti dan notifikasi cerita sebenarnya
	setup_evidence_items()
	show_notification("WHISTLEBLOWER: THE MAFIA IS ALREADY IN THE BUILDING! \n GRAB THE EVIDENCE AND RUN!")

func setup_evidence_items():
	total_evidence = evidence_container.get_child_count()
	update_hud()
	
	for item in evidence_container.get_children():
		# 1. Jika anak item adalah ColorRect, set agar tidak memblokir klik mouse
		for child in item.get_children():
			if child is ColorRect:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# 2. Hubungkan sinyal klik berdasarkan tipe Node
		if item is BaseButton: # Berlaku untuk Button & TextureButton
			item.connect("pressed", self, "_on_evidence_clicked", [item])
		elif item is Control: # Jika menggunakan ColorRect langsung sebagai tombol
			item.connect("gui_input", self, "_on_evidence_gui_input", [item])

func _on_evidence_clicked(item_node):
	collect_evidence(item_node)

func _on_evidence_gui_input(event, item_node):
	# Mendeteksi klik mouse / sentuhan jari pada node Control/ColorRect
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		collect_evidence(item_node)

func collect_evidence(item_node):
	# Mencegah bukti ter-klik dua kali jika belum tersembunyi
	if not item_node.visible:
		return
		
	sfx_player.play()
	item_node.hide() # GANTI queue_free() MENJADI hide()
	
	evidence_collected += 1
	update_hud()
	
	if evidence_collected >= total_evidence:
		next_floor_or_win()

func _on_second_passed():
	time_left -= 1
	update_hud()
	
	# Efek panik: Guncang layar jika waktu tersisa <= 10 detik
	if time_left <= 10 and time_left > 0:
		shake_screen()
		
	if time_left <= 0:
		game_over("Time's Up! The Mafia Captured You.")
		
func shake_screen():
	# Menggoyangkan posisi node Main/Background secara acak
	var shake_intensity = 6.0
	position = Vector2(
		rand_range(-shake_intensity, shake_intensity),
		rand_range(-shake_intensity, shake_intensity)
	)
	
	# Kembalikan posisi ke normal setelah 0.2 detik
	yield(get_tree().create_timer(0.2), "timeout")
	position = Vector2.ZERO

func _on_EmergencyHint_pressed():
	moral_score -= 35
	if moral_score < 0:
		moral_score = 0
		
	# Sembunyikan semua sisa bukti, jangan di-queue_free
	for item in evidence_container.get_children():
		item.hide()
		
	update_hud()
	next_floor_or_win()

func update_hud():
	timer_label.text = "Time: " + str(time_left) + "s"
	evidence_label.text = "Evidence: " + str(evidence_collected) + "/" + str(total_evidence)
	score_label.text = "Morality: " + str(moral_score) + "%"

func next_floor_or_win():
	timer_node.stop()
	
	if current_floor > 2:
		current_floor -= 1
		show_notification("RUN TO " + str(current_floor) + " FLOOR! THE MAFIA GETTING CLOSER!")
		
		# Reset waktu & bukti untuk lantai berikutnya
		time_left = 5 # Lantai bawah waktunya lebih singkat!
		evidence_collected = 0
		
		# Respawn/tampilkan kembali bukti-bukti di layar
		reset_evidence_items()
		
		# Restart timer
		timer_node.start()
		
	elif current_floor > 1:
		current_floor -= 1
		show_notification("RUN TO " + str(current_floor) + " FLOOR! THE MAFIA GETTING CLOSER!")
		
		# Reset waktu & bukti untuk lantai berikutnya
		time_left = 3 # Lantai bawah waktunya lebih singkat!
		evidence_collected = 0
		
		# Respawn/tampilkan kembali bukti-bukti di layar
		reset_evidence_items()
		
		# Restart timer
		timer_node.start()
		
	else:
		# Jika sudah menyelesaikan Lantai 1 -> MENANG!
		status_label.text = "ESCAPED!"
		result_score_label.text = "Morality: " + str(moral_score) + "%"
		end_screen.show()

func reset_evidence_items():
	# Hitung ulang total bukti di lantai ini
	total_evidence = evidence_container.get_child_count()
	
	for item in evidence_container.get_children():
		item.show() # Munculkan kembali bukti yang disembunyikan
		
		# (Opsional) Geser posisi bukti sedikit secara acak agar terasa seperti ruangan baru:
		var random_x = rand_range(120, 580)
		var random_y = rand_range(350, 950)
		item.rect_position = Vector2(random_x, random_y) # Jika memakai TextureButton/Button

func game_over(reason: String):
	timer_node.stop()
	bgm_player.stop() # Hentikan lagu atau ganti SFX kalah
	
	status_label.text = reason
	result_score_label.text = "Evidence Obtained: " + str(evidence_collected) + "/" + str(total_evidence)
	end_screen.show()
	
func _on_RestartButton_pressed():
	# Reload scene saat ini untuk mencoba lagi
	get_tree().reload_current_scene()
	
func show_notification(text_message: String):
	notif_label.text = text_message
	
	# Slide Down: Turun dari Y: -130 (luar layar atas) ke Y: 160
	tween_node.interpolate_property(
		notif_panel, 
		"rect_position:y", 
		-130, 160, 
		0.5, 
		Tween.TRANS_BACK, 
		Tween.EASE_OUT
	)
	tween_node.start()
	
	# Tahan 3.5 detik
	yield(get_tree().create_timer(3.5), "timeout")
	
	# Slide Up: Naik kembali ke Y: -130
	tween_node.interpolate_property(
		notif_panel, 
		"rect_position:y", 
		160, -130, 
		0.5, 
		Tween.TRANS_QUAD, 
		Tween.EASE_IN
	)
	tween_node.start()
