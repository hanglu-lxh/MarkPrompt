import AppKit

public enum ReaderCursorKind: Equatable, Sendable {
    case iBeam
    case crosshair
    case pointingHand
    case arrow
}

public enum ReaderAnnotationCursorState: Equatable, Sendable {
    case textSelection
    case annotationReady
    case annotationEditing
    case existingAnnotation

    public static func state(
        canCreateAnnotation: Bool,
        isAnnotationPopoverPresented: Bool,
        hasExistingAnnotationSelection: Bool
    ) -> ReaderAnnotationCursorState {
        if isAnnotationPopoverPresented {
            return .annotationEditing
        }
        if hasExistingAnnotationSelection {
            return .existingAnnotation
        }
        if canCreateAnnotation {
            return .annotationReady
        }
        return .textSelection
    }

    public var cursorKind: ReaderCursorKind {
        switch self {
        case .textSelection:
            return .iBeam
        case .annotationReady:
            return .crosshair
        case .annotationEditing:
            return .arrow
        case .existingAnnotation:
            return .pointingHand
        }
    }
}

public struct ReaderCursorRefreshDecision: Equatable, Sendable {
    public var invalidatesCursorRects: Bool
    public var immediateCursorKind: ReaderCursorKind?

    public init(
        invalidatesCursorRects: Bool,
        immediateCursorKind: ReaderCursorKind?
    ) {
        self.invalidatesCursorRects = invalidatesCursorRects
        self.immediateCursorKind = immediateCursorKind
    }

    public static func decision(
        from oldState: ReaderAnnotationCursorState,
        to newState: ReaderAnnotationCursorState,
        isPointerInsideReader: Bool,
        isPointerOverTaskMarker: Bool
    ) -> ReaderCursorRefreshDecision {
        guard oldState != newState else {
            return ReaderCursorRefreshDecision(
                invalidatesCursorRects: false,
                immediateCursorKind: nil
            )
        }

        guard isPointerInsideReader else {
            return ReaderCursorRefreshDecision(
                invalidatesCursorRects: true,
                immediateCursorKind: nil
            )
        }

        return ReaderCursorRefreshDecision(
            invalidatesCursorRects: true,
            immediateCursorKind: isPointerOverTaskMarker ? .pointingHand : newState.cursorKind
        )
    }
}

public final class ReaderTextView: NSTextView {
    public var onTaskMarkerClick: ((SourceTextRange) -> Bool)?
    public var onTaskMarkerStatusChange: ((SourceTextRange, String) -> Bool)?
    public var onTaskMarkerUndo: (() -> Bool)?
    public var annotationCursorState: ReaderAnnotationCursorState = .textSelection {
        didSet {
            refreshAnnotationCursor(from: oldValue, to: annotationCursorState)
        }
    }
    private var taskMarkerAccessibilityElements: [NSAccessibilityElement] = []

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

    public func taskMarkerSourceRange(atCharacterIndex characterIndex: Int) -> SourceTextRange? {
        let textLength = (string as NSString).length
        guard characterIndex >= 0,
              characterIndex < textLength,
              let sourceRange = textStorage?.attribute(
                .markPromptTaskMarkerSourceRange,
                at: characterIndex,
                effectiveRange: nil
              ) as? SourceTextRange
        else {
            return nil
        }

        return sourceRange
    }

    public func taskMarkerSourceRange(at point: NSPoint) -> SourceTextRange? {
        guard let layoutManager,
              let textContainer
        else {
            return nil
        }

        layoutManager.ensureLayout(for: textContainer)
        let containerPoint = NSPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )
        let characterIndex = layoutManager.characterIndex(
            for: containerPoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        guard let sourceRange = taskMarkerSourceRange(atCharacterIndex: characterIndex) else {
            return nil
        }
        guard let hitRect = taskMarkerHitRect(atCharacterIndex: characterIndex) else {
            return nil
        }

        return hitRect.contains(point) ? sourceRange : nil
    }

    public func taskMarkerHitRect(atCharacterIndex characterIndex: Int) -> NSRect? {
        guard taskMarkerSourceRange(atCharacterIndex: characterIndex) != nil,
              let layoutManager,
              let textContainer
        else {
            return nil
        }

        layoutManager.ensureLayout(for: textContainer)
        let characterRange = NSRange(location: characterIndex, length: 1)
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: characterRange,
            actualCharacterRange: nil
        )
        guard glyphRange.location != NSNotFound,
              glyphRange.length > 0
        else {
            return nil
        }

