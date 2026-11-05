extends Node
## 칩튠 느낌의 사각파 효과음과 배경음악을 코드로 만들어 재생한다 (외부 음원 없음).

const RATE := 22050

var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _bgm_player: AudioStreamPlayer
var _bgm_name := ""

# 배경음악: 멜로디(사각파)·베이스(삼각파)·하이햇(노이즈).
# 음은 기준음(멜로디 C5, 베이스 C3)에서 반음 수, 길이는 8분음표 개수. 4마디(8분음표 32개)를 반복한다.
const BGM := {
	"home": {
		"bpm": 104, "hat": false,
		"lead": [[4, 1], [7, 1], [9, 1], [7, 1], [4, 1], [2, 1], [0, 2], [2, 1], [4, 1], [7, 1], [4, 1], [2, 4],
			[4, 1], [7, 1], [9, 1], [12, 1], [9, 1], [7, 1], [4, 2], [7, 1], [4, 1], [2, 1], [4, 1], [0, 4]],
		"bass": [[0, 2], [7, 2], [0, 2], [7, 2], [5, 2], [12, 2], [5, 2], [12, 2],
			[9, 2], [16, 2], [9, 2], [16, 2], [7, 2], [14, 2], [7, 2], [14, 2]],
	},
	"wod": {
		"bpm": 150, "hat": true,
		"lead": [[12, 1], [12, 1], [9, 1], [7, 1], [9, 1], [12, 1], [14, 2], [12, 1], [9, 1], [7, 1], [4, 1], [7, 4],
			[12, 1], [12, 1], [14, 1], [16, 1], [14, 1], [12, 1], [9, 2], [7, 1], [9, 1], [7, 1], [4, 1], [0, 4]],
		"bass": [[0, 1], [12, 1], [0, 1], [12, 1], [0, 1], [12, 1], [0, 1], [12, 1],
			[9, 1], [21, 1], [9, 1], [21, 1], [9, 1], [21, 1], [9, 1], [21, 1],
			[5, 1], [17, 1], [5, 1], [17, 1], [5, 1], [17, 1], [5, 1], [17, 1],
			[7, 1], [19, 1], [7, 1], [19, 1], [7, 1], [19, 1], [7, 1], [19, 1]],
	},
}

# 이름: [[주파수, 길이(초)], ...]
const SOUNDS := {
	"move": [[880.0, 0.03]],
	"select": [[660.0, 0.04], [990.0, 0.06]],
	"back": [[440.0, 0.05], [330.0, 0.05]],
	"tap": [[520.0, 0.025]],
	"perfect": [[1320.0, 0.04], [1760.0, 0.05]],
	"good": [[990.0, 0.05]],
	"miss": [[160.0, 0.12]],
	"tick": [[1200.0, 0.015]],
	"success": [[523.0, 0.1], [659.0, 0.1], [784.0, 0.1], [1047.0, 0.25]],
	"fail": [[392.0, 0.15], [330.0, 0.15], [262.0, 0.3]],
	"levelup": [[784.0, 0.08], [988.0, 0.08], [1175.0, 0.08], [1568.0, 0.2]],
	"call": [[1400.0, 0.06], [0.0, 0.04], [1400.0, 0.06], [0.0, 0.04], [1400.0, 0.06]],
	"evolve": [[392.0, 0.12], [523.0, 0.12], [392.0, 0.12], [523.0, 0.12], [659.0, 0.12], [784.0, 0.3]],
}


func _ready() -> void:
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.volume_db = -10.0
		add_child(p)
		_players.append(p)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = -16.0
	add_child(_bgm_player)


## 배경음악 틀기. 같은 곡이 이미 나오고 있으면 그대로 둔다.
func bgm(name: String) -> void:
	Settings.ensure()
	if _bgm_player == null:
		return
	if not Settings.music:
		stop_bgm()
		return
	if _bgm_name == name and _bgm_player.playing:
		return
	var key := "bgm_" + name
	if not _cache.has(key):
		_cache[key] = _build_bgm(BGM[name])
	_bgm_name = name
	_bgm_player.stream = _cache[key]
	_bgm_player.play()


func stop_bgm() -> void:
	_bgm_name = ""
	if _bgm_player:
		_bgm_player.stop()


func _build_bgm(spec: Dictionary) -> AudioStreamWAV:
	var eighth := 60.0 / float(spec.bpm) / 2.0
	var total := int(RATE * eighth * 32)
	var buf := PackedFloat32Array()
	buf.resize(total)
	buf = _voice(buf, spec.lead, 523.25, eighth, "square", 0.16)
	buf = _voice(buf, spec.bass, 130.81, eighth, "triangle", 0.22)
	if spec.hat:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var step := int(RATE * eighth)
		for k in 32:
			var start := k * step
			for i in int(RATE * 0.02):
				if start + i < total:
					buf[start + i] += rng.randf_range(-1.0, 1.0) * 0.05 * (1.0 - i / (RATE * 0.02))
	var bytes := PackedByteArray()
	bytes.resize(total * 2)
	for i in total:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = total
	return s


## 한 성부를 버퍼에 더해서 돌려준다. notes = [[반음, 8분음표 개수], ...], 반음 < 0이면 쉼표.
func _voice(buf: PackedFloat32Array, notes: Array, base: float, eighth: float, wave: String, amp: float) -> PackedFloat32Array:
	var pos := 0
	for n in notes:
		var nlen := int(RATE * eighth * int(n[1]))
		var semi: int = n[0]
		if semi >= 0:
			var freq := base * pow(2.0, semi / 12.0)
			var period := RATE / freq
			for i in nlen:
				if pos + i >= buf.size():
					break
				# 짧은 어택과 끝부분 페이드로 음이 또렷하게
				var env := minf(1.0, i / (RATE * 0.005)) * (1.0 - 0.7 * float(i) / nlen)
				var ph := fmod(i, period) / period
				var v := 0.0
				if wave == "square":
					v = 1.0 if ph < 0.25 else -1.0
				else:
					v = 4.0 * absf(ph - 0.5) - 1.0
				buf[pos + i] += v * amp * env
		pos += nlen
	return buf


func play(name: String) -> void:
	Settings.ensure()
	# 앱 시작 직후(다른 autoload가 먼저 준비될 때)에는 플레이어가 아직 없다
	if not Settings.sound or not SOUNDS.has(name) or _players.is_empty():
		return
	if not _cache.has(name):
		_cache[name] = _build(SOUNDS[name])
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _cache[name]
	p.play()


func _build(notes: Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	for n in notes:
		var freq: float = n[0]
		var count := int(RATE * float(n[1]))
		if freq <= 0.0:
			for i in count:
				bytes.append(0)
			continue
		var period := RATE / freq
		for i in count:
			# 끝부분을 줄여서 딸깍 소리를 막는다
			var env := 1.0 - float(i) / count * 0.6
			var v := 0.35 * env if fmod(i, period) < period * 0.5 else -0.35 * env
			bytes.append(int(v * 127.0) & 0xFF)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_8_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s


## 짧은 진동 (지원하는 기기에서만, 설정에서 끌 수 있다).
func buzz(ms: int = 15) -> void:
	Settings.ensure()
	if Settings.vibrate:
		Input.vibrate_handheld(ms)
