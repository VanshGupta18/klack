Sound pack provenance. Resources/Sounds/<theme name>/ is one selectable theme
in the menu bar's "Sound Theme" picker (SoundEngine discovers theme folders
by name at launch — see Sources/Klack/SoundEngine.swift). Within each theme,
only alphanumeric/ is populated; space/enter/backspace/modifier/other are
left empty and fall back to that theme's alphanumeric bucket at runtime
(SoundEngine.play()) — every key across the whole board draws from the same
pool within a theme, so nothing sounds like a different keyboard was spliced
in. Do not mix samples from different sources within one theme's folder —
that's exactly the bug that motivated this structure in the first place.

"Cherry KC1000" theme (32 files — keypress-001.wav .. keypress-032.wav)
  License: CC0 1.0 (public domain), clearly stated on the source page.
  Source: OpenGameArt "Keyboard Soundpack #1" by Unicae Games
  https://opengameart.org/content/keyboard-soundpack-1-typing-and-single-keystrokes
  Downloaded by the user directly in a browser on 2026-08-20, raw pack kept
  at SoundPack/raw/opengameart/keyboard-soundpack-1/ for provenance.
  Keyboard: Cherry KC 1000 (membrane). Recorded with a Shure SM7B.
  Not used from this pack: "Human Typing" (10 files) and "Generated Typing"
  (7 files) — multi-key typing-run recordings, not usable as single-trigger
  samples without manual slicing.

"CherryMX Black PBT" theme (86 files — click-001.wav .. click-086.wav)
  License: UNCLEAR — accepted by the user anyway for personal use only.
  Source: the "CherryMX Black - PBT keycaps" default/pre-installed sound
  pack bundled with the Mechvibes app (github.com/hainguyents13/mechvibes),
  downloaded by the user from Mechvibes on 2026-08-20. Raw pack (one
  sound.ogg audio sprite + config.json byte-offset table, Mechvibes' native
  format) kept at SoundPack/raw/mechvibes/cherrymx-black-pbt/ for
  provenance. The 86 individual clips here were sliced out of that sprite
  via ffmpeg, using each unique (offset, duration) pair from config.json —
  114 key mappings collapse to 86 unique underlying clips.
  Mechvibes' own code is MIT-licensed, but config.json for this pack carries
  zero author/license/attribution metadata, and no documentation was found
  establishing where this specific pack's audio originally came from.
  Community sound packs on Mechvibes' wiki are known to be a mixed bag
  (some are reportedly extracted from other people's recordings/videos
  without clear redistribution rights) — this one being tagged
  "pre-installed" in its own config.json suggests it ships with the base
  app rather than being a user upload, but that alone isn't a confirmed
  license. Genuinely mechanical (real Cherry MX Black switches, per the
  name) vs. the Cherry KC1000 theme's membrane keyboard — meaningfully
  different, more clacky character, which is the point of having it as a
  separate theme rather than mixed into the CC0 one.

License source of truth for CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/legalcode
