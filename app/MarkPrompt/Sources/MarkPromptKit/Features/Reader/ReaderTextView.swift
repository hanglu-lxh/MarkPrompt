import AppKit

public final class ReaderTextView: NSTextView {
    public override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    public override var acceptsFirstResponder: Bool {
        true
    }

    private func configure() {
        isEditable = false
        isSelectable = true
        isRichText = true
        drawsBackground = true
        backgroundColor = .textBackgroundColor
        textContainerInset = NSSize(width: 36, height: 28)
        textContainer?.lineFragmentPadding = 0
        allowsUndo = false
        usesFindBar = true
        isAutomaticLinkDetectionEnabled = false
    }
}
