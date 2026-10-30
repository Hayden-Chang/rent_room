import SwiftUI

struct SummaryInput: View {
    @Binding var decision: String
    @Binding var note: String
    var readonly = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppText("意向").font(.system(size: 14)).frame(height: 20).padding(.top, 8)
            HStack(spacing: 0) {
                ForEach(["考虑租住", "继续比较", "放弃"], id: \.self) { value in
                    Button { decision = decision == value ? "" : value } label: {
                        AppText(value == "放弃" ? "放弃这套" : value)
                            .font(.system(size: 13, weight: decision == value ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(decision == value ? .white : XJTheme.muted)
                            .background(decision == value ? XJTheme.primary : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).disabled(readonly).accessibilityIdentifier("summary.\(value)")
                        .accessibilityAddTraits(decision == value ? .isSelected : [])
                }
            }.padding(4).background(.white).clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(XJTheme.line))
            AppText("备注").font(.system(size: 14)).frame(height: 20).padding(.top, 12)
            ZStack(alignment: .topLeading) {
                if note.isEmpty { AppText("记录下你对这套房源的整体感受…").foregroundStyle(Color(white: 0.5)).frame(height: 22) }
                SummaryNoteTextView(text: $note, readonly: readonly).frame(height: 168)
            }.font(.system(size: 14)).lineSpacing(5).padding(16).frame(height: 200).background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(XJTheme.line))
        }.foregroundStyle(XJTheme.ink)
    }
}

// Match textarea padding/line height without UITextView's implicit 8pt/5pt inset.
private struct SummaryNoteTextView: UIViewRepresentable {
    @Binding var text: String
    let readonly: Bool
    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 22; paragraph.maximumLineHeight = 22
        view.typingAttributes = [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor(XJTheme.ink), .paragraphStyle: paragraph]
        view.accessibilityIdentifier = "summary.note"
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.text = $text
        if view.text != text {
            view.attributedText = NSAttributedString(string: text, attributes: view.typingAttributes)
        }
        view.isEditable = !readonly
    }
    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func textViewDidChange(_ textView: UITextView) { text.wrappedValue = textView.text }
    }
}
