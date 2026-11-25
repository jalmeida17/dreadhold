extends SceneTree
## Dreadhold - procedural audio generator (all SFX + looping music).
## 100% synthesized in code: no samples, no downloads. Deterministic (fixed seeds).
## Run:
##   Godot_v4.6-stable_mono_win64_console.exe --headless --path C:\dev\jeu-godot --script res://tools/gen_audio.gd
## Output: res://assets/sfx/*.wav and res://assets/music/*.wav (RIFF PCM 16-bit mono, 22050 Hz).

const SR := 22050
const SFX_DIR := "res://assets/sfx/"
const MUS_DIR := "res://assets/music/"
const SFX_PEAK_DB := -1.0
const MUS_PEAK_DB := -3.0

const LP := 0
const BP := 1
const HP := 2

# Male formant frequencies (F1, F2, F3).
const VOW := {
	"a": [730.0, 1090.0, 2440.0],
	"o": [570.0, 840.0, 2410.0],
	"u": [300.0, 870.0, 2240.0],
	"e": [530.0, 1840.0, 2480.0],
	"i": [270.0, 2290.0, 3010.0],
	"uh": [640.0, 1190.0, 2390.0],
}

# Freeverb-style comb / allpass lengths (scaled for 22.05 kHz).
const COMBS := [557, 593, 641, 677, 709, 743, 779, 811]
const APS := [277, 219, 173, 113]

# Church-bell-like partial ratios relative to the strike tone.
const BELL_R := [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 2.662, 3.011, 4.166, 5.433, 6.796]
const BELL_A := [0.55, 0.42, 0.5, 0.22, 0.45, 0.2, 0.15, 0.14, 0.1, 0.07, 0.05]
const BELL_T := [4.0, 2.2, 1.7, 1.2, 1.1, 0.75, 0.6, 0.45, 0.32, 0.22, 0.15]

const SFX_LIST := [
	"ui_hover", "ui_click", "ui_confirm",
	"swing", "spin", "charge", "hit_flesh", "hit_bone", "hit_metal",
	"fireball_cast", "fireball_explode", "frost_nova", "blink",
	"bow_shoot", "arrow_hit", "volley", "dash",
	"player_hurt", "player_death", "potion_drink", "coin_pickup", "item_pickup", "footstep",
	"ghoul_alert", "ghoul_attack", "ghoul_death", "skeleton_alert", "skeleton_death",
	"cultist_cast", "cultist_death", "brute_roar", "brute_smash", "brute_death",
	"boss_roar", "boss_cast", "boss_death", "enemy_spawn", "shadow_bolt", "bolt_impact", "enemy_arrow",
	"wave_start", "wave_clear", "boon_select", "game_over", "boss_warning",
]

const MUSIC_LIST := ["music_menu", "music_battle", "music_boss"]

var rng := RandomNumberGenerator.new()
var rows: Array = []
var failures: Array = []


func _init() -> void:
	var t_all := Time.get_ticks_msec()
	var sfx_abs := ProjectSettings.globalize_path(SFX_DIR)
	var mus_abs := ProjectSettings.globalize_path(MUS_DIR)
	DirAccess.make_dir_recursive_absolute(sfx_abs)
	DirAccess.make_dir_recursive_absolute(mus_abs)
	print("[gen_audio] SFX dir:   ", sfx_abs)
	print("[gen_audio] Music dir: ", mus_abs)

	# optional subset:  ... --script res://tools/gen_audio.gd -- only=swing,music_menu
	var only: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5).split(",")

	for sname in SFX_LIST:
		if only.size() > 0 and not only.has(sname):
			continue
		var t0 := Time.get_ticks_msec()
		rng.seed = hash(sname)
		var res: Variant = call("sfx_" + sname)
		if typeof(res) != TYPE_PACKED_FLOAT32_ARRAY:
			failures.append(sname)
			push_error("gen_audio: recipe failed: " + sname)
			continue
		var raw: PackedFloat32Array = res
		if raw.size() == 0:
			failures.append(sname)
			continue
		var buf := finish_sfx(raw)
		save_wav(sfx_abs + sname + ".wav", buf, sname, Time.get_ticks_msec() - t0, "")

	for mname in MUSIC_LIST:
		if only.size() > 0 and not only.has(mname):
			continue
		var t0 := Time.get_ticks_msec()
		var res: Variant = call(mname)
		if typeof(res) != TYPE_PACKED_FLOAT32_ARRAY:
			failures.append(mname)
			push_error("gen_audio: music failed: " + mname)
			continue
		var buf: PackedFloat32Array = res
		save_wav(mus_abs + mname + ".wav", buf, mname, Time.get_ticks_msec() - t0, seam_info(buf), true)

	print_summary(sfx_abs, mus_abs, Time.get_ticks_msec() - t_all)
	quit()


# =====================================================================
# Output, stats, finishing
# =====================================================================
func finish_sfx(x: PackedFloat32Array) -> PackedFloat32Array:
	var y := hp1(x, 18.0)
	normalize(y, SFX_PEAK_DB)
	var last := 0
	for i in range(y.size() - 1, -1, -1):
		if absf(y[i]) > 0.0018:
			last = i
			break
	var keep := mini(y.size(), last + ns(0.012))
	y = y.slice(0, keep)
	fade(y, ns(0.0015), mini(ns(0.03), int(keep * 0.25)))
	normalize(y, SFX_PEAK_DB)
	return y


func finish_music(bus: PackedFloat32Array, loop_len: int) -> PackedFloat32Array:
	tail_fade(bus, 1.0)
	var y := loop_wrap(bus, loop_len)
	# remove DC (mean subtraction keeps the loop periodic), find peak
	var s := 0.0
	for i in loop_len:
		s += y[i]
	var mean := s / loop_len
	var p := 1e-9
	for i in loop_len:
		var v: float = y[i] - mean
		y[i] = v
		if v > p:
			p = v
		elif -v > p:
			p = -v
	# gentle tanh glue, peak lands exactly on MUS_PEAK_DB
	var drive := 1.5
	var k := drive / p
	var target := pow(10.0, MUS_PEAK_DB / 20.0) / tanh(drive)
	for i in loop_len:
		y[i] = tanh(y[i] * k) * target
	return y


# RIFF PCM 16-bit mono. loop=true appends a standard "smpl" chunk with one forward
# loop over the whole file; Godot's WAV importer ("Loop Mode: Detect From WAV", the
# default) then imports the stream as looping. loop_end = frame count (Godot's loop
# end is exclusive), so the whole buffer plays before wrapping.
func save_wav(path: String, buf: PackedFloat32Array, label: String, ms: int, extra: String, loop: bool = false) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		failures.append(label)
		push_error("gen_audio: cannot write " + path + " err=" + str(FileAccess.get_open_error()))
		return
	var n := buf.size()
	var data_size := n * 2
	var smpl_size := 60 if loop else 0
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data_size + (8 + smpl_size if loop else 0))
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(1)
	f.store_32(SR)
	f.store_32(SR * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data_size)
	var bytes := PackedByteArray()
	bytes.resize(data_size)
	for i in n:
		var v := int(round(clampf(buf[i], -1.0, 1.0) * 32767.0))
		bytes.encode_s16(i * 2, v)
	f.store_buffer(bytes)
	if loop:
		f.store_buffer("smpl".to_ascii_buffer())
		f.store_32(smpl_size)
		f.store_32(0)                       # manufacturer
		f.store_32(0)                       # product
		f.store_32(int(1000000000.0 / SR))  # sample period (ns)
		f.store_32(60)                      # MIDI unity note
		f.store_32(0)                       # pitch fraction
		f.store_32(0)                       # SMPTE format
		f.store_32(0)                       # SMPTE offset
		f.store_32(1)                       # number of loops
		f.store_32(0)                       # sampler data size
		f.store_32(0)                       # cue point id
		f.store_32(0)                       # loop type: forward
		f.store_32(0)                       # loop start
		f.store_32(n)                       # loop end
		f.store_32(0)                       # fraction
		f.store_32(0)                       # play count: infinite
	f.close()
	var pk := peak(buf)
	var rm := rms(buf)
	rows.append([label, float(n) / SR, db(pk), db(rm), 44 + data_size, ms, extra])
	print("  %-18s %6.2f s  peak %6.2f dBFS  rms %6.2f dBFS  (%d ms) %s" % [label, float(n) / SR, db(pk), db(rm), ms, extra])


func seam_info(y: PackedFloat32Array) -> String:
	var n := y.size()
	var s := 0.0
	for i in range(1, n):
		s += absf(y[i] - y[i - 1])
	var avg := s / float(n - 1)
	var jump := absf(y[0] - y[n - 1])
	return "loop seam jump %.4f (avg step %.4f)" % [jump, avg]


func print_summary(sfx_abs: String, mus_abs: String, total_ms: int) -> void:
	print("")
	print("[gen_audio] ===== files on disk =====")
	for d in [sfx_abs, mus_abs]:
		var files := DirAccess.get_files_at(d)
		for fn in files:
			if not fn.ends_with(".wav"):
				continue
			var fa := FileAccess.open(d + fn, FileAccess.READ)
			var sz := fa.get_length() if fa != null else -1
			print("  %s%s  %d bytes" % [d, fn, sz])
	var silent := []
	var clipped := []
	for r in rows:
		if float(r[3]) < -45.0:
			silent.append(r[0])
		if float(r[2]) > -0.5:
			clipped.append(r[0])
	print("[gen_audio] generated %d files in %.1f s. failures: %s  near-silent: %s  too-hot: %s" % [rows.size(), total_ms / 1000.0, str(failures), str(silent), str(clipped)])


# =====================================================================
# Buffer helpers
# =====================================================================
func ns(sec: float) -> int:
	return maxi(1, int(round(sec * SR)))


func db(v: float) -> float:
	return 20.0 * log(maxf(v, 1e-9)) / log(10.0)