        var markerRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        markerRect.origin.x += textContainerOrigin.x
        markerRect.origin.y += textContainerOrigin.y
        return markerRect.insetBy(dx: -2, dy: -2)
    }

    public func taskMarkerHitRects() -> [NSRect] {
        guard let textStorage else {
            return []
        }

        var hitRects: [NSRect] = []
        textStorage.enumerateAttribute(
            .markPromptTaskMarkerSourceRange,
            in: NSRange(location: 0, length: textStorage.length)
        ) { value, range, _ in
            guard value is SourceTextRange,
                  range.location != NSNotFound,
                  let hitRect = taskMarkerHitRect(atCharacterIndex: range.location)
            else {
                return
            }

            hitRects.append(hitRect)
        }
        return hitRects
    }

    public func taskMarkerCharacterIndexes() -> [Int] {
        guard let textStorage else {
            return []
        }

        var indexes: [Int] = []
        textStorage.enumerateAttribute(
            .markPromptTaskMarkerSourceRange,
            in: NSRange(location: 0, length: textStorage.length)
        ) { value, range, _ in
            guard value is SourceTextRange,
                  range.location != NSNotFound
            else {
                return
            }

            indexes.append(range.location)
        }
        return indexes.sorted()
    }

    public override func accessibilityChildren() -> [Any]? {
        taskMarkerAccessibilityElements = taskMarkerAccessibilityChildren()
        let inheritedChildren = super.accessibilityChildren() ?? []
        return inheritedChildren + taskMarkerAccessibilityElements
    }

    public func taskMarkerCharacter(for sourceRange: SourceTextRange) -> String? {
        guard let textStorage else {
            return nil
        }

        var markerCharacter: String?
        textStorage.enumerateAttribute(
            .markPromptTaskMarkerSourceRange,
            in: NSRange(location: 0, length: textStorage.length)
        ) { value, range, stop in
            guard let candidateRange = value as? SourceTextRange,
                  candidateRange == sourceRange
            else {
                return
            }

            markerCharacter = textStorage.attribute(
                .markPromptTaskMarkerCharacter,
                at: range.location,
                effectiveRange: nil
            ) as? String
            stop.pointee = true
        }
        return markerCharacter
    }

    public func taskMarkerSourceRangeForKeyboardToggle() -> SourceTextRange? {
        let selectedRange = selectedRange()
        if selectedRange.length == 0 {
            return taskMarkerSourceRange(atCharacterIndex: selectedRange.location)
        }

        guard selectedRange.length == 1 else {
            return nil
        }

        return taskMarkerSourceRange(atCharacterIndex: selectedRange.location)
    }

    public func invalidateTaskMarkerCursorRects() {
        window?.invalidateCursorRects(for: self)
    }

    private func refreshAnnotationCursor(
        from oldState: ReaderAnnotationCursorState,
        to newState: ReaderAnnotationCursorState
    ) {
        let pointerLocation = currentPointerLocationInsideReader()
        let decision = ReaderCursorRefreshDecision.decision(
            from: oldState,
            to: newState,
            isPointerInsideReader: pointerLocation != nil,
            isPointerOverTaskMarker: pointerLocation.map { taskMarkerSourceRange(at: $0) != nil } ?? false
        )

        guard decision.invalidatesCursorRects else {
            return
        }

        invalidateTaskMarkerCursorRects()
        decision.immediateCursorKind?.nsCursor.set()
    }

    private func currentPointerLocationInsideReader() -> NSPoint? {
        guard let window else {
            return nil
        }

        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        return bounds.contains(point) ? point : nil
    }

    public override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: annotationCursorState.cursorKind.nsCursor)
        for hitRect in taskMarkerHitRects() {
            addCursorRect(hitRect, cursor: .pointingHand)
        }
    }

    public override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let sourceRange = taskMarkerSourceRange(at: point),
           onTaskMarkerClick?(sourceRange) == true {
            return
        }

        super.mouseDown(with: event)
    }

    public override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        return taskMarkerStatusMenu(at: point) ?? super.menu(for: event)
    }

    public func taskMarkerStatusMenu(at point: NSPoint) -> NSMenu? {
        guard let sourceRange = taskMarkerSourceRange(at: point) else {
            return nil
        }

        let currentMarkerCharacter = taskMarkerCharacter(for: sourceRange)
        let statuses = TaskMarkerStatusMenuAction.statuses(for: sourceRange)
        let currentStatusLabel = statuses
            .first { $0.matches(markerCharacter: currentMarkerCharacter) }?
            .statusLabel
        let menu = NSMenu(title: currentStatusLabel.map { "任务状态：\($0)" } ?? "任务状态")
        for status in statuses {
            let isCurrentStatus = status.matches(markerCharacter: currentMarkerCharacter)
            let itemTitle = isCurrentStatus ? status.currentTitle : status.title
            let item = NSMenuItem(title: itemTitle, action: #selector(changeTaskMarkerStatus(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = status
            item.setAccessibilityLabel(status.accessibilityMenuLabel)
            item.setAccessibilityHelp("只更改这一项任务；菜单关闭后阅读位置保持不变")
            if isCurrentStatus {
                item.state = .on
                item.isEnabled = false
                item.toolTip = "当前状态：\(status.statusLabel)。选择其它状态只更改这一项任务，阅读位置保持不变。"
            } else {
                item.toolTip = "将当前任务\(status.statusVerb)；只更改这一项任务，阅读位置保持不变"
            }
            menu.addItem(item)
        }
        return menu
    }

    @objc
    public func changeTaskMarkerStatus(_ sender: NSMenuItem) {
        guard let status = sender.representedObject as? TaskMarkerStatusMenuAction else {
            return
        }

        _ = onTaskMarkerStatusChange?(status.sourceRange, status.markerCharacter)
    }

    public override func keyDown(with event: NSEvent) {
        if isTaskMarkerSpaceToggleEvent(event),
           let sourceRange = taskMarkerSourceRangeForKeyboardToggle(),
           onTaskMarkerClick?(sourceRange) == true {
            return
        }

        super.keyDown(with: event)
    }

    @objc(toggleTaskMarkerStatus:)
    public func toggleTaskMarkerStatus(_ sender: Any?) {
        if let sourceRange = taskMarkerSourceRangeForKeyboardToggle(),
           onTaskMarkerClick?(sourceRange) == true {
            return
        }

        _ = nextResponder?.tryToPerform(#selector(toggleTaskMarkerStatus(_:)), with: sender)
    }

    @objc(selectNextTaskMarker:)
    public func selectNextTaskMarker(_ sender: Any?) {
        if selectTaskMarker(movingForward: true) {
            return
        }

        _ = nextResponder?.tryToPerform(#selector(selectNextTaskMarker(_:)), with: sender)
    }

    @objc(selectPreviousTaskMarker:)
    public func selectPreviousTaskMarker(_ sender: Any?) {
        if selectTaskMarker(movingForward: false) {
            return
        }

        _ = nextResponder?.tryToPerform(#selector(selectPreviousTaskMarker(_:)), with: sender)
    }

    public override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(toggleTaskMarkerStatus(_:)) {
            return taskMarkerSourceRangeForKeyboardToggle() != nil
        }
        if item.action == #selector(selectNextTaskMarker(_:))
            || item.action == #selector(selectPreviousTaskMarker(_:)) {
            return !taskMarkerCharacterIndexes().isEmpty
        }

        return super.validateUserInterfaceItem(item)
    }

    @discardableResult
    private func selectTaskMarker(movingForward: Bool) -> Bool {
        let indexes = taskMarkerCharacterIndexes()
        guard !indexes.isEmpty else {
            return false
        }

        let selectedRange = selectedRange()
        let isOnTaskMarker = selectedRange.length <= 1
            && taskMarkerSourceRange(atCharacterIndex: selectedRange.location) != nil
        let targetIndex: Int
        if movingForward {
            let lowerBound = isOnTaskMarker
                ? selectedRange.location + 1
                : selectedRange.location + selectedRange.length
            targetIndex = indexes.first { $0 >= lowerBound } ?? indexes[0]
        } else {
            let upperBound = selectedRange.location
            targetIndex = indexes.last { $0 < upperBound } ?? indexes[indexes.count - 1]
        }

        let targetRange = NSRange(location: targetIndex, length: 1)
        setSelectedRange(targetRange)
        scrollRangeToVisible(targetRange)
        return true
    }

    private func isTaskMarkerSpaceToggleEvent(_ event: NSEvent) -> Bool {
        guard event.charactersIgnoringModifiers == " " else {
            return false
        }

        let shortcutModifiers: NSEvent.ModifierFlags = [.command, .option, .control]
        return event.modifierFlags.intersection(shortcutModifiers).isEmpty
    }

    @objc(undo:)
    public func undo(_ sender: Any?) {
        if onTaskMarkerUndo?() == true {
            return
        }

        _ = nextResponder?.tryToPerform(#selector(undo(_:)), with: sender)
    }

    private func taskMarkerAccessibilityChildren() -> [NSAccessibilityElement] {
        guard let textStorage else {
            return []
        }

        var elements: [NSAccessibilityElement] = []
        textStorage.enumerateAttribute(
            .markPromptTaskMarkerSourceRange,
            in: NSRange(location: 0, length: textStorage.length)
        ) { value, range, _ in
            guard let sourceRange = value as? SourceTextRange,
                  range.location != NSNotFound,
                  let hitRect = taskMarkerHitRect(atCharacterIndex: range.location)
            else {
                return
            }

            let markerCharacter = textStorage.attribute(
                .markPromptTaskMarkerCharacter,
                at: range.location,
                effectiveRange: nil
            ) as? String
            let status = taskMarkerAccessibilityStatus(
                markerCharacter: markerCharacter,
                glyph: textStorage.attributedSubstring(from: NSRange(location: range.location, length: 1)).string
            )
            elements.append(TaskMarkerAccessibilityElement(
                textView: self,
                frameInParentSpace: hitRect,
                label: taskMarkerAccessibilityLabel(atCharacterIndex: range.location),
                status: status,
                statusActions: taskMarkerAccessibilityStatusActions(
                    for: sourceRange,
                    currentMarkerCharacter: markerCharacter
                ),
                performPress: { [weak self] in
                    self?.onTaskMarkerClick?(sourceRange) == true
                },
                performStatusChange: { [weak self] markerCharacter in
                    self?.onTaskMarkerStatusChange?(sourceRange, markerCharacter) == true
                }
            ))
        }
        return elements
    }

    private func taskMarkerAccessibilityLabel(atCharacterIndex characterIndex: Int) -> String {
        let nsString = string as NSString
        guard characterIndex >= 0,
              characterIndex < nsString.length
        else {
            return "任务"
        }

        let lineRange = nsString.lineRange(for: NSRange(location: characterIndex, length: 0))
        let taskTextStart = min(characterIndex + 1, NSMaxRange(lineRange))
        let taskTextRange = NSRange(
            location: taskTextStart,
            length: max(0, NSMaxRange(lineRange) - taskTextStart)
        )
        let taskText = nsString.substring(with: taskTextRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return taskText.isEmpty ? "任务" : "任务：\(taskText)"
    }

    private func taskMarkerAccessibilityStatus(
        markerCharacter: String?,
        glyph: String
    ) -> TaskMarkerAccessibilityStatus {
        switch markerCharacter?.lowercased() {
        case " ":
            return TaskMarkerAccessibilityStatus(label: "待办", isChecked: false)
        case "x":
            return TaskMarkerAccessibilityStatus(label: "完成", isChecked: true)
        case "-":
            return TaskMarkerAccessibilityStatus(label: "取消", isChecked: true)
        case "/":
            return TaskMarkerAccessibilityStatus(label: "进行中", isChecked: false)
        case "!":
            return TaskMarkerAccessibilityStatus(label: "重要", isChecked: false)
        case .some(let custom) where !custom.isEmpty:
            return TaskMarkerAccessibilityStatus(label: "完成", isChecked: true)
        default:
            if glyph == "☑" || glyph == "☒" {
                return TaskMarkerAccessibilityStatus(label: "完成", isChecked: true)
            }
            return TaskMarkerAccessibilityStatus(label: "待办", isChecked: false)
        }
    }

    private func taskMarkerAccessibilityStatusActions(
        for sourceRange: SourceTextRange,
        currentMarkerCharacter: String?
    ) -> [TaskMarkerAccessibilityStatusAction] {
        TaskMarkerStatusMenuAction.statuses(for: sourceRange)
            .filter { !$0.matches(markerCharacter: currentMarkerCharacter) }
            .map {
                TaskMarkerAccessibilityStatusAction(
                    title: $0.accessibilityActionTitle,
                    markerCharacter: $0.markerCharacter
                )
            }
    }
}

private extension ReaderCursorKind {
    var nsCursor: NSCursor {
        switch self {
        case .iBeam:
            return .iBeam
        case .crosshair:
            return .crosshair
        case .pointingHand:
            return .pointingHand
        case .arrow:
            return .arrow
        }
    }
}

private struct TaskMarkerAccessibilityStatus {
    let label: String
    let isChecked: Bool
}

private struct TaskMarkerAccessibilityStatusAction {
    let title: String
    let markerCharacter: String
}

private final class TaskMarkerAccessibilityElement: NSAccessibilityElement {
    private let performPressHandler: @MainActor () -> Bool
    private let performStatusChangeHandler: @MainActor (String) -> Bool

    init(
        textView: ReaderTextView,
        frameInParentSpace: NSRect,
        label: String,
        status: TaskMarkerAccessibilityStatus,
        statusActions: [TaskMarkerAccessibilityStatusAction],
        performPress: @escaping @MainActor () -> Bool,
        performStatusChange: @escaping @MainActor (String) -> Bool
    ) {
        self.performPressHandler = performPress
        self.performStatusChangeHandler = performStatusChange
        super.init()
        setAccessibilityRole(.checkBox)
        setAccessibilityParent(textView)
        setAccessibilityLabel(label)
        setAccessibilityValue(NSNumber(value: status.isChecked))
        setAccessibilityValueDescription(status.label)
        setAccessibilityHelp("状态：\(status.label)。按 Space 或 Return 切换完成/待办；右键或自定义动作可设为待办、完成、取消、进行中、重要；⌘⌥J/K 跳到上/下一个任务。")
        setAccessibilityFrameInParentSpace(frameInParentSpace)
        setAccessibilityCustomActions(statusActions.map { statusAction in
            NSAccessibilityCustomAction(name: statusAction.title) { [performStatusChangeHandler] in
                MainActor.assumeIsolated {
                    performStatusChangeHandler(statusAction.markerCharacter)
                }
            }
        })
    }

    override func accessibilityPerformPress() -> Bool {
        let performPressHandler = performPressHandler
        return MainActor.assumeIsolated {
            performPressHandler()
        }
    }
}

private final class TaskMarkerStatusMenuAction: NSObject {
    let title: String
    let markerCharacter: String
    let sourceRange: SourceTextRange

    init(title: String, markerCharacter: String, sourceRange: SourceTextRange) {
        self.title = title
        self.markerCharacter = markerCharacter
        self.sourceRange = sourceRange
    }

    var currentTitle: String {
        title.replacingOccurrences(of: "标记为", with: "当前：")
    }

    var accessibilityActionTitle: String {
        "仅当前任务：\(title)"
    }

    var accessibilityMenuLabel: String {
        title.replacingOccurrences(of: "标记为", with: "将当前任务标记为")
    }

    var statusLabel: String {
        title.replacingOccurrences(of: "标记为", with: "")
    }

    var statusVerb: String {
        title.replacingOccurrences(of: "标记为", with: "标记为")
    }

    static func statuses(for sourceRange: SourceTextRange) -> [TaskMarkerStatusMenuAction] {
        [
            TaskMarkerStatusMenuAction(title: "标记为待办", markerCharacter: " ", sourceRange: sourceRange),
            TaskMarkerStatusMenuAction(title: "标记为完成", markerCharacter: "x", sourceRange: sourceRange),
            TaskMarkerStatusMenuAction(title: "标记为取消", markerCharacter: "-", sourceRange: sourceRange),
            TaskMarkerStatusMenuAction(title: "标记为进行中", markerCharacter: "/", sourceRange: sourceRange),
            TaskMarkerStatusMenuAction(title: "标记为重要", markerCharacter: "!", sourceRange: sourceRange)
        ]
    }

    func matches(markerCharacter: String?) -> Bool {
        guard let markerCharacter,
              markerCharacter.isEmpty == false
        else {
            return false
        }

        let normalizedMarkerCharacter = markerCharacter.lowercased()
        if self.markerCharacter.lowercased() == normalizedMarkerCharacter {
            return true
        }

        let knownMarkerCharacters: Set<String> = [" ", "x", "-", "/", "!"]
        return self.markerCharacter == "x"
            && !knownMarkerCharacters.contains(normalizedMarkerCharacter)
    }
}
