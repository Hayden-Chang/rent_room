import SwiftUI
import Observation
import UIKit

enum ChecklistFeedback {
    case selection, disclosure

    @MainActor private static let selectionGenerator = UISelectionFeedbackGenerator()
    @MainActor private static let disclosureGenerator = UIImpactFeedbackGenerator(style: .soft)

    @MainActor func play() {
        switch self {
        case .selection: Self.selectionGenerator.selectionChanged()
        case .disclosure: Self.disclosureGenerator.impactOccurred(intensity: 0.5)
        }
    }
}

struct MPSwipeMotion {
    enum Axis { case undecided, horizontal, vertical }
    var base: CGFloat = 0
    private(set) var offset: CGFloat = 0
    private(set) var axis: Axis = .undecided
    private var samples: [(CGFloat, Double)] = []
    init(base: CGFloat = 0) { self.base = base; offset = base }
    mutating func sample(x: CGFloat, y: CGFloat, time: Double) {
        if axis == .undecided, max(abs(x), abs(y)) >= 8 {
            if abs(x) > abs(y) * 1.2 { axis = .horizontal }
            else if abs(y) > abs(x) * 1.2 { axis = .vertical }
        }
        samples = samples.filter { time - $0.1 <= 0.1 }
        samples.append((x, time))
        if axis == .horizontal { offset = max(-132, min(0, base + x)) }
    }
    mutating func finish(x: CGFloat, y: CGFloat, time: Double) -> Bool {
        sample(x: x, y: y, time: time)
        guard axis == .horizontal else { return base < 0 && axis != .vertical }
        let first = samples.first!, last = samples.last!, elapsed = last.1 - first.1
        let velocity = elapsed > 0 ? (last.0 - first.0) / elapsed / 1000 : 0
        if abs(x) >= 8 && abs(velocity) >= 0.3 { return velocity < 0 }
        if x <= -20 { return true }
        if x >= 20 { return false }
        return base < 0
    }
}

@Observable final class MPSwipeCoordinator {
    private(set) var active: String?
    private(set) var dragging: String?
    private var motion = MPSwipeMotion()
    private(set) var diagnostic = ""
    func trace(_ message: String) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--parity-trace") {
            diagnostic = String((diagnostic + " | " + message).suffix(1500))
        }
        #endif
    }
    func offset(_ id: String) -> CGFloat { dragging == id ? motion.offset : active == id ? -132 : 0 }
    func move(_ id: String, x: CGFloat, y: CGFloat, time: Double) {
        trace("move \(id) \(Int(x)),\(Int(y))")
        if dragging != id {
            motion = MPSwipeMotion(base: active == id ? -132 : 0)
            if active != id { active = nil }
            dragging = id
        }
        motion.sample(x: x, y: y, time: time)
        if motion.axis == .vertical { active = nil }
    }
    func finish(_ id: String, x: CGFloat, y: CGFloat, time: Double, nativeVelocity: CGFloat? = nil) {
        trace("finish \(id) \(Int(x)),\(Int(y)) dragging=\(dragging ?? "-")")
        guard dragging == id else { return }
        let distanceDecision = motion.finish(x: x, y: y, time: time)
        // UIKit can recognize a short flick at finger-up before delivering translation.
        // Recognition already enforces touch slop; use its measured points/sec velocity.
        if let nativeVelocity, motion.axis != .vertical, abs(nativeVelocity) >= 300 {
            active = nativeVelocity < 0 ? id : nil
        } else { active = distanceDecision ? id : nil }
        dragging = nil
    }
    func reveal(_ id: String) { dragging = nil; active = id }
    func close() { trace("close"); active = nil; dragging = nil }
    @discardableResult func consumeTap() -> Bool {
        let wasOpen = active != nil || dragging != nil
        close(); return wasOpen
    }
}

struct MPFieldItem {
    enum Kind { case category, group, choice, text, number, date, wheel }
    let id: String, title: String
    var kind: Kind = .choice
    var options: [String] = []
    var labels: [String: String] = [:]
    var multiple = false, inline = true, skippable = false, hideDivider = false
    var stats = "", photoRef = ""
    var description = ""
    var allowsNone = false, numberPad = false
    var progress: Double? = nil
    var issueCount = 0
    var collapsible = true
    var currency: String? = nil
    var heading: Bool { kind == .category || kind == .group }
}

struct MPFieldState {
    var text = "", note = "", otherText = ""
    var selected: Set<String> = []
    var flagged = false, expanded = false, skipped = false
    var noneSelected = false
}

