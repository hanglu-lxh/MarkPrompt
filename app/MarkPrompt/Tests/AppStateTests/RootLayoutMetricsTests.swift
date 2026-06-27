import CoreGraphics
@testable import MarkPromptKit
import XCTest

final class RootLayoutMetricsTests: XCTestCase {
    func testInspectorWidthDragDirectionAndBounds() {
        XCTAssertEqual(
            RootLayoutMetrics.inspectorWidth(startingWidth: 360, dragTranslationX: -80),
            440,
            accuracy: 0.01
        )
        XCTAssertEqual(
            RootLayoutMetrics.inspectorWidth(startingWidth: 360, dragTranslationX: 120),
            RootLayoutMetrics.minimumInspectorWidth,
            accuracy: 0.01
        )
        XCTAssertEqual(
            RootLayoutMetrics.clampedInspectorWidth(900),
            RootLayoutMetrics.maximumInspectorWidth,
            accuracy: 0.01
        )
    }

    func testInspectorResizeFeedbackReportsBoundaryStates() {
        XCTAssertEqual(
            RootLayoutMetrics.inspectorResizeBoundary(for: RootLayoutMetrics.minimumInspectorWidth),
            .minimum
        )
        XCTAssertEqual(
            RootLayoutMetrics.inspectorResizeBoundary(for: RootLayoutMetrics.maximumInspectorWidth),
            .maximum
        )
        XCTAssertNil(RootLayoutMetrics.inspectorResizeBoundary(for: RootLayoutMetrics.defaultInspectorWidth))
    }

    func testInspectorLiveWidthUsesDragValueWithoutChangingStoredWidthUntilCommit() {
        let storedWidth: CGFloat = 360
        let liveWidth = RootLayoutMetrics.inspectorLiveWidth(
            storedWidth: storedWidth,
            dragStartWidth: storedWidth,
            dragTranslationX: -120
        )

        XCTAssertEqual(liveWidth, 480, accuracy: 0.01)
        XCTAssertEqual(storedWidth, 360, accuracy: 0.01)
        XCTAssertEqual(
            RootLayoutMetrics.committedInspectorWidth(afterLiveDragWidth: liveWidth),
            480,
            accuracy: 0.01
        )
    }

    func testInspectorResizeHandlePresentationExpandsHitTargetAndHoverFeedback() {
        let idle = InspectorResizeHandlePresentation.presentation(
            width: RootLayoutMetrics.defaultInspectorWidth,
            isHovering: false,
            isDragging: false
        )

        XCTAssertEqual(idle.hitTargetWidth, 14, accuracy: 0.01)
        XCTAssertEqual(idle.indicatorWidth, 1, accuracy: 0.01)
        XCTAssertEqual(idle.backgroundOpacity, 0, accuracy: 0.001)
        XCTAssertEqual(idle.help, "拖动调整批注与 Prompt 宽度")
        XCTAssertEqual(idle.accessibilityValue, "360 点")
        XCTAssertEqual(idle.accessibilityHint, "拖动可调整右侧批注与 Prompt 面板宽度")

        let hovering = InspectorResizeHandlePresentation.presentation(
            width: RootLayoutMetrics.defaultInspectorWidth,
            isHovering: true,
            isDragging: false
        )

        XCTAssertEqual(hovering.hitTargetWidth, 14, accuracy: 0.01)
        XCTAssertEqual(hovering.indicatorWidth, 2, accuracy: 0.01)
        XCTAssertEqual(hovering.backgroundOpacity, 0.06, accuracy: 0.001)
        XCTAssertEqual(hovering.help, "拖动调整批注与 Prompt 宽度")
    }

    func testInspectorResizeHandlePresentationExplainsActiveDrag() {
        let presentation = InspectorResizeHandlePresentation.presentation(
            width: 480,
            isHovering: true,
            isDragging: true
        )

        XCTAssertEqual(presentation.indicatorWidth, 3, accuracy: 0.01)
        XCTAssertEqual(presentation.backgroundOpacity, 0.10, accuracy: 0.001)
        XCTAssertEqual(presentation.help, "拖动中，松开后应用 480 点宽度")
        XCTAssertEqual(presentation.accessibilityValue, "480 点")
        XCTAssertEqual(presentation.accessibilityHint, "松开鼠标应用当前宽度")
    }

