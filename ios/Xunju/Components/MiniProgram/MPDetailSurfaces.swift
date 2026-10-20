import SwiftUI

// Keep each child mounted so scroll position, keyboard drafts and filters survive
// tab changes. Inactive children cannot receive taps or accessibility focus.
struct MPRetainedPage<Content: View>: View {
    let active: Bool
    @ViewBuilder var content: Content
    var body: some View {
        content.opacity(active ? 1 : 0).allowsHitTesting(active)
            .accessibilityElement(children: .contain).accessibilityHidden(!active).zIndex(active ? 1 : 0)
    }
}

struct MPDetailSurface<Checklist: View, Media: View, Issues: View, Summary: View>: View {
    @Binding var tab: String
    var readonly = false
    var mediaCount: Int, issueCount: Int
    @ViewBuilder var checklist: Checklist
    @ViewBuilder var media: Media
    @ViewBuilder var issues: Issues
    @ViewBuilder var summary: Summary
    var body: some View {
        VStack(spacing: 0) {
            if readonly {
                Text("房源已归档，当前为只读查看").font(.system(size: 12)).foregroundStyle(XJTheme.primary)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading).background(XJTheme.soft)
            }
            ZStack {
                MPRetainedPage(active: tab == "清单") { checklist }
                MPRetainedPage(active: tab == "影像") { media }
                MPRetainedPage(active: tab == "问题") { issues }
                MPRetainedPage(active: tab == "总结") { summary }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            MPTabBar(selection: $tab, detail: true, mediaCount: mediaCount, issueCount: issueCount)
        }
    }
}

struct MPIssuesSurface<Content: View>: View {
    let count: Int
    var readonly = false
    let add: () -> Void
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("需要关注 · \(count)").font(.system(size: 16, weight: .semibold))
                if count == 0 {
                    VStack(spacing: 12) {
                        Text("目前没有标记的问题").font(.system(size: 17, weight: .semibold))
                        Text("未检查的项目仍需继续查看。").font(.system(size: 13)).foregroundStyle(XJTheme.muted)
                    }.frame(maxWidth: .infinity).padding(.top, 40)
                }
                content
            }.padding(16).padding(.bottom, 80)
        }.overlay(alignment: .bottomTrailing) {
            if !readonly { MPFloatingButton(icon: "plus", label: "新建问题", action: add).padding(16).accessibilityIdentifier("mp.issue.add") }
        }
    }
}

struct MPComparisonRow: Identifiable {
    let id: String, label: String, values: [String]
    var different: Bool { Set(values).count > 1 }
}

struct MPComparisonResults: View {
    let names: [String], rows: [MPComparisonRow]
    @Binding var differences: Bool
    let back: () -> Void
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        HStack {
                            Text("隐藏相同属性").font(.system(size: 14, weight: .semibold))
                            Spacer()
                            MPSwitch(value: $differences, label: "隐藏相同属性").accessibilityIdentifier("mp.compare.differences")
                        }.padding(.horizontal, 12).frame(height: 48).background(.white).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.top, 8)
                        table(width: max(0, geometry.size.width - 32))
                        if rows.filter({ !differences || $0.different }).isEmpty {
                            Text("所选房源没有已显示的差异").font(.system(size: 14)).foregroundStyle(XJTheme.muted)
                        }
                    }.padding(16)
                }
                Button("返回选择房源", action: back).font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 52).foregroundStyle(.white).background(XJTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12)).buttonStyle(.plain)
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 22)
            }
        }
    }
    private func table(width: CGFloat) -> some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                cell("属性", width: width * 0.26, label: true, header: true)
                ForEach(names.indices, id: \.self) { index in cell(names[index], width: width * 0.74 / CGFloat(max(1, names.count)), header: true) }
            }.background(XJTheme.soft)
            ForEach(rows.filter { !differences || $0.different }) { row in
                GridRow {
                    cell(row.label, width: width * 0.26, label: true)
                    ForEach(row.values.indices, id: \.self) { index in cell(row.values[index], width: width * 0.74 / CGFloat(max(1, names.count))) }
                }.background(row.different ? Color(red: 1, green: 245/255, blue: 206/255) : .white)
                    .accessibilityIdentifier("mp.compare.row.\(row.id)")
            }
        }.clipShape(RoundedRectangle(cornerRadius: 14))
    }
    private func cell(_ text: String, width: CGFloat, label: Bool = false, header: Bool = false) -> some View {
        Text(text).font(.system(size: label ? 12 : 13, weight: header ? .semibold : .regular))
            .foregroundStyle(label || text == "未填写" ? XJTheme.muted : XJTheme.ink)
            .multilineTextAlignment(label ? .leading : .center).padding(.vertical, 16).padding(.horizontal, label ? 12 : 6)
            .frame(width: width).frame(minHeight: header ? 74 : 56, alignment: label ? .leading : .center)
            .overlay(alignment: .bottom) { XJTheme.line.frame(height: 1) }
    }
}