struct MPFieldRow: View {
    static let measurementWheelMinimumWidth: CGFloat = 100
    let item: MPFieldItem
    @Binding var state: MPFieldState
    var readonly = false
    var coordinator: MPSwipeCoordinator
    let note: () -> Void, capture: () -> Void
    var measurement: MeasurementAction? = nil
    var wheel: (() -> Void)? = nil
    var interaction: (String, Bool?) -> Void = { _, _ in }
    var feedback: @MainActor (ChecklistFeedback) -> Void = { $0.play() }
    @FocusState private var focused: Bool
    @State private var datePicker = false
    private var height: CGFloat { item.kind == .category ? 56 : item.heading ? 48 : 44 }
    private var offset: CGFloat { readonly ? 0 : coordinator.offset(item.id) }
    private var problemInk: Color { state.flagged ? XJTheme.danger : XJTheme.ink }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if item.kind == .group { XJTheme.line.frame(height: 1).padding(.bottom, 4) }
            ZStack(alignment: .topTrailing) {
                if !readonly && offset < 0 {
                    HStack(spacing: 0) {
                        tray(state.flagged ? "取消问题" : "标记问题", icon: state.flagged ? "swipe-issue-active" : "swipe-issue", color: state.flagged ? XJTheme.danger : XJTheme.dangerBackground) { state.flagged.toggle() }
                        tray("备注", icon: "swipe-note", color: XJTheme.soft, action: note)
                        tray("拍摄", icon: "swipe-camera", color: XJTheme.primary, action: capture)
                    }.offset(x: 132 + offset).opacity(offset < 0 ? 1 : 0)
                        .allowsHitTesting(coordinator.active == item.id && coordinator.dragging == nil)
                        .accessibilityHidden(coordinator.active != item.id || coordinator.dragging != nil).zIndex(1)
                }
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text(verbatim: (item.currency.map { AppCopy.moneyLabel(item.title, currency: $0, verbatim: item.id.hasPrefix("cost_")) } ?? AppCopy.text(item.title)) + (item.multiple ? AppCopy.text(" · 多选") : ""))
                            .font(.system(size: item.heading ? 14 : 13, weight: item.heading ? .semibold : .regular))
                            .foregroundStyle(problemInk).multilineTextAlignment(.leading)
                            .accessibilityIdentifier("mp.field.title.\(item.id)")
                            .accessibilityValue(AppCopy.text(item.heading && item.collapsible ? (state.expanded ? "已展开" : "已折叠") : ""))
                        if item.heading && item.collapsible { AppText(state.expanded ? "⌃" : "⌄").font(.system(size: 11)).foregroundStyle(XJTheme.muted).accessibilityHidden(true) }
                    }.frame(maxWidth: item.kind == .text ? 104 : .infinity, minHeight: height, alignment: .leading)
                        .contentShape(Rectangle()).onTapGesture {
                            if !coordinator.consumeTap(), item.heading && item.collapsible {
                                state.expanded.toggle()
                                feedback(.disclosure)
                            }
                        }
                    if item.inline || item.heading {
                        ZStack { answer.offset(x: offset) }.clipped().allowsHitTesting(offset == 0)
                    }
                }.frame(minHeight: height)
            }.clipped().contentShape(Rectangle())
            if !item.inline && !item.heading { answer.padding(.top, 6).allowsHitTesting(offset == 0) }
            if !item.description.isEmpty {
                AppText(item.description).font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                    .accessibilityIdentifier("mp.field.description.\(item.id)")
            }
            if state.selected.contains("其他") {
                TextField(AppCopy.text(focused ? "" : "请填写其他内容"), text: $state.otherText).focused($focused).font(.system(size: 13)).padding(.horizontal, 12).frame(height: 44)
                    .background(.white).overlay(RoundedRectangle(cornerRadius: 8).stroke(XJTheme.line)).padding(.top, 8).disabled(readonly)
                    .onChange(of: state.otherText) { state.otherText = String(state.otherText.prefix(2000)) }
                    .accessibilityIdentifier("mp.field.other.\(item.id)")
            }
            if !state.note.isEmpty {
                Button { if !coordinator.consumeTap() { note() } } label: {
                    Text(verbatim: state.note).font(.system(size: 12)).foregroundStyle(XJTheme.noteInk).multilineTextAlignment(.leading)
                        .lineLimit(item.heading ? nil : 2).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).padding(.top, 8)
            }
            if !item.photoRef.isEmpty { AppText("原照片编号：" + item.photoRef).font(.system(size: 11)).foregroundStyle(XJTheme.muted).padding(.top, 4) }
        }.padding(.vertical, item.inline ? 2 : item.heading ? 4 : 12).padding(.top, item.kind == .group ? 8 : 0)
            .background(state.flagged ? XJTheme.dangerBackground : .clear)
            .clipShape(RoundedRectangle(cornerRadius: state.flagged ? 8 : 0))
            .overlay(alignment: .bottom) { if !item.heading && !item.hideDivider { XJTheme.line.frame(height: 1) } }
            .onChange(of: focused) { if focused { coordinator.close() }; interaction(item.id, focused) }
            .onChange(of: readonly) { if readonly { coordinator.close() } }
            .contentShape(Rectangle())
            .modifier(MPFieldSwipe(id: item.id, readonly: readonly, coordinator: coordinator))
            .highPriorityGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                if !readonly { withAnimation(.easeOut(duration: 0.18)) { coordinator.reveal(item.id) } }
            })
            .accessibilityElement(children: .contain).accessibilityIdentifier("mp.field.\(item.id)")
            .accessibilityValue(AppCopy.text((coordinator.active == item.id ? "操作已展开" : "操作已收起") + coordinator.diagnostic))
            .sheet(isPresented: $datePicker) { DateInputSheet(value: $state.text).presentationDetents([.medium]) }
    }
    @ViewBuilder private var answer: some View {
        if item.kind == .wheel, let spec = WheelFieldSpec.all[item.id] {
            HStack(spacing: 8) {
                Button { if !coordinator.consumeTap() { wheel?() } } label: {
                    HStack(spacing: 8) {
                        Text(verbatim: spec.display(state.text)).lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 10))
                    }.font(.system(size: 13)).foregroundStyle(state.text.isEmpty ? XJTheme.muted : XJTheme.ink)
                        .padding(.horizontal, 12).frame(minWidth: measurement == nil ? 96 : Self.measurementWheelMinimumWidth, minHeight: 44)
                        .background(.white).overlay(RoundedRectangle(cornerRadius: 8).stroke(XJTheme.line))
                }.buttonStyle(.plain).disabled(readonly || state.noneSelected).accessibilityIdentifier("mp.field.wheel.\(item.id)")
                    .accessibilityValue(spec.display(state.text))
                if item.allowsNone { noneOption }
                if let measurement {
                    Button(AppCopy.text("查询")) { if !coordinator.consumeTap() { measurement.perform() } }
                        .font(.system(size: 13)).padding(.horizontal, 10).frame(height: 44).foregroundStyle(XJTheme.primary)
                        .background(XJTheme.soft).clipShape(RoundedRectangle(cornerRadius: 8)).buttonStyle(.plain)
                        .disabled(readonly).accessibilityIdentifier("measurement.\(item.id)")
                }
            }
        } else if item.kind == .date {
            Button(AppCopy.text(state.text.isEmpty ? "选择日期" : state.text)) { if !coordinator.consumeTap() { datePicker = true } }
                .font(.system(size: 13)).padding(.horizontal, 12).frame(minHeight: 44)
                .background(.white).overlay(RoundedRectangle(cornerRadius: 8).stroke(XJTheme.line))
                .buttonStyle(.plain).disabled(readonly).accessibilityIdentifier("mp.field.input.\(item.id)")
        } else if item.kind == .text || item.kind == .number {
            HStack(spacing: measurement?.kind == .speed ? 6 : 8) {
            TextField(AppCopy.text(focused ? "" : measurement.map { $0.kind == .speed ? "网速" : "分钟" } ?? (item.kind == .number ? "填写数值" : "填写信息")), text: $state.text)
                .font(.system(size: 13)).keyboardType(item.kind == .number ? (item.numberPad ? .numberPad : .decimalPad) : .default).focused($focused)
                .multilineTextAlignment(item.kind == .number ? .trailing : .leading)
                .padding(.horizontal, measurement == nil ? 12 : 8).frame(width: item.kind == .number ? (measurement == nil ? 96 : 76) : nil, height: 44)
                .frame(maxWidth: item.kind == .text ? .infinity : nil)
                .background(.white).overlay(RoundedRectangle(cornerRadius: 8).stroke(XJTheme.line)).disabled(readonly || state.noneSelected)
                .onChange(of: state.text) { state.text = String(state.text.prefix(2000)) }.accessibilityIdentifier("mp.field.input.\(item.id)")
                if item.allowsNone { noneOption }
                if let measurement {
                    if measurement.kind == .speed { AppText("Mbps").font(.system(size: 11)).foregroundStyle(XJTheme.muted) }
                    Button(AppCopy.text(measurement.kind == .speed ? "测试" : "查询")) { if !coordinator.consumeTap() { measurement.perform() } }
                        .font(.system(size: 13)).padding(.horizontal, 10).frame(height: 44).foregroundStyle(XJTheme.primary)
                        .background(XJTheme.soft).clipShape(RoundedRectangle(cornerRadius: 8)).buttonStyle(.plain)
                        .disabled(readonly).accessibilityIdentifier("measurement.\(item.id)")
                }
            }
        } else {
            HStack(spacing: 4) {
                if !item.stats.isEmpty {
                    if let progress = item.progress {
                        HStack(spacing: 8) {
                            if item.issueCount > 0 { AppText("\(item.issueCount) 个问题").foregroundStyle(XJTheme.danger) }
                            GeometryReader { geometry in
                                Capsule().fill(XJTheme.soft)
                                Capsule().fill(progress == 1 ? Color(red: 22/255, green: 163/255, blue: 74/255) : XJTheme.primary)
                                    .frame(width: geometry.size.width * max(0, min(1, progress)))
                            }.frame(width: 48, height: 4)
                            AppText(item.stats).monospacedDigit().foregroundStyle(XJTheme.muted).frame(minWidth: 40, alignment: .trailing)
                        }.font(.system(size: 12)).accessibilityElement(children: .combine)
                    } else { AppText(item.stats).font(.system(size: 12)).foregroundStyle(XJTheme.muted).fixedSize() }
                }
                if item.skippable { option("不涉及", selected: state.skipped, isSkip: true) { state.skipped.toggle() } }
                if !state.skipped {
                    if item.inline || item.heading {
                        ForEach(item.options, id: \.self) { value in option(item.labels[value] ?? value, selected: state.selected.contains(value)) { select(value) } }
                    } else {
                        ChoiceFlow { ForEach(item.options, id: \.self) { value in option(item.labels[value] ?? value, selected: state.selected.contains(value)) { select(value) } } }
                    }
                }
            }.fixedSize(horizontal: item.inline || item.heading, vertical: false)
        }
    }
    private var noneOption: some View {
        option("无", selected: state.noneSelected) { state.noneSelected.toggle() }
    }
    private func option(_ title: String, selected: Bool, isSkip: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            if !coordinator.consumeTap() {
                action()
                // One feedback per user action, including a parent choice that also expands.
                feedback(.selection)
            }
        } label: {
            AppText(title).font(.system(size: isSkip ? 12 : 13, weight: item.heading && !isSkip ? .semibold : .regular))
                .fixedSize(horizontal: true, vertical: false).padding(.horizontal, item.inline ? 10 : 14).frame(minWidth: 44, minHeight: 44)
                .foregroundStyle(selected ? XJTheme.primary : XJTheme.ink).background(selected ? XJTheme.soft : XJTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain).disabled(readonly).opacity(readonly ? 0.55 : 1)
            .accessibilityIdentifier("mp.field.choice.\(item.id).\(title)").accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func select(_ value: String) {
        if item.multiple { if !state.selected.insert(value).inserted { state.selected.remove(value) } }
        else { state.selected = state.selected.contains(value) ? [] : [value] }
        if item.heading { state.expanded = true }
    }
    private func tray(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button { coordinator.close(); action() } label: { XJIcon(name: icon).frame(width: 44, height: 44).background(color) }
            .buttonStyle(.plain).accessibilityLabel(AppCopy.text(title)).accessibilityIdentifier("mp.field.action.\(item.id).\(title)")
    }
}