    func testInspectorResizeHandlePresentationIncludesBoundaryWidthInAccessibleValue() {
        let minimum = InspectorResizeHandlePresentation.presentation(
            width: RootLayoutMetrics.minimumInspectorWidth,
            isHovering: false,
            isDragging: false
        )
        XCTAssertEqual(minimum.indicatorWidth, 2, accuracy: 0.01)
        XCTAssertEqual(minimum.help, "批注与 Prompt 宽度已到最小值")
        XCTAssertEqual(minimum.accessibilityValue, "最小宽度 \(Int(RootLayoutMetrics.minimumInspectorWidth)) 点")

        let maximum = InspectorResizeHandlePresentation.presentation(
            width: RootLayoutMetrics.maximumInspectorWidth,
            isHovering: false,
            isDragging: false
        )
        XCTAssertEqual(maximum.indicatorWidth, 2, accuracy: 0.01)
        XCTAssertEqual(maximum.help, "批注与 Prompt 宽度已到最大值")
        XCTAssertEqual(maximum.accessibilityValue, "最大宽度 \(Int(RootLayoutMetrics.maximumInspectorWidth)) 点")
    }

    func testToolbarSearchPresentationAvoidsDisabledTextFieldAmbiguity() {
        XCTAssertEqual(
            ToolbarSearchPresentation.presentation(hasOpenDocument: false),
            ToolbarSearchPresentation(
                title: "查找",
                systemImage: "magnifyingglass",
                isEnabled: false,
                help: "打开 Markdown 后可在阅读区查找",
                accessibilityLabel: "查找",
                accessibilityHint: "打开 Markdown 后可在阅读区查找",
                keyboardShortcutHint: nil
            )
        )
        XCTAssertEqual(
            ToolbarSearchPresentation.presentation(hasOpenDocument: true),
            ToolbarSearchPresentation(
                title: "查找",
                systemImage: "magnifyingglass",
                isEnabled: true,
                help: "在阅读区查找（⌘F）",
                accessibilityLabel: "查找文档内容",
                accessibilityHint: "按 ⌘F 在阅读区查找",
                keyboardShortcutHint: "⌘F"
            )
        )
    }

    func testToolbarOpenPresentationExplainsPrimaryAndMenuActions() {
        XCTAssertEqual(
            ToolbarOpenPresentation.presentation(),
            ToolbarOpenPresentation(
                title: "打开",
                systemImage: "folder",
                help: "打开 Markdown（⌘O）",
                accessibilityLabel: "打开 Markdown",
                accessibilityHint: "按 ⌘O 选择 Markdown 文件",
                actionTitle: "打开 Markdown...",
                actionHelp: "选择 Markdown 文件开始阅读（⌘O）",
                actionAccessibilityLabel: "打开 Markdown 文件",
                actionAccessibilityHint: "按 Return 选择 Markdown 文件"
            )
        )
    }

    func testToolbarDocumentTitlePresentationKeepsFullPathAvailable() {
        let url = URL(fileURLWithPath: "/Users/example/Documents/Specs/very-long-product-plan.md")

        XCTAssertEqual(
            ToolbarDocumentTitlePresentation.presentation(displayName: nil, fileURL: nil),
            ToolbarDocumentTitlePresentation(
                title: "MarkPrompt",
                help: "未打开文档",
                accessibilityLabel: "MarkPrompt"
            )
        )
        XCTAssertEqual(
            ToolbarDocumentTitlePresentation.presentation(displayName: "very-long-product-plan.md", fileURL: url),
            ToolbarDocumentTitlePresentation(
                title: "very-long-product-plan.md",
                help: url.path,
                accessibilityLabel: "当前文档：very-long-product-plan.md"
            )
        )
    }

    func testDropTargetPresentationOnlyAppearsWhileDraggingSupportedFiles() {
        XCTAssertNil(DropTargetPresentation.presentation(isTargeted: false))
        XCTAssertEqual(
            DropTargetPresentation.presentation(isTargeted: true),
            DropTargetPresentation(
                title: "松开以打开 Markdown",
                message: "支持 .md/.markdown；多个文件会打开第一个可读取 Markdown",
                systemImage: "arrow.down.doc",
                accessibilityLabel: "松开以打开 Markdown，支持 .md/.markdown；多个文件会打开第一个可读取 Markdown",
                accessibilityHint: "松开鼠标后打开第一个可读取 Markdown 文件"
            )
        )
    }

