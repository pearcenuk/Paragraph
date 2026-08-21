# Paragraph

Paragraph is a native macOS Markdown writing application focused on readability
and distraction-free drafting.

It is built for writing novels and notes. The guiding rule is that **if a
feature does not directly help the writer write or edit words, it does not
belong in Paragraph.**

---

## What it does

- Opens ordinary `.md`, `.markdown` and `.txt` files, in place, without
  converting them to anything
- Shows a workspace folder — local, external, or in iCloud Drive — in a
  left-hand browser you never have to leave the application to use
- Opens files as native macOS tabs and in native windows
- Puts the manuscript in a centred, left-aligned writing column with a fixed,
  comfortable measure
- Uses the system's own spell checking, and shows no other analysis while you
  type
- Sets prose in IBM Plex Sans, at a size you can change with `⌘+` and `⌘-`
- Shows the current document's word count, and nothing else
- Offers Light, Dark and Green Screen themes
- Offers Typewriter Mode and Focus Mode
- Comes back the way you left it

## What it deliberately does not do

No AI. No accounts, cloud service or subscription. No plugins, themes, custom
CSS, font pickers or colour pickers. No writing goals, streaks, reading times,
readability scores or style advice. No corkboard, no character database, no
project planning. No Markdown preview, and no hidden-Markdown editor.

Paragraph has no file format of its own and no database. If you delete it, you
are left with exactly the folder of Markdown files you started with.

---

## Requirements

- **macOS 13.0 Ventura or later** (Apple Silicon and Intel)
- **Xcode 16 or later** to build (developed against Xcode 26.6)

### Why macOS 13

The deployment target was chosen to be as old as it could be without forcing
compatibility code into the application:

- macOS 13 is old enough to include Intel Macs going back to around 2017, which
  matters for a writing tool people keep an old machine for.
- The Swift concurrency runtime is present natively from macOS 12, so nothing
  needs back-deploying.
- Every SwiftUI API Paragraph uses for its panels is dependable on 13. Going
  older would mean working around SwiftUI rough edges; going newer would buy
  conveniences like `@Observable` in exchange for excluding machines.

Two consequences of that choice are visible in the source:

- The Workspace Browser is an `NSOutlineView` rather than a SwiftUI `List`,
  because Return-to-open and full keyboard navigation of a tree are not
  expressible in SwiftUI on this target. `NSOutlineView` gives them, plus the
  correct VoiceOver behaviour, for free.
- Observation uses `ObservableObject` and Combine rather than `@Observable`.

The project builds against the current macOS SDK and back-deploys. No
availability guards are needed anywhere in the source, which is the check that
the target was chosen honestly.

## Building

```bash
xcodebuild -project Paragraph.xcodeproj -scheme Paragraph -configuration Debug build
```

For a universal (Apple Silicon and Intel) release build:

```bash
xcodebuild -project Paragraph.xcodeproj -scheme Paragraph -configuration Release -destination 'generic/platform=macOS' ONLY_ACTIVE_ARCH=NO build
```

If `xcode-select` points at the Command Line Tools rather than Xcode, prefix
either command with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

The application is signed to run locally ("ad-hoc"), so it builds without a
developer account. It runs in the App Sandbox and reaches files only through
folders and documents you choose yourself.

## Testing

Pure logic — word counting, Writing Check, and file reading and writing — lives
in a local Swift package with no dependency on the application, so it can be
tested in under a second:

```bash
swift test --package-path ParagraphKit
```

Application behaviour — the shortcut map, the menus, theme contrast, the
document and editor, the workspace and session — is tested against the real
objects:

```bash
xcodebuild -project Paragraph.xcodeproj -scheme Paragraph -configuration Debug test
```

## Layout

```
Paragraph/
  App/          Application shell: entry point, delegate, menus, commands, settings
  Document/     NSDocument subclass; one document per file on disk
  Editor/       The manuscript editor: NSTextView on TextKit 1, layout, modes
  Window/       Windows, native tabs, document placement, session restoration
  Workspace/    The workspace folder, its browser, and file operations
  Theme/        The three themes and the type decisions
  UI/           SwiftUI panels: Quick Open, Writing Check, Shortcuts, Settings
  Resources/    Localised strings and the string catalogue
ParagraphKit/   Local Swift package: word count, Writing Check, file encoding
ParagraphTests/ Application tests
Config/         Info.plist and entitlements
Samples/        A small sample workspace to open
```

