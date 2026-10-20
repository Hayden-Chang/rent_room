import SwiftUI
import UIKit

struct MeasurementAction {
    enum Kind: Equatable { case commute, speed }
    let kind: Kind
    let perform: () -> Void
}

/// Free text, numeric, date and longer choices retain the original field contract.
/// The caller owns persistence and choice rules; this view never changes a record.
struct AnswerInput: View {
    let field: JSONValue
    @Binding var text: String
    @Binding var otherText: String
    var readonly = false
    var showsKeyboardToolbar = true
    var choose: (String) -> Void
    var action: (String) -> Void
    var measurement: MeasurementAction? = nil
    @State private var actionsOpen = false
    @State private var datePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(field["label"].string + (field["multiple"].bool ? " · 多选" : ""))
                    .font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading)
                if actionsOpen && !readonly {
                    HStack(spacing: 0) {
                        tray("标记问题", icon: field["problem"].bool ? "swipe-issue-active" : "swipe-issue", color: XJTheme.dangerBackground)
                        tray("备注", icon: "swipe-note", color: XJTheme.soft)
                        tray("拍摄", icon: "swipe-camera", color: XJTheme.primary)
                    }
                } else if field["heading"].string.isEmpty && field["options"].array.isEmpty && field["type"].string != "d" {
                    if let measurement {
                        HStack(spacing: 6) {
                            input.frame(width: measurement.kind == .speed ? 68 : 72)
                            if measurement.kind == .speed { Text("Mbps").font(.system(size: 12)).fixedSize(horizontal: true, vertical: false).foregroundStyle(XJTheme.muted) }
                            Button(measurement.kind == .speed ? "测试" : "查询", action: measurement.perform)
                                .font(.system(size: 13)).foregroundStyle(XJTheme.primary).frame(width: 48, height: 44)
                                .background(XJTheme.soft).clipShape(RoundedRectangle(cornerRadius: 6)).disabled(readonly)
                                .accessibilityLabel((measurement.kind == .speed ? "测试" : "查询") + field["label"].string)
                                .accessibilityIdentifier("measurement.\(field.id)")
                        }
                    } else {
                    input
                        .frame(maxWidth: field["type"].string == "n" ? 96 : .infinity)
                    }
                }
            }.frame(minHeight: 44).contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { gesture in
                    guard !readonly, abs(gesture.translation.width) > abs(gesture.translation.height) else { return }
                    withAnimation(.easeOut(duration: 0.18)) { actionsOpen = gesture.translation.width < 0 }
                })
                .onLongPressGesture { if !readonly { actionsOpen = true } }
            if !field["options"].array.isEmpty {
                ChoiceFlow(spacing: 8) {
                    ForEach(field["options"].array, id: \.self) { choice in
                        Button { choose(choice["value"].string) } label: {
                            Text(choice["label"].string).font(.system(size: 13)).padding(.horizontal, 14)
                                .frame(minHeight: 44).foregroundStyle(choice["selected"].bool ? XJTheme.primary : XJTheme.ink)
                                .background(choice["selected"].bool ? XJTheme.soft : XJTheme.background)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }.buttonStyle(.plain).disabled(readonly)
                            .accessibilityIdentifier("input.\(field.id).choice.\(choice["value"].string)")
                            .accessibilityAddTraits(choice["selected"].bool ? .isSelected : [])
                    }
                }
            } else if field["type"].string == "d" {
                Button(text.isEmpty ? "选择日期" : text) { datePicker = true }
                    .font(.system(size: 13)).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 12).overlay(RoundedRectangle(cornerRadius: 8).stroke(XJTheme.line))
                    .disabled(readonly)
            }
            if field["other"].bool {
                TextField("请填写其他内容", text: $otherText).font(.system(size: 13))
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(XJTheme.line))
                    .disabled(readonly).accessibilityIdentifier("input.\(field.id).other")
            }
            if !field["note"].string.isEmpty {
                Button { action("备注") } label: {
                    Text(field["note"].string).font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                        .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
            }
            Rectangle().fill(XJTheme.line).frame(height: 1)
        }.padding(.vertical, 4).foregroundStyle(XJTheme.ink)
            .accessibilityElement(children: .contain).accessibilityIdentifier("input.\(field.id)")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if showsKeyboardToolbar {
                    Spacer()
                    Button("完成") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    }
                }
            }
            .sheet(isPresented: $datePicker) {
                DateInputSheet(value: $text)
                    .presentationDetents([.medium])
            }
    }

    private var input: some View {
        TextField(measurement.map { $0.kind == .speed ? "网速" : "分钟" } ?? (field["type"].string == "n" ? "填写数值" : "填写信息"), text: $text)
            .font(.system(size: 13)).keyboardType(field["type"].string == "n" ? .decimalPad : .default)
            .multilineTextAlignment(field["type"].string == "n" ? .trailing : .leading)
            .padding(.horizontal, 12).frame(minHeight: 44)
            .background(.white).overlay(RoundedRectangle(cornerRadius: 8).stroke(XJTheme.line))
            .disabled(readonly).accessibilityIdentifier("input.\(field.id).value")
    }
    private func tray(_ label: String, icon: String, color: Color) -> some View {
        Button { actionsOpen = false; action(label) } label: {
            XJIcon(name: icon).frame(width: 44, height: 44).background(color)
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}

struct ChoiceFlow: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width ?? 360, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrangement(width: bounds.width, subviews: subviews)
        for (index, view) in subviews.enumerated() {
            view.place(at: CGPoint(x: bounds.minX + layout.points[index].x, y: bounds.minY + layout.points[index].y),
                       proposal: ProposedViewSize(width: min(view.sizeThatFits(.unspecified).width, bounds.width), height: nil))
        }
    }
    private func arrangement(width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var points: [CGPoint] = [], x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0 && x + size.width > width { x = 0; y += lineHeight + spacing; lineHeight = 0 }
            points.append(CGPoint(x: x, y: y))
            x += min(size.width, width) + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return (CGSize(width: width, height: y + lineHeight), points)
    }
}

private struct DateInputSheet: View {
    @Binding var value: String
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    private static let format: DateFormatter = {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian); formatter.dateFormat = "yyyy-MM-dd"; return formatter
    }()
    var body: some View {
        NavigationStack {
            DatePicker("选择日期", selection: $date, displayedComponents: .date).datePickerStyle(.wheel).labelsHidden()
                .padding().onAppear { date = Self.format.date(from: value) ?? Date() }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("确定") { value = Self.format.string(from: date); dismiss() } }
                }
        }
    }
}
