# Architecture

Short notes on the decisions that shaped Paragraph V1, and the ones deliberately
left open.

## The central choice: AppKit document architecture, SwiftUI where it earns its place

Paragraph is an `NSDocument` application with SwiftUI used for its panels and
chrome, and an `NSTextView` for the manuscript.

That is not a preference for AppKit. It follows from the requirements that carry
the most risk:

- **One file must never become two conflicting documents.**
  `NSDocumentController` guarantees at most one `NSDocument` per URL. Opening a
  file that is already open produces another *view* of the same document.
- **Tabs must reorder by dragging, move to a new window, and restore.**
  macOS window tabbing gives all of it. Each tab is genuinely a window, grouped
  by `tabbingIdentifier`.
- **Files must be written safely.** `NSDocument` provides coordinated reads,
  safe-save through a temporary file, autosave in place, Versions, Revert,
  Duplicate, Rename and Move To.
- **External changes must not be silently overwritten.** `NSDocument` is an
  `NSFilePresenter`; Paragraph adds a clean-reload path and a conflict banner.

SwiftUI's `DocumentGroup` cannot deliver these. SwiftUI is used where it is
genuinely better: Settings, Quick Open, Writing Check, the Keyboard Shortcuts
reference, the word-count bar and the file banners.

| Layer | Framework | Why |
|---|---|---|
| Documents, windows, tabs, restoration | AppKit | The guarantees above |
| Manuscript editor | AppKit + TextKit 1 | Shared storage, temporary attributes |
| Workspace Browser | AppKit (`NSOutlineView`) | Tree keyboard navigation and VoiceOver |
| Panels, settings, chrome | SwiftUI | Less code, no behaviour lost |
| Word count, Writing Check, file encoding | Pure Swift package | Fast, independent tests |

## Why TextKit 1

Two requirements decide it:

1. **The same document in two windows.** Several `NSLayoutManager`s attach to one
   `NSTextStorage`. Each view gets its own cursor and scroll position; the text
   and undo stack are shared. This is what TextKit 1 was designed for.
2. **Focus Mode must not modify the document.**
   `NSLayoutManager.setTemporaryAttributes` dims surrounding paragraphs without
   touching a character, and spelling squiggles — themselves temporary
   attributes — survive underneath.

The stack is built explicitly (`NSLayoutManager` → `NSTextContainer` →
`NSTextView(frame:textContainer:)`), which is the documented way to opt into
TextKit 1 rather than the TextKit 2 default.

## Document identity and file access

- One `MarkdownDocument` per URL, enforced by `NSDocumentController`.
- Text lives in one `NSTextStorage` per document.
- Reading records the encoding, byte-order mark and line-ending style; writing
  restores all three. A file using one line-ending convention is normalised to
  `\n` for editing and written back in its own style. A file that *mixes*
  conventions is left exactly as found, because tidying it would be a change the
  writer did not ask for.
- A file that is not valid UTF-8 falls back to the system's guess only if that
  guess is lossless, and to Latin-1 otherwise, which maps all 256 byte values and
  therefore always round-trips.
- Opening never marks a document edited, so it can never cause a write. Applying
  a theme does not either: colours are display attributes, and only
  `textStorage.string` is ever written.
- The workspace folder is reached through a security-scoped bookmark, which is
  what lets a sandboxed Paragraph reopen an iCloud Drive folder without asking
  again. Nothing outside the chosen folder and the explicitly opened files is
  ever enumerated.

## External changes

`presentedItemDidChange` compares modification dates. If the document is clean,
it reloads and restores the cursor. If it has unsaved edits, it raises a banner
offering Reload from Disk or Keep My Version, and `NSDocument`'s own safety check
still stands between the writer and an overwrite.

## Session restoration

Paragraph restores its own session from JSON in Application Support and switches
off AppKit's parallel window restoration (`window.isRestorable = false`), so the
two cannot fight. Windows are captured per tab group; each tab records a
security-scoped bookmark, the cursor location and the scroll position as a
fraction. Theme and the mode toggles live in `UserDefaults`, so they survive even
when session restoration is switched off.

A file that has moved or been deleted is named in an alert offering Locate… or
Remove from Session. Nothing is ever recreated.

## Keeping the door open for reference tiles

No tile infrastructure exists. What has been kept separate so it could be added
later without replacing the document layer:

- **Document identity** lives in `MarkdownDocument`, keyed by URL.
- **View state** lives in `EditorViewController` — selection, scroll, modes —
  and a document already supports several of them.
- **Window state** lives in `DocumentWindowController` and the tab group.

A future fixed reference tile would be one more `EditorViewController` on an
existing document, placed beside the main editor and not participating in the
tab group. Nothing in the current design assumes one editor per window; the
two-windows-one-document tests already exercise the multi-view path.

## Word counting and Writing Check

Both read a shared `ProseDocument`, which segments Markdown into prose runs once
and keeps `String.Index` ranges into the original text, so a Writing Check result
can be selected in the editor without re-deriving offsets. Rules are a small
protocol with no registration, discovery or plugin mechanism. Rules describe
findings structurally; the wording lives in the localisation catalogue.

Word count is recomputed on a 250 ms debounce, off the main thread. Focus Mode
touches only the visible character range. Neither does full-document work on
every keystroke.

## Known risks

- **Native tabs mean per-tab sidebars.** Each tab is a window with its own
  browser. Sidebar visibility is synchronised across a tab group so the group
  behaves like the single window a writer perceives, but the state is per-window
  underneath.
- **Session restoration pumps the run loop** while opening documents in order, to
  build tab groups correctly. It is bounded by the number of restored tabs.
- **The workspace scan is eager**, capped at 5,000 items and 12 levels. A folder
  larger than that is truncated rather than crawled.
- **`FSEvents` needs sandbox access to the folder**, which the security-scoped
  bookmark provides. A workspace that becomes unreachable stops updating until
  reopened.
