import SwiftUI

struct HouseDetailPage: View {
    let workspace: AppWorkspace
    let id: String
    var newHouse = false
    @State private var tab = "清单"
    @State private var showCoach = false
    @State private var appeared = false
    var body: some View {
        VStack(spacing: 0) {
            if workspace.store.house(id)["archived"].bool {
                Text("归档房源 · 只读查看，在归档列表中可还原")
                    .font(.system(size: 12)).foregroundStyle(XJTheme.muted).padding(10)
                    .frame(maxWidth: .infinity).background(XJTheme.soft).accessibilityIdentifier("house.readonly")
            }
            Group {
                switch tab {
                case "总结":
                    ScrollView {
                        VStack(spacing: 16) {
                            SaveBanner(workspace: workspace)
                            SummaryInput(decision: summary("decision"), note: summary("summary"), readonly: readonly)
                        }.padding(16)
                    }
                case "问题": IssuesPage(workspace: workspace, id: id)
                case "影像": HouseMediaPage(workspace: workspace, id: id)
                default: ChecklistPage(workspace: workspace, id: id, showCoach: $showCoach)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.background(XJTheme.background).navigationTitle(workspace.store.house(id)["name"].string)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                XJTabBar(selection: $tab, items: [("清单", "checklist"), ("影像", "media"), ("问题", "issues"), ("总结", "summary")])
                    .disabled(showCoach)
            }
            .navigationBarBackButtonHidden(showCoach)
            .onAppear {
                if !appeared { appeared = true; showCoach = newHouse && !readonly && workspace.store.state["settings"]["onboarding"].bool }
            }
    }
    private var readonly: Bool { workspace.store.house(id)["archived"].bool }
    private func summary(_ property: String) -> Binding<String> {
        Binding(get: { workspace.store.house(id)[property].string }, set: { value in
            workspace.perform { try workspace.store.call("summary", ["id": .string(id), "property": .string(property), "value": .string(String(value.prefix(10000)))]) }
        })
    }
}

private struct NoteTarget: Identifiable { let id: String; let title: String; let value: String }

struct ChecklistPage: View {
    let workspace: AppWorkspace
    let id: String
    @Binding var showCoach: Bool
    @State private var phase = "全部"
    @State private var query = ""
    @State private var filters: Set<String> = []
    @State private var showFilters = false
    @State private var folds: [String: [String: Bool]] = [:]
    @State private var sections: [JSONValue] = []
    @State private var activeHeading: String?
    @State private var note: NoteTarget?
    @State private var cost: JSONValue?
    @State private var mediaTarget: String?
    @State private var commuteField: String?
    @State private var showSpeed = false
    @State private var speedVisit = UUID()
    @State private var coachStep = 1
    @State private var coachSteps: [CoachStep] = []
    @State private var coachTarget: JSONValue = .null
    @State private var coachHidden = false
    @State private var coachError = ""
    @State private var coachSavedFolds: [String: [String: Bool]]?
    private var viewKey: String { phase + "|" + query + "|" + filters.sorted().joined(separator: ",") }
    private var readonly: Bool { workspace.store.house(id)["archived"].bool }
    private var stats: InspectionStats? { workspace.store.houses.first { $0.id == id }?.stats }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 0).id("top")
                    SaveBanner(workspace: workspace)
                    progress
                    HStack(spacing: 8) {
                        ForEach(["全部", "房源", "现场", "询问签约"], id: \.self) { value in
                            Button { phase = value } label: { Text(value).frame(maxWidth: .infinity) }
                                .buttonStyle(FilterChip(selected: phase == value))
                                .accessibilityIdentifier("phase.\(value)")
                                .anchorPreference(key: CoachAnchors.self, value: .bounds) { anchor in
                                    let step = value == "房源" ? 1 : value == "现场" ? 2 : value == "询问签约" ? 3 : 0
                                    return step == 0 ? [:] : [step: anchor]
                                }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        TextField("搜索检查项、结果或备注", text: $query).font(.system(size: 13))
                            .padding(.horizontal, 12).frame(minHeight: 44).background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityIdentifier("checklist.search")
                            .submitLabel(.search)
                        Button("筛选" + (filters.isEmpty ? "" : " \(filters.count)")) { showFilters.toggle() }
                            .buttonStyle(XJButtonStyle(primary: false)).frame(width: filters.isEmpty ? 64 : 76)
                    }
                    if showFilters {
                        ChoiceFlow {
                            ForEach(["全部", "未记录", "已记录", "有问题", "有备注", "有影像"], id: \.self) { value in
                                Button(value) {
                                    if value == "全部" { filters.removeAll() }
                                    else if !filters.insert(value).inserted { filters.remove(value) }
                                }.buttonStyle(FilterChip(selected: value == "全部" ? filters.isEmpty : filters.contains(value)))
                            }
                        }
                    }
                    ForEach(sections, id: \.id) { section in
                        XJCard {
                            VStack(spacing: 4) {
                                ChecklistHeadingRow(id: section["header"].id, title: section["title"].string, kind: .category,
                                    done: section["stats"]["done"].int, total: section["stats"]["total"].int, issues: section["stats"]["issues"].int,
                                    readonly: readonly, noteText: section["header"]["note"].string,
                                    expanded: Binding(get: { section["expanded"].bool }, set: { setFold(section["title"].string, $0) }),
                                    skipped: .constant(false), value: .constant(""), flagged: flagBinding(section["header"]), activeRow: $activeHeading,
                                    note: { openNote(section["header"]) }, capture: { mediaTarget = section["header"].id })
                                if section["expanded"].bool {
                                    ForEach(section["rows"].array, id: \.rowKey) { row in
                                        checklistRow(row).padding(.leading, CGFloat(min(row["depth"].int, 2) * 12)).id(row.id)
                                            .anchorPreference(key: CoachAnchors.self, value: .bounds) { row.id == coachTarget["field"].id ? [4: $0] : [:] }
                                    }
                                }
                            }
                        }
                    }
                    if sections.isEmpty { Text("没有符合条件的检查项").font(.system(size: 14)).foregroundStyle(XJTheme.muted).padding(32) }
                }.padding(.horizontal, 16).padding(.bottom, 72)
            }.scrollDismissesKeyboard(.interactively)
                .overlay(alignment: .bottomTrailing) {
                    Button { withAnimation { proxy.scrollTo("top", anchor: .top) } } label: {
                        XJIcon(name: "up").frame(width: 48, height: 48).background(.white).clipShape(Circle())
                    }.padding(16).accessibilityLabel("回到顶部")
                }
                .overlayPreferenceValue(CoachAnchors.self) { anchors in
                    if showCoach {
                        GeometryReader { geometry in
                            CoachOverlay(steps: coachSteps, step: coachStep, target: anchors[coachStep].map { geometry[$0] }, fieldLabel: coachTarget["field"]["label"].string,
                                         hideAutomatically: $coachHidden, error: coachError) { advanceCoach(proxy) }
                        }
                    }
                }
                .onChange(of: showCoach) { if showCoach { prepareCoach() } }
                .onChange(of: coachStep) {
                    if coachStep == 4 { proxy.scrollTo(coachTarget["field"].id, anchor: .center) }
                }
        }.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    .accessibilityIdentifier("checklist.keyboard.done")
            }
        }.onAppear { refresh(); if showCoach { prepareCoach() } }
            .onChange(of: viewKey) { _, _ in activeHeading = nil; refresh() }
            .onChange(of: workspace.store.status.revision) { _, _ in refresh() }
            .sheet(item: $note) { target in
                NoteEditor(title: target.title + " · 备注", text: target.value, readonly: readonly) { value in
                    try workspace.store.answer(id, field: target.id, property: "note", value: .string(value))
                    if !workspace.store.status.error.isEmpty { throw CoreFailure(message: workspace.store.status.error) }
                }
            }
            .sheet(item: $cost) { group in
                TextPrompt(title: "添加" + group["title"].string, placeholder: "填写费用名称", text: "") { label in
                    try workspace.store.call("addCost", ["id": .string(id), "group": .string(group.id), "value": .string(label)])
                }
            }
            .sheet(isPresented: Binding(get: { mediaTarget != nil }, set: { if !$0 { mediaTarget = nil } })) {
                if let mediaTarget { MediaPickerSheet(workspace: workspace, houseID: id, fieldID: mediaTarget) }
            }
            .navigationDestination(isPresented: Binding(get: { commuteField != nil }, set: { if !$0 { commuteField = nil } })) {
                if let commuteField { CommutePage(workspace: workspace, houseID: id, fieldID: commuteField) }
            }
            .navigationDestination(isPresented: $showSpeed) { SpeedPage(workspace: workspace, houseID: id).id(speedVisit) }
    }
    private var progress: some View {
        XJCard {
            VStack(spacing: 12) {
                HStack { Text("现场检查").font(.system(size: 14, weight: .semibold)); Spacer(); Text("\(stats?.done ?? 0) / \(stats?.total ?? 0)").font(.system(size: 13)) }
                ProgressView(value: Double(stats?.done ?? 0), total: Double(max(1, stats?.total ?? 1))).tint(XJTheme.primary)
                HStack { Text("已记录 \(stats?.done ?? 0) 项"); Spacer(); Text("\(stats?.issues ?? 0) 项有问题").foregroundStyle(XJTheme.danger) }
                    .font(.system(size: 12)).foregroundStyle(XJTheme.muted)
            }
        }
    }
    @ViewBuilder private func checklistRow(_ row: JSONValue) -> some View {
        if row["kind"].string == "add-cost" {
            Button("＋") { cost = row }.buttonStyle(XJButtonStyle(primary: false)).disabled(readonly)
        } else if row["kind"].string == "group" {
            ChecklistHeadingRow(id: row["swipe"].id, title: row["title"].string,
                options: row["options"].array.map { $0["value"].string },
                choiceLabels: Dictionary(uniqueKeysWithValues: row["options"].array.map { ($0["value"].string, $0["label"].string) }),
                skippable: row["skippable"].bool, readonly: readonly, noteText: row["swipe"]["note"].string,
                expanded: Binding(get: { row["expanded"].bool }, set: { setFold(row.id, $0) }),
                skipped: Binding(get: { row["skipped"].bool }, set: { _ in group(row, operation: "skip") }),
                value: Binding(get: { row["options"].array.first { $0["selected"].bool }?["value"].string ?? "" }, set: { value in
                    let prior = row["options"].array.first { $0["selected"].bool }?["value"].string ?? ""
                    // Canonical group commands toggle their selected result themselves.
                    group(row, operation: "result", value: value.isEmpty ? prior : value)
                }), flagged: flagBinding(row["swipe"]), activeRow: $activeHeading,
                note: { openNote(row["swipe"]) }, capture: { mediaTarget = row["swipe"].id })
        } else {
            field(row)
        }
    }
    @ViewBuilder private func field(_ row: JSONValue) -> some View {
        if row["map"].bool {
            HousePlaceField(workspace: workspace, id: id)
        } else if !row["options"].array.isEmpty && row["inline"].bool && !row["multiple"].bool {
            VStack(alignment: .leading, spacing: 0) {
                InspectionChoiceRow(title: row["label"].string, options: row["options"].array.map { $0["value"].string },
                    choiceLabels: Dictionary(uniqueKeysWithValues: row["options"].array.map { ($0["value"].string, $0["label"].string) }),
                    value: answerBinding(row.id), flagged: flagBinding(row), readonly: readonly,
                    note: { openNote(row) }, capture: { mediaTarget = row.id })
                if !row["note"].string.isEmpty { Button(row["note"].string) { openNote(row) }.font(.system(size: 12)).foregroundStyle(XJTheme.muted) }
            }
        } else {
            AnswerInput(field: row, text: answerBinding(row.id), otherText: answerBinding(row.id, property: "otherText"), readonly: readonly, showsKeyboardToolbar: false,
                choose: { value in workspace.perform { try workspace.store.call("choose", ["id": .string(id), "field": .string(row.id), "value": .string(value)]) } },
                action: { action in
                    if action == "备注" { openNote(row) }
                    else if action == "标记问题" { flag(row) }
                    else { mediaTarget = row.id }
                }, measurement: measurement(row.id))
        }
    }
    private func group(_ row: JSONValue, operation: String, value: String = "") {
        if workspace.perform({ try workspace.store.call("group", ["id": .string(id), "group": .string(row.id), "property": .string(operation), "value": .string(value)]) }) {
            setFold(row.id, true)
        }
    }
    private func measurement(_ field: String) -> MeasurementAction? {
        if UtilityField.mode(field) != nil { return MeasurementAction(kind: .commute) { commuteField = field } }
        if field == UtilityField.speed { return MeasurementAction(kind: .speed) { speedVisit = UUID(); showSpeed = true } }
        return nil
    }
    private func answerBinding(_ field: String, property: String = "value") -> Binding<String> {
        Binding(get: { workspace.store.house(id)["answers"][field][property].string }, set: { value in
            workspace.perform { try workspace.store.answer(id, field: field, property: property, value: .string(String(value.prefix(10000)))) }
        })
    }
    private func flagBinding(_ field: JSONValue) -> Binding<Bool> {
        Binding(get: { field["problem"].bool }, set: { value in
            workspace.perform { try workspace.store.answer(id, field: field.id, property: "issueFlag", value: .bool(value)) }
        })
    }
    private func flag(_ field: JSONValue) { flagBinding(field).wrappedValue.toggle() }
    private func openNote(_ field: JSONValue) { note = NoteTarget(id: field.id, title: field["label"].string, value: field["note"].string) }
    private func setFold(_ key: String, _ value: Bool) { folds[viewKey, default: [:]][key] = value; refresh() }
    private func refresh() { workspace.perform { sections = try workspace.store.form(id, phase: phase, query: query, filters: filters.sorted(), folds: folds[viewKey] ?? [:]) } }
    private func prepareCoach() {
        do {
            let value = try workspace.store.call("coach", ["id": .string(id)])
            coachSteps = value["steps"].array.map { CoachStep(title: $0["title"].string, body: $0["body"].string) }
            coachTarget = value["target"]; coachStep = 1; coachError = ""
        } catch { coachError = error.localizedDescription }
    }
    private func advanceCoach(_ proxy: ScrollViewProxy) {
        if coachStep < 4 {
            if coachStep == 3 {
                coachSavedFolds = folds; phase = "全部"; query = ""; filters = []
                if case .object(let expanded) = coachTarget["folds"] {
                    folds[viewKey, default: [:]].merge(expanded.mapValues(\.bool), uniquingKeysWith: { _, new in new })
                }
                refresh()
            }
            coachStep += 1
        } else {
            do {
                try workspace.store.call("coachFinish", ["value": .bool(coachHidden)])
                showCoach = false; coachError = ""
                if let saved = coachSavedFolds { folds = saved; coachSavedFolds = nil; refresh() }
                proxy.scrollTo("top", anchor: .top)
            } catch { coachError = "偏好未保存，请重试。" }
        }
    }
}

extension JSONValue: Identifiable {
    var rowKey: String { self["key"].string }
}

struct FilterChip: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13)).padding(.horizontal, 12).frame(minHeight: 44)
            .foregroundStyle(selected ? XJTheme.primary : XJTheme.muted)
            .background(selected ? XJTheme.soft : .white).clipShape(RoundedRectangle(cornerRadius: 22))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct NoteEditor: View {
    let title: String
    @State var text: String
    var readonly = false
    let save: (String) throws -> Void
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $text).font(.system(size: 14)).disabled(readonly)
                    .accessibilityIdentifier("note.text")
                    .onChange(of: text) { _, value in if value.count > 10000 { text = String(value.prefix(10000)) } }
                if !error.isEmpty { Text(error).font(.system(size: 13)).foregroundStyle(XJTheme.danger) }
            }.padding(16).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(readonly ? "关闭" : "取消") { dismiss() } }
                    if !readonly { ToolbarItem(placement: .confirmationAction) {
                        Button("保存备注") { do { try save(text); dismiss() } catch { self.error = error.localizedDescription } }
                    } }
                }
        }.presentationDetents([.medium, .large])
    }
}
