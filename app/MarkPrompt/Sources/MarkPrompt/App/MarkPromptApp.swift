import MarkPromptKit
import AppKit
import SwiftUI

@main
struct MarkPromptApp: App {
    @NSApplicationDelegateAdaptor(MarkPromptApplicationDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
        .defaultSize(width: 1120, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("打开 Markdown...") {
                    appState.openDocumentWithPanel()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandGroup(replacing: .saveItem) {
                Button("保存审稿会话") {
                    appState.saveReviewSessionNow()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(appState.currentDocument == nil)
            }

            CommandMenu("批注") {
                Button("添加批注") {
                    appState.beginAnnotationFromCurrentSelection()
                }
                .keyboardShortcut("A", modifiers: [.command, .shift])
                .disabled(!appState.canCreateAnnotation)
            }

            CommandMenu("Prompt") {
                Button("复制 Prompt") {
                    appState.copyPromptToPasteboard()
                }
                .keyboardShortcut("C", modifiers: [.command, .shift])
                .disabled(appState.promptPreview.prompt.isEmpty)

                Button("保存 .prompt.md") {
                    appState.savePromptToDisk()
                }
                .disabled(appState.promptPreview.prompt.isEmpty)
            }
        }
    }
}

final class MarkPromptApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
