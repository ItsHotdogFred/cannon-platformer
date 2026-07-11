// ============================================================
//  "Skyward Recoil" — exploration theme for Cannon Platformer
//  Celeste-inspired: soft piano, warm pads, gentle pulse
//  Not chiptune — warm, emotional, floaty platformer energy
//
//  How to use:
//    1. Open https://strudel.cc/
//    2. Paste this entire file into the editor
//    3. Press Ctrl+Enter (or Cmd+Enter) to play
//    4. Export audio from the UI if you want a .wav for Godot
// ============================================================

// ~92 BPM — unhurried, good for exploratory platforming
setcpm(92 / 4)

// Chord progression (8 bars): hopeful → lift → settle → resolve
// Dmaj7 → Gmaj9 → Bm7 → Aadd9  |  Em7 → Gmaj7 → A7sus4 → Dmaj9
const progression = chord("<D^7 G^9 Bm7 Aadd9 Em7 G^7 Asus4 D^9>/2").dict('ireal')

stack(
  // ---------- soft pulse (heartbeat, not a drum kit) ----------
  s("bd ~ ~ ~ bd ~ ~ ~")
    .bank("RolandTR808")
    .gain(0.28)
    .lpf(600)
    .room(0.4),

  s("~ ~ hh:1 ~ ~ ~ hh:1 ~")
    .bank("RolandTR808")
    .gain(0.12)
    .hpf(6000)
    .room(0.5)
    .delay(0.25)
    .delaytime(0.33)
    .delayfeedback(0.2),

  // ---------- warm pad bed ----------
  progression
    .voicing()
    .s("gm_pad_warm")
    .gain(0.32)
    .attack(0.4)
    .release(1.2)
    .lpf(sine.range(900, 1600).slow(16))
    .room(0.85)
    .roomsize(4)
    .slow(1),

  // ---------- soft electric piano chords ----------
  progression
    .voicing()
    .s("gm_epiano1")
    .struct("x ~ ~ x ~ ~ x ~")
    .gain(0.38)
    .clip(1.5)
    .room(0.7)
    .delay(0.2)
    .delaytime(".375")
    .delayfeedback(0.25)
    .lpf(2800)
    .phaser(0.3),

  // ---------- gentle walking bass ----------
  note("<d2 g2 b1 a1 e2 g2 a1 d2>/2")
    .s("gm_acoustic_bass")
    .gain(0.45)
    .lpf(400)
    .room(0.3)
    .clip(0.9),

  // ---------- main piano melody (floats above) ----------
  // Phrase A: lift / Phrase B: answer
  note(`<
    [d4 ~ f#4 a4 ~ a4 g4 f#4]
    [e4 ~ g4 b4 ~ a4 g4 e4]
    [f#4 ~ d4 f#4 ~ e4 d4 b3]
    [a3 ~ c#4 e4 ~ d4 ~ ~]
    [e4 ~ g4 b4 ~ d5 c#5 b4]
    [a4 ~ g4 f#4 ~ e4 d4 ~]
    [c#4 ~ e4 a4 ~ g4 f#4 e4]
    [d4 ~ ~ ~ f#4 ~ a4 ~]
  >/2`)
    .s("piano")
    .gain(0.55)
    .clip(0.85)
    .room(0.75)
    .roomsize(3)
    .delay(0.3)
    .delaytime(0.375)
    .delayfeedback(0.35)
    .lpf(4500)
    .attack(0.01)
    .release(0.6),

  // ---------- high sparkle / ice-crystal counter melody ----------
  // enters lightly — Celeste-like chime color without harsh 8-bit
  note(`<
    [~ ~ ~ ~ a5 ~ ~ f#5]
    [~ ~ ~ ~ b5 ~ a5 ~]
    [~ ~ f#5 ~ ~ d5 ~ ~]
    [~ e5 ~ ~ ~ ~ ~ ~]
    [~ ~ ~ b5 ~ ~ a5 ~]
    [~ ~ f#5 ~ ~ ~ e5 ~]
    [~ ~ ~ a5 ~ ~ ~ g5]
    [f#5 ~ ~ ~ ~ ~ ~ ~]
  >/2`)
    .s("gm_music_box")
    .gain(0.18)
    .room(0.9)
    .delay(0.4)
    .delaytime(0.5)
    .delayfeedback(0.4)
    .lpf(5000)
    .attack(0.02)
    .release(1.5),

  // ---------- subtle rising arp (momentum / grappling feel) ----------
  note("d4 f#4 a4 d5 f#5 a5 d6 a5")
    .struct("~ x ~ x ~ x ~ x")
    .s("gm_vibraphone")
    .gain(sine.range(0.08, 0.16).slow(8))
    .room(0.8)
    .delay(0.35)
    .delaytime(0.25)
    .delayfeedback(0.3)
    .lpf(3500)
    .slow(2)
)
.gain(0.85)
// slight stereo wobble for width
.jux(x => x.detune(3))