func midi(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


func zeros(n: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(n)
	b.fill(0.0)
	return b


func filled(n: int, v: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(n)
	b.fill(v)
	return b


func scaled(a: PackedFloat32Array, g: float) -> PackedFloat32Array:
	var b := a.duplicate()
	for i in b.size():
		b[i] *= g
	return b


func gain(a: PackedFloat32Array, g: float) -> PackedFloat32Array:
	for i in a.size():
		a[i] *= g
	return a


func mulb(a: PackedFloat32Array, e: PackedFloat32Array) -> PackedFloat32Array:
	var n := mini(a.size(), e.size())
	for i in n:
		a[i] *= e[i]
	for i in range(n, a.size()):
		a[i] = 0.0
	return a


func mix(dst: PackedFloat32Array, src: PackedFloat32Array, off: int = 0, g: float = 1.0) -> void:
	var s0 := maxi(0, -off)
	var s1 := mini(src.size(), dst.size() - off)
	for i in range(s0, s1):
		dst[off + i] += src[i] * g


func mix_t(dst: PackedFloat32Array, src: PackedFloat32Array, t: float, g: float = 1.0) -> void:
	mix(dst, src, int(round(t * SR)), g)


func peak(a: PackedFloat32Array) -> float:
	var p := 0.0
	for i in a.size():
		var v := absf(a[i])
		if v > p:
			p = v
	return p


func rms(a: PackedFloat32Array) -> float:
	var s := 0.0
	for i in a.size():
		var v: float = a[i]
		s += v * v
	return sqrt(s / maxf(1.0, float(a.size())))


func normalize(a: PackedFloat32Array, peak_db: float) -> PackedFloat32Array:
	var p := peak(a)
	if p > 1e-9:
		gain(a, pow(10.0, peak_db / 20.0) / p)
	return a


# scale to a given linear peak (in place) - used to balance layers
func nrm(a: PackedFloat32Array, p: float) -> PackedFloat32Array:
	var pk := peak(a)
	if pk > 1e-9:
		gain(a, p / pk)
	return a


func norm_rms(a: PackedFloat32Array, target: float) -> PackedFloat32Array:
	var r := rms(a)
	if r > 1e-9:
		gain(a, target / r)
	return a


func fade(a: PackedFloat32Array, n_in: int, n_out: int) -> void:
	var n := a.size()
	for i in mini(n_in, n):
		a[i] *= float(i) / n_in
	for k in mini(n_out, n):
		a[n - 1 - k] *= float(k) / n_out


func tail_fade(a: PackedFloat32Array, sec: float) -> void:
	var n := a.size()
	var nf := mini(ns(sec), n)
	for k in nf:
		a[n - nf + k] *= 0.5 + 0.5 * cos(PI * float(k) / nf)


func loop_wrap(bus: PackedFloat32Array, loop_len: int) -> PackedFloat32Array:
	var out := bus.slice(0, loop_len)
	var k := loop_len
	while k < bus.size():
		var e := mini(bus.size(), k + loop_len)
		for i in range(k, e):
			out[i - k] += bus[i]
		k += loop_len
	return out


func noise(n: int) -> PackedFloat32Array:
	var b := zeros(n)
	for i in n:
		b[i] = rng.randf() * 2.0 - 1.0
	return b


# smooth random curve in [-1, 1], new target `rate` times per second
func smooth_noise(n: int, rate: float) -> PackedFloat32Array:
	var b := zeros(n)
	var stp := maxi(1, int(SR / maxf(rate, 0.01)))
	var a := rng.randf() * 2.0 - 1.0
	var c := rng.randf() * 2.0 - 1.0
	var k := 0
	var inv := 1.0 / stp
	for i in n:
		if k >= stp:
			k = 0
			a = c
			c = rng.randf() * 2.0 - 1.0
		var t := k * inv
		b[i] = a + (c - a) * (t * t * (3.0 - 2.0 * t))
		k += 1
	return b


# =====================================================================
# Envelopes and control curves
# =====================================================================
# Piecewise-linear breakpoints: pts = [t0, v0, t1, v1, ...] in seconds.
func env_bp(n: int, pts: Array) -> PackedFloat32Array:
	var b := zeros(n)
	var m := pts.size() >> 1
	var v0: float = pts[1]
	var t0i := clampi(int(float(pts[0]) * SR), 0, n)
	for i in t0i:
		b[i] = v0
	for s in range(m - 1):
		var ta: float = pts[s * 2]
		var va: float = pts[s * 2 + 1]
		var tb: float = pts[s * 2 + 2]
		var vb: float = pts[s * 2 + 3]
		var ia := int(ta * SR)
		var ib := int(tb * SR)
		if ib <= ia:
			continue
		var inv := 1.0 / float(ib - ia)
		var lo := clampi(ia, 0, n)
		var hi := clampi(ib, 0, n)
		for i in range(lo, hi):
			b[i] = va + (vb - va) * float(i - ia) * inv
	var vl: float = pts[m * 2 - 1]
	var tl := clampi(int(float(pts[m * 2 - 2]) * SR), 0, n)
	for i in range(tl, n):
		b[i] = vl
	return b


# Same as env_bp but interpolates in the log domain (for frequencies).
func freq_bp(n: int, pts: Array) -> PackedFloat32Array:
	var p := pts.duplicate()
	for k in range(1, p.size(), 2):
		p[k] = log(maxf(float(p[k]), 0.001))
	var b := env_bp(n, p)
	for i in n:
		b[i] = exp(b[i])
	return b


func env_perc(n: int, att: float, tau: float) -> PackedFloat32Array:
	var b := zeros(n)
	var na := maxi(1, int(att * SR))
	var g := exp(-1.0 / (maxf(tau, 0.0001) * SR))
	var v := 1.0
	for i in n:
		if i < na:
			b[i] = float(i) / na
		else:
			b[i] = v
			v *= g
	return b


# exponential pitch drop from f_hi to f_lo
func fdrop(n: int, f_hi: float, f_lo: float, tau: float) -> PackedFloat32Array:
	var b := zeros(n)
	var g := exp(-1.0 / (tau * SR))
	var d := f_hi - f_lo
	for i in n:
		b[i] = f_lo + d
		d *= g
	return b


func vibrato(fr: PackedFloat32Array, rate: float, depth: float, delay: float = 0.0, ramp: float = 0.0, ph: float = 0.0) -> PackedFloat32Array:
	var w := TAU * rate / SR
	var d0 := int(delay * SR)
	var rr := maxf(1.0, ramp * SR)
	for i in range(d0, fr.size()):
		var r := minf(1.0, float(i - d0) / rr)
		fr[i] *= 1.0 + depth * r * sin(ph + w * i)
	return fr


# =====================================================================
# Oscillators (frequency given per sample)
# =====================================================================
func osc_sine(freq: PackedFloat32Array, ph0: float = 0.0) -> PackedFloat32Array:
	var n := freq.size()
	var b := zeros(n)
	var ph := ph0
	var k := TAU / SR
	for i in n:
		b[i] = sin(ph)
		ph += freq[i] * k
	return b


# PolyBLEP band-limited sawtooth (phase 0..1)
func osc_saw(freq: PackedFloat32Array, ph0: float = 0.0) -> PackedFloat32Array:
	var n := freq.size()
	var b := zeros(n)
	var ph := ph0
	var isr := 1.0 / SR
	for i in n:
		var dt: float = freq[i] * isr
		var v := 2.0 * ph - 1.0
		if ph < dt:
			var t := ph / dt
			v -= t + t - t * t - 1.0
		elif ph > 1.0 - dt:
			var t := (ph - 1.0) / dt
			v -= t * t + t + t + 1.0
		b[i] = v
		ph += dt
		if ph >= 1.0:
			ph -= 1.0
	return b


func osc_square(freq: PackedFloat32Array, pw: float = 0.5, ph0: float = 0.0) -> PackedFloat32Array:
	var n := freq.size()
	var b := zeros(n)
	var ph := ph0
	var isr := 1.0 / SR
	for i in n:
		var dt: float = freq[i] * isr
		var v := 1.0 if ph < pw else -1.0
		if ph < dt:
			var t := ph / dt
			v += t + t - t * t - 1.0
		elif ph > 1.0 - dt:
			var t := (ph - 1.0) / dt
			v += t * t + t + t + 1.0
		var p2 := ph - pw
		if p2 < 0.0:
			p2 += 1.0
		if p2 < dt:
			var t := p2 / dt
			v -= t + t - t * t - 1.0
		elif p2 > 1.0 - dt:
			var t := (p2 - 1.0) / dt
			v -= t * t + t + t + 1.0
		b[i] = v
		ph += dt
		if ph >= 1.0:
			ph -= 1.0
	return b


func osc_tri(freq: PackedFloat32Array, ph0: float = 0.0) -> PackedFloat32Array:
	var n := freq.size()
	var b := zeros(n)
	var ph := ph0
	var isr := 1.0 / SR
	for i in n:
		b[i] = 4.0 * absf(ph - 0.5) - 1.0
		ph += freq[i] * isr
		if ph >= 1.0:
			ph -= 1.0
	return b


# =====================================================================
# Filters
# =====================================================================
func lp1(x: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var y := zeros(x.size())
	var a := exp(-TAU * fc / SR)
	var s := 0.0
	for i in x.size():
		var v: float = x[i]
		s = v + a * (s - v)
		y[i] = s
	return y


func hp1(x: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var y := zeros(x.size())
	var a := exp(-TAU * fc / SR)
	var s := 0.0
	for i in x.size():
		var v: float = x[i]
		s = v + a * (s - v)
		y[i] = v - s
	return y


# Zavalishin TPT state-variable filter, static cutoff. mode LP / BP (unity peak) / HP
func svf(x: PackedFloat32Array, fc: float, q: float, mode: int) -> PackedFloat32Array:
	var n := x.size()
	var y := zeros(n)
	var g := tan(PI * clampf(fc, 5.0, SR * 0.45) / SR)
	var k := 1.0 / q
	var a1 := 1.0 / (1.0 + g * (g + k))
	var a2 := g * a1
	var a3 := g * a2
	var ic1 := 0.0
	var ic2 := 0.0
	for i in n:
		var v0: float = x[i]
		var v3 := v0 - ic2
		var v1 := a1 * ic1 + a2 * v3
		var v2 := ic2 + a2 * ic1 + a3 * v3
		ic1 = 2.0 * v1 - ic1
		ic2 = 2.0 * v2 - ic2
		if mode == LP:
			y[i] = v2
		elif mode == BP:
			y[i] = v1 * k
		else:
			y[i] = v0 - k * v1 - v2
	return y


# Same SVF with a per-sample cutoff curve.
func svf_v(x: PackedFloat32Array, fc: PackedFloat32Array, q: float, mode: int) -> PackedFloat32Array:
	var n := mini(x.size(), fc.size())
	var y := zeros(x.size())
	var k := 1.0 / q
	var ic1 := 0.0
	var ic2 := 0.0
	var lim := SR * 0.45
	var pis := PI / SR
	for i in n:
		var f: float = fc[i]
		if f < 10.0:
			f = 10.0
		elif f > lim:
			f = lim
		var g := tan(pis * f)
		var a1 := 1.0 / (1.0 + g * (g + k))
		var a2 := g * a1
		var a3 := g * a2
		var v0: float = x[i]
		var v3 := v0 - ic2
		var v1 := a1 * ic1 + a2 * v3
		var v2 := ic2 + a2 * ic1 + a3 * v3
		ic1 = 2.0 * v1 - ic1
		ic2 = 2.0 * v2 - ic2
		if mode == LP:
			y[i] = v2
		elif mode == BP:
			y[i] = v1 * k
		else:
			y[i] = v0 - k * v1 - v2
	return y


func comb_fb(x: PackedFloat32Array, delay_s: float, fb: float) -> PackedFloat32Array:
	var n := x.size()
	var d := maxi(1, int(delay_s * SR))
	var y := zeros(n)
	for i in n:
		var v: float = x[i]
		if i >= d:
			v += fb * y[i - d]
		y[i] = v
	return y


# Static vowel formant bank.
func formant_static(x: PackedFloat32Array, vowel: String, shift: float, q: float) -> PackedFloat32Array:
	var fs: Array = VOW[vowel]
	var y := svf(x, float(fs[0]) * shift, q, BP)
	mix(y, svf(x, float(fs[1]) * shift, q * 1.4, BP), 0, 0.55)
	mix(y, svf(x, float(fs[2]) * shift, q * 1.8, BP), 0, 0.3)
	return y


# Time-varying vowel: seq = [t0, "a", t1, "o", ...]; formants glide between vowels.
func vocal_tract(x: PackedFloat32Array, seq: Array, shift: float, q: float) -> PackedFloat32Array:
	var n := x.size()
	var y := zeros(n)
	var gains := [1.0, 0.6, 0.3]
	var qs := [q, q * 1.4, q * 1.8]
	for k in 3:
		var pts := []
		for j in range(0, seq.size(), 2):
			pts.append(seq[j])
			var vf: Array = VOW[seq[j + 1]]
			pts.append(float(vf[k]) * shift)
		var fk := freq_bp(n, pts)
		mix(y, svf_v(x, fk, qs[k], BP), 0, gains[k])
	return y


# Mono Freeverb-style reverb (8 damped combs + 4 allpasses). Returns x + tail.
func reverb(x: PackedFloat32Array, wet: float, room: float = 0.78, damp: float = 0.35, size: float = 1.0, tail: float = 0.4, dry: float = 1.0) -> PackedFloat32Array:
	var nt := ns(tail) if tail > 0.0 else 0
	var nx := x.size()
	var n := nx + nt
	var inp := zeros(n)
	for i in nx:
		inp[i] = x[i]
	var acc := zeros(n)
	var d2 := 1.0 - damp
	for cl in COMBS:
		var cl_len := maxi(8, int(float(cl) * size))
		var line := zeros(cl_len)
		var idx := 0
		var filt := 0.0
		for i in n:
			var o: float = line[idx]
			filt = o * d2 + filt * damp
			line[idx] = inp[i] + filt * room
			acc[i] += o
			idx += 1
			if idx >= cl_len:
				idx = 0
	for al in APS:
		var al_len := maxi(4, int(float(al) * size))
		var line := zeros(al_len)
		var idx := 0
		for i in n:
			var bo: float = line[idx]
			var v: float = acc[i]
			acc[i] = bo - v
			line[idx] = v + bo * 0.5
			idx += 1
			if idx >= al_len:
				idx = 0
	var wg := wet / float(COMBS.size())
	for i in n:
		acc[i] = inp[i] * dry + acc[i] * wg
	if nt > 0:
		var fl := maxi(1, int(nt * 0.5))
		for k in fl:
			acc[n - fl + k] *= 0.5 + 0.5 * cos(PI * float(k) / fl)
	return acc


func sat(x: PackedFloat32Array, drive: float) -> PackedFloat32Array:
	var p := peak(x)
	if p < 1e-9:
		return x
	var k := drive / p
	var nk := 1.0 / tanh(drive)
	for i in x.size():
		x[i] = tanh(x[i] * k) * nk
	return x


# =====================================================================
# Synthesis building blocks
# =====================================================================
# sine with exponential pitch drop and exponential amplitude decay
func thump(dur: float, f_hi: float, f_lo: float, ptau: float, atau: float) -> PackedFloat32Array:
	var n := ns(dur)
	var y := osc_sine(fdrop(n, f_hi, f_lo, ptau))
	return mulb(y, env_perc(n, 0.0015, atau))


# filtered noise burst with percussive envelope
func burst(dur: float, fc: float, q: float, mode: int, att: float, tau: float) -> PackedFloat32Array:
	var n := ns(dur)
	var y := svf(noise(n), fc, q, mode)
	return mulb(y, env_perc(n, att, tau))


# band-passed noise with swept centre frequency
func whoosh(dur: float, fc_pts: Array, amp_pts: Array, q: float) -> PackedFloat32Array:
	var n := ns(dur)
	var y := svf_v(noise(n), freq_bp(n, fc_pts), q, BP)
	return mulb(y, env_bp(n, amp_pts))


# damped sine (resonant mode)
func ping(dur: float, f: float, tau: float, ph0: float = 0.0) -> PackedFloat32Array:
	var n := ns(dur)
	var y := zeros(n)
	var w := TAU * f / SR
	var g := exp(-1.0 / (tau * SR))
	var e := 1.0
	var ph := ph0
	for i in n:
		y[i] = e * sin(ph)
		ph += w
		e *= g
	return y


# gliding sine blip (bubbles etc.)
func chirp(dur: float, f0: float, f1: float, att: float, tau: float) -> PackedFloat32Array:
	var n := ns(dur)
	var y := osc_sine(freq_bp(n, [0.0, f0, dur, f1]))
	return mulb(y, env_perc(n, att, tau))


# sparse crackles: random decaying noise grains, density given in events/s
func crackle(dur: float, rate_pts: Array, gmin_ms: float, gmax_ms: float, hp_fc: float) -> PackedFloat32Array:
	var n := ns(dur)
	var dens := env_bp(n, rate_pts)
	var y := zeros(n)
	var inv_sr := 1.0 / SR
	for i in n:
		if rng.randf() < dens[i] * inv_sr:
			var amp := pow(rng.randf(), 1.5)
			if rng.randf() < 0.5:
				amp = -amp
			var glen := maxi(2, int(rng.randf_range(gmin_ms, gmax_ms) * SR * 0.001))
			var g := exp(-5.0 / glen)
			var e := amp
			for k in mini(glen, n - i):
				y[i + k] += e * (rng.randf() * 2.0 - 1.0)
				e *= g
	return hp1(y, hp_fc)


# additive inharmonic partials (struck metal, bells, coins, gongs)
func partials(dur: float, f0: float, ratios: Array, amps: Array, taus: Array, att: float = 0.001) -> PackedFloat32Array:
	# each partial is a damped recursive resonator x[n] = 2r.cos(w).x[n-1] - r^2.x[n-2]
	# (no sin() per sample), computed only until it has decayed by ~66 dB
	var n := ns(dur)
	var y := zeros(n)
	var lim := SR * 0.45
	for k in ratios.size():
		var f: float = f0 * float(ratios[k])
		if f >= lim or f <= 0.0:
			continue
		var a: float = amps[k]
		var tau: float = taus[k]
		var r := exp(-1.0 / (tau * SR))
		var w := TAU * f / SR
		var ph := rng.randf() * TAU
		var c1 := 2.0 * r * cos(w)
		var c2 := r * r
		var s2 := a * sin(ph)
		var s1 := a * r * sin(ph + w)
		var full := int(tau * 7.6 * SR) + 2
		var m := mini(n, full)
		if m < 2:
			continue
		# when truncated early, fade the last stretch so the cut can't tick
		var fl := 0
		if m == full:
			fl = mini(m - 2, 1024)
		y[0] += s2
		y[1] += s1
		for i in range(2, m - fl):
			var s0 := c1 * s1 - c2 * s2
			y[i] += s0
			s2 = s1
			s1 = s0
		var inv_fl := 1.0 / maxf(1.0, float(fl))
		for i in range(m - fl, m):
			var s0 := c1 * s1 - c2 * s2
			y[i] += s0 * float(m - i) * inv_fl
			s2 = s1
			s1 = s0
	var na := mini(n, maxi(1, int(att * SR)))
	for i in na:
		y[i] *= float(i) / na
	return y


func bell(dur: float, f: float, decay: float = 1.0, bright: float = 1.0) -> PackedFloat32Array:
	var amps := []
	var taus := []
	for k in BELL_R.size():
		var bk: float = 1.0 if k < 5 else bright
		amps.append(float(BELL_A[k]) * bk)
		taus.append(float(BELL_T[k]) * decay)
	var y := partials(dur, f, BELL_R, amps, taus, 0.0015)
	# slightly detuned copy of the low partials -> slow beating / warble
	var y2 := partials(dur, f * 1.0021, BELL_R.slice(0, 5), amps.slice(0, 5), taus.slice(0, 5), 0.0015)
	mix(y, y2, 0, 0.45)
	var strike := burst(0.05, 2200.0, 0.8, BP, 0.0003, 0.008)
	mix(y, nrm(strike, 0.35 * bright), 0, 1.0)
	return y


# Karplus-Strong plucked string
func pluck(dur: float, f: float, damp: float, bright: float) -> PackedFloat32Array:
	var n := ns(dur)
	var y := zeros(n)
	var pl := maxi(2, int(SR / f - 0.5))
	var s := 0.0
	for i in mini(pl, n):
		s += bright * ((rng.randf() * 2.0 - 1.0) - s)
		y[i] = s
	for i in range(pl, n):
		var a: float = y[i - pl]
		var b: float = y[i - pl - 1] if i - pl - 1 >= 0 else 0.0
		y[i] = damp * 0.5 * (a + b)
	return hp1(y, 40.0)


# glottal-ish source: saw + subharmonic growl + flutter + pitch-synchronous rasp noise
func voice_src(f0: PackedFloat32Array, jitter: float, growl: float, rasp: float) -> PackedFloat32Array:
	var n := f0.size()
	var jn := smooth_noise(n, 25.0)
	var fj := zeros(n)
	var half := zeros(n)
	for i in n:
		var f: float = f0[i] * (1.0 + jitter * jn[i])
		fj[i] = f
		half[i] = f * 0.5
	var saw := osc_saw(fj, rng.randf())
	var sub := osc_sine(half)
	var fl := smooth_noise(n, 30.0)
	var nz := noise(n)
	var y := zeros(n)
	for i in n:
		var s: float = saw[i] * (1.0 + growl * sub[i]) * (1.0 + 0.35 * growl * fl[i])
		y[i] = s * (1.0 - rasp) + nz[i] * rasp * (0.35 + 0.65 * absf(s))
	return y


# full creature/human vocalisation
func creature(d: float, f0_pts: Array, jitter: float, growl: float, rasp: float, seq: Array, shift: float, q: float, env_pts: Array, drive: float) -> PackedFloat32Array:
	var n := ns(d)
	var src := voice_src(freq_bp(n, f0_pts), jitter, growl, rasp)
	var v := vocal_tract(src, seq, shift, q)
	mulb(v, env_bp(n, env_pts))
	return sat(v, drive)


# brass-like note: detuned saws + pulse through an envelope-tracking low-pass
# k = render-rate divisor: the buffer is at SR/k (times in real seconds).
func brass_note(dur: float, f0: float, att: float, rel: float, bright0: float, vib: float, scoop: float, k: float = 1.0) -> PackedFloat32Array:
	var tk := 1.0 / k
	var n := ns(dur * tk)
	var f := f0 * k
	var bright := bright0 * k
	var fr := freq_bp(n, [0.0, f * (1.0 - scoop), minf(0.09, dur * 0.3) * tk, f])
	if vib > 0.0:
		vibrato(fr, 5.1 * k, vib, 0.22 * tk, 0.35 * tk)
	var a := osc_saw(fr, 0.0)
	var b := osc_saw(scaled(fr, 1.0035), 0.41)
	var sq := osc_square(fr, 0.42, 0.13)
	var x := zeros(n)
	for i in n:
		x[i] = 0.45 * a[i] + 0.45 * b[i] + 0.25 * sq[i]
	var t_rel := maxf(att + 0.01, dur - rel)
	var env := env_bp(n, pts_div([0.0, 0.0, att * 0.5, 0.75, att, 1.0, t_rel, 0.88, dur, 0.0], k))
	var fc := zeros(n)
	var base := f * 1.2 + 120.0 * k
	for i in n:
		var e: float = env[i]
		fc[i] = base + bright * e * e
	var y := svf_v(x, fc, 1.05, LP)
	mix(y, svf(y, 1100.0 * k, 2.2, BP), 0, 0.35)
	return mulb(y, env)


# war-horn note: brass + horn body resonance + sub octave + breath
func horn(dur: float, f: float) -> PackedFloat32Array:
	var n := ns(dur)
	var y := nrm(brass_note(dur, f, 0.12, 0.28, 2600.0, 0.006, 0.05), 1.0)
	mix(y, nrm(svf(y, 520.0, 2.5, BP), 0.5), 0, 1.0)
	var env := env_bp(n, [0.0, 0.0, 0.06, 0.8, 0.12, 1.0, dur - 0.28, 0.9, dur, 0.0])
	var sub := osc_sine(filled(n, f * 0.5))
	mulb(sub, env)
	mix(y, nrm(sub, 0.35), 0, 1.0)
	var br := svf(noise(n), 900.0, 1.5, BP)
	mulb(br, env)
	mix(y, nrm(br, 0.06), 0, 1.0)
	return y


# choir-ish voice: several detuned band-limited saws with independent slow vibrato,
# fused into one loop per voice (vibrato updated every 16 samples).
# k = render-rate divisor: the buffer is at SR/k.
func choir_voice(n: int, f: float, voices: int, detune_c: float, vib_depth: float = 0.004, k: float = 1.0) -> PackedFloat32Array:
	var y := zeros(n)
	var g := 1.0 / voices
	for v in voices:
		var c := 0.0
		if voices > 1:
			c = detune_c * (2.0 * float(v) / float(voices - 1) - 1.0)
		var dt0 := f * k * pow(2.0, c / 1200.0) / SR
		var vw := TAU * rng.randf_range(4.2, 5.6) * k * 16.0 / SR
		var vph := rng.randf() * TAU
		var ph := rng.randf()
		var dt := dt0
		for i in n:
			if (i & 15) == 0:
				dt = dt0 * (1.0 + vib_depth * sin(vph))
				vph += vw
			var s := 2.0 * ph - 1.0
			if ph < dt:
				var t := ph / dt
				s -= t + t - t * t - 1.0
			elif ph > 1.0 - dt:
				var t := (ph - 1.0) / dt
				s -= t * t + t + t + 1.0
			y[i] += s * g
			ph += dt
			if ph >= 1.0:
				ph -= 1.0
	return y


func bone_tick() -> PackedFloat32Array:
	var f := rng.randf_range(900.0, 3500.0)
	var c := ping(0.05, f, rng.randf_range(0.005, 0.02))
	mix(c, ping(0.05, f * rng.randf_range(1.4, 2.1), 0.006), 0, 0.5)
	mix(c, burst(0.01, 3000.0, 0.7, HP, 0.0001, 0.0015), 0, 0.4)
	return c


# =====================================================================
# SFX - UI
# =====================================================================
func sfx_ui_hover() -> PackedFloat32Array:
	var y := ping(0.07, 1650.0, 0.010)
	mix(y, ping(0.07, 2890.0, 0.006), 0, 0.35)
	mix(y, nrm(burst(0.02, 4200.0, 0.9, BP, 0.0003, 0.002), 0.2), 0, 1.0)
	y = lp1(y, 6000.0)
	return reverb(y, 0.12, 0.6, 0.5, 0.6, 0.12)


func sfx_ui_click() -> PackedFloat32Array:
	var y := nrm(thump(0.1, 380.0, 190.0, 0.01, 0.018), 0.8)
	mix(y, nrm(burst(0.06, 2300.0, 1.3, BP, 0.0003, 0.007), 0.7))
	mix(y, nrm(partials(0.1, 870.0, [1.0, 1.53, 2.41, 3.12], [0.5, 0.35, 0.25, 0.15], [0.02, 0.014, 0.01, 0.007]), 0.5))
	return reverb(y, 0.18, 0.65, 0.4, 0.7, 0.2)


func sfx_ui_confirm() -> PackedFloat32Array:
	var y := zeros(ns(0.45))
	var r := [1.0, 2.756, 5.404, 8.933]
	var a := [1.0, 0.45, 0.25, 0.12]
	var tt := [0.32, 0.16, 0.09, 0.05]
	mix_t(y, nrm(partials(0.45, 784.0, r, a, tt, 0.001), 0.75), 0.0)
	mix_t(y, nrm(partials(0.37, 1174.7, r, a, tt, 0.001), 1.0), 0.08)
	mix_t(y, nrm(burst(0.05, 6000.0, 0.7, HP, 0.0005, 0.01), 0.15), 0.08)
	return reverb(y, 0.22, 0.75, 0.2, 0.9, 0.35)


# =====================================================================
# SFX - Warrior
# =====================================================================
func sfx_swing() -> PackedFloat32Array:
	var d := 0.34
	var env := [0.0, 0.0, 0.11, 1.0, 0.2, 0.55, d, 0.0]
	var y := nrm(whoosh(d, [0.0, 350.0, 0.13, 1300.0, d, 420.0], env, 1.6), 0.8)
	mix(y, nrm(whoosh(d, [0.0, 110.0, 0.13, 260.0, d, 110.0], env, 0.8), 0.7))
	mix(y, nrm(whoosh(d, [0.0, 2500.0, 0.13, 4500.0, d, 2000.0], [0.0, 0.0, 0.12, 0.5, 0.24, 0.0], 2.0), 0.25))
	return reverb(y, 0.15, 0.7, 0.4, 0.8, 0.25)


func sfx_spin() -> PackedFloat32Array:
	var d := 0.72
	var n := ns(d)
	var rate := env_bp(n, [0.0, 3.2, 0.4, 5.0, d, 4.2])
	var fc := zeros(n)
	var am := zeros(n)
	var ph := -PI * 0.5
	for i in n:
		ph += TAU * rate[i] / SR
		var s := sin(ph)
		fc[i] = 650.0 * pow(2.0, 1.1 * s)
		var p := 0.5 + 0.5 * s
		am[i] = 0.3 + 0.7 * p * p
	var y := svf_v(noise(n), fc, 1.8, BP)
	mulb(y, am)
	var lo := svf_v(noise(n), scaled(fc, 0.3), 0.9, BP)
	mulb(lo, am)
	nrm(y, 0.8)
	mix(y, nrm(lo, 0.6))
	mulb(y, env_bp(n, [0.0, 0.0, 0.08, 1.0, 0.5, 0.9, d, 0.0]))
	return reverb(y, 0.18, 0.72, 0.4, 0.9, 0.3)


func sfx_charge() -> PackedFloat32Array:
	var d := 0.55
	var y := nrm(whoosh(d, [0.0, 300.0, 0.3, 1100.0, d, 700.0], [0.0, 0.0, 0.28, 1.0, 0.36, 0.55, d, 0.0], 1.2), 0.7)
	mix(y, nrm(whoosh(d, [0.0, 90.0, 0.3, 220.0, d, 150.0], [0.0, 0.0, 0.28, 1.0, d, 0.0], 0.7), 0.5))
	var ts := 0.3
	mix_t(y, nrm(thump(0.25, 140.0, 45.0, 0.03, 0.08), 1.0), ts)
	mix_t(y, nrm(burst(0.15, 700.0, 0.7, LP, 0.001, 0.03), 0.6), ts)
	for j in 5:
		var f := rng.randf_range(2200.0, 3600.0)
		var p := partials(0.12, f, [1.0, 1.47, 2.09], [1.0, 0.6, 0.4], [0.03, 0.02, 0.015])
		mix_t(y, nrm(p, 0.22 * (1.0 - j * 0.15)), ts + 0.005 + j * 0.018 + rng.randf() * 0.01)
	sat(y, 1.2)
	return reverb(y, 0.2, 0.72, 0.4, 0.9, 0.3)


func sfx_hit_flesh() -> PackedFloat32Array:
	var d := 0.26
	var y := nrm(thump(d, 170.0, 55.0, 0.025, 0.06), 1.0)
	mix(y, nrm(burst(d, 500.0, 0.7, LP, 0.001, 0.04), 0.8))
	var cr := crackle(0.12, [0.0, 900.0, 0.08, 300.0, 0.12, 0.0], 0.3, 1.5, 900.0)
	mix(y, nrm(svf(cr, 1600.0, 0.8, BP), 0.45))
	mix_t(y, nrm(whoosh(0.18, [0.0, 1400.0, 0.18, 350.0], [0.0, 0.0, 0.01, 1.0, 0.18, 0.0], 3.0), 0.3), 0.01)
	sat(y, 1.6)
	return reverb(y, 0.1, 0.65, 0.45, 0.7, 0.2)


func sfx_hit_bone() -> PackedFloat32Array:
	var d := 0.26
	var y := zeros(ns(d))
	mix(y, nrm(burst(0.04, 3000.0, 0.6, HP, 0.0002, 0.004), 1.0))
	mix(y, nrm(thump(0.1, 600.0, 340.0, 0.01, 0.02), 0.5))
	var t := 0.008
	for j in 7:
		t += rng.randf_range(0.012, 0.035)
		mix_t(y, nrm(bone_tick(), 0.6 * pow(0.8, j)), t)
	return reverb(y, 0.12, 0.65, 0.4, 0.7, 0.2)


func sfx_hit_metal() -> PackedFloat32Array:
	var d := 0.36
	var y := nrm(partials(d, 430.0, [1.0, 2.32, 3.86, 5.1, 6.93, 8.6, 11.2], [1.0, 0.7, 0.55, 0.4, 0.3, 0.2, 0.12], [0.2, 0.13, 0.09, 0.07, 0.05, 0.04, 0.03]), 0.8)
	mix(y, nrm(partials(d, 610.0, [1.0, 2.7, 4.2, 5.9], [0.6, 0.4, 0.3, 0.2], [0.08, 0.05, 0.04, 0.03]), 0.5))
	mix(y, nrm(burst(0.03, 3500.0, 0.7, BP, 0.0002, 0.004), 0.8))
	mix(y, nrm(thump(0.12, 200.0, 120.0, 0.02, 0.03), 0.4))
	return reverb(y, 0.2, 0.75, 0.3, 0.9, 0.35)


# =====================================================================
# SFX - Mage
# =====================================================================
func sfx_fireball_cast() -> PackedFloat32Array:
	var d := 0.42
	var n := ns(d)
	var w := whoosh(d, [0.0, 300.0, 0.25, 1800.0, d, 900.0], [0.0, 0.0, 0.22, 1.0, d, 0.0], 1.0)
	var fl := smooth_noise(n, 35.0)
	for i in n:
		w[i] *= 0.7 + 0.3 * fl[i]
	var y := nrm(w, 0.8)
	mix(y, nrm(whoosh(d, [0.0, 80.0, 0.25, 300.0, d, 160.0], [0.0, 0.0, 0.2, 1.0, d, 0.0], 0.7), 0.7))
	mix(y, nrm(crackle(d, [0.0, 20.0, 0.25, 250.0, d, 80.0], 0.2, 1.2, 1800.0), 0.45))
	return reverb(y, 0.18, 0.72, 0.4, 0.9, 0.3)


func sfx_fireball_explode() -> PackedFloat32Array:
	var d := 0.95
	var n := ns(d)
	var boom := nrm(thump(d, 110.0, 32.0, 0.07, 0.3), 1.0)
	var body := svf_v(noise(n), freq_bp(n, [0.0, 4000.0, 0.08, 1500.0, 0.5, 300.0, d, 150.0]), 0.8, LP)
	mulb(body, env_perc(n, 0.003, 0.22))
	mix(boom, nrm(body, 0.9))
	sat(boom, 2.0)
	var cr := crackle(d, [0.0, 600.0, 0.3, 250.0, d, 10.0], 0.3, 2.0, 1500.0)
	mulb(cr, env_bp(n, [0.0, 1.0, 0.6, 0.5, d, 0.0]))
	mix(boom, nrm(cr, 0.35))
	return reverb(boom, 0.25, 0.82, 0.4, 1.2, 0.55)


func sfx_frost_nova() -> PackedFloat32Array:
	var d := 1.0
	var n := ns(d)
	var y := nrm(burst(d, 3500.0, 0.7, HP, 0.002, 0.07), 0.6)
	var glass := zeros(n)
	for j in 14:
		var f := rng.randf_range(1800.0, 7500.0)
		var t0 := rng.randf_range(0.0, 0.12)
		var p := ping(d - t0, f, rng.randf_range(0.15, 0.6))
		mix_t(glass, p, t0, rng.randf_range(0.5, 1.0))
	var trem := smooth_noise(n, 18.0)
	for i in n:
		glass[i] *= 0.75 + 0.25 * trem[i]
	mix(y, nrm(glass, 0.7))
	var sh := svf(noise(n), 6500.0, 3.0, BP)
	mulb(sh, env_bp(n, [0.0, 0.0, 0.05, 1.0, d, 0.0]))
	mix(y, nrm(sh, 0.2))
	mix(y, nrm(crackle(d, [0.0, 300.0, 0.4, 120.0, 0.8, 10.0, d, 0.0], 0.1, 0.8, 2500.0), 0.5))
	mix(y, nrm(whoosh(0.6, [0.0, 4000.0, 0.6, 900.0], [0.0, 0.0, 0.02, 1.0, 0.6, 0.0], 1.2), 0.4))
	mix(y, nrm(thump(0.3, 160.0, 80.0, 0.03, 0.08), 0.4))
	return reverb(y, 0.3, 0.8, 0.1, 1.1, 0.5)


func sfx_blink() -> PackedFloat32Array:
	var d := 0.36
	var n := ns(d)
	var f1 := freq_bp(n, [0.0, 250.0, 0.16, 2600.0])
	vibrato(f1, 32.0, 0.08)
	var a := osc_sine(f1)
	mix(a, osc_tri(f1, 0.0), 0, 0.3)
	mulb(a, env_bp(n, [0.0, 0.0, 0.01, 1.0, 0.15, 0.8, 0.22, 0.0]))
	var nb := ns(0.24)
	var f2 := freq_bp(nb, [0.0, 3200.0, 0.24, 300.0])
	vibrato(f2, 24.0, 0.06)
	var b := osc_sine(f2)
	mulb(b, env_bp(nb, [0.0, 0.0, 0.02, 0.7, 0.24, 0.0]))
	var y := nrm(a, 0.8)
	mix_t(y, nrm(b, 0.55), 0.12)
	mix(y, nrm(whoosh(d, [0.0, 600.0, 0.15, 5000.0, d, 1500.0], [0.0, 0.0, 0.13, 0.6, d, 0.0], 3.0), 0.4))
	return reverb(y, 0.25, 0.75, 0.25, 0.9, 0.3)


# =====================================================================
# SFX - Hunter
# =====================================================================
# Longbow release (dry): short dark string thrum damped within ~100 ms (no ringing
# twang), wooden limb/knock transient, then a crisp arrow zip sweeping down.
func bow_release(thrum_f: float, zip_hi: float, zip_lo: float, zip_len: float, weight: float) -> PackedFloat32Array:
	var y := zeros(ns(zip_len + 0.04))
	# string thrum: dark, heavily damped string + pitched body thump + air puff
	var st := pluck(0.16, thrum_f, 0.965, 0.22)
	mulb(st, env_perc(st.size(), 0.0005, 0.028))
	mix(y, nrm(st, 0.75 * weight))
	mix(y, nrm(thump(0.12, thrum_f * 1.45, thrum_f * 0.92, 0.015, 0.03), 0.65 * weight))
	mix(y, nrm(burst(0.08, 550.0, 0.7, LP, 0.0008, 0.018), 0.5 * weight))
	# wooden limb / arrow-knock transient
	var ex := burst(0.06, 2500.0, 0.7, LP, 0.0002, 0.003)
	var wood := svf(ex, rng.randf_range(650.0, 760.0), 9.0, BP)
	mix(wood, svf(ex, rng.randf_range(1500.0, 1750.0), 11.0, BP), 0, 0.6)
	mix(y, nrm(wood, 0.45))
	mix(y, nrm(burst(0.01, 3500.0, 0.7, HP, 0.0001, 0.0015), 0.35))
	# arrow zip: band-passed noise with a slight downward sweep, fast attack, ~exp decay
	var zn := ns(zip_len)
	var ze := env_perc(zn, 0.025, zip_len * 0.28)
	mulb(ze, env_bp(zn, [0.0, 1.0, zip_len * 0.7, 1.0, zip_len, 0.0]))
	var zip := svf_v(noise(zn), freq_bp(zn, [0.0, zip_hi, zip_len, zip_lo]), 2.2, BP)
	mulb(zip, ze)
	var crisp := svf(noise(zn), 5500.0, 0.7, HP)
	mulb(crisp, ze)
	mix_t(y, nrm(zip, 0.55), 0.008)
	mix_t(y, nrm(crisp, 0.15), 0.008)
	return y


func sfx_bow_shoot() -> PackedFloat32Array:
	var y := bow_release(118.0, 3600.0, 1500.0, 0.24, 1.0)
	return reverb(y, 0.1, 0.65, 0.4, 0.8, 0.12)


func sfx_arrow_hit() -> PackedFloat32Array:
	var d := 0.22
	var n := ns(d)
	var y := nrm(thump(d, 320.0, 170.0, 0.015, 0.035), 0.8)
	var ex := burst(d, 1500.0, 0.7, LP, 0.0005, 0.006)
	var wood := svf(ex, 430.0, 8.0, BP)
	mix(wood, svf(ex, 1150.0, 10.0, BP), 0, 0.6)
	mix(y, nrm(wood, 0.7))
	var qv := osc_sine(filled(n, 85.0))
	for i in n:
		qv[i] *= 0.5 + 0.5 * sin(TAU * 35.0 * i / SR)
	mulb(qv, env_perc(n, 0.005, 0.06))
	mix(y, nrm(qv, 0.3))
	mix(y, nrm(burst(0.015, 4000.0, 0.7, HP, 0.0001, 0.002), 0.4))
	return reverb(y, 0.12, 0.65, 0.4, 0.7, 0.2)


func sfx_volley() -> PackedFloat32Array:
	# 5 staggered, detuned longbow releases
	var y := zeros(ns(0.52))
	var ts := [0.0, 0.05, 0.095, 0.16, 0.22]
	var fs := [116.0, 128.0, 110.0, 136.0, 122.0]
	var gs := [1.0, 0.85, 0.9, 0.75, 0.8]
	for j in 5:
		var zl := rng.randf_range(0.22, 0.26)
		var b := bow_release(float(fs[j]), rng.randf_range(3300.0, 3900.0), rng.randf_range(1300.0, 1700.0), zl, 1.0)
		mix_t(y, nrm(b, float(gs[j])), float(ts[j]) + rng.randf() * 0.01)
	return reverb(y, 0.1, 0.65, 0.4, 0.8, 0.14)


func sfx_dash() -> PackedFloat32Array:
	var d := 0.3
	var env := [0.0, 0.0, 0.07, 1.0, d, 0.0]
	var y := nrm(whoosh(d, [0.0, 500.0, 0.1, 1800.0, d, 600.0], env, 1.3), 0.8)
	mix(y, nrm(whoosh(d, [0.0, 150.0, 0.1, 350.0, d, 150.0], env, 0.8), 0.55))
	mix(y, nrm(burst(0.05, 900.0, 1.5, BP, 0.001, 0.012), 0.4))
	mix_t(y, nrm(burst(0.05, 800.0, 1.5, BP, 0.001, 0.012), 0.3), 0.05)
	return reverb(y, 0.12, 0.68, 0.4, 0.8, 0.2)


# =====================================================================
# SFX - Player
# =====================================================================
func sfx_player_hurt() -> PackedFloat32Array:
	var d := 0.3
	var y := creature(d, [0.0, 150.0, 0.05, 168.0, d, 105.0], 0.02, 0.15, 0.22, [0.0, "uh", d, "a"], 1.0, 6.0, [0.0, 0.0, 0.015, 1.0, 0.12, 0.8, d, 0.0], 1.3)
	return reverb(y, 0.12, 0.7, 0.4, 0.8, 0.22)


func sfx_player_death() -> PackedFloat32Array:
	var d := 1.25
	var n := ns(d)
	var f0 := freq_bp(n, [0.0, 170.0, 0.15, 190.0, 0.6, 140.0, d, 80.0])
	for i in n:
		var t := float(i) / SR
		f0[i] *= 1.0 + 0.03 * (t / d) * sin(TAU * 7.0 * t)
	var src := voice_src(f0, 0.03, 0.25, 0.3)
	var v := vocal_tract(src, [0.0, "a", 0.5, "a", 0.9, "o", d, "u"], 1.0, 6.0)
	mulb(v, env_bp(n, [0.0, 0.0, 0.06, 1.0, 0.5, 0.9, 0.9, 0.5, d, 0.0]))
	var br := vocal_tract(noise(n), [0.0, "uh", d, "uh"], 1.0, 4.0)
	mulb(br, env_bp(n, [0.0, 0.0, 0.7, 0.0, 0.95, 1.0, d, 0.0]))
	var y := nrm(v, 0.9)
	mix(y, nrm(br, 0.25))
	sat(y, 1.3)
	return reverb(y, 0.2, 0.78, 0.4, 1.0, 0.45)


func sfx_potion_drink() -> PackedFloat32Array:
	var d := 0.62
	var y := zeros(ns(d))
	var starts := [0.0, 0.17, 0.35]
	for j in 3:
		var t0: float = float(starts[j]) + rng.randf() * 0.02
		var gd := 0.11
		var gn := ns(gd)
		var sweep := freq_bp(gn, [0.0, 170.0 + j * 15.0, 0.08, 430.0 + j * 20.0])
		var tone := osc_sine(sweep)
		mulb(tone, env_bp(gn, [0.0, 0.0, 0.006, 1.0, 0.05, 0.5, gd, 0.0]))
		var res := svf_v(noise(gn), scaled(sweep, 2.0), 8.0, BP)
		mulb(res, env_perc(gn, 0.003, 0.03))
		var glug := nrm(tone, 0.8)
		mix(glug, nrm(res, 0.35))
		mix_t(y, glug, t0, 1.0 - j * 0.1)
		for k in 2:
			var bf := rng.randf_range(600.0, 1100.0)
			mix_t(y, nrm(chirp(0.04, bf, bf * 1.6, 0.002, 0.012), 0.25), t0 + rng.randf_range(0.03, 0.12))
	mix_t(y, nrm(thump(0.1, 120.0, 70.0, 0.02, 0.04), 0.4), 0.52)
	return reverb(y, 0.1, 0.65, 0.4, 0.7, 0.15)


func sfx_coin_pickup() -> PackedFloat32Array:
	var y := zeros(ns(0.32))
	var r := [1.0, 1.51, 2.27, 2.93, 3.71]
	var a := [1.0, 0.6, 0.45, 0.3, 0.2]
	var tt := [0.13, 0.1, 0.07, 0.05, 0.04]
	mix_t(y, nrm(partials(0.3, 1975.0, r, a, tt, 0.0005), 0.7), 0.0)
	mix_t(y, nrm(partials(0.25, 2637.0, r, a, tt, 0.0005), 0.85), 0.07)
	return reverb(y, 0.12, 0.7, 0.3, 0.8, 0.2)


func sfx_item_pickup() -> PackedFloat32Array:
	var d := 0.45
	var y := zeros(ns(d))
	var notes := [659.25, 987.77, 1318.5]
	for j in 3:
		var t0 := j * 0.06
		var nn := ns(d - t0)
		var fr := filled(nn, notes[j])
		var s := osc_sine(fr)
		mix(s, osc_sine(scaled(fr, 2.0)), 0, 0.2)
		mulb(s, env_perc(nn, 0.008, 0.22))
		mix_t(y, nrm(s, 0.6), t0)
	var sh := svf(noise(ns(d)), 7000.0, 2.0, BP)
	mulb(sh, env_bp(sh.size(), [0.0, 0.0, 0.1, 1.0, d, 0.0]))
	mix(y, nrm(sh, 0.08))
	return reverb(y, 0.3, 0.8, 0.2, 1.0, 0.4)


func sfx_footstep() -> PackedFloat32Array:
	var d := 0.12
	var y := nrm(thump(d, 110.0, 60.0, 0.015, 0.03), 0.7)
	mix(y, nrm(burst(d, 700.0, 0.7, LP, 0.002, 0.025), 0.8))
	mix_t(y, nrm(burst(0.06, 2500.0, 1.0, BP, 0.003, 0.012), 0.25), 0.01)
	mix(y, nrm(crackle(0.06, [0.0, 400.0, 0.06, 0.0], 0.1, 0.4, 2000.0), 0.15))
	return reverb(y, 0.08, 0.6, 0.45, 0.7, 0.12)


# =====================================================================
# SFX - Enemies
# =====================================================================
func sfx_ghoul_alert() -> PackedFloat32Array:
	var d := 0.62
	var env := [0.0, 0.0, 0.06, 1.0, 0.4, 0.85, d, 0.0]
	var y := creature(d, [0.0, 120.0, 0.15, 175.0, 0.4, 150.0, d, 105.0], 0.05, 0.6, 0.55, [0.0, "uh", 0.2, "a", d, "o"], 0.9, 4.0, env, 2.0)
	var hs := svf(noise(ns(d)), 2500.0, 0.7, HP)
	mulb(hs, env_bp(hs.size(), env))
	mix(y, nrm(hs, 0.12))
	return reverb(y, 0.15, 0.72, 0.4, 0.9, 0.3)


func sfx_ghoul_attack() -> PackedFloat32Array:
	var d := 0.36
	var y := nrm(whoosh(d, [0.0, 4500.0, 0.1, 3500.0, d, 3000.0], [0.0, 0.0, 0.02, 1.0, 0.1, 0.6, 0.18, 0.0], 1.0), 0.55)
	var sn := creature(0.28, [0.0, 190.0, 0.1, 215.0, 0.28, 140.0], 0.06, 0.7, 0.6, [0.0, "e", 0.28, "a"], 0.95, 4.0, [0.0, 0.0, 0.02, 1.0, 0.18, 0.7, 0.28, 0.0], 2.2)
	mix_t(y, nrm(sn, 0.9), 0.07)
	return reverb(y, 0.12, 0.7, 0.4, 0.8, 0.25)


func sfx_ghoul_death() -> PackedFloat32Array:
	var d := 0.85
	var n := ns(d)
	var v := creature(d, [0.0, 150.0, 0.2, 120.0, 0.6, 70.0, d, 55.0], 0.08, 0.8, 0.4, [0.0, "a", 0.1, "o", 0.18, "u", 0.26, "o", 0.34, "u", 0.42, "o", 0.55, "u", d, "u"], 0.85, 5.0, [0.0, 0.0, 0.04, 1.0, 0.5, 0.7, 0.75, 0.0], 1.8)
	var gm := smooth_noise(n, 28.0)
	for i in n:
		v[i] *= 0.6 + 0.4 * (0.5 + 0.5 * sin(TAU * 13.0 * i / SR + 2.0 * gm[i]))
	var y := nrm(v, 0.85)
	for k in 5:
		var bf := rng.randf_range(300.0, 700.0)
		mix_t(y, nrm(chirp(0.05, bf, bf * 1.5, 0.003, 0.015), 0.2), rng.randf_range(0.1, 0.6))
	mix_t(y, nrm(thump(0.25, 120.0, 50.0, 0.03, 0.07), 0.8), 0.58)
	mix_t(y, nrm(burst(0.2, 400.0, 0.7, LP, 0.002, 0.04), 0.5), 0.58)
	return reverb(y, 0.18, 0.75, 0.4, 0.9, 0.35)


func sfx_skeleton_alert() -> PackedFloat32Array:
	var d := 0.62
	var n := ns(d)
	var y := zeros(n)
	var t := 0.0
	while t < 0.4:
		mix_t(y, nrm(bone_tick(), rng.randf_range(0.35, 0.7) * (1.0 - t)), t)
		t += rng.randf_range(0.022, 0.036)
	var f0 := freq_bp(n, [0.0, 150.0, 0.2, 175.0, d, 140.0])
	vibrato(f0, 5.5, 0.02)
	var src := osc_tri(f0, 0.0)
	mix(src, noise(n), 0, 0.25)
	var mo := vocal_tract(src, [0.0, "u", d, "o"], 1.0, 7.0)
	mo = comb_fb(mo, 0.0037, 0.55)
	mulb(mo, env_bp(n, [0.0, 0.0, 0.15, 1.0, 0.45, 0.8, d, 0.0]))
	mix(y, nrm(mo, 0.8))
	return reverb(y, 0.25, 0.8, 0.35, 1.0, 0.4)


func sfx_skeleton_death() -> PackedFloat32Array:
	var d := 0.85
	var y := zeros(ns(d))
	for j in 12:
		mix_t(y, nrm(bone_tick(), rng.randf_range(0.4, 0.9)), rng.randf_range(0.0, 0.18))
	var sk := ping(0.12, 520.0, 0.03)
	mix(sk, ping(0.12, 1250.0, 0.02), 0, 0.6)
	mix(sk, thump(0.12, 300.0, 180.0, 0.01, 0.02), 0, 0.8)
	mix_t(y, nrm(sk, 0.9), 0.22)
	var t2 := 0.27
	for j in 9:
		mix_t(y, nrm(bone_tick(), 0.6 * pow(0.82, j)), t2)
		t2 += rng.randf_range(0.03, 0.07) * (1.0 + j * 0.08)
	return reverb(y, 0.2, 0.75, 0.35, 0.9, 0.35)


func sfx_cultist_cast() -> PackedFloat32Array:
	var d := 0.62
	var n := ns(d)
	var wh := vocal_tract(noise(n), [0.0, "o", 0.15, "a", 0.3, "e", 0.45, "u", d, "o"], 1.05, 8.0)
	mulb(wh, env_bp(n, [0.0, 0.0, 0.45, 1.0, 0.55, 0.8, d, 0.0]))
	var y := nrm(wh, 0.8)
	var ss := svf(noise(n), 4500.0, 0.7, HP)
	mulb(ss, env_bp(n, [0.0, 0.0, 0.3, 0.0, 0.38, 1.0, 0.45, 0.0]))
	mix(y, nrm(ss, 0.25))
	var ch := zeros(n)
	for fv in [98.0, 98.6, 146.8]:
		var fr := filled(n, fv)
		vibrato(fr, 4.8, 0.006, 0.0, 0.0, rng.randf() * TAU)
		mix(ch, osc_saw(fr, rng.randf()), 0, 0.33)
	var chf := formant_static(ch, "o", 1.0, 6.0)
	var swl := env_bp(n, [0.0, 0.0, 0.5, 1.0, d, 0.0])
	mulb(chf, swl)
	mix(y, nrm(chf, 0.45))
	var sub := osc_sine(filled(n, 49.0))
	mulb(sub, swl)
	mix(y, nrm(sub, 0.3))
	return reverb(y, 0.3, 0.82, 0.35, 1.1, 0.45)


func sfx_cultist_death() -> PackedFloat32Array:
	var d := 0.85
	var n := ns(d)
	var f0 := freq_bp(n, [0.0, 360.0, 0.1, 420.0, 0.35, 300.0, d, 170.0])
	vibrato(f0, 6.0, 0.03)
	var src := voice_src(f0, 0.04, 0.3, 0.35)
	var v := vocal_tract(src, [0.0, "a", 0.3, "a", 0.6, "o", d, "u"], 1.05, 6.0)
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		var choke := clampf((t - 0.25) / 0.4, 0.0, 0.8)
		ph += TAU * (12.0 + 10.0 * t) / SR
		v[i] *= 1.0 - choke * (0.5 + 0.5 * sin(ph))
	mulb(v, env_bp(n, [0.0, 0.0, 0.03, 1.0, 0.3, 0.8, d, 0.0]))
	sat(v, 1.5)
	return reverb(v, 0.25, 0.8, 0.35, 1.0, 0.45)


func sfx_brute_roar() -> PackedFloat32Array:
	var d := 1.25
	var n := ns(d)
	var f0 := freq_bp(n, [0.0, 62.0, 0.25, 78.0, 0.8, 72.0, d, 55.0])
	var seq := [0.0, "o", 0.3, "a", 1.0, "a", d, "o"]
	var y := nrm(vocal_tract(voice_src(f0, 0.03, 0.7, 0.5), seq, 0.7, 4.0), 1.0)
	mix(y, nrm(vocal_tract(voice_src(scaled(f0, 2.01), 0.04, 0.5, 0.5), seq, 0.75, 4.0), 0.5))
	var env := env_bp(n, [0.0, 0.0, 0.15, 1.0, 0.85, 0.85, d, 0.0])
	mulb(y, env)
	sat(y, 2.5)
	var sub := osc_sine(scaled(f0, 0.5))
	mulb(sub, env)
	mix(y, nrm(sub, 0.35))
	return reverb(y, 0.25, 0.82, 0.4, 1.2, 0.5)


func sfx_brute_smash() -> PackedFloat32Array:
	var d := 0.65
	var n := ns(d)
	var y := nrm(thump(d, 95.0, 30.0, 0.05, 0.18), 1.0)
	var body := svf_v(noise(n), freq_bp(n, [0.0, 2500.0, 0.06, 600.0, d, 120.0]), 0.7, LP)
	mulb(body, env_perc(n, 0.002, 0.12))
	mix(y, nrm(body, 0.9))
	sat(y, 2.2)
	var deb := svf(crackle(d, [0.0, 0.0, 0.03, 200.0, 0.25, 90.0, d, 0.0], 0.5, 4.0, 500.0), 3000.0, 0.7, LP)
	mix(y, nrm(deb, 0.35))
	for j in 6:
		var f := rng.randf_range(300.0, 900.0)
		mix_t(y, nrm(ping(0.08, f, 0.015), rng.randf_range(0.1, 0.25)), rng.randf_range(0.05, 0.45))
	return reverb(y, 0.22, 0.8, 0.4, 1.2, 0.5)


func sfx_brute_death() -> PackedFloat32Array:
	var d := 1.45
	var n := ns(d)
	var g := creature(1.15, [0.0, 85.0, 0.3, 90.0, 1.0, 50.0, 1.15, 45.0], 0.04, 0.6, 0.35, [0.0, "a", 0.5, "o", 1.15, "u"], 0.7, 4.5, [0.0, 0.0, 0.1, 1.0, 0.6, 0.8, 1.05, 0.3, 1.15, 0.0], 2.0)
	var y := zeros(n)
	mix(y, nrm(g, 0.9))
	var td := 1.0
	mix_t(y, nrm(thump(0.45, 90.0, 32.0, 0.05, 0.14), 1.0), td)
	var bn := ns(0.4)
	var body := svf_v(noise(bn), freq_bp(bn, [0.0, 1500.0, 0.05, 400.0, 0.4, 100.0]), 0.7, LP)
	mulb(body, env_perc(bn, 0.002, 0.08))
	mix_t(y, nrm(body, 0.7), td)
	mix_t(y, nrm(crackle(0.35, [0.0, 150.0, 0.35, 0.0], 0.5, 3.0, 400.0), 0.25), td + 0.02)
	return reverb(y, 0.25, 0.82, 0.4, 1.2, 0.5)


func sfx_boss_roar() -> PackedFloat32Array:
	var d := 2.0
	var n := ns(d)
	var f0 := freq_bp(n, [0.0, 48.0, 0.3, 62.0, 1.3, 58.0, d, 40.0])
	var seq := [0.0, "o", 0.4, "a", 1.5, "a", d, "o"]
	var y := nrm(vocal_tract(voice_src(f0, 0.03, 0.85, 0.5), seq, 0.62, 3.5), 1.0)
	mix(y, nrm(vocal_tract(voice_src(scaled(f0, 1.498), 0.03, 0.7, 0.5), seq, 0.7, 4.0), 0.6))
	mix(y, nrm(vocal_tract(voice_src(scaled(f0, 2.02), 0.04, 0.5, 0.6), seq, 0.8, 4.0), 0.45))
	var scr := vocal_tract(voice_src(scaled(f0, 7.3), 0.06, 0.4, 0.6), [0.0, "e", 1.0, "a", d, "a"], 1.1, 5.0)
	mulb(scr, env_bp(n, [0.0, 0.0, 0.2, 0.0, 0.5, 1.0, 1.4, 0.7, d, 0.0]))
	mix(y, nrm(scr, 0.22))
	var env := env_bp(n, [0.0, 0.0, 0.25, 1.0, 1.5, 0.85, d, 0.0])
	mulb(y, env)
	sat(y, 3.0)
	var sub := osc_sine(freq_bp(n, [0.0, 30.0, 0.5, 42.0, d, 28.0]))
	mulb(sub, env)
	mix(y, nrm(sub, 0.5))
	return reverb(y, 0.3, 0.85, 0.4, 1.4, 0.65)


func sfx_boss_cast() -> PackedFloat32Array:
	var d := 1.05
	var n := ns(d)
	var dr := zeros(n)
	var bend := freq_bp(n, [0.0, 1.0, d, 1.06])
	for fv in [55.0, 82.4, 110.3]:
		mix(dr, osc_saw(scaled(bend, fv), rng.randf()), 0, 0.33)
	var drf := svf_v(dr, freq_bp(n, [0.0, 150.0, 0.9, 2200.0, d, 600.0]), 2.5, LP)
	mulb(drf, env_bp(n, [0.0, 0.0, 0.7, 1.0, 0.92, 1.0, d, 0.0]))
	var y := nrm(drf, 0.8)
	var fc := zeros(n)
	var rc_env := zeros(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		ph += TAU * (4.0 + 10.0 * t / d) / SR
		fc[i] = 700.0 * pow(2.0, t / d) * pow(2.0, 0.8 * sin(ph))
		var u := clampf(t / 0.95, 0.0, 1.0)
		rc_env[i] = u * u * u
	var sw := svf_v(noise(n), fc, 4.0, BP)
	mulb(sw, env_bp(n, [0.0, 0.0, 0.8, 1.0, 0.95, 0.6, d, 0.0]))
	mix(y, nrm(sw, 0.5))
	var rc := svf(noise(n), 3000.0, 0.7, HP)
	mulb(rc, rc_env)
	mulb(rc, env_bp(n, [0.0, 1.0, 0.95, 1.0, d, 0.0]))
	mix(y, nrm(rc, 0.25))
	mix_t(y, nrm(thump(0.15, 120.0, 60.0, 0.02, 0.04), 0.6), 0.88)
	sat(y, 1.5)
	return reverb(y, 0.3, 0.82, 0.35, 1.2, 0.45)


func sfx_boss_death() -> PackedFloat32Array:
	var d := 2.7
	var n := ns(d)
	var rn := ns(1.6)
	var f0 := freq_bp(rn, [0.0, 62.0, 0.4, 55.0, 1.6, 30.0])
	var seq := [0.0, "a", 0.8, "o", 1.6, "u"]
	var roar := nrm(vocal_tract(voice_src(f0, 0.03, 0.85, 0.5), seq, 0.62, 3.5), 1.0)
	mix(roar, nrm(vocal_tract(voice_src(scaled(f0, 1.5), 0.03, 0.7, 0.5), seq, 0.7, 4.0), 0.55))
	mix(roar, nrm(vocal_tract(voice_src(scaled(f0, 6.8), 0.06, 0.4, 0.6), [0.0, "a", 1.6, "u"], 1.1, 5.0), 0.15))
	mulb(roar, env_bp(rn, [0.0, 0.0, 0.12, 1.0, 0.8, 0.8, 1.6, 0.0]))
	sat(roar, 2.6)
	var y := zeros(n)
	mix(y, nrm(roar, 0.85))
	var rum := svf(noise(n), 110.0, 0.7, LP)
	mulb(rum, env_bp(n, [0.0, 0.0, 0.3, 0.6, 1.2, 1.0, d, 0.0]))
	mix(y, nrm(rum, 0.5))
	var crum := svf(crackle(d, [0.0, 0.0, 1.1, 60.0, 1.3, 150.0, d, 0.0], 1.0, 5.0, 200.0), 900.0, 0.7, LP)
	mix(y, nrm(crum, 0.3))
	var ti := 1.2
	mix_t(y, nrm(thump(1.3, 80.0, 28.0, 0.08, 0.35), 1.0), ti)
	var bn := ns(0.6)
	var body := svf_v(noise(bn), freq_bp(bn, [0.0, 2000.0, 0.08, 400.0, 0.6, 90.0]), 0.7, LP)
	mulb(body, env_perc(bn, 0.002, 0.15))
	mix_t(y, nrm(body, 0.7), ti)
	mix_t(y, nrm(bell(d - 1.25, 110.0, 0.9, 0.8), 0.45), 1.25)
	return reverb(y, 0.3, 0.86, 0.4, 1.5, 0.7)


func sfx_enemy_spawn() -> PackedFloat32Array:
	var d := 0.82
	var n := ns(d)
	var y := zeros(n)
	var paths := [[420.0, 640.0], [600.0, 470.0], [890.0, 1010.0]]
	for p in paths:
		var fr := freq_bp(n, [0.0, p[0], d, p[1]])
		vibrato(fr, rng.randf_range(5.5, 7.0), 0.015, 0.0, 0.0, rng.randf() * TAU)
		mix(y, osc_tri(fr, rng.randf()), 0, 0.33)
	mulb(y, env_bp(n, [0.0, 0.0, 0.3, 1.0, 0.6, 0.7, d, 0.0]))
	nrm(y, 0.5)
	var fc := zeros(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		ph += TAU * (3.0 + 6.0 * t / d) / SR
		fc[i] = 900.0 * pow(2.0, 0.8 * sin(ph))
	var sw := svf_v(noise(n), fc, 5.0, BP)
	mulb(sw, env_bp(n, [0.0, 0.0, 0.25, 1.0, d, 0.0]))
	mix(y, nrm(sw, 0.5))
	mix(y, nrm(whoosh(d, [0.0, 100.0, 0.4, 260.0, d, 90.0], [0.0, 0.0, 0.35, 1.0, d, 0.0], 0.8), 0.45))
	return reverb(y, 0.35, 0.85, 0.25, 1.2, 0.55)


func sfx_shadow_bolt() -> PackedFloat32Array:
	var d := 0.42
	var n := ns(d)
	var fr := freq_bp(n, [0.0, 260.0, d, 85.0])
	var bz := osc_saw(fr, 0.0)
	mix(bz, osc_saw(scaled(fr, 1.012), 0.3), 0, 0.8)
	bz = svf_v(bz, freq_bp(n, [0.0, 3000.0, d, 400.0]), 3.0, LP)
	mulb(bz, env_bp(n, [0.0, 0.0, 0.01, 1.0, 0.15, 0.6, d, 0.0]))
	var y := nrm(bz, 0.6)
	mix(y, nrm(whoosh(d, [0.0, 1500.0, 0.12, 700.0, d, 300.0], [0.0, 0.0, 0.03, 1.0, d, 0.0], 1.2), 0.6))
	mix(y, nrm(thump(0.15, 180.0, 70.0, 0.02, 0.05), 0.55))
	sat(y, 1.6)
	return reverb(y, 0.2, 0.78, 0.35, 1.0, 0.3)


func sfx_bolt_impact() -> PackedFloat32Array:
	var d := 0.36
	var n := ns(d)
	var y := nrm(thump(0.2, 260.0, 60.0, 0.012, 0.035), 0.9)
	mix(y, nrm(burst(0.05, 1500.0, 0.7, LP, 0.0003, 0.008), 0.6))
	var fz := svf(noise(n), 3000.0, 0.7, HP)
	var sm := smooth_noise(n, 60.0)
	for i in n:
		fz[i] *= 0.5 + 0.5 * sm[i]
	mulb(fz, env_perc(n, 0.005, 0.1))
	mix(y, nrm(fz, 0.45))
	mix(y, nrm(crackle(d, [0.0, 500.0, d, 0.0], 0.1, 0.6, 2500.0), 0.35))
	var rg := svf(osc_saw(filled(n, 110.0), 0.0), 600.0, 0.8, LP)
	mulb(rg, env_perc(n, 0.002, 0.08))
	mix(y, nrm(rg, 0.3))
	sat(y, 1.5)
	return reverb(y, 0.18, 0.75, 0.35, 0.9, 0.25)


func sfx_enemy_arrow() -> PackedFloat32Array:
	# lighter, shorter variant of the longbow release (smaller enemy bow)
	var y := bow_release(172.0, 4200.0, 1900.0, 0.2, 0.7)
	return reverb(y, 0.1, 0.65, 0.4, 0.8, 0.12)


# =====================================================================
# SFX - Game flow
# =====================================================================
func sfx_wave_start() -> PackedFloat32Array:
	var y := zeros(ns(2.0))
	mix_t(y, horn(0.78, 110.0), 0.0)
	mix_t(y, horn(1.3, 146.83), 0.7)
	sat(y, 1.4)
	return reverb(y, 0.35, 0.86, 0.4, 1.5, 0.75)


func sfx_wave_clear() -> PackedFloat32Array:
	var d := 1.65
	var n := ns(d)
	var ch := zeros(n)
	var n1 := ns(0.38)
	var e1 := env_bp(n1, [0.0, 0.0, 0.04, 1.0, 0.25, 0.8, 0.38, 0.0])
	for m in [57, 61, 64]:
		var v := choir_voice(n1, midi(float(m)), 3, 8.0)
		mulb(v, e1)
		mix(ch, v)
	var t2 := 0.28
	var n2 := ns(d - t2)
	var e2 := env_bp(n2, [0.0, 0.0, 0.08, 1.0, 0.6, 0.85, d - t2, 0.0])
	for m in [62, 66, 69, 74]:
		var v := choir_voice(n2, midi(float(m)), 3, 8.0)
		mulb(v, e2)
		mix_t(ch, v, t2)
	var chf := formant_static(ch, "a", 1.15, 5.0)
	mix(chf, svf(ch, 900.0, 0.7, LP), 0, 0.4)
	chf = svf(chf, 3500.0, 0.7, LP)
	var y := nrm(chf, 0.8)
	mix_t(y, nrm(bell(d - t2, 587.33, 0.5, 0.7), 0.3), t2)
	mix_t(y, nrm(bell(d - t2, 880.0, 0.4, 0.6), 0.2), t2 + 0.01)
	return reverb(y, 0.35, 0.85, 0.3, 1.3, 0.6)


func sfx_boon_select() -> PackedFloat32Array:
	var d := 1.05
	var n := ns(d)
	var y := zeros(n)
	var tw := [1174.66, 1479.98, 1760.0, 2349.32, 2959.96, 3520.0, 4698.64]
	for j in tw.size():
		var t0 := j * 0.055 + rng.randf() * 0.01
		var nn := ns(d - t0)
		var fr := filled(nn, tw[j])
		var s := osc_sine(fr)
		mix(s, osc_sine(scaled(fr, 2.0)), 0, 0.15)
		mulb(s, env_perc(nn, 0.004, 0.2))
		mix_t(y, nrm(s, 0.3), t0)
	var sh := svf(noise(n), 7000.0, 2.0, BP)
	var sm := smooth_noise(n, 20.0)
	for i in n:
		sh[i] *= 0.6 + 0.4 * sm[i]
	mulb(sh, env_bp(n, [0.0, 0.0, 0.25, 1.0, d, 0.0]))
	mix(y, nrm(sh, 0.12))
	var gong := partials(d, 98.0, [1.0, 1.52, 2.0, 2.4, 2.98, 3.6, 4.3], [1.0, 0.6, 0.5, 0.4, 0.3, 0.2, 0.12], [0.9, 0.7, 0.6, 0.5, 0.4, 0.3, 0.25], 0.02)
	mix(y, nrm(gong, 0.55))
	return reverb(y, 0.3, 0.82, 0.25, 1.2, 0.5)


func sfx_game_over() -> PackedFloat32Array:
	var d := 3.0
	var n := ns(d)
	var y := zeros(n)
	mix(y, nrm(bell(d, 146.83, 1.2, 0.8), 0.8))
	mix_t(y, nrm(bell(d - 1.45, 146.83, 1.0, 0.7), 0.5), 1.45)
	var dr := zeros(n)
	for fv in [36.71, 55.0, 73.42]:
		mix(dr, osc_saw(filled(n, fv), rng.randf()), 0, 0.33)
	dr = svf(dr, 280.0, 0.9, LP)
	for i in n:
		dr[i] *= 0.85 + 0.15 * sin(TAU * 0.7 * i / SR)
	mulb(dr, env_bp(n, [0.0, 0.0, 0.8, 1.0, 2.3, 0.9, d, 0.0]))
	mix(y, nrm(dr, 0.5))
	return reverb(y, 0.3, 0.86, 0.4, 1.5, 0.8)


func sfx_boss_warning() -> PackedFloat32Array:
	var d := 2.5
	var n := ns(d)
	var y := zeros(n)
	mix(y, nrm(bell(d, 98.0, 0.9, 0.9), 0.85))
	mix_t(y, nrm(bell(d - 1.1, 98.0, 0.9, 0.9), 0.85), 1.1)
	mix(y, nrm(ping(d, 277.18, 0.8), 0.12))
	mix_t(y, nrm(ping(d - 1.1, 277.18, 0.8), 0.12), 1.1)
	var rum := svf(noise(n), 90.0, 0.7, LP)
	mulb(rum, env_bp(n, [0.0, 0.0, 1.0, 1.0, d, 0.0]))
	mix(y, nrm(rum, 0.35))
	return reverb(y, 0.3, 0.85, 0.4, 1.4, 0.6)


# =====================================================================
# Music instruments
# =====================================================================
func drum_taiko(v: int) -> PackedFloat32Array:
	var n := ns(1.0)
	var body := mulb(osc_sine(fdrop(n, 150.0 + v * 6.0, 56.0 - v * 1.5, 0.035)), env_perc(n, 0.001, 0.30))
	var ov := mulb(osc_sine(fdrop(n, 240.0, 92.0, 0.03)), env_perc(n, 0.001, 0.07))
	var skin := mulb(svf(noise(n), 900.0, 0.7, LP), env_perc(n, 0.0005, 0.03))
	var slap := mulb(svf(noise(n), 2200.0, 0.7, HP), env_perc(n, 0.0003, 0.005))
	var y := nrm(body, 1.0)
	mix(y, nrm(ov, 0.35))
	mix(y, nrm(skin, 0.5))
	mix(y, nrm(slap, 0.25))
	return sat(y, 1.4)


func drum_tom(f_hi: float, f_lo: float) -> PackedFloat32Array:
	var n := ns(0.6)
	var y := nrm(mulb(osc_sine(fdrop(n, f_hi, f_lo, 0.03)), env_perc(n, 0.001, 0.17)), 1.0)
	mix(y, nrm(mulb(osc_sine(fdrop(n, f_hi * 1.6, f_lo * 1.55, 0.02)), env_perc(n, 0.001, 0.05)), 0.3))
	mix(y, nrm(mulb(svf(noise(n), 1800.0, 0.7, LP), env_perc(n, 0.0005, 0.018)), 0.5))
	return sat(y, 1.3)


func drum_frame() -> PackedFloat32Array:
	var n := ns(0.3)
	var y := nrm(mulb(osc_sine(fdrop(n, 380.0, 290.0, 0.02)), env_perc(n, 0.001, 0.07)), 0.6)
	mix(y, nrm(mulb(svf(noise(n), 1400.0, 1.0, BP), env_perc(n, 0.0005, 0.035)), 1.0))
	mix(y, nrm(mulb(svf(noise(n), 5000.0, 0.7, HP), env_perc(n, 0.0002, 0.003)), 0.3))
	return y


func drum_tabor() -> PackedFloat32Array:
	var n := ns(0.4)
	var y := nrm(mulb(osc_sine(fdrop(n, 240.0, 190.0, 0.02)), env_perc(n, 0.001, 0.06)), 0.6)
	mix(y, nrm(mulb(svf(noise(n), 2500.0, 0.6, BP), env_perc(n, 0.001, 0.11)), 1.0))
	mix(y, nrm(mulb(svf(noise(n), 5000.0, 0.7, HP), env_perc(n, 0.002, 0.14)), 0.5))
	return y


func cymbal(dur: float) -> PackedFloat32Array:
	var n := ns(dur)
	var nz := noise(n)
	var y := nrm(svf(nz, 5000.0, 0.6, HP), 0.8)
	mix(y, nrm(svf(nz, 8000.0, 1.5, BP), 0.4))
	mix(y, nrm(partials(dur, 420.0, [3.11, 4.72, 6.23, 8.31, 11.47, 13.9, 17.3], [0.3, 0.3, 0.25, 0.25, 0.2, 0.15, 0.1], [0.6, 0.55, 0.5, 0.45, 0.4, 0.35, 0.3]), 0.25))
	mulb(y, env_perc(n, 0.002, dur * 0.3))
	return y


# reverse-cymbal style swell that peaks exactly at its end
func swell(dur: float) -> PackedFloat32Array:
	var n := ns(dur)
	var y := nrm(svf(noise(n), 3500.0, 0.7, HP), 0.8)
	mix(y, nrm(svf(noise(n), 7000.0, 1.2, BP), 0.4))
	var e := zeros(n)
	var nf := ns(0.015)
	for i in n:
		var u := float(i) / n
		var v := u * u * u
		if i > n - nf:
			v *= float(n - i) / nf
		e[i] = v
	return mulb(y, e)


func bass_note(nl: float, f: float) -> PackedFloat32Array:
	var dur := nl + 0.08
	var n := ns(dur)
	var fr := filled(n, f)
	var a := osc_saw(fr, 0.0)
	var b := osc_saw(scaled(fr, 1.004), 0.5)
	var x := zeros(n)
	for i in n:
		x[i] = 0.5 * a[i] + 0.5 * b[i]
	var y := svf_v(x, fdrop(n, 1900.0, 260.0, 0.06), 1.1, LP)
	mix(y, svf(y, 500.0, 2.0, BP), 0, 0.4)
	mix(y, osc_sine(fr), 0, 0.5)
	return mulb(y, env_bp(n, [0.0, 0.0, 0.004, 1.0, nl * 0.5, 0.75, nl, 0.6, dur, 0.0]))


func hit(dst: PackedFloat32Array, src: PackedFloat32Array, t: float, g: float) -> void:
	mix_t(dst, src, maxf(0.0, t + rng.randf_range(0.0, 0.006)), g)


# =====================================================================
# Music helpers.
# Smooth layers (pads, drones, bass, reverb) are rendered at a reduced rate
# SR/k (all frequencies and times scaled by k) and linearly upsampled: several
# times faster in GDScript and inaudible since those layers are low-passed anyway.
# Every track is rendered onto [0, L + tail]; continuous layers are exactly
# periodic over L, and everything past L (releases, reverb) is wrapped back onto
# the start, so the loop is seamless.
# =====================================================================
func pts_div(pts: Array, k: float) -> Array:
	var p := pts.duplicate()
	for j in range(0, p.size(), 2):
		p[j] = float(p[j]) / k
	return p


# sample index of time t in a SR/k buffer
func at(t: float, k: int) -> int:
	return int(round(t * SR / k))


# linear-interpolation upsample of a SR/k buffer, added into dst (k times the rate)
func up_mix(dst: PackedFloat32Array, src: PackedFloat32Array, k: int, g: float, periodic: bool = false) -> void:
	var n := src.size()
	var inv := 1.0 / k
	var o := 0
	var dn := dst.size()
	for j in n:
		if o + k > dn:
			break
		var a: float = src[j] * g
		var b := 0.0
		if j + 1 < n:
			b = src[j + 1] * g
		elif periodic:
			b = src[0] * g
		var d := (b - a) * inv
		for r in k:
			dst[o] += a
			a += d
			o += 1


# decimate a full-rate buffer by 2 (pair average) and add into a SR/2 buffer
func down_mix(dst: PackedFloat32Array, src: PackedFloat32Array, g: float) -> void:
	var n := mini(src.size() >> 1, dst.size())
	var h := 0.5 * g
	for j in n:
		dst[j] += (src[2 * j] + src[2 * j + 1]) * h


# choir chord bus at SR/k; events = [[t, [midi, ...], gain], ...]. Notes share one
# envelope shape, so each pitch is rendered once and reused.
func choir_bus(n_bus: int, events: Array, dur: float, env_pts: Array, voices: int, detune: float, vib: float, k: int) -> PackedFloat32Array:
	var bus := zeros(n_bus)
	var cache := {}
	var n := ns(dur / k)
	var env := env_bp(n, pts_div(env_pts, k))
	for ev in events:
		var t: float = ev[0]
		var g: float = ev[2]
		for m in ev[1]:
			var key := int(m)
			if not cache.has(key):
				var v := choir_voice(n, midi(float(m)), voices, detune, vib, float(k))
				mulb(v, env)
				cache[key] = v
			mix(bus, cache[key], at(t, k), g)
	return bus


# choir colour: vowel formants + some darker body + gentle top roll-off (all at SR/k)
func choir_colour(bus: PackedFloat32Array, vowel: String, shift: float, body_fc: float, body_g: float, top_fc: float, k: float) -> PackedFloat32Array:
	var y := formant_static(bus, vowel, shift * k, 4.0)
	mix(y, svf(bus, body_fc * k, 0.7, LP), 0, body_g)
	return svf(y, top_fc * k, 0.7, LP)


# =====================================================================
# Menu: 48 BPM, 8 bars of 4/4 = 40.0 s. D minor: Dm Bb Gm A | Dm Bb Gm A
# =====================================================================
func music_menu() -> PackedFloat32Array:
	rng.seed = 7001
	var ls := 40.0
	var L := ns(ls)
	var N := L + ns(10.0)
	var H := N >> 1
	var bar := 5.0
	var chords := [[50, 53, 57], [50, 53, 58], [50, 55, 58], [49, 52, 57],
		[53, 57, 62], [53, 58, 62], [55, 58, 62], [52, 57, 61]]
	var roots := [38, 34, 31, 33, 38, 34, 31, 33]

	# choir pad with slow swells and overlapping releases (SR/2)
	var ev := []
	for c in 8:
		ev.append([c * bar, chords[c], 1.0])
	var pdur := bar + 2.8
	var pad := choir_bus(H, ev, pdur, [0.0, 0.0, 1.8, 1.0, 3.2, 0.82, bar, 0.9, pdur, 0.0], 3, 9.0, 0.004, 2)
	var padf := choir_colour(pad, "o", 1.0, 700.0, 0.6, 2600.0, 2.0)

	# soprano line in the second half (SR/2, processed from 19 s on only)
	var s0 := at(19.0, 2)
	var sop := zeros(H - s0)
	var sop_notes := [[20.0, 5.0, 69], [25.0, 2.5, 70], [27.5, 2.5, 69], [30.0, 2.5, 67], [32.5, 2.5, 65], [35.0, 5.0, 64]]
	for sn in sop_notes:
		var dl: float = sn[1]
		var dur := dl + 1.6
		var n := ns(dur / 2.0)
		var v := choir_voice(n, midi(float(sn[2])), 2, 5.0, 0.007, 2.0)
		mulb(v, env_bp(n, pts_div([0.0, 0.0, 0.9, 1.0, dl, 0.85, dur, 0.0], 2.0)))
		mix(sop, v, at(float(sn[0]), 2) - s0)
	var sopf := choir_colour(sop, "a", 1.18, 1200.0, 0.3, 3200.0, 2.0)

	# soft bass on chord roots (SR/4)
	var Q := N >> 2
	var bass := zeros(Q)
	for c in 8:
		var dur := bar + 2.0
		var n := ns(dur / 4.0)
		var fr := filled(n, midi(float(roots[c])) * 4.0)
		var v := osc_sine(fr)
		mix(v, osc_tri(fr, 0.25), 0, 0.35)
		mulb(v, env_bp(n, pts_div([0.0, 0.0, 1.2, 1.0, bar, 0.8, dur, 0.0], 4.0)))
		mix(bass, v, at(c * bar, 4))
	bass = svf(bass, 1200.0, 0.7, LP)

	# low drone in fifths, exactly periodic over the loop (SR/4)
	var L4 := L >> 2
	var drone := zeros(L4)
	var dfreqs := [[36.71, 0.5, 0], [73.42, 0.7, 1], [110.0, 0.45, 1], [146.83, 0.15, 1]]
	for dd in dfreqs:
		var fq: float = round(float(dd[0]) * ls) / ls
		var fr := filled(L4, fq * 4.0)
		var s := osc_saw(fr, rng.randf()) if int(dd[2]) == 1 else osc_sine(fr, 0.0)
		mix(drone, s, 0, float(dd[1]))
	var two := drone.duplicate()
	two.append_array(drone)
	two = svf(two, 1040.0, 0.8, LP)
	drone = two.slice(L4)
	for i in L4:
		drone[i] *= 0.72 + 0.28 * sin(TAU * 2.0 * float(i) / L4)

	# airy wind (SR/2), crossfaded across the loop point
	var L2 := L >> 1
	var xf := ns(3.0) >> 1
	var wind := zeros(L2 + xf)
	var ca := 1.0 - exp(-TAU * 700.0 * 2.0 / SR)
	var cb := 1.0 - exp(-TAU * 220.0 * 2.0 / SR)
	var la := 0.0
	var lb := 0.0
	for i in L2 + xf:
		var r := rng.randf() * 2.0 - 1.0
		la += ca * (r - la)
		lb += cb * (r - lb)
		var t := float(i) / L2
		var g := 0.65 + 0.2 * sin(TAU * 3.0 * t + 1.0) + 0.15 * sin(TAU * 7.0 * t)
		if i < xf:
			g *= sin(0.5 * PI * float(i) / xf)
		elif i >= L2:
			g *= cos(0.5 * PI * float(i - L2) / xf)
		wind[i] = (la - lb) * g

	# sparse deep bells (full rate, cached per pitch)
	var bells := zeros(N)
	var bcache := {}
	var bell_ev := [[0.0, 146.83, 1.0, 1.0], [10.0, 98.0, 0.8, 1.0], [20.0, 146.83, 1.0, 1.0],
		[22.5, 440.0, 0.22, 0.5], [30.0, 98.0, 0.8, 1.0], [35.0, 110.0, 0.6, 1.0], [37.5, 659.25, 0.15, 0.5]]
	for be in bell_ev:
		var key := "%.2f" % float(be[1])
		if not bcache.has(key):
			bcache[key] = nrm(bell(8.0, float(be[1]), 1.1, float(be[3])), 1.0)
		mix_t(bells, bcache[key], float(be[0]), float(be[2]))

	norm_rms(padf, 0.10)
	norm_rms(sopf, 0.064)
	norm_rms(bass, 0.05)
	norm_rms(drone, 0.06)
	norm_rms(wind, 0.018)
	norm_rms(bells, 0.045)

	var half := zeros(H)
	var send := zeros(H)
	mix(half, padf)
	mix(send, padf, 0, 0.8)
	mix(half, sopf, s0)
	mix(send, sopf, s0, 1.0)
	up_mix(half, bass, 2, 1.0)
	up_mix(send, bass, 2, 0.2)
	up_mix(half, drone, 2, 1.0, true)
	up_mix(send, drone, 2, 0.3, true)
	mix(half, wind)
	mix(send, wind, 0, 0.5)
	down_mix(send, bells, 0.7)
	var rv := reverb(send, 1.0, 0.88, 0.45, 0.85, 0.0, 0.0)
	mix(half, rv, 0, 0.7)
	var mixb := bells
	up_mix(mixb, half, 2, 1.0)
	return finish_music(mixb, L)


# =====================================================================
# Battle: 120 BPM, 16 bars = 32.0 s. Drums + galloping ostinato + choir;
# brass melody in bars 9-16; cymbal swells/crashes at phrase ends.
# =====================================================================
func music_battle() -> PackedFloat32Array:
	rng.seed = 7002
	var L := ns(32.0)
	var N := L + ns(5.0)
	var H := N >> 1
	var beat := 0.5
	var stp := 0.125
	var bar := 2.0
	var harm := ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Bb", "A", "Dm", "Bb", "Gm", "A", "Dm", "Bb", "C", "A"]
	var root := {"Dm": 38, "Bb": 34, "C": 36, "A": 33, "Gm": 31}
	var walk := {"Dm": [50, 48, 45], "Bb": [46, 45, 41], "C": [48, 46, 43], "A": [45, 43, 40], "Gm": [43, 41, 38]}
	var pads := {"Dm": [50, 53, 57], "Bb": [50, 53, 58], "C": [52, 55, 60], "A": [49, 52, 57], "Gm": [50, 55, 58]}

	var taikos := [drum_taiko(0), drum_taiko(1), drum_taiko(2)]
	var tom_hi := drum_tom(260.0, 150.0)
	var tom_mid := drum_tom(200.0, 115.0)
	var tom_lo := drum_tom(150.0, 85.0)
	var frame := drum_frame()
	var tabor := drum_tabor()
	var crash := cymbal(2.5)
	var sw := swell(1.0)

	var drums := zeros(N)
	var cym := zeros(N)
	for b in 16:
		var t0 := b * bar
		var second := b >= 8
		var pend := (b % 4) == 3
		var tk := [0, 8]
		if second:
			tk = [0, 3, 8, 10]
			if b % 2 == 1:
				tk.append(14)
		elif b % 2 == 1:
			tk.append(10)
		for s in tk:
			var tg := 1.0 if (s == 0 or s == 8) else 0.7
			hit(drums, taikos[rng.randi() % 3], t0 + s * stp, tg)
		if pend:
			hit(drums, tom_mid, t0 + 4 * stp, 0.8)
			hit(drums, tom_hi, t0 + 12 * stp, 0.75)
			hit(drums, tom_hi, t0 + 13 * stp, 0.65)
			hit(drums, tom_mid, t0 + 14 * stp, 0.8)
			hit(drums, tom_lo, t0 + 15 * stp, 0.9)
		else:
			hit(drums, tom_mid if b % 2 == 0 else tom_hi, t0 + 4 * stp, 0.75)
			hit(drums, tom_mid, t0 + 12 * stp, 0.75)
		for s in range(0, 16, 2):
			hit(drums, frame, t0 + s * stp, 0.55 if s % 4 == 0 else 0.35)
		if second:
			for s in range(1, 16, 2):
				hit(drums, frame, t0 + s * stp, 0.15)
		if second or pend:
			hit(drums, tabor, t0 + 4 * stp, 0.45)
			hit(drums, tabor, t0 + 12 * stp, 0.45)
		if b % 4 == 0:
			mix_t(cym, crash, t0, 0.8 if b % 8 == 0 else 0.6)
		if pend:
			mix_t(cym, sw, t0 + bar - 1.0, 0.6)

	# galloping ostinato (8th + two 16ths per beat), beat 4 walks down (full rate, cached)
	var bass := zeros(N)
	var cache := {}
	var offs := [0.0, 0.25, 0.375]
	var lens := [0.22, 0.11, 0.11]
	for b in 16:
		var h: String = harm[b]
		var r: int = root[h]
		for bt in 4:
			var tb := b * bar + bt * beat
			var notes: Array = [r, r, r] if bt < 3 else walk[h]
			for k in 3:
				var m: int = notes[k]
				var key := "%d_%d" % [m, mini(k, 1)]
				if not cache.has(key):
					cache[key] = bass_note(lens[k], midi(float(m)))
				mix_t(bass, cache[key], tb + float(offs[k]), 1.0 if k == 0 else 0.7)

	# choir pad, quieter in the first half (SR/2)
	var ev := []
	for b in 16:
		ev.append([b * bar, pads[harm[b]], 0.5 if b < 8 else 1.0])
	var pdur := bar + 0.5
	var pad := choir_bus(H, ev, pdur, [0.0, 0.0, 0.25, 1.0, bar, 0.85, pdur, 0.0], 3, 8.0, 0.004, 2)
	var padf := choir_colour(pad, "a", 1.0, 600.0, 0.5, 2800.0, 2.0)

	# heroic-but-grim brass melody, second half (bar, beat, beats, midi) (SR/2, cached)
	var mel := [[8, 0, 2, 62], [8, 2, 1, 65], [8, 3, 1, 69], [9, 0, 3, 70], [9, 3, 1, 69],
		[10, 0, 2, 67], [10, 2, 1, 65], [10, 3, 1, 67], [11, 0, 2, 64], [11, 2, 2, 69],
		[12, 0, 2, 74], [12, 2, 1, 72], [12, 3, 1, 69], [13, 0, 2, 70], [13, 2, 1, 69], [13, 3, 1, 67],
		[14, 0, 2, 67], [14, 2, 1, 65], [14, 3, 1, 64], [15, 0, 4, 69]]
	var lead := zeros(H)
	var lcache := {}
	for nt in mel:
		var t0: float = float(nt[0]) * bar + float(nt[1]) * beat
		var key := "%d_%d" % [int(nt[3]), int(nt[2])]
		if not lcache.has(key):
			var dl: float = float(nt[2]) * beat
			var dur := dl + 0.12
			var f := midi(float(nt[3]))
			var vib := 0.007 if dl >= 1.0 else 0.0
			var v := brass_note(dur, f, 0.05, 0.14, 2400.0, vib, 0.03, 2.0)
			mix(v, brass_note(dur, f * 0.5, 0.06, 0.14, 1400.0, 0.0, 0.03, 2.0), 0, 0.5)
			lcache[key] = v
		mix(lead, lcache[key], at(t0, 2))

	norm_rms(drums, 0.16)
	norm_rms(bass, 0.085)
	norm_rms(cym, 0.03)
	norm_rms(padf, 0.045)
	norm_rms(lead, 0.06)

	var half := zeros(H)
	var send := zeros(H)
	mix(half, padf)
	mix(send, padf, 0, 0.7)
	mix(half, lead)
	mix(send, lead, 0, 0.5)
	down_mix(send, drums, 0.25)
	down_mix(send, bass, 0.1)
	down_mix(send, cym, 0.3)
	var rv := reverb(send, 1.0, 0.82, 0.4, 0.65, 0.0, 0.0)
	mix(half, rv, 0, 0.45)
	var mixb := drums
	mix(mixb, bass)
	mix(mixb, cym)
	up_mix(mixb, half, 2, 1.0)
	return finish_music(mixb, L)


# =====================================================================
# Boss: 140 BPM, 14 bars = 24.0 s, 7 two-bar units: Dm Eb Dm Bb Gm Eb A.
# Faster 3-3-2 taiko groove, chugging low ostinato, dissonant low brass stabs,
# dark choir, tolling bells.
# =====================================================================
func music_boss() -> PackedFloat32Array:
	rng.seed = 7003
	var beat := 60.0 / 140.0
	var stp := beat / 4.0
	var bar := beat * 4.0
	var L := ns(24.0)
	var N := L + ns(5.0)
	var H := N >> 1
	var units := ["Dm", "Eb", "Dm", "Bb", "Gm", "Eb", "A"]
	var root := {"Dm": 38, "Eb": 39, "Bb": 34, "Gm": 31, "A": 33}
	var stabv := {"Dm": [38, 45, 50, 51], "Eb": [39, 46, 50, 55], "Bb": [34, 46, 50, 52], "Gm": [43, 50, 55, 56], "A": [45, 52, 55, 58]}
	var choirv := {"Dm": [57, 62, 65], "Eb": [55, 58, 63], "Bb": [53, 58, 62], "Gm": [55, 58, 62], "A": [57, 61, 64]}

	var taikos := [drum_taiko(0), drum_taiko(1), drum_taiko(2)]
	var tom_hi := drum_tom(260.0, 150.0)
	var tom_mid := drum_tom(200.0, 115.0)
	var tom_lo := drum_tom(150.0, 85.0)
	var frame := drum_frame()
	var tabor := drum_tabor()
	var crash := cymbal(2.0)
	var sw := swell(beat * 2.0)
	var boom := thump(1.2, 70.0, 35.0, 0.08, 0.4)

	var drums := zeros(N)
	var cym := zeros(N)
	var tk := [0, 3, 6, 8, 11, 14]
	var tgs := [1.0, 0.7, 0.75, 0.95, 0.7, 0.75]
	for b in 14:
		var t0 := b * bar
		var uend := (b % 2) == 1
		for j in tk.size():
			hit(drums, taikos[rng.randi() % 3], t0 + int(tk[j]) * stp, float(tgs[j]))
		hit(drums, tom_mid, t0 + 4 * stp, 0.8)
		if uend:
			hit(drums, tom_hi, t0 + 12 * stp, 0.75)
			hit(drums, tom_hi, t0 + 13 * stp, 0.65)
			hit(drums, tom_mid, t0 + 14 * stp, 0.8)
			hit(drums, tom_lo, t0 + 15 * stp, 0.9)
		else:
			hit(drums, tom_hi, t0 + 12 * stp, 0.75)
		for s in 16:
			var fg := 0.15
			if s % 2 == 0:
				fg = 0.5 if s % 4 == 0 else 0.3
			hit(drums, frame, t0 + s * stp, fg)
		hit(drums, tabor, t0 + 4 * stp, 0.5)
		hit(drums, tabor, t0 + 12 * stp, 0.5)
		if not uend:
			mix_t(cym, crash, t0, 0.7 if b % 8 == 0 else 0.5)
			mix_t(drums, boom, t0, 0.6)
	mix_t(cym, sw, 6 * bar - beat * 2.0, 0.6)
	mix_t(cym, sw, 14 * bar - beat * 2.0, 0.7)

	# 16th-note chugging low ostinato with 3-3-2 accents (full rate, cached)
	var bass := zeros(N)
	var cache := {}
	var acc := [0, 3, 6, 8, 11, 14]
	for b in 14:
		var h: String = units[b >> 1]
		var r: int = root[h]
		if not cache.has(r):
			cache[r] = bass_note(0.085, midi(float(r)))
		for s in 16:
			mix_t(bass, cache[r], b * bar + s * stp, 1.0 if acc.has(s) else 0.45)

	# dissonant low brass stabs (SR/2, cached per chord+length)
	var stabs := zeros(H)
	var scache := {}
	for u in 7:
		var tu := u * 2.0 * bar
		var hits := [[0.0, 0.45, 1.0], [bar, 0.25, 0.8], [bar + 10.0 * stp, 0.3, 0.9]]
		if u == 6:
			hits.append([bar + 6.0 * stp, 0.2, 0.8])
			hits.append([bar + 14.0 * stp, 0.2, 0.9])
		for hh in hits:
			var dur: float = float(hh[1]) + 0.12
			var key := "%s_%.2f" % [units[u], dur]
			if not scache.has(key):
				var ch := zeros(ns(dur / 2.0))
				for m in stabv[units[u]]:
					mix(ch, brass_note(dur, midi(float(m)), 0.02, 0.1, 3000.0, 0.0, 0.02, 2.0))
				scache[key] = ch
			mix(stabs, scache[key], at(tu + float(hh[0]), 2), float(hh[2]))
	sat(stabs, 1.6)

	# dark choir pad (SR/2)
	var ev := []
	for u in 7:
		ev.append([u * 2.0 * bar, choirv[units[u]], 1.0])
	var pdur := 2.0 * bar + 0.8
	var pad := choir_bus(H, ev, pdur, [0.0, 0.0, 0.6, 1.0, 2.0 * bar, 0.9, pdur, 0.0], 3, 10.0, 0.004, 2)
	var padf := choir_colour(pad, "a", 0.95, 600.0, 0.5, 2400.0, 2.0)

	# ominous bells (full rate)
	var bells := zeros(N)
	mix_t(bells, nrm(bell(5.0, 146.83, 0.8, 0.9), 1.0), 0.0, 1.0)
	mix_t(bells, nrm(bell(5.0, 98.0, 0.8, 0.9), 1.0), 8.0 * bar, 0.9)

	norm_rms(drums, 0.17)
	norm_rms(bass, 0.075)
	norm_rms(cym, 0.03)
	norm_rms(bells, 0.035)
	norm_rms(stabs, 0.07)
	norm_rms(padf, 0.05)

	var half := zeros(H)
	var send := zeros(H)
	mix(half, stabs)
	mix(send, stabs, 0, 0.4)
	mix(half, padf)
	mix(send, padf, 0, 0.7)
	down_mix(send, drums, 0.25)
	down_mix(send, bass, 0.1)
	down_mix(send, cym, 0.3)
	down_mix(send, bells, 0.6)
	var rv := reverb(send, 1.0, 0.84, 0.4, 0.7, 0.0, 0.0)
	mix(half, rv, 0, 0.45)
	var mixb := drums
	mix(mixb, bass)
	mix(mixb, cym)
	mix(mixb, bells)
	up_mix(mixb, half, 2, 1.0)
	return finish_music(mixb, L)