    func testDropTargetPresentationSurfacesImportFailuresAfterDropEnds() {
        XCTAssertEqual(
            DropTargetPresentation.presentation(
                isTargeted: false,
                saveState: .failed("请拖入 .md 或 .markdown 文件。")
            ),
            DropTargetPresentation(
                title: "未打开文件",
                message: "请拖入 .md 或 .markdown 文件。",
                systemImage: "exclamationmark.triangle",
                isFailure: true,
                showsDropBoundary: false,
                dismissTitle: "关闭",
                dismissHelp: "关闭这条导入提示",
                dismissShortcutHint: "Esc",
                dismissAccessibilityLabel: "关闭导入提示",
                dismissAccessibilityHint: "按 Esc 关闭当前导入提示；不会重试打开文件",
                copyTitle: "复制错误详情",
                copyHelp: "复制完整错误详情；不会关闭提示",
                copyValue: "请拖入 .md 或 .markdown 文件。",
                copyAccessibilityLabel: "复制导入失败详情",
                copyAccessibilityHint: "按 Return 复制完整错误详情；提示会保持显示",
                messageLineLimit: 3,
                messageHelp: "请拖入 .md 或 .markdown 文件。",
                accessibilityLabel: "未打开文件，请拖入 .md 或 .markdown 文件。",
                accessibilityHint: "导入失败提示，可复制完整错误详情，按 Esc 关闭"
            )
        )
        XCTAssertEqual(
            DropTargetPresentation.presentation(
                isTargeted: false,
                saveState: .failed("拖拽导入失败：无法读取文件 URL"),
                hasOpenDocument: true
            ),
            DropTargetPresentation(
                title: "导入未完成",
                message: "拖拽导入失败：无法读取文件 URL。当前文档仍保持打开。",
                systemImage: "exclamationmark.triangle",
                isFailure: true,
                showsDropBoundary: false,
                dismissTitle: "关闭",
                dismissHelp: "关闭这条导入提示",
                dismissShortcutHint: "Esc",
                dismissAccessibilityLabel: "关闭导入提示",
                dismissAccessibilityHint: "按 Esc 关闭当前导入提示；不会重试打开文件",
                copyTitle: "复制错误详情",
                copyHelp: "复制完整错误详情；不会关闭提示",
                copyValue: "拖拽导入失败：无法读取文件 URL。当前文档仍保持打开。",
                copyAccessibilityLabel: "复制导入失败详情",
                copyAccessibilityHint: "按 Return 复制完整错误详情；提示会保持显示",
                messageLineLimit: 3,
                messageHelp: "拖拽导入失败：无法读取文件 URL。当前文档仍保持打开。",
                accessibilityLabel: "导入未完成，拖拽导入失败：无法读取文件 URL。当前文档仍保持打开。",
                accessibilityHint: "导入失败提示，当前文档仍保持打开；可复制完整错误详情，按 Esc 关闭"
            )
        )
        XCTAssertEqual(
            DropTargetPresentation.presentation(
                isTargeted: true,
                saveState: .failed("拖拽导入失败：无法读取文件 URL")
            ),
            DropTargetPresentation(
                title: "松开以打开 Markdown",
                message: "支持 .md/.markdown；多个文件会打开第一个可读取 Markdown",
                systemImage: "arrow.down.doc",
                isFailure: false,
                showsDropBoundary: true,
                dismissTitle: nil,
                dismissHelp: nil,
                dismissAccessibilityLabel: nil,
                dismissAccessibilityHint: nil,
                accessibilityLabel: "松开以打开 Markdown，支持 .md/.markdown；多个文件会打开第一个可读取 Markdown",
                accessibilityHint: "松开鼠标后打开第一个可读取 Markdown 文件"
            )
        )
        XCTAssertNil(
            DropTargetPresentation.presentation(
                isTargeted: false,
                saveState: .failed("Prompt 保存失败")
            )
        )
    }

