extends Node
## 칩튠 느낌의 사각파 효과음을 코드로 만들어 재생한다 (외부 음원 없음).

const RATE := 22050

var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0

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
