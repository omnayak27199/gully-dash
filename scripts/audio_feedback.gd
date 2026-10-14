extends Node
## Creates short synthesized tones at runtime, avoiding third-party audio assets.
## Replace these tones with original/licensed sound design during the art/audio pass.

const SAMPLE_RATE: int = 22050
const MAX_AMPLITUDE: float = 0.22


func play_event(event_name: StringName) -> void:
	if not SettingsManager.sound_enabled:
		return

	var frequency: float = 660.0
	var duration: float = 0.09
	match event_name:
		&"coin":
			frequency = 1000.0
			duration = 0.075
		&"passenger":
			frequency = 740.0
			duration = 0.18
		&"powerup":
			frequency = 520.0
			duration = 0.22
		&"crash":
			frequency = 150.0
			duration = 0.16
		&"start":
			frequency = 480.0
			duration = 0.12
		_:
			frequency = 660.0

	var sample_count: int = maxi(1, int(SAMPLE_RATE * duration))
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	for index in range(sample_count):
		var t: float = float(index) / float(SAMPLE_RATE)
		var envelope: float = exp(-t * (14.0 if event_name == &"crash" else 25.0))
		var harmonic: float = 0.0
		if event_name == &"passenger" or event_name == &"powerup":
			harmonic = 0.32 * sin(TAU * frequency * 1.5 * t)
		var wave: float = (sin(TAU * frequency * t) + harmonic) * envelope * MAX_AMPLITUDE
		var sample: int = int(clampf(wave, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(index * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm

	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
