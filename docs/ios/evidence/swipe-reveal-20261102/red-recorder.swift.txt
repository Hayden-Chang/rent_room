#if DEBUG
import SwiftUI
import UIKit

// Opt-in observation of rendered pixels only; never drives the gesture or row.
// The row's red action background reveals progressively from 0 to 44 points.
struct TeachingRevealRecorder: UIViewRepresentable {
    func makeUIView(context: Context) -> SamplesView { SamplesView() }
    func updateUIView(_ view: SamplesView, context: Context) {}
    static func dismantleUIView(_ view: SamplesView, coordinator: ()) { view.stop() }

    final class SamplesView: UIView {
        private var link: CADisplayLink?
        private var samples: [[String: Any]] = []
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = true
            accessibilityIdentifier = "teaching.motion"
            accessibilityLabel = "Rendered swipe samples"
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override var accessibilityValue: String? {
            get {
                guard let data = try? JSONSerialization.data(withJSONObject: samples) else { return "[]" }
                return String(data: data, encoding: .utf8)
            }
            set {}
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            stop()
            guard window != nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(sample))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 20, preferred: 20)
            link.add(to: .main, forMode: .common)
            self.link = link
        }
        func stop() { link?.invalidate(); link = nil }
        @objc private func sample() {
            guard let window, bounds.width > 0, bounds.height >= 10 else { return }
            let rect = convert(bounds, to: window)
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
            let image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { context in
                context.cgContext.translateBy(x: -rect.minX, y: -rect.minY)
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
            }
            guard let cg = image.cgImage else { return }
            let width = cg.width, height = cg.height
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            guard let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            let y = 6
            let revealed = (0..<width).filter { x in
                let i = (y * width + x) * 4
                return bytes[i] >= 252 && abs(Int(bytes[i + 1]) - 240) <= 3 && abs(Int(bytes[i + 2]) - 239) <= 3
            }.count
            // Keep distinct rendered states, bounded in size for XCTest export.
            guard samples.count < 40, samples.last?["width"] as? Int != revealed,
                  let png = image.pngData() else { return }
            samples.append(["width": revealed, "time": CACurrentMediaTime(), "png": png.base64EncodedString()])
        }
    }
}
#endif