    func testDropTargetPresentationShowsLoadingWhileDropIsOpening() {
        XCTAssertEqual(
            DropTargetPresentation.presentation(isTargeted: false, saveState: .loading),
            DropTargetPresentation(
                title: "正在打开 Markdown",
                message: "正在读取拖入的文件",
                systemImage: "clock",
                isFailure: false,
                showsDropBoundary: false,
                showsProgress: true,
                dismissTitle: nil,
                dismissHelp: nil,
                dismissAccessibilityLabel: nil,
                dismissAccessibilityHint: nil,
                accessibilityLabel: "正在打开 Markdown，正在读取拖入的文件",
                accessibilityHint: "文件正在打开，请稍候"
            )
        )
    }

    func testDropTargetCopyButtonPresentationShowsCopiedFeedback() {
        XCTAssertEqual(
            DropTargetCopyButtonPresentation.presentation(
                title: "复制错误详情",
                help: "复制完整错误详情；不会关闭提示",
                isCopied: false
            ),
            DropTargetCopyButtonPresentation(
                title: "复制错误详情",
                systemImage: "doc.on.doc",
                help: "复制完整错误详情；不会关闭提示",
                accessibilityLabel: "复制错误详情",
                accessibilityHint: "按 Return 复制完整错误详情；提示会保持显示"
            )
        )
        XCTAssertEqual(
            DropTargetCopyButtonPresentation.presentation(
                title: "复制错误详情",
                help: "复制完整错误详情；不会关闭提示",
                isCopied: true
            ),
            DropTargetCopyButtonPresentation(
                title: "已复制",
                systemImage: "checkmark.circle",
                help: "已复制错误详情",
                accessibilityLabel: "已复制错误详情",
                accessibilityHint: "错误详情已复制到剪切板，可继续复制；按钮会短暂恢复"
            )
        )
    }

    func testDropTargetDismissButtonPresentationClarifiesEscDismissal() {
        XCTAssertEqual(
            DropTargetDismissButtonPresentation.presentation(
                title: "关闭",
                help: "关闭这条导入提示",
                shortcutHint: "Esc"
            ),
            DropTargetDismissButtonPresentation(
                title: "关闭",
                help: "关闭这条导入提示（Esc）",
                accessibilityLabel: "关闭导入提示",
                accessibilityHint: "按 Esc 关闭当前导入提示；不会重试打开文件"
            )
        )
    }

    func testOutlineEmptyStatePresentationClarifiesMissingNavigation() {
        let closedDocument = OutlineEmptyStatePresentation.presentation(hasOpenDocument: false)
        XCTAssertEqual(closedDocument.title, "未打开文档")
        XCTAssertEqual(closedDocument.message, "打开 Markdown 后显示大纲")
        XCTAssertEqual(closedDocument.systemImage, "doc.text")
        XCTAssertEqual(closedDocument.help, "打开 Markdown 后可通过大纲跳转标题；可按 ⌘O 打开文档")
        XCTAssertEqual(mirroredStringField("accessibilityLabel", in: closedDocument), "大纲未打开文档")
        XCTAssertEqual(
            mirroredStringField("accessibilityHint", in: closedDocument),
            "按 ⌘O 打开 Markdown；打开后会显示标题层级"
        )

        let emptyDocument = OutlineEmptyStatePresentation.presentation(hasOpenDocument: true)
        XCTAssertEqual(emptyDocument.title, "当前文档没有标题")
        XCTAssertEqual(emptyDocument.message, "添加 Markdown 标题后会显示层级导航")
        XCTAssertEqual(emptyDocument.systemImage, "text.justify.left")
        XCTAssertEqual(emptyDocument.help, "当前文档没有可跳转标题；添加 # 或 ## 标题后会显示在这里")
        XCTAssertEqual(mirroredStringField("accessibilityLabel", in: emptyDocument), "大纲暂无标题")
        XCTAssertEqual(
            mirroredStringField("accessibilityHint", in: emptyDocument),
            "在 Markdown 中添加 # 或 ## 标题后可通过大纲跳转"
        )
    }