## Keyboard shortcuts

Every command is also in the menus; shortcuts are accelerators, not the only
way to work. Help ▸ Keyboard Shortcuts (`⌘/`) shows the current list, generated
from the same table the menu bar is built from.

| | |
|---|---|
| Open Workspace Folder… | `⌥⌘O` |
| Quick Open… | `⇧⌘O` |
| Show/Hide Workspace Browser | `⌥⌘S` |
| Move Focus to Workspace Browser | `⌘1` |
| Move Focus to Editor | `⌘2` |
| Open in Tab | `⌘↩` |
| Open in New Window | `⇧⌘↩` |
| Show Next / Previous Tab | `⌃⇥` / `⌃⇧⇥` |
| Reopen Closed Tab | `⇧⌘T` |
| Bigger / Smaller text | `⌘+` / `⌘-` |
| Actual Size | `⌘0` |
| Typewriter Mode | `⌃⌘T` |
| Focus Mode | `⌃⌘P` |
| Show/Hide Word Count | `⌃⌘W` |
| Run Writing Check | `⌃⌘R` |
| Show Writing Check Results | `⌃⌘Y` |
| Keyboard Shortcuts | `⌘/` |

New, Open, Save, Save As, Close, Print, Undo, Find, Full Screen and the rest
keep their standard macOS keys. `⌘P` is left to Print, which is why Quick Open
is `⇧⌘O`. Full Screen is not defined by Paragraph at all: AppKit adds its own
item with whatever key the running version of macOS uses.

## Typography

Prose is set in **IBM Plex Sans**, which ships inside the application bundle
and is registered at launch, so it looks the same on every machine. The size
is the one thing about the type a writer can change — `⌘+`, `⌘-` and `⌘0`,
clamped to a readable range and remembered between launches.

There is still no font picker and no colour picker. The measure is counted in
characters rather than points, so making the text bigger widens the column to
keep about 66 characters on a line rather than making lines shorter.

`⌘0` belongs to Actual Size in every Mac application that scales text, so the
panes take `⌘1` and `⌘2`.

## Word counting

Markdown markup is removed before counting, so headings, bullets, emphasis
markers, link destinations and code blocks contribute nothing; a link still
contributes its visible text. A word is a run of letters or digits, and an
apostrophe, hyphen, full stop or comma between two word characters does not
split one — so `don't`, `well-known`, `U.S.A.` and `1,000` each count as one.

## Writing Check

Writing Check is run deliberately, like a compiler, and reports in its own
window. It never leaves a mark in the manuscript and never applies a change.

It reports unmatched quotation marks, parentheses and square brackets as
errors, and consecutive duplicate words and closely repeated phrases as
warnings. It knows that `don't` and `the boys' coats` contain apostrophes
rather than quotes, and that fiction re-opens a quotation mark on each
paragraph of continued speech.

It says nothing about the quality of the writing, and it never will.

## Localisation

Every user-facing string is defined in `Paragraph/Resources/Localized.swift` and
translated through `Localizable.xcstrings`. Counts are pluralised through the
string catalogue rather than by string concatenation. Adding a language means
adding a translation to the catalogue and nothing else.

The interface language follows macOS. It is independent of the spell-checking
language, which comes from your macOS keyboard settings, and of any future
language-specific Writing Check rules.

## Licence

Paragraph itself has no licence yet — see [LICENCE-NOTICE.md](LICENCE-NOTICE.md).

The bundled typeface, **IBM Plex Sans**, is © IBM Corp. and licensed under the
SIL Open Font License 1.1. The licence text travels with the font, in
`Paragraph/Resources/Fonts/IBMPlexSans-OFL.txt` and inside the application
bundle. The application icon is a pilcrow set in the same typeface.
