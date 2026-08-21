import AppKit

/// Closes a list of documents one at a time, asking about unsaved work.
///
/// `NSDocument.canClose(withDelegate:shouldClose:contextInfo:)` is the only way
/// to get the standard "Do you want to save…?" behaviour, and it is
/// asynchronous — so the documents have to be worked through in sequence rather
/// than in a loop, or the writer is handed a stack of sheets at once.
///
/// If the writer cancels any one of them, the whole operation reports failure
/// and the caller abandons what it was doing. Cancelling means "don't close
/// this", and honouring that halfway would leave things in exactly the
/// inconsistent state the operation was trying to avoid.
final class DocumentCloser: NSObject {

    private var remaining: [NSDocument]
    private let completion: (Bool) -> Void

    init(documents: [NSDocument], completion: @escaping (Bool) -> Void) {
        self.remaining = documents
        self.completion = completion
    }

    func start() {
        closeNext()
    }

    private func closeNext() {
        guard !remaining.isEmpty else {
            completion(true)
            return
        }
        let document = remaining.removeFirst()
        document.canClose(
            withDelegate: self,
            shouldClose: #selector(document(_:shouldClose:contextInfo:)),
            contextInfo: nil
        )
    }

    @objc private func document(
        _ document: NSDocument,
        shouldClose: Bool,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        guard shouldClose else {
            completion(false)
            return
        }
        document.close()
        closeNext()
    }
}