    func testOutlineRowPresentationDistinguishesHoverActiveAndSelectedStates() {
        let topLevel = OutlineRowPresentation.presentation(
            title: "产品说明",
            depth: 0,
            isHovered: false,
            isActive: false,
            isSelected: false
        )
        XCTAssertEqual(topLevel.emphasis, .normal)
        XCTAssertEqual(topLevel.textWeight, .semibold)
        XCTAssertFalse(topLevel.showsAccentIndicator)
        XCTAssertEqual(topLevel.help, "跳转到一级标题：产品说明")
        XCTAssertEqual(topLevel.accessibilityLabel, "一级标题：产品说明")
        XCTAssertEqual(
            mirroredStringField("accessibilityHint", in: topLevel),
            "按 Return 跳转到产品说明；阅读区会滚动到该章节"
        )

        let hovered = OutlineRowPresentation.presentation(
            title: "交互细节",
            depth: 1,
            isHovered: true,
            isActive: false,
            isSelected: false
        )
        XCTAssertEqual(hovered.emphasis, .hover)
        XCTAssertEqual(hovered.textWeight, .regular)
        XCTAssertFalse(hovered.showsAccentIndicator)
        XCTAssertEqual(hovered.help, "跳转到二级标题：交互细节")
        XCTAssertEqual(hovered.accessibilityLabel, "二级标题：交互细节")
        XCTAssertEqual(
            mirroredStringField("accessibilityHint", in: hovered),
            "按 Return 跳转到交互细节；阅读区会滚动到该章节"
        )

        let active = OutlineRowPresentation.presentation(
            title: "交互细节",
            depth: 1,
            isHovered: false,
            isActive: true,
            isSelected: false
        )
        XCTAssertEqual(active.emphasis, .active)
        XCTAssertEqual(active.help, "当前阅读标题：交互细节")
        XCTAssertEqual(active.accessibilityLabel, "当前阅读的二级标题：交互细节")
        XCTAssertEqual(
            mirroredStringField("accessibilityHint", in: active),
            "当前阅读区已在交互细节；按 Return 可重新定位到该章节"
        )

        let selected = OutlineRowPresentation.presentation(
            title: "交互细节",
            depth: 1,
            isHovered: true,
            isActive: true,
            isSelected: true
        )
        XCTAssertEqual(selected.emphasis, .selected)
        XCTAssertEqual(selected.textWeight, .semibold)
        XCTAssertTrue(selected.showsAccentIndicator)
        XCTAssertEqual(selected.help, "正在跳转到标题：交互细节")
        XCTAssertEqual(selected.accessibilityLabel, "已选择二级标题：交互细节")
        XCTAssertEqual(
            mirroredStringField("accessibilityHint", in: selected),
            "阅读区正在滚动到交互细节；再次按 Return 可重新定位"
        )
    }

    func testCollapsedOutlineRailPresentationShowsCurrentHeadingAndCount() {
        let currentID = UUID()
        let outline = [
            DocumentHeading(
                id: UUID(),
                level: 1,
                title: "产品说明",
                sourceRange: SourceTextRange(lowerBound: 0, upperBound: 8),
                children: [
                    DocumentHeading(
                        id: currentID,
                        level: 2,
                        title: "交互细节",
                        sourceRange: SourceTextRange(lowerBound: 9, upperBound: 18)
                    )
                ]
            )
        ]

        XCTAssertEqual(
            CollapsedOutlineRailPresentation.presentation(
                outline: outline,
                currentHeadingID: currentID
            ),
            CollapsedOutlineRailPresentation(
                headingCountText: "2",
                currentHeadingTitle: "交互细节",
                help: "展开大纲；当前章节：交互细节；共 2 个标题",
                accessibilityLabel: "大纲已折叠，当前章节：交互细节，共 2 个标题",
                accessibilityHint: "按 Return 展开大纲；展开后可继续从当前章节交互细节导航"
            )
        )
    }

