# FUTO Keyboard for Sailfish OS

A feature-rich native keyboard for Sailfish OS, based on FUTO Keyboard and designed to work across both native Sailfish applications and Android AppSupport.

This project brings the FUTO typing experience to Sailfish OS while adding many new features and integrations made specifically for the platform.

> This is an independent community project and is not an official FUTO product.

## Features

### Smarter typing

- Multilingual predictions across 25 available languages
- Automatic per-word language detection
- Spelling corrections and next-word predictions
- Context-aware suggestions and compound-word support
- Swipe typing with a smooth visual trail
- Cursor control by holding and dragging the space bar
- Fully offline voice input with live transcription and push-to-talk
- Optional URL history and suggestions

### Make the keyboard yours

- 20 keyboard layouts
- A separate layout can be selected for each language
- Full-size, thumb, left-handed, and right-handed modes
- Separate keyboard modes for portrait and landscape
- Adjustable keyboard height
- Optional number row and secondary symbols
- Adjustable long-press timing
- Customizable sounds, vibration, and key previews
- Customizable Quick Settings menu

### Emoji and symbols

- Complete Emoji 17 collection
- Emoji search using your enabled languages
- Categories, favourites, recently used emoji, and skin tones
- Built-in Sailfish OS emojis, plus downloadable Twemoji, OpenMoji, and Noto Color Emoji styles
- Large categorized symbol collection
- Favourite symbols for quick access

### Privacy and useful tools

- Manual and automatic Incognito mode
- Privacy Switch integration
- Automatic protection while entering passwords
- Encrypted learned words and URL history
- Encrypted password manager protected by your device code or fingerprint
- Password import and export, with optional AES-256 ZIP protection
- Clipboard history with pinned entries and automatic cleanup
- No account or online service required for typing, predictions, or voice input

### Hardware keyboards

- Automatic hardware-keyboard detection
- Option to keep the virtual keyboard visible
- Dead-key support for entering accented characters

## Download

Download the latest RPM from the [Releases page](https://github.com/HtheB/futo-keyboard-sailfish/releases/latest).

Choose the RPM that matches your device: `aarch64`, `armv7hl`, or `i486`.
The new Jolla Phone uses the `aarch64` package.

This release was made and tested on the new Jolla Phone running Sailfish OS 5.2.0.16.

## Getting started

1. Download and install the RPM.
2. Open **Settings → Text input → Keyboards**.
3. Enable **FUTO**.
4. Open **Settings → Text input → FUTO Keyboard settings** to choose your languages and customize the keyboard.

You can also open the settings directly from the keyboard by holding the **123** button and selecting **Settings**.

## Downloadable content

Open **FUTO Keyboard settings → Downloadable content** to install the content you want:

- Language dictionaries
- Emoji artwork
- Offline voice input

Content can also be removed again from the same menu.

## Privacy

Typing, predictions, learned words, clipboard history, voice recognition, and saved passwords are handled locally on your phone.

Clipboard history, URL learning, and the password manager are optional. Incognito mode prevents the keyboard from learning or collecting clipboard content while it is active.

Saved passwords and protected learned data can be secured using the existing device code or fingerprint authentication.

## Building from source

The included build script creates the Sailfish OS RPM and the separately downloadable content packages. Select the target architecture with `FUTO_ARCH`:

```sh
FUTO_ARCH=aarch64 bash scripts/build-rpm.sh
FUTO_ARCH=armv7hl bash scripts/build-rpm.sh
FUTO_ARCH=i486 bash scripts/build-rpm.sh
```

Build results are placed in the `build/` directory. Use the matching Sailfish SDK target and toolchain for each architecture.

## Source and licensing

This project contains modified and newly developed components under their respective licenses.

The upstream sources and revisions are documented in [UPSTREAM.md](UPSTREAM.md). Details about modifications can be found in [MODIFIED-NOTICE.md](MODIFIED-NOTICE.md), with additional license information in the [LICENSES](LICENSES) directory.

Ported to Sailfish OS with additional features by HtheB.
