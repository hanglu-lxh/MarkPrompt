import MarkPromptKit
import AppKit
import SwiftUI

@main
struct MarkPromptApp: App {
    @NSApplicationDelegateAdaptor(MarkPromptApplicationDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @State private var didOpenLaunchDocument = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .onAppear {
                    guard !didOpenLaunchDocument else {
                        return
                    }

                    didOpenLaunchDocument = true
                    if let launchDocumentURL = Self.launchDocumentURL() {
                        appState.openDocument(at: launchDocumentURL)
                    } else {
                        appState.openLastDocumentIfAvailable()
                    }
                    appState.refreshClipboardMarkdownCandidate()
                }
        }
        .defaultSize(width: 1120, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("打开 Markdown...") {
                    appState.openDocumentWithPanel()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("打开剪切板 Markdown") {
                    appState.openMarkdownFromPasteboard()
                }
                .disabled(appState.clipboardMarkdownCandidate == nil)

                if appState.recentDocumentURLs.isEmpty == false {
                    Divider()

                    Menu("打开历史") {
                        ForEach(appState.recentDocumentURLs, id: \.path) { url in
                            Button(url.lastPathComponent) {
                                appState.openDocument(at: url)
                            }
                        }
                    }

                    Divider()

                    Button("清除打开历史") {
                        appState.clearRecentDocuments()
                    }
                }
            }

            CommandGroup(replacing: .undoRedo) {
                Button("撤销") {
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: [.command])

                Button("重做") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }
                .keyboardShortcut("Z", modifiers: [.command, .shift])
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

    private static func launchDocumentURL() -> URL? {
        let arguments = CommandLine.arguments
        guard let openFlagIndex = arguments.firstIndex(of: "--open"),
              arguments.indices.contains(openFlagIndex + 1)
        else {
            return nil
        }

        return URL(fileURLWithPath: arguments[openFlagIndex + 1])
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
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}