    func testPromptActionPresentationMakesEmptyCopyActionFeedbackReachable() {
        XCTAssertEqual(
            PromptActionButtonPresentation.copy(hasPrompt: false, saveState: .idle),
            PromptActionButtonPresentation(
                title: "复制 Prompt",
                systemImage: "doc.on.doc",
                isEnabled: true,
                help: "没有可复制内容时会提示先添加并勾选批注；不会修改剪切板",
                accessibilityLabel: "复制 Prompt",
                accessibilityHint: "按 Return 显示需要先添加并勾选批注的提示；不会修改剪切板",
                lineLimit: 1,
                minimumScaleFactor: 0.82
            )
        )
        XCTAssertEqual(
            PromptActionButtonPresentation.save(hasPrompt: false, saveState: .idle),
            PromptActionButtonPresentation(
                title: "保存 .prompt.md",
                systemImage: "doc.badge.plus",
                isEnabled: false,
                help: "添加并勾选批注生成 Prompt 后可保存",
                accessibilityLabel: "保存 Prompt 文件",
                accessibilityHint: "添加并勾选批注生成 Prompt 后可保存；当前不可用",
                lineLimit: 1,
                minimumScaleFactor: 0.82
            )
        )
    }

    func testPromptActionPresentationExplainsEnabledActionsAndTransientFeedback() {
        XCTAssertEqual(
            PromptActionButtonPresentation.copy(hasPrompt: true, saveState: .idle),
            PromptActionButtonPresentation(
                title: "复制 Prompt",
                systemImage: "doc.on.doc",
                isEnabled: true,
                help: "复制当前 Prompt",
                accessibilityLabel: "复制 Prompt",
                accessibilityHint: "按 Return 复制当前 Prompt；会先同步批注，复制后短暂显示已复制",
                lineLimit: 1,
                minimumScaleFactor: 0.82
            )
        )
        XCTAssertEqual(
            PromptActionButtonPresentation.save(hasPrompt: true, saveState: .idle),
            PromptActionButtonPresentation(
                title: "保存 .prompt.md",
                systemImage: "doc.badge.plus",
                isEnabled: true,
                help: "保存当前 Prompt",
                accessibilityLabel: "保存 Prompt 文件",
                accessibilityHint: "按 Return 保存当前 Prompt 到 .prompt.md 文件；会先同步批注，保存后短暂显示已保存",
                lineLimit: 1,
                minimumScaleFactor: 0.82
            )
        )
    }

    func testPromptActionPresentationReflectsRecentSuccessFeedback() {
        XCTAssertEqual(
            PromptActionButtonPresentation.copy(hasPrompt: true, saveState: .copied),
            PromptActionButtonPresentation(
                title: "已复制",
                systemImage: "checkmark.circle",
                isEnabled: true,
                help: "Prompt 已复制",
                accessibilityLabel: "Prompt 已复制",
                accessibilityHint: "可继续复制当前 Prompt；按钮会短暂恢复",
                lineLimit: 1,
                minimumScaleFactor: 0.82
            )
        )
        XCTAssertEqual(
            PromptActionButtonPresentation.save(hasPrompt: true, saveState: .promptSaved("/tmp/sample.prompt.md")),
            PromptActionButtonPresentation(
                title: "已保存",
                systemImage: "checkmark.circle",
                isEnabled: true,
                help: "Prompt 已保存",
                accessibilityLabel: "Prompt 已保存",
                accessibilityHint: "可继续保存当前 Prompt；按钮会短暂恢复",
                lineLimit: 1,
                minimumScaleFactor: 0.82
            )
        )
    }

    func testClipboardMarkdownBannerPresentationKeepsPathAndActionHelpAvailable() {
        let url = URL(fileURLWithPath: "/Users/example/Documents/Specs/very-long-copied-plan.md")
        XCTAssertEqual(
            ClipboardMarkdownBannerPresentation.presentation(candidate: ClipboardMarkdownCandidate(url: url)),
            ClipboardMarkdownBannerPresentation(
                title: "剪切板中有 Markdown 文件：very-long-copied-plan.md",
                help: url.path,
                openHelp: "打开剪切板中的 Markdown 文件",
                dismissHelp: "忽略这次剪切板文件提示",
                accessibilityLabel: "剪切板中有 Markdown 文件：very-long-copied-plan.md",
                accessibilityHint: "可打开剪切板中的 Markdown 文件，或忽略这次提示",
                openAccessibilityLabel: "打开剪切板中的 Markdown 文件",
                openAccessibilityHint: "按 Return 打开 very-long-copied-plan.md",
                dismissAccessibilityLabel: "忽略剪切板 Markdown 提示",
                dismissAccessibilityHint: "按 Return 忽略这次提示；文件不会被修改"
            )
        )
    }

