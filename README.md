# Paragraph

Paragraph is a native macOS Markdown writing application focused on readability
and distraction-free drafting.

It is built for writing novels and notes. The guiding rule is that **if a
feature does not directly help the writer write or edit words, it does not
belong in Paragraph.**

![Paragraph in the Light theme](Documentation/screenshots/theme-light.png)

---

## What it does

- Opens ordinary `.md`, `.markdown` and `.txt` files, in place, without
  converting them to anything
- Shows a workspace folder — local, external, or in iCloud Drive — in a
  left-hand browser you never have to leave the application to use
- Opens files as native macOS tabs and in native windows
- Puts the manuscript in a centred, left-aligned writing column with a fixed,
  comfortable measure
- Sets prose in IBM Plex Sans, at a size you change with `⌘+` and `⌘-`
- Draws bold and italic as bold and italic, with the Markdown markers left in
  place — no preview, nothing hidden
- Uses the system's own spell checking, and shows no other analysis while you
  type
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

## Themes

Three, chosen and finished rather than configurable. Every colour is held to a
contrast floor by the test suite: body text at 7:1 or better, and the text
Focus Mode dims never below 3:1, so it stays readable rather than merely
present.

| Light | Dark | Green Screen |
|---|---|---|
| ![Light](Documentation/screenshots/theme-light.png) | ![Dark](Documentation/screenshots/theme-dark.png) | ![Green Screen](Documentation/screenshots/theme-green-screen.png) |

Green Screen is a dark room and green text, and nothing else: no scan lines, no
bloom, no curvature, no flicker. Those would be decoration, and decoration is
not writing.

## The workspace

A workspace is a folder and nothing more. Choose one and its Markdown and text
files appear in the browser on the left, where you can navigate them entirely
from the keyboard: `⌘1` moves focus there, arrow keys walk the tree, `↩` opens,
and `Esc` hands focus back to the manuscript.

There is no index, no database, no metadata and no tags. Delete Paragraph and
you are left with exactly the folder you started with. It watches the folder,
so files added, renamed or removed by Finder, another editor or iCloud Drive
appear without a refresh.

Choosing a different folder closes the documents belonging to the old one, so
the browser and the editor never disagree about which workspace you are in.
Unsaved work is not closed on your behalf: each document is asked in the
standard way, and cancelling any of them abandons the switch rather than
leaving half a workspace open. Documents from outside the workspace — and any
untitled draft — are left alone.

## Markdown, shown but not hidden

Emphasis is drawn as emphasis — **bold** is bold, *italic* is italic — while the
markers stay exactly where you typed them, dimmed. This is not a preview and
not a hidden-Markdown editor: nothing moves, appears or disappears as the
cursor travels over it, and the source on screen is still the source on disk.

![Markdown styling](Documentation/screenshots/markdown-styling.png)

The scanner is deliberately cautious, because a wrongly bolded half-paragraph
is far more irritating than a missed italic. `some_file_name_here` stays
upright, `2 * 3 * 4` is arithmetic, `\*escaped\*` is literal, and nothing
inside a code span or fenced block is touched.

Styling is applied as text *attributes*, never as characters. Only the plain
string is written to disk, and only a change to the characters marks a document
edited — so this cannot alter a file and never enters the undo stack. The test
suite checks exactly that: style a document, then require the bytes it would
write to be identical.

Emphasis is matched within a line, so a `**phrase spanning
a soft line break**` is not styled.

## Typewriter Mode

Keeps the line you are writing near the middle of the window, so your eyes stay
in one place instead of drifting to the bottom of the screen. `⌃⌘T`.

![Typewriter Mode](Documentation/screenshots/typewriter-mode.png)

It opens up room above the first line and below the last so they can reach the
middle too, and it never fights a deliberate scroll: the view only moves when
the insertion point does.

## Focus Mode

Keeps the paragraph you are in fully readable and quietly de-emphasises the
rest. It never modifies the document — the dimming is drawn, not written — and
spelling squiggles survive underneath it.

![Focus Mode](Documentation/screenshots/focus-mode.png)

## Quick Open

`⇧⌘O` finds files in the workspace and nothing else. It is not a command
palette, and it never looks outside the folder you chose.

![Quick Open](Documentation/screenshots/quick-open.png)

## Writing Check

`⌃⌘R` runs a small set of mechanical checks, deliberately, the way you run a
compiler. Results appear in their own window, nothing is changed for you, and
no squiggle is ever left behind in the manuscript.

![Writing Check](Documentation/screenshots/writing-check.png)

It reports unmatched quotation marks, parentheses and square brackets as
errors, and consecutive duplicate words and closely repeated phrases as
warnings. It knows that `don't` and `the boys' coats` contain apostrophes
rather than quotes, that `had had` is grammatical, and that fiction re-opens a
quotation mark on each paragraph of continued speech.

It says nothing about the quality of the writing, and it never will.

---

## Coming back

Quit with a workspace open and a few chapters in tabs, and that is what you
return to: the same windows at the same size, the same tabs in the same order,
the right one in front, the browser open with the folders you had expanded, and
each document roughly where you left the cursor.

Restoration never takes priority over your files. A document that has moved or
been deleted is named in a message offering to find it or drop it from the
session — nothing is ever recreated to fill the gap. It can be turned off
entirely in Settings, in which case every launch starts clean.

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
- Every SwiftUI API Paragraph uses for its panels is dependable on 13.

Two consequences are visible in the source: the Workspace Browser is an
`NSOutlineView` rather than a SwiftUI `List`, because Return-to-open and full
keyboard navigation of a tree are not expressible in SwiftUI on this target;
and observation uses `ObservableObject` and Combine rather than `@Observable`.

