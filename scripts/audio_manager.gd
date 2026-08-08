class_name EcoAudioManager
extends Node

const CONFIG_PATH := "user://eco_rebirth.cfg"
const MIX_RATE := 22050.0

var music_enabled: bool = true
var sfx_enabled: bool = true
var music_player: AudioStreamPlayer
var music_playback: AudioStreamGeneratorPlayback
var sfx_players: Array[AudioStreamPlayer] = []
var effects: Dictionary = {}
var effect_cooldowns: Dictionary = {}
var sample_clock: int = 0
var noise_state: int = 918273
var context: String = "menu"
var current_music_db: float = -15.0
var target_music_db: float = -15.0
var pool_cursor: int = 0


func setup() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_build_music_player()
	_build_effects()
	_build_sfx_pool()
	if "--batch-sim" in " ".join(OS.get_cmdline_user_args()):
		music_enabled = false
		sfx_enabled = false
		set_process(false)
		return
	if music_enabled:
		_start_music()


func _build_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "LivingForestMusic"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 1.25
	music_player.stream = generator
	music_player.volume_db = current_music_db
	add_child(music_player)


func _build_sfx_pool() -> void:
	for index in range(10):
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%02d" % index
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		sfx_players.append(player)


func _build_effects() -> void:
	effects["ui"] = _make_tone_effect(0.075, 520.0, 760.0, 0.34, 0.02)
	effects["world"] = _make_tone_effect(0.62, 180.0, 420.0, 0.32, 0.08)
	effects["attack"] = _make_noise_effect(0.13, 150.0, 82.0, 0.56)
	effects["hit"] = _make_noise_effect(0.17, 105.0, 58.0, 0.68)
	effects["skill"] = _make_tone_effect(0.34, 210.0, 820.0, 0.48, 0.10)
	effects["skill_rabbit"] = _make_tone_effect(0.30, 480.0, 1180.0, 0.42, 0.20)
	effects["skill_fox"] = _make_noise_effect(0.28, 390.0, 120.0, 0.48)
	effects["skill_deer"] = _make_tone_effect(0.42, 150.0, 520.0, 0.52, 0.08)
	effects["skill_wolf"] = _make_tone_effect(0.55, 270.0, 125.0, 0.50, 0.16)
	effects["skill_snake"] = _make_noise_effect(0.48, 860.0, 310.0, 0.38)
	effects["skill_bear"] = _make_noise_effect(0.58, 92.0, 42.0, 0.68)
	effects["eat"] = _make_bubble_effect()
	effects["death"] = _make_tone_effect(0.62, 270.0, 58.0, 0.55, 0.18)
	effects["victory"] = _make_arpeggio_effect()
	effects["collapse"] = _make_noise_effect(0.85, 78.0, 34.0, 0.58)
	effects["reset"] = _make_tone_effect(0.42, 360.0, 120.0, 0.42, 0.12)


func _process(delta: float) -> void:
	for effect_name in effect_cooldowns.keys():
		effect_cooldowns[effect_name] = maxf(float(effect_cooldowns[effect_name]) - delta, 0.0)
	if not music_enabled:
		return
	if not music_player.playing:
		_start_music()
	current_music_db = move_toward(current_music_db, target_music_db, delta * 8.0)
	music_player.volume_db = current_music_db
	if music_playback == null:
		return
	var frames := music_playback.get_frames_available()
	for frame_index in range(frames):
		music_playback.push_frame(_music_frame(float(sample_clock) / MIX_RATE))
		sample_clock += 1


func _start_music() -> void:
	if music_player == null:
		return
	music_player.play()
	music_playback = music_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _music_frame(time_value: float) -> Vector2:
	var chord_length := 10.0
	var chord_number := int(floor(time_value / chord_length))
	var local_time := fmod(time_value, chord_length)
	var blend := smoothstep(8.2, 10.0, local_time)
	var current_chord := _chord(chord_number)
	var next_chord := _chord(chord_number + 1)
	var pad_left := _chord_sample(current_chord, time_value, 0.0)
	var pad_right := _chord_sample(current_chord, time_value, 0.017)
	pad_left = lerpf(pad_left, _chord_sample(next_chord, time_value, 0.0), blend)
	pad_right = lerpf(pad_right, _chord_sample(next_chord, time_value, 0.017), blend)

	noise_state = (noise_state * 48271) % 2147483647
	var wind := (float(noise_state % 65536) / 32768.0 - 1.0) * 0.012
	var slow_breath := 0.76 + sin(TAU * 0.045 * time_value) * 0.18
	var melody := _melody_sample(time_value)
	var bird := _bird_sample(time_value)
	var intensity := 0.78 if context == "game" else (0.58 if context == "pause" else 0.67)
	return Vector2(
		clampf((pad_left * slow_breath + melody + wind + bird) * intensity, -0.82, 0.82),
		clampf((pad_right * slow_breath + melody * 0.86 + wind * 0.72 + bird * 0.48) * intensity, -0.82, 0.82)
	)


func _chord(index: int) -> PackedFloat32Array:
	var progression := [
		PackedFloat32Array([130.81, 164.81, 196.00]),
		PackedFloat32Array([110.00, 146.83, 164.81]),
		PackedFloat32Array([98.00, 130.81, 164.81]),
		PackedFloat32Array([116.54, 146.83, 174.61])
	]
	return progression[posmod(index, progression.size())]


func _chord_sample(chord: PackedFloat32Array, time_value: float, stereo_offset: float) -> float:
	var value := 0.0
	for note_index in range(chord.size()):
		var frequency := chord[note_index]
		value += sin(TAU * frequency * (time_value + stereo_offset * float(note_index + 1))) * 0.030
		value += sin(TAU * frequency * 0.5 * time_value + float(note_index) * 0.8) * 0.018
	return value


