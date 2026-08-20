Sound pack provenance — all free-to-use / CC0, verified per-file before use.

alphanumeric/ (32 files — keypress-001.wav .. keypress-032.wav)
  Source: OpenGameArt "Keyboard Soundpack #1" by Unicae Games
  https://opengameart.org/content/keyboard-soundpack-1-typing-and-single-keystrokes
  Downloaded by the user directly in a browser on 2026-08-20 (automated download
  was blocked from this environment — see git log), raw pack kept at
  SoundPack/raw/opengameart/keyboard-soundpack-1/ for provenance.
  Keyboard: Cherry KC 1000. Recorded with a Shure SM7B. Per the pack's own
  readme.txt: "Free to use however you like." (page license: CC0.)
  These are generic single-keystroke recordings (not labeled per specific key),
  so all 32 were used for the alphanumeric bucket — the highest-frequency
  category, where maximum variety matters most.
  Not used from this pack: the "Human Typing" (10 files) and "Generated Typing"
  (7 files) folders — those are multi-key typing-run recordings, not usable as
  single-trigger samples without manual slicing.

space/, enter/, backspace/, modifier/, other/
  (intentionally empty)
  These previously held one mismatched clip each from unrelated freesound.org
  uploads — different keyboards, different mics, different mastering entirely
  (backspace's was even a different duration class: 1.66s stereo vs. the
  Cherry pack's uniform 0.25s mono). Mixing those into an otherwise consistent
  32-sample authentic set made non-letter keys sound like a different
  keyboard had been spliced in. Removed for tonal consistency — every key
  should sound like the same keyboard.
  SoundEngine.play() already falls back to the alphanumeric bucket whenever a
  category's folder is empty or missing (this is exactly how `other/` worked
  from the start), so leaving these folders empty means every key across the
  whole board draws from the same 32-sample Cherry KC1000 pool — one
  keyboard, one mic, one mastering chain, no code changes required.
  The removed Freesound files are still archived (unused) under
  SoundPack/raw/freesound/ for reference.

  Only repopulate one of these folders in future with recordings that come
  from the *same* physical keyboard/mic/mastering chain as the Cherry KC1000
  pack above — mixing in a different source reintroduces this exact bug.

License source of truth for CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/legalcode
