import SwiftUI

struct MPTrashIcon: View {
    var disabled = false
    var body: some View {
        Canvas { context, _ in
            let ink = disabled ? Color(red: 116/255, green: 121/255, blue: 135/255) : Color(red: 217/255, green: 75/255, blue: 85/255)
            var line = Path()
            line.move(to: CGPoint(x: 3, y: 5)); line.addLine(to: CGPoint(x: 21, y: 5))
            line.move(to: CGPoint(x: 9, y: 5)); line.addLine(to: CGPoint(x: 9, y: 1)); line.addLine(to: CGPoint(x: 15, y: 1)); line.addLine(to: CGPoint(x: 15, y: 5))
            line.move(to: CGPoint(x: 6, y: 5)); line.addLine(to: CGPoint(x: 6, y: 21)); line.addQuadCurve(to: CGPoint(x: 8, y: 22), control: CGPoint(x: 6, y: 22)); line.addLine(to: CGPoint(x: 16, y: 22)); line.addQuadCurve(to: CGPoint(x: 18, y: 20), control: CGPoint(x: 18, y: 22)); line.addLine(to: CGPoint(x: 18, y: 5))
            for x in [10.0, 14.0] { line.move(to: CGPoint(x: x, y: 9)); line.addLine(to: CGPoint(x: x, y: 17)) }
            context.stroke(line, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            if disabled {
                var slash = Path(); slash.move(to: CGPoint(x: 3, y: 20)); slash.addLine(to: CGPoint(x: 21, y: 2))
                context.stroke(slash, with: .color(Color(red: 248/255, green: 249/255, blue: 252/255)), lineWidth: 4)
                context.stroke(slash, with: .color(ink), lineWidth: 2)
            }
        }.accessibilityHidden(true)
    }
}