    func testRecentHistoryPresentationReflectsAvailabilityAndCount() {
        XCTAssertEqual(
            RecentHistoryPresentation.presentation(recentDocumentCount: 0),
            RecentHistoryPresentation(
                title: "历史",
                systemImage: "clock.arrow.circlepath",
                help: "暂无打开历史，可打开 Markdown 后出现在这里",
                accessibilityLabel: "打开历史，暂无记录",
                accessibilityHint: "暂无记录，按 Return 打开菜单；菜单焦点会停在打开 Markdown 动作",
                emptyMessage: "暂无打开历史",
                emptyActionTitle: "打开 Markdown...",
                emptyActionHelp: "选择 Markdown 文件开始阅读；成功打开后会加入历史（Return）",
                emptyActionShortcutHint: "Return",
                emptyActionAccessibilityLabel: "打开 Markdown 文件",
                emptyActionAccessibilityHint: "按 Return 选择 Markdown 文件；成功打开后会加入历史"
            )
        )
        XCTAssertEqual(
            RecentHistoryPresentation.presentation(recentDocumentCount: 3, unavailableDocumentCount: 2),
            RecentHistoryPresentation(
                title: "历史",
                systemImage: "clock.arrow.circlepath",
                help: "打开历史菜单，共 3 项；2 项失效可清理",
                accessibilityLabel: "打开历史，3 项",
                accessibilityHint: "按 Return 打开历史菜单；菜单焦点会停在最近打开项；可清理 2 项失效记录",
                emptyMessage: nil,
                emptyActionTitle: nil,
                emptyActionHelp: nil,
                cleanupTitle: "清理 2 个失效项",
                cleanupHelp: "从打开历史移除 2 个不存在或不是 Markdown 的文件记录",
                cleanupAccessibilityLabel: "清理 2 个失效历史项",
                cleanupAccessibilityHint: "按 Return 从打开历史移除 2 个失效记录并更新菜单；不会删除磁盘文件"
            )
        )
        XCTAssertEqual(
            RecentHistoryPresentation.presentation(
                recentDocumentCount: 1,
                unavailableDocumentCount: 0,
                saveState: .historyCleaned(2)
            ),
            RecentHistoryPresentation(
                title: "已清理",
                systemImage: "checkmark.circle",
                help: "已从打开历史移除 2 个失效项；打开历史菜单，共 1 项",
                accessibilityLabel: "打开历史，已清理 2 个失效项，1 项",
                accessibilityHint: "清理完成，仍可继续打开历史菜单；菜单焦点会停在最近打开项"
            )
        )
        XCTAssertEqual(
            RecentHistoryPresentation.presentation(
                recentDocumentCount: 0,
                saveState: .historyCleared(3)
            ),
            RecentHistoryPresentation(
                title: "已清除",
                systemImage: "checkmark.circle",
                help: "已清除 3 项打开历史；暂无打开历史，可打开 Markdown 后出现在这里",
                accessibilityLabel: "打开历史，已清除 3 项，暂无记录",
                accessibilityHint: "清除完成，按 Return 打开菜单；菜单焦点会停在打开 Markdown 动作",
                emptyMessage: "暂无打开历史",
                emptyActionTitle: "打开 Markdown...",
                emptyActionHelp: "选择 Markdown 文件开始阅读；成功打开后会加入历史（Return）",
                emptyActionShortcutHint: "Return",
                emptyActionAccessibilityLabel: "打开 Markdown 文件",
                emptyActionAccessibilityHint: "按 Return 选择 Markdown 文件；成功打开后会加入历史"
            )
        )
    }

