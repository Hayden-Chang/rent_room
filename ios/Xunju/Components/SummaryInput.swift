import SwiftUI

struct SummaryInput: View {
    @Binding var decision: String
    @Binding var note: String
    var readonly = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("意向").font(.system(size: 14)).frame(height: 20).padding(.top, 8)
            HStack(spacing: 0) {
                ForEach(["考虑租住", "继续比较", "放弃"], id: \.self) { value in
                    Button { decision = decision == value ? "" : value } label: {
                        Text(value == "放弃" ? "放弃这套" : value)
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
            Text("备注").font(.system(size: 14)).frame(height: 20).padding(.top, 12)
            ZStack(alignment: .topLeading) {
                if note.isEmpty { Text("记录下你对这套房源的整体感受…").foregroundStyle(XJTheme.muted).padding(.top, 8).padding(.leading, 5) }
                TextEditor(text: $note).scrollContentBackground(.hidden).frame(height: 168)
                    .disabled(readonly).accessibilityIdentifier("summary.note")
            }.font(.system(size: 14)).lineSpacing(5).padding(16).frame(height: 200).background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(XJTheme.line))
        }.foregroundStyle(XJTheme.ink)
    }
}
