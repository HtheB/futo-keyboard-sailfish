# Modified derivative notice

This is **FUTO Keyboard for Sailfish OS 0.2.3**, an independent and modified
Sailfish OS integration. It is not an official FUTO product and is not built,
published, or supported by FUTO.

The derivative uses FUTO Keyboard word-list data and selected native Unicode
utility code at upstream commit
`eaf0389f962b0dba07778d0feab6511e6e98c581` (2026-08-11). The Android UI,
Android input method service and Android application code are not included.

Sailfish-specific code adds a unified Maliit layout, a QML input handler,
multilingual native settings, a local D-Bus service, a native dictionary worker,
configurable auto-correction with undo, cross-language typo/prefix ranking, and
a private on-device personal dictionary. Version 0.1.0 also adds local context
and next-word learning, automatic per-word language weighting, configurable
letter/symbol/emoji pages, seventeen per-language arrangements adapted from the
Apache-2.0 FUTO layout repository and standard Turkish F arrangement,
Sailfish-native typing gestures, selectable
top-row/aligned-numpad symbol layouts, compact settings subpages, a dedicated
Turkish layout, device-authenticated dictionary access, live height adjustment,
an opt-in private clipboard history, collapsible prediction controls, native
touch-feedback controls, and a complete Unicode Emoji 17 picker with image category tabs, multilingual
Unicode CLDR search with locale-aware Turkish casing, recent emoji, adjustable
grid sizing, visible tone markers,
skin-tone selection, ambience-aware keyboard utility panels, and adjustable
Sailfish-native key sounds. Release 20 adds a geometry-aware local swipe decoder
for the active Sailfish layout and an offline microphone workflow using the
separately licensed FUTO Voice Input Whisper implementation and
Multilingual-39 model. Captured PCM is temporary and removed after every voice
session. The bundled
emoji artwork is separately attributed and licensed in
`LICENSES/EMOJI-ATTRIBUTION.md`.

Release 21 corrects automatic capitalization between consecutive swipe words
and adds a live highlighted path above the letter keys during a swipe.

Release 22 adds live partial voice transcription, push-to-talk and continuous
listening modes, accelerating Backspace, optional centered predictions, an
ordered configurable hold-123 action menu, Android AppSupport URL-field
fallbacks, single-step vault authentication, and opt-in encrypted password-save
prompts.

Release 23 restores an explicit phone-code/fingerprint challenge for Saved
passwords without leaving a retry page or requiring a redundant secrets prompt,
adds horizontal scrolling to crowded hold-123 actions, closes that menu when
Microphone starts, keeps downward letter gestures available to swipe typing,
and relayouts the dedicated microphone key immediately when its setting changes.

Release 42 adds independent portrait/landscape Full, Thumb, and One-handed
geometry, in-keyboard side/maximize controls, and a Quick Settings mode action.
It also integrates Sailfish's native MCE hardware-keyboard state, offers an
opt-in simultaneous virtual surface through an isolated Maliit-only policy
shim, and exposes supported XKB dead-key variants. Mouse and pointer handling
are deliberately outside this integration.

Release 43 groups the simultaneous-virtual-keyboard and physical dead-key
controls in a dedicated Hardware keyboard section, and optionally suppresses
pressed-key previews across every source of Incognito state. It also bundles
the MIT-licensed libX11 UTF-8 Compose table missing from Sailfish, isolates and
synchronizes portrait/landscape modes, and corrects the one-handed control
overlay's coordinates and touch bounds. It also adds a categorized,
font-coverage-generated extended picker with 5,807 insertable symbols behind a
long press of the {&= key.

Release 44 removes the unreliable one-handed side/maximize overlays and makes
left- and right-handed geometry explicit, independently selectable modes. It
also adds persistent symbol Favorites, complete common/Arabic numeric rows,
de-duplicates emoji artwork from the symbol grid, bundles Amiri for Arabic
religious ligatures, and strengthens the selected-tab indicators.

Release 45 synchronizes orientation-specific mode changes between the live
keyboard and Settings, refines picker tabs and Favorites interaction, and makes
every landscape Thumb surface genuinely split. The letter, numpad, emoji, and
extended-symbol pages keep an empty center reach gap, while Quick Settings and
category headers remain available without restoring stale predictions or
changing the selected keyboard mode. Mode persistence is dispatched before a
geometry rebuild and retried until the helper confirms the dconf write. The
layout also tracks orientation while Maliit is starting or temporarily
inactive, preventing portrait from loading the saved landscape mode.

Release 46 supplies the dynamically linked Qt Compose platform input-context
plugin and a compatibility wrapper for the Qt 5.6 Sailfish Maliit build, which
explicitly disables its otherwise present Compose hook. The wrapper delegates
all normal behavior to the unmodified stock Maliit plugin and filters only
Compose sequences.
Together with the release-43 libX11 table, this restores both composed accents
and standalone dead-key output. It also makes rotation select the current
surface's saved mode immediately and arranges Arabic religious ligatures in a
semantic right-to-left sequence, using a readable compatibility phrase where
Sailfish's native fonts lack U+FDFB.

The Sailfish edition adds portable password export and restore. One ZIP
contains separate browser-compatible website CSV files and a FUTO app-account
CSV. Exports may be protected with WinZip-compatible AES-256 encryption through
the MIT-licensed `github.com/yeka/zip` library; leaving the password empty
requires an explicit warning in Settings.
