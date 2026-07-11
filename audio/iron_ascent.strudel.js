// ============================================================
//  "Iron Ascent" — boss theme for Cannon Platformer
//  Sister track to "Skyward Recoil" (same DNA, higher stakes)
//  Celeste-inspired intensity: driving pulse, tense harmony,
//  urgent piano — still warm/musical, not harsh chiptune
//
//  How to use:
//    1. Open https://strudel.cc/
//    2. Paste this entire file into the editor
//    3. Press Ctrl+Enter (or Cmd+Enter) to play
//    4. Export audio from the UI if you want a .wav for Godot
// ============================================================

// ~128 BPM — tight, confrontational, still playable under stress
setcpm(128 / 4)

// Darker mirror of the exploration progression (relative minor territory)
// Bm → G → Em → F#sus4/F#   |   G → A → F#m → Bm(add9)
// Feels like Skyward Recoil flipped into a fight
const bossChords = chord("<Bm G Em F#sus4 G A F#m Bm9>/2").dict('ireal')

stack(
  // ---------- driving kick (heartbeat under pressure) ----------
  s("bd ~ bd ~ bd ~ [bd ~] ~")
    .bank("RolandTR808")
    .gain(0.42)
    .lpf(900)
    .room(0.25)
    .shape(0.2),

  // snare / clap hits on 2 & 4 — restrained, not stadium-metal
  s("~ sd ~ sd")
    .bank("RolandTR808")
    .gain(0.28)
    .lpf(3500)
    .room(0.35)
    .hpf(200),

  // restless hi-hats — tension without noise-wall
  s("hh*8")
    .bank("RolandTR808")
    .gain(0.11)
    .hpf(7000)
    .room(0.3)
    .speed(perlin.range(0.95, 1.05)),

  // off-beat open hats for urgency
  s("~ ~ oh ~ ~ ~ oh ~")
    .bank("RolandTR808")
    .gain(0.1)
    .room(0.4)
    .hpf(4000)
    .cut(1),

  // ---------- tense pad (colder than exploration) ----------
  bossChords
    .voicing()
    .s("gm_pad_choir")
    .gain(0.28)
    .attack(0.25)
    .release(0.9)
    .lpf(sine.range(700, 1400).slow(8))
    .room(0.8)
    .roomsize(5)
    .hpf(120),

  // ---------- urgent electric piano stabs ----------
  bossChords
    .voicing()
    .s("gm_epiano1")
    .struct("x ~ x ~ ~ x ~ x")
    .gain(0.4)
    .clip(0.7)
    .room(0.55)
    .delay(0.15)
    .delaytime(0.25)
    .delayfeedback(0.2)
    .lpf(2200)
    .shape(0.15),

  // ---------- pulsing bass (cannon recoil weight) ----------
  note("<b1 b1 g1 g1 e1 e1 f#1 f#1 g1 g1 a1 a1 f#1 f#1 b1 b1>/1")
    .s("gm_synth_bass_1")
    .gain(0.5)
    .lpf(sine.range(280, 520).slow(4))
    .room(0.2)
    .clip(0.85)
    .shape(0.25),

  // ---------- main piano — twisted Skyward motif ----------
  // Same contour as exploration melody, minor/tense, more note density
  note(`<
    [b3 ~ d4 f#4 ~ f#4 e4 d4]
    [g3 ~ b3 d4 ~ e4 d4 b3]
    [e4 ~ g4 b4 ~ a4 g4 e4]
    [f#4 ~ c#4 f#4 ~ e4 d4 c#4]
    [g4 ~ b3 d4 ~ g4 f#4 e4]
    [a4 ~ e4 a4 ~ g4 f#4 e4]
    [f#4 ~ a3 c#4 ~ f#4 e4 d4]
    [b3 ~ ~ d4 f#4 ~ b4 ~]
  >/2`)
    .s("piano")
    .gain(0.58)
    .clip(0.75)
    .room(0.65)
    .roomsize(2.5)
    .delay(0.22)
    .delaytime(0.25)
    .delayfeedback(0.3)
    .lpf(4200)
    .attack(0.005)
    .release(0.35),

  // ---------- high pressure line (lead synth, not square-wave) ----------
  note(`<
    [~ f#5 ~ f#5 ~ e5 d5 ~]
    [~ ~ d5 ~ e5 ~ f#5 ~]
    [~ g5 ~ g5 ~ f#5 e5 ~]
    [~ f#5 ~ ~ c#5 ~ ~ ~]
    [~ ~ g5 ~ a5 ~ b5 a5]
    [~ ~ a5 ~ g5 ~ f#5 ~]
    [~ f#5 ~ e5 ~ d5 c#5 ~]
    [b4 ~ ~ ~ f#5 ~ ~ ~]
  >/2`)
    .s("gm_lead_6_voice")
    .gain(0.22)
    .room(0.7)
    .delay(0.3)
    .delaytime(0.375)
    .delayfeedback(0.35)
    .lpf(sine.range(1800, 3200).slow(4))
    .attack(0.02)
    .release(0.5)
    .vib(4)
    .vibmod(0.15),

  // ---------- rapid arpeggios (panic / climb intensity) ----------
  note("<[b3 d4 f#4 a4]*2 [g3 b3 d4 f#4]*2 [e3 g3 b3 d4]*2 [f#3 a3 c#4 e4]*2 [g3 b3 d4 f#4]*2 [a3 c#4 e4 g4]*2 [f#3 a3 c#4 e4]*2 [b3 d4 f#4 b4]*2>/2")
    .s("gm_vibraphone")
    .gain(0.14)
    .room(0.75)
    .delay(0.25)
    .delaytime(0.125)
    .delayfeedback(0.25)
    .lpf(3000)
    .clip(0.5),

  // ---------- sparse danger chimes (hits every other phrase) ----------
  note("<~ ~ ~ [f#5, c#6] ~ ~ ~ [b5, f#5]>/2")
    .s("gm_music_box")
    .gain(0.14)
    .room(0.95)
    .delay(0.45)
    .delaytime(0.5)
    .delayfeedback(0.45)
    .lpf(4500)
    .attack(0.01)
    .release(2)
)
.gain(0.88)
// wider, slightly unstable stereo — fight is off-balance
.jux(x => x.detune("<5 -4 6 -3>").late(0.01))