The project builds against the current macOS SDK and back-deploys. **No
availability guards are needed anywhere in the source**, which is the check
that the target was chosen honestly.

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

Currently 101 package tests and 79 application tests, with no compiler warnings.

## Layout

```
Paragraph/
  App/          Application shell: entry point, delegate, menus, commands, settings
  Document/     NSDocument subclass; one document per file on disk
  Editor/       The manuscript editor: NSTextView on TextKit 1, layout, modes
  Window/       Windows, native tabs, document placement, session restoration
  Workspace/    The workspace folder, its browser, and file operations
  Theme/        The three themes, typography, and the bundled font
  UI/           SwiftUI panels: Quick Open, Writing Check, Shortcuts, Settings
  Resources/    Localised strings, the string catalogue, the font, the icon
ParagraphKit/   Local Swift package: word count, Writing Check, file encoding
ParagraphTests/ Application tests
Config/         Info.plist and entitlements
Documentation/  Screenshots
Samples/        A small sample workspace to open
Tools/          Icon generation
```

`ARCHITECTURE.md` explains why the document, window and tab layers are AppKit
and what that buys.

---

## Opening files

Double-clicking a file in the browser opens it **in the tab you are already
looking at**, the way an editor does. The tab it replaces is closed only if it
holds nothing unsaved — a document with unsaved changes stays open and you
simply end up with an extra tab.

Opening an *additional* tab is deliberate: middle-click, `⌥↩`, or the
contextual menu. `⇧↩` opens a new window.

## Keyboard shortcuts

Every command is also in the menus; shortcuts are accelerators, not the only
way to work. Help ▸ Keyboard Shortcuts (`⌘/`) shows the current list, generated
from the same table the menu bar is built from — so the two cannot disagree.

| | |
|---|---|
| Open Workspace Folder… | `⌥⌘O` |
| Quick Open… | `⇧⌘O` |
| Show/Hide Workspace Browser | `⌥⌘S` |
| Move Focus to Workspace Browser | `⌘1` |
| Move Focus to Editor | `⌘2` |
| Open | `⌘↩` |
| Open in New Tab | `⌥⌘↩` |
| Open in New Window | `⇧⌘↩` |
| Show Next / Previous Tab | `⌃⇥` / `⌃⇧⇥` |
| Reopen Closed Tab | `⇧⌘T` |
| Bigger / Smaller text | `⌘+` / `⌘-` |
| Actual Size | `⌘0` |
| Typewriter Mode | `⌃⌘T` |
| Focus Mode | `⌃⌘P` |
| Show/Hide Word Count | `⌃⌘W` |
| Run Writing Check | `⌃⌘R` |
| Keyboard Shortcuts | `⌘/` |

New, Open, Save, Save As, Close, Print, Undo, Find and the rest keep their
standard macOS keys. `⌘P` is left to Print, which is why Quick Open is `⇧⌘O`.
`⌘0` belongs to Actual Size, which is why the panes are `⌘1` and `⌘2`. Full
Screen is not defined by Paragraph at all: AppKit adds its own item with
whatever key the running version of macOS uses.

## Typography

Prose is set in **IBM Plex Sans**, which ships inside the application bundle
and is registered at launch, so it looks the same on every machine. The size is
the one thing about the type you can change — `⌘+`, `⌘-` and `⌘0`, clamped to a
readable range and remembered between launches.

The measure is counted in characters rather than points, so making the text
bigger widens the column to keep about 66 characters on a line rather than
making lines shorter.

## Word counting

Markdown markup is removed before counting, so headings, bullets, emphasis
markers, link destinations and code blocks contribute nothing; a link still
contributes its visible text. A word is a run of letters or digits, and an
apostrophe, hyphen, full stop or comma between two word characters does not
split one — so `don't`, `well-known`, `U.S.A.` and `1,000` each count as one.

## Files and safety

Paragraph works directly on your files and does not convert them. Reading
records the text encoding, byte-order mark and line-ending style; writing
restores all three. A file that mixes line-ending conventions is left exactly
as found, because tidying it would be a change you did not ask for. A file that
is not valid UTF-8 is decoded only if that decode is lossless.

Opening a document can never write to it. The test suite checks these as round
trips: read a file, change nothing, write it back, and require the bytes to be
identical.

`NSDocumentController` guarantees one document per file, so the same file open
in two windows shares one text storage and one undo stack rather than becoming
two copies racing to overwrite each other.

## Localisation

Every user-facing string is defined in `Paragraph/Resources/Localized.swift`
and translated through `Localizable.xcstrings`. Counts are pluralised through
the string catalogue rather than by concatenation. Adding a language means
adding a translation and nothing else.

The interface language follows macOS. It is independent of the spell-checking
language, which comes from your macOS settings, and of any future
language-specific Writing Check rules.

## Status

Working and usable for real writing. Known gaps:

- **iCloud Drive workspaces work.** Opening a folder inside iCloud Drive,
  editing and saving a file there, and having the folder come back after a quit
  have all been exercised against a real iCloud folder.
- Native window tabbing means each tab is a window with its own browser;
  visibility is kept in step across a tab group so the group behaves like the
  single window it appears to be.
- Closing every window and then quitting brings those windows back next launch.
  Losing an arrangement of tabs would be the worse trade.
- Emphasis is matched within a line, so a phrase emphasised across a soft line
  break is not styled.

## Licence

Paragraph is released under the [MIT License](LICENSE).

The bundled typeface, **IBM Plex Sans**, is © IBM Corp. and licensed separately
under the SIL Open Font License 1.1. The licence text travels with the font, in
`Paragraph/Resources/Fonts/IBMPlexSans-OFL.txt` and inside the application
bundle. The application icon is a pilcrow set in the same typeface. See
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