    func testRecentHistoryItemPresentationLabelsMissingFiles() {
        let existingURL = URL(fileURLWithPath: "/Users/example/Documents/spec.md")
        XCTAssertEqual(
            RecentHistoryItemPresentation.presentation(url: existingURL, fileExists: true),
            RecentHistoryItemPresentation(
                title: "spec.md",
                systemImage: "doc.text",
                help: existingURL.path,
                accessibilityLabel: "打开历史文件：spec.md",
                accessibilityHint: "按 Return 打开 spec.md；打开后菜单会关闭；完整路径可在提示中查看"
            )
        )

        let unsupportedURL = URL(fileURLWithPath: "/Users/example/Documents/notes.txt")
        XCTAssertEqual(
            RecentHistoryItemPresentation.presentation(
                url: unsupportedURL,
                fileExists: true,
                isSupportedMarkdown: false
            ),
            RecentHistoryItemPresentation(
                title: "不支持：notes.txt",
                systemImage: "exclamationmark.triangle",
                help: "不是 Markdown 文件，选择后会从历史移除：\(unsupportedURL.path)",
                accessibilityLabel: "不支持的历史文件：notes.txt",
                accessibilityHint: "按 Return 从打开历史移除该记录并更新菜单；不会删除磁盘文件"
            )
        )

        let missingURL = URL(fileURLWithPath: "/Users/example/Documents/missing.md")
        XCTAssertEqual(
            RecentHistoryItemPresentation.presentation(url: missingURL, fileExists: false),
            RecentHistoryItemPresentation(
                title: "失效：missing.md",
                systemImage: "exclamationmark.triangle",
                help: "文件不存在，选择后会从历史移除：\(missingURL.path)",
                accessibilityLabel: "失效的历史文件：missing.md",
                accessibilityHint: "按 Return 从打开历史移除该记录并更新菜单；不会删除磁盘文件"
            )
        )
    }

    func testRecentHistoryItemPresentationDisambiguatesDuplicateFilenames() {
        let firstURL = URL(fileURLWithPath: "/Users/example/ProductA/README.md")
        XCTAssertEqual(
            RecentHistoryItemPresentation.presentation(
                url: firstURL,
                fileExists: true,
                duplicateFilenameCount: 2
            ),
            RecentHistoryItemPresentation(
                title: "README.md — ProductA",
                systemImage: "doc.text",
                help: firstURL.path,
                accessibilityLabel: "打开历史文件：README.md，位于 ProductA",
                accessibilityHint: "按 Return 打开 ProductA 中的 README.md；打开后菜单会关闭；完整路径可在提示中查看"
            )
        )

        let missingURL = URL(fileURLWithPath: "/Users/example/ProductB/README.md")
        XCTAssertEqual(
            RecentHistoryItemPresentation.presentation(
                url: missingURL,
                fileExists: false,
                duplicateFilenameCount: 2
            ),
            RecentHistoryItemPresentation(
                title: "失效：README.md — ProductB",
                systemImage: "exclamationmark.triangle",
                help: "文件不存在，选择后会从历史移除：\(missingURL.path)",
                accessibilityLabel: "失效的历史文件：README.md，位于 ProductB",
                accessibilityHint: "按 Return 从打开历史移除 ProductB 中的 README.md 并更新菜单；不会删除磁盘文件"
            )
        )
    }

    func testRecentHistoryClearPresentationExplainsActionImpact() {
        XCTAssertEqual(
            RecentHistoryClearPresentation.presentation(recentDocumentCount: 0),
            RecentHistoryClearPresentation(
                title: "清除打开历史",
                help: "暂无可清除的打开历史",
                isEnabled: false,
                isDestructive: false,
                accessibilityLabel: "清除打开历史",
                accessibilityHint: "暂无可清除的打开历史；打开 Markdown 后会出现在这里，清除动作会启用"
            )
        )
        XCTAssertEqual(
            RecentHistoryClearPresentation.presentation(recentDocumentCount: 3),
            RecentHistoryClearPresentation(
                title: "清除打开历史",
                help: "清除 3 项历史记录，仅影响列表；菜单会更新，不会删除磁盘文件",
                isEnabled: true,
                isDestructive: true,
                accessibilityLabel: "清除 3 项打开历史",
                accessibilityHint: "按 Return 清除 3 项历史记录并更新菜单；不会删除磁盘文件"
            )
        )
    }

    private func mirroredStringField(_ fieldName: String, in value: Any?) -> String? {
        guard let value else {
            return nil
        }

        let mirror = Mirror(reflecting: value)
        return mirror.children.first { $0.label == fieldName }?.value as? String
    }
}
