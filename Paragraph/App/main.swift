import AppKit

// Paragraph builds its menus and windows in code rather than from a nib, so the
// entry point is explicit: create the delegate, then hand control to AppKit.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
