import SwiftUI
import UIKit

enum SpeedConsentKind: Equatable, Sendable { case wifi, mobile }
struct SpeedConsentRequest: Identifiable {
    let id = UUID()
    let kind: SpeedConsentKind
}

// Completes after UIKit dismissal, so a second consent can be presented without
// racing the first alert's automatic dismissal. No arbitrary delay or window lookup.
struct SpeedNetworkConsent: UIViewControllerRepresentable {
    let request: SpeedConsentRequest?
    let answer: (UUID, Bool) -> Void

    func makeUIViewController(context: Context) -> ConsentController { ConsentController() }
    func updateUIViewController(_ controller: ConsentController, context: Context) {
        controller.update(request: request, answer: answer)
    }
    static func dismantleUIViewController(_ controller: ConsentController, coordinator: ()) { controller.cancel() }

    @MainActor final class ConsentController: UIViewController {
        private var desired: SpeedConsentRequest?
        private var current: UUID?
        private var answer: ((UUID, Bool) -> Void)?
        override func viewDidLoad() { super.viewDidLoad(); view.backgroundColor = .clear; view.isUserInteractionEnabled = false }
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); showIfReady() }
        func update(request: SpeedConsentRequest?, answer: @escaping (UUID, Bool) -> Void) {
            desired = request; self.answer = answer
            if request == nil, current != nil { cancel() } else { showIfReady() }
        }
        private func showIfReady() {
            guard isViewLoaded, view.window != nil, current == nil, presentedViewController == nil, let request = desired else { return }
            current = request.id
            let mobile = request.kind == .mobile
            let alert = UIAlertController(title: AppCopy.text(mobile ? "使用当前网络测速？" : "是否已连接 WiFi"),
                                          message: mobile ? AppCopy.text("本次最多下载约 64 MiB 数据，可能消耗移动流量。建议连接房源 Wi-Fi 后测试。") : nil, preferredStyle: .alert)
            func action(_ title: String, style: UIAlertAction.Style, accepted: Bool) -> UIAlertAction {
                UIAlertAction(title: AppCopy.text(title), style: style) { [weak self, weak alert] _ in
                    guard let self else { return }
                    let finish: () -> Void = { [weak self] in self?.finish(request.id, accepted: accepted) }
                    if let alert { alert.dismiss(animated: true, completion: finish) } else { finish() }
                }
            }
            alert.addAction(action(mobile ? "暂不测试" : "否", style: .cancel, accepted: false))
            alert.addAction(action(mobile ? "开始测速" : "是", style: .default, accepted: true))
            present(alert, animated: true)
        }
        private func finish(_ id: UUID, accepted: Bool) {
            guard current == id else { return }
            current = nil
            let callback = answer
            desired = nil
            callback?(id, accepted)
        }
        func cancel() {
            guard let id = current else { desired = nil; answer = nil; return }
            // Cancelled presenters cannot start a measurement after disappearing.
            current = nil; desired = nil
            let callback = answer; answer = nil
            presentedViewController?.dismiss(animated: false)
            callback?(id, false)
        }
    }
}