struct MPConfirmation: View {
    let title: String, message: String, confirmTitle: String
    var destructive = false
    let cancel: () -> Void, confirm: () -> Void
    var body: some View {
        ZStack {
            XJTheme.ink.opacity(0.38).ignoresSafeArea()
            VStack(spacing: 0) {
                Text(title).font(.system(size: 17, weight: .semibold)).padding(.top, 24)
                Text(message).font(.system(size: 14)).foregroundStyle(XJTheme.muted).multilineTextAlignment(.center).padding(24)
                HStack(spacing: 0) {
                    Button(action: cancel) { Text("取消").frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle()) }
                        .foregroundStyle(XJTheme.muted).accessibilityIdentifier("mp.confirm.cancel")
                    XJTheme.line.frame(width: 1, height: 52)
                    Button(confirmTitle, action: confirm).frame(maxWidth: .infinity, minHeight: 52).foregroundStyle(destructive ? XJTheme.danger : XJTheme.primary)
                        .accessibilityIdentifier("mp.confirm")
                }.font(.system(size: 16, weight: .medium)).overlay(alignment: .top) { XJTheme.line.frame(height: 1) }
            }.background(.white).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 40)
        }
    }
}

struct MPPressActions: ViewModifier {
    let tap: () -> Void, hold: () -> Void
    func body(content: Content) -> some View {
        content.highPriorityGesture(
            LongPressGesture(minimumDuration: 0.45).exclusively(before: TapGesture()).onEnded { event in
                switch event {
                case .first: hold()
                case .second: tap()
                }
            }
        ).accessibilityAction(perform: tap)
    }
}

struct MPToast: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 14)).foregroundStyle(.white).multilineTextAlignment(.center)
            .padding(.horizontal, 24).padding(.vertical, 16).background(.black.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 10)).padding(40).allowsHitTesting(false)
            .accessibilityIdentifier("mp.toast")
    }
}

struct MPAccountIcon: View {
    var body: some View {
        Canvas { context, size in
            let s = size.width / 24
            var path = Path()
            path.addEllipse(in: CGRect(x: 8*s, y: 3*s, width: 8*s, height: 8*s))
            path.move(to: CGPoint(x: 5*s, y: 20*s))
            path.addLine(to: CGPoint(x: 5*s, y: 18*s))
            path.addCurve(to: CGPoint(x: 19*s, y: 18*s), control1: CGPoint(x: 5*s, y: 8.67*s), control2: CGPoint(x: 19*s, y: 8.67*s))
            path.addLine(to: CGPoint(x: 19*s, y: 20*s))
            context.stroke(path, with: .color(XJTheme.primary), style: StrokeStyle(lineWidth: 1.8*s, lineCap: .round, lineJoin: .round))
        }.frame(width: 30, height: 30).accessibilityHidden(true)
    }
}