struct MPChecklistScrollRequest: Equatable {
    let id: String
    let anchor: UnitPoint
}

struct MPChecklistSurface<Content: View>: View {
    var done: Int, total: Int, issues: Int
    @Binding var phase: String
    @Binding var query: String
    @Binding var filters: Set<String>
    @Binding var showFilters: Bool
    var readonly = false
    var coordinator: MPSwipeCoordinator
    var scrollTarget = ""
    var scrollAnchor: UnitPoint = .center
    var scrollRequest: MPChecklistScrollRequest? = nil
    var scrollLocked = false
    var floatingActionsVisible = true
    var scrollPosition: NativeScrollPosition? = nil
    var guidance: JSONValue = .null
    var guidanceAction: (String) -> Void = { _ in }
    let capture: () -> Void
    @ViewBuilder var content: Content
    @State private var lastScrollY: CGFloat?
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 28).id("top").background { if let scrollPosition { NativeScrollProbe(position: scrollPosition) } }
                    MPCard {
                        VStack(spacing: 0) {
                            HStack { AppText("总进度").font(.system(size: 17, weight: .semibold)).frame(height: 25.5); Spacer(); AppText("\(done) / \(total)").font(.system(size: 14)) }
                            GeometryReader { geometry in
                                Capsule().fill(XJTheme.soft)
                                Capsule().fill(XJTheme.primary).frame(width: geometry.size.width * CGFloat(done) / CGFloat(max(1, total)))
                            }.frame(height: 5).padding(.top, 14).padding(.bottom, 10)
                            HStack { Spacer(); AppText("\(issues) 项有问题").foregroundStyle(XJTheme.danger) }.font(.system(size: 12)).frame(height: 18)
                        }
                    }
                    if guidance != .null { XiaodaGuidanceCard(prompt: guidance, action: guidanceAction).padding(.top, 12).id("xiaoda.guide") }
                    GeometryReader { geometry in
                        HStack(spacing: 8) {
                            ForEach(["全部", "房源", "现场", "询问签约"], id: \.self) { value in
                                Button { if !coordinator.consumeTap() { phase = value } } label: {
                                    AppText(["房源":"基本情况", "现场":"现场检查", "询问签约":"费用与合同"][value] ?? value)
                                        .font(.system(size: 13, weight: .medium))
                                        .frame(width: max(0, geometry.size.width - 24) / 4.25 * (value == "询问签约" ? 1.25 : 1), height: 44)
                                        .background(phase == value ? XJTheme.soft : .white).clipShape(Capsule())
                                }.foregroundStyle(phase == value ? XJTheme.primary : XJTheme.ink).buttonStyle(.plain).accessibilityIdentifier("mp.phase.\(value)")
                            }
                        }
                    }.frame(height: 44).padding(.vertical, 14).anchorPreference(key: CoachAnchors.self, value: .bounds) { [1:$0] }
                    HStack(spacing: 8) {
                        TextField(AppCopy.text("搜索检查项、结果或备注"), text: $query, prompt: AppText("搜索检查项、结果或备注").foregroundStyle(Color(white: 0.5))).font(.system(size: 14)).padding(.horizontal, 12).frame(height: 44).background(.white).clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(XJTheme.line)).accessibilityIdentifier("mp.checklist.search")
                        Button { if !coordinator.consumeTap() { showFilters.toggle() } } label: {
                            HStack(spacing: 8) {
                                AppText("筛选" + (filters.isEmpty ? "" : " \(filters.count)"))
                                Image(systemName: showFilters ? "chevron.up" : "chevron.down").font(.system(size: 10, weight: .semibold))
                            }
                        }.buttonStyle(MPButtonStyle(kind: .soft)).frame(width: filters.isEmpty ? 71 : 88).accessibilityLabel(AppCopy.text("筛选" + (filters.isEmpty ? "" : " \(filters.count)")))
                    }
                    if showFilters {
                        ChoiceFlow {
                            ForEach(["全部", "未记录", "已记录", "有问题", "有备注", "有影像"], id: \.self) { value in
                                Button {
                                    guard !coordinator.consumeTap() else { return }
                                    if value == "全部" { filters = [] } else if !filters.insert(value).inserted { filters.remove(value) }
                                } label: {
                                    AppText(value).font(.system(size: 13)).padding(.horizontal, 14).frame(minHeight: 44)
                                        .foregroundStyle((value == "全部" ? filters.isEmpty : filters.contains(value)) ? XJTheme.primary : XJTheme.ink)
                                        .background((value == "全部" ? filters.isEmpty : filters.contains(value)) ? XJTheme.soft : .white).clipShape(Capsule())
                                }.buttonStyle(.plain)
                            }
                        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.white).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.top, 8)
                            .anchorPreference(key: CoachAnchors.self, value: .bounds) { [2:$0] }
                    }
                    content.padding(.top, 16)
                }.padding(.horizontal, 16).padding(.bottom, 128)
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: MPChecklistScrollOrigin.self, value: geometry.frame(in: .named("mp.checklist")).minY)
                    })
            }.scrollDismissesKeyboard(.interactively)
                .scrollDisabled(scrollLocked)
                .coordinateSpace(name: "mp.checklist")
                .onPreferenceChange(MPChecklistScrollOrigin.self) { y in
                    if !scrollLocked, let lastScrollY, abs(y - lastScrollY) > 1 { coordinator.trace("scroll \(y - lastScrollY)"); coordinator.close() }
                    lastScrollY = y
                }.accessibilityIdentifier("mp.checklist.scroll")
                .onChange(of: scrollTarget) { if !scrollTarget.isEmpty { proxy.scrollTo(scrollTarget, anchor: scrollTarget == "top" ? .top : scrollAnchor) } }
                .onChange(of: scrollRequest) {
                    if let request = scrollRequest { proxy.scrollTo(request.id, anchor: request.anchor) }
                }
                .overlay(alignment: .bottomTrailing) {
                    if floatingActionsVisible {
                        VStack(spacing: 12) {
                            MPFloatingButton(icon: "up", label: "回到顶部", size: 44) { coordinator.close(); withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("top", anchor: .top) } }
                            if !readonly { MPFloatingButton(icon: "camera", label: "拍照或录视频", action: capture).accessibilityIdentifier("mp.checklist.capture") }
                        }.padding(16)
                    }
                }
        }
    }
}

