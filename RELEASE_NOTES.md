# FUTO Keyboard for Sailfish OS 0.4.0

This release expands the keyboard's language and layout coverage, and collects
the fixes made since the previous release.

## New features

- Expanded language and layout support with additional FUTO layouts, their
  proper key order, and language-specific long-press characters.
- Added predictions and swipe typing for additional languages where an offline
  dictionary is available.
- Added native Sailfish font support for scripts such as Amazigh, Sinhala,
  Myanmar, and Khmer.
- Improved the Arabic and Persian layouts with appropriate punctuation,
  numerals, and alternative letters.
- Added the new Saudi Riyal symbol and improved the rendering of Arabic Rial
  and Jalla Jalaluhu symbols.

## Fixes

- Greatly reduced emoji-picker memory usage and improved scrolling
  performance, especially in long categories such as flags.
- Improved emoji search so unrelated results are no longer shown for searches
  such as "happy".
- Spacebar cursor control now works smoothly in both native Sailfish and
  Android applications.
- The optional number row now matches the letter-row height and no longer
  overlaps it.
- Swipe vibration now occurs only on the first touched letter.
- Swiped words receive a space only after accepting the suggestion or
  beginning the next swipe.
- Swipe typing stays disabled until the required FUTO Swipe content has been
  downloaded.
- Pressing Space now accepts the visibly highlighted correction instead of an
  unseen suggestion.
- System-default keyboard sounds now respect both Sailfish Touch sounds and
  Silent mode.
- The current system clipboard entry can be pasted into password fields
  without enabling clipboard history.
- Corrected duplicated and misplaced secondary symbols across keyboard
  layouts.