func _melody_sample(time_value: float) -> float:
	var notes := PackedFloat32Array([392.0, 440.0, 523.25, 440.0, 349.23, 392.0, 329.63, 293.66])
	var step_length := 1.25
	var step := int(floor(time_value / step_length))
	var local := fmod(time_value, step_length)
	var envelope := exp(-local * 3.4) * smoothstep(0.0, 0.025, local)
	var frequency := notes[posmod(step, notes.size())]
	return sin(TAU * frequency * time_value) * envelope * 0.018


func _bird_sample(time_value: float) -> float:
	var local := fmod(time_value + 2.4, 13.0)
	if local > 0.62:
		return 0.0
	var envelope := sin(PI * local / 0.62)
	var frequency := 920.0 + local * 880.0 + sin(local * 38.0) * 85.0
	return sin(TAU * frequency * time_value) * envelope * 0.014


func play_sfx(effect_name: String, gain_db: float = 0.0) -> void:
	if not sfx_enabled or not effects.has(effect_name) or sfx_players.is_empty():
		return
	if float(effect_cooldowns.get(effect_name, 0.0)) > 0.0:
		return
	effect_cooldowns[effect_name] = _effect_cooldown(effect_name)
	var selected: AudioStreamPlayer
	for player in sfx_players:
		if not player.playing:
			selected = player
			break
	if selected == null:
		selected = sfx_players[pool_cursor % sfx_players.size()]
		pool_cursor += 1
	selected.stream = effects[effect_name]
	selected.volume_db = -6.0 + gain_db
	selected.pitch_scale = 0.96 + float((sample_clock + pool_cursor * 17) % 9) * 0.01
	selected.play()


func _effect_cooldown(effect_name: String) -> float:
	match effect_name:
		"attack", "hit": return 0.055
		"death": return 0.16
		"ui": return 0.025
		_: return 0.08


func _make_tone_effect(duration: float, start_frequency: float, end_frequency: float, amplitude: float, shimmer: float) -> AudioStreamWAV:
	return _make_wav(duration, func(time_value: float, progress: float) -> float:
		var frequency := lerpf(start_frequency, end_frequency, progress)
		var envelope := pow(1.0 - progress, 1.8) * smoothstep(0.0, 0.025, progress)
		var base := sin(TAU * frequency * time_value)
		var upper := sin(TAU * frequency * 2.01 * time_value + 0.4) * shimmer
		return (base + upper) * amplitude * envelope
	)


func _make_noise_effect(duration: float, start_frequency: float, end_frequency: float, amplitude: float) -> AudioStreamWAV:
	var local_noise := 72193
	return _make_wav(duration, func(time_value: float, progress: float) -> float:
		local_noise = (local_noise * 16807) % 2147483647
		var noise := float(local_noise % 65536) / 32768.0 - 1.0
		var frequency := lerpf(start_frequency, end_frequency, progress)
		var tone := sin(TAU * frequency * time_value)
		var envelope := pow(1.0 - progress, 2.4) * smoothstep(0.0, 0.012, progress)
		return (noise * 0.58 + tone * 0.62) * amplitude * envelope
	)


func _make_bubble_effect() -> AudioStreamWAV:
	return _make_wav(0.34, func(time_value: float, progress: float) -> float:
		var pulse := fmod(time_value, 0.11)
		var pulse_index := int(time_value / 0.11)
		var envelope := exp(-pulse * 27.0) * (1.0 - progress)
		var frequency := 420.0 + float(pulse_index) * 135.0 + pulse * 900.0
		return sin(TAU * frequency * time_value) * envelope * 0.36
	)


func _make_arpeggio_effect() -> AudioStreamWAV:
	var notes := PackedFloat32Array([261.63, 329.63, 392.0, 523.25, 659.25])
	return _make_wav(1.05, func(time_value: float, progress: float) -> float:
		var note_index := mini(int(time_value / 0.19), notes.size() - 1)
		var local := fmod(time_value, 0.19)
		var envelope := exp(-local * 7.5) * (1.0 - progress * 0.35)
		return (sin(TAU * notes[note_index] * time_value) + sin(TAU * notes[note_index] * 2.0 * time_value) * 0.18) * envelope * 0.32
	)


func _make_wav(duration: float, sample_function: Callable) -> AudioStreamWAV:
	var sample_count := maxi(int(duration * MIX_RATE), 1)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var progress := float(sample_index) / float(sample_count)
		var sample := clampf(float(sample_function.call(float(sample_index) / MIX_RATE, progress)), -1.0, 1.0)
		bytes.encode_s16(sample_index * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(MIX_RATE)
	stream.stereo = false
	stream.data = bytes
	return stream


func set_context(new_context: String) -> void:
	context = new_context
	match context:
		"game": target_music_db = -13.0
		"pause": target_music_db = -20.0
		"result": target_music_db = -18.0
		_: target_music_db = -15.0


func set_music_enabled(value: bool) -> void:
	music_enabled = value
	if music_enabled:
		_start_music()
	else:
		music_player.stop()
		music_playback = null
	_save_settings()


func set_sfx_enabled(value: bool) -> void:
	sfx_enabled = value
	if not sfx_enabled:
		for player in sfx_players:
			player.stop()
	_save_settings()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "sfx_enabled", sfx_enabled)
	config.save(CONFIG_PATH)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	music_enabled = bool(config.get_value("audio", "music_enabled", true))
	sfx_enabled = bool(config.get_value("audio", "sfx_enabled", true))
