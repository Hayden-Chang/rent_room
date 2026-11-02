#if DEBUG
import SwiftUI

/// Counts one deliberate burst; time is monotonic and injectable for boundary tests.
struct DevelopmentCreditsTapSequence {
    private var startedAt: TimeInterval?
    private var count = 0

    mutating func tap(at now: TimeInterval) -> Bool {
        guard now.isFinite else { reset(); return false }
        if let start = startedAt, now < start || now - start > 5 { reset() }
        if startedAt == nil { startedAt = now }
        count += 1
        guard count == 10 else { return false }
        reset()
        return true
    }

    mutating func reset() { startedAt = nil; count = 0 }
}

/// Debug-only presentation. The owner must persist the grant before returning.
struct DevelopmentCreditsVersionRow: View {
    let version: String
    let grant: () throws -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var sequence = DevelopmentCreditsTapSequence()
    @State private var message = ""
    @State private var showingResult = false
    private var english: Bool { AppLanguage.shared.value == .english }

    var body: some View {
        HStack {
            Button(action: tapped) { AppText("版本").frame(minHeight: 50).contentShape(Rectangle()) }
                .buttonStyle(.plain).accessibilityIdentifier("settings.development-credits")
            Spacer()
            Text(verbatim: version).foregroundStyle(XJTheme.muted)
        }
        .font(.system(size: 14)).frame(minHeight: 50)
        .alert(english ? "Development credits" : "开发点数", isPresented: $showingResult) {
            Button(AppCopy.text("确定"), role: .cancel) {}
        } message: { Text(verbatim: message) }
        .onDisappear { sequence.reset() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { sequence.reset() } }
    }

    private func tapped() {
        guard !showingResult, sequence.tap(at: ProcessInfo.processInfo.systemUptime) else { return }
        do {
            try grant()
            message = english
                ? "Added 10 property credits for development testing on this device."
                : "已添加 10 个房源点数，仅用于本机开发测试。"
        } catch {
            message = english ? "Unable to add credits. Please try again." : "点数添加失败，请重试。"
        }
        showingResult = true
    }
}
#endif