private struct MPChecklistScrollOrigin: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct MPFieldSwipe: ViewModifier {
    let id: String, readonly: Bool
    let coordinator: MPSwipeCoordinator
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.gesture(MPHorizontalPan(enabled: !readonly, changed: move, ended: { translation, time, velocity in
                finish(translation, time, velocity: velocity)
            }, cancelled: coordinator.close, trace: coordinator.trace))
        } else {
            content.simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { value in
                move(value.translation, value.time.timeIntervalSinceReferenceDate)
            }.onEnded { value in
                finish(value.translation, value.time.timeIntervalSinceReferenceDate)
            })
        }
    }
    private func move(_ translation: CGSize, _ time: Double) {
        guard !readonly else { return }
        coordinator.move(id, x: translation.width, y: translation.height, time: time)
    }
    private func finish(_ translation: CGSize, _ time: Double, velocity: CGFloat? = nil) {
        guard !readonly else { return }
        withAnimation(.easeOut(duration: 0.18)) { coordinator.finish(id, x: translation.width, y: translation.height, time: time, nativeVelocity: velocity) }
    }
}

// Reject vertical pans before recognition so the parent ScrollView keeps scrolling.
// SwiftUI's simultaneousGesture no longer implies simultaneous ancestor gestures on iOS 26.
@available(iOS 18, *)
struct MPHorizontalPan: UIGestureRecognizerRepresentable {
    let enabled: Bool
    let changed: (CGSize, Double) -> Void, ended: (CGSize, Double, CGFloat) -> Void, cancelled: () -> Void
    let trace: (String) -> Void
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator(trace: trace, vertical: cancelled) }
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        pan.isEnabled = enabled
        return pan
    }
    func updateUIGestureRecognizer(_ pan: UIPanGestureRecognizer, context: Context) { pan.isEnabled = enabled }
    func handleUIGestureRecognizerAction(_ pan: UIPanGestureRecognizer, context: Context) {
        let point = pan.translation(in: nil), time = ProcessInfo.processInfo.systemUptime
        trace("pan \(pan.state.rawValue) xy=\(Int(point.x)),\(Int(point.y)) vx=\(Int(pan.velocity(in: nil).x))")
        let translation = CGSize(width: point.x, height: point.y)
        switch pan.state {
        case .began, .changed: changed(translation, time)
        case .ended: ended(translation, time, pan.velocity(in: nil).x)
        case .cancelled, .failed: cancelled()
        default: break
        }
    }
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let trace: (String) -> Void
        let vertical: () -> Void
        init(trace: @escaping (String) -> Void, vertical: @escaping () -> Void) { self.trace = trace; self.vertical = vertical }
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: nil)
            trace("shouldBegin \(Int(velocity.x)),\(Int(velocity.y))")
            if abs(velocity.y) > abs(velocity.x) * 1.2 { vertical() }
            return abs(velocity.x) > abs(velocity.y) * 1.2
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            // A diagonal horizontal swipe must not move the enclosing list too.
            false
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            guard let scroll = other.view as? UIScrollView,
                  other === scroll.panGestureRecognizer,
                  let view = gestureRecognizer.view else { return false }
            // Let the row decide its direction first. A vertical pan fails in
            // shouldBegin and immediately leaves scrolling to the parent.
            return view.isDescendant(of: scroll)
        }
    }
}
