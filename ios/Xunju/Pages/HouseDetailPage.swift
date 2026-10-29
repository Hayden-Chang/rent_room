import SwiftUI

struct HouseDetailPage: View {
    let workspace: AppWorkspace
    let id: String
    var newHouse = false
    var returnToHouses: () -> Void = {}
    @State private var tab = "清单"
    @State private var showCoach = false
    @State private var appeared = false
    var body: some View {
        let _ = PerformanceLayoutTrace.body(Self.self)
        VStack(spacing: 0) {
            if workspace.store.house(id)["archived"].bool {
                Text("归档房源 · 只读查看，在归档列表中可还原")
                    .font(.system(size: 12)).foregroundStyle(XJTheme.muted).padding(10)
                    .frame(maxWidth: .infinity).background(XJTheme.soft).accessibilityIdentifier("house.readonly")
            }
            ZStack {
                MPRetainedPage(active: tab == "清单") { ChecklistPage(workspace: workspace, id: id, showCoach: $showCoach, isActive: tab == "清单", returnToHouses: returnToHouses) }
                Group { switch tab {
                case "总结":
                    ScrollView {
                        VStack(spacing: 16) {
                            SaveBanner(workspace: workspace)
                            SummaryInput(decision: summary("decision"), note: summary("summary"), readonly: readonly)
                        }.padding(16)
                    }
                case "问题": IssuesPage(workspace: workspace, id: id)
                case "影像": HouseMediaPage(workspace: workspace, id: id)
                default: EmptyView()
                } }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.background(XJTheme.background).miniNavigation(workspace.store.house(id)["name"].string, showsBack: !showCoach)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                XJTabBar(selection: $tab, items: [("清单", "checklist"), ("影像", "media"), ("问题", "issues"), ("总结", "summary")],
                    mediaCount: workspace.store.house(id)["media"].array.count,
                    issueCount: workspace.store.houses.first { $0.id == id }?.stats.issues ?? 0)
                    .disabled(showCoach)
            }
            .onAppear {
                if !appeared { appeared = true; showCoach = !readonly && workspace.store.state["xiaoda"]["firstHouseId"].string == id && workspace.store.state["xiaoda"]["tutorialStep"].int > 0 }
            }
    }
    private var readonly: Bool { workspace.store.house(id)["archived"].bool }
    private func summary(_ property: String) -> Binding<String> {
        Binding(get: { workspace.store.house(id)[property].string }, set: { value in
            workspace.perform { try workspace.store.call("summary", ["id": .string(id), "property": .string(property), "value": .string(String(value.prefix(10000)))]) }
        })
    }
}

private struct NoteTarget: Identifiable { let id: String; let title: String }

struct ChecklistPage: View {
    let workspace: AppWorkspace
    let id: String
    @Binding var showCoach: Bool
    var isActive = true
    var returnToHouses: () -> Void = {}
    @State private var phase = "全部"
    @State private var query = ""
    @State private var filters: Set<String> = []
    @State private var showFilters = false
    @State private var folds: [String: [String: Bool]] = [:]
    @State private var sections: [JSONValue] = []
    @State private var coordinator = MPSwipeCoordinator()
    @State private var scrollTarget = ""
    @State private var noteText = ""
    @State private var noteError = ""
    @State private var costText = ""
    @State private var costError = ""
    @State private var note: NoteTarget?
    @State private var cost: JSONValue?
    @State private var mediaTarget: String?
    @State private var coachStep = 0
    @State private var coachTarget: JSONValue = .null
    @State private var coachSavedFolds: [String: [String: Bool]]?
    @State private var guidance: JSONValue = .null
    @State private var editingField: String?
    @State private var visiblePrompt: JSONValue = .null
    @State private var returnOffset: CGFloat?
    @State private var scrollPosition = NativeScrollPosition()
    @Environment(\.wheelInput) private var wheelInput
    private var viewKey: String { phase + "|" + query + "|" + filters.sorted().joined(separator: ",") }
    private var readonly: Bool { workspace.store.house(id)["archived"].bool }
    private var stats: InspectionStats? { workspace.store.houses.first { $0.id == id }?.stats }
    private var prompt: JSONValue { canPresentGuide ? visiblePrompt : .null }

    var body: some View {
        let _ = PerformanceLayoutTrace.body(Self.self)
        MPChecklistSurface(done: stats?.done ?? 0, total: stats?.total ?? 0, issues: stats?.issues ?? 0,
            phase: $phase, query: $query, filters: $filters, showFilters: $showFilters, readonly: readonly,
            coordinator: coordinator, scrollTarget: scrollTarget, scrollAnchor: showCoach ? .top : .center, scrollLocked: showCoach && coachStep == 3, floatingActionsVisible: editingField == nil, scrollPosition: scrollPosition,
            guidance: prompt != .null && !sections.contains(where: { $0["title"].string == prompt["target"].string }) ? prompt : .null,
            guidanceAction: guideAction, capture: { mediaTarget = "" }) {
            VStack(spacing: 12) {
                SaveBanner(workspace: workspace)
                ForEach(sections, id: \.titleKey) { section in
                    if prompt != .null && section["title"].string == prompt["target"].string {
                        XiaodaGuidanceCard(prompt: prompt, action: guideAction).id("xiaoda.guide")
                    }
                    VStack(spacing: 0) {
                        heading(section["header"], foldKey: section["title"].string)
                        FieldRelatedMedia(workspace: workspace, houseID: id, fieldID: section["header"].id)
                        if section["expanded"].bool {
                            let rows = section["rows"].array
                            VStack(spacing: 0) {
                                ForEach(Array(rows.enumerated()), id: \.element.rowKey) { index, row in
                                    checklistRow(row, hideDivider: ChecklistPresentation.hidesDivider(at: index, rows: rows))
                                        .padding(.leading, ChecklistPresentation.indent(row)).id(row.id)
                                        .anchorPreference(key: CoachAnchors.self, value: .bounds) { row.id == coachTarget["field"].id ? [3: $0, 4: $0] : [:] }
                                }
                            }.padding(.bottom, 12)
                        }
                    }.padding(.horizontal, 16).background(.white).clipShape(RoundedRectangle(cornerRadius: 16)).id(section["title"].string)
                }
                if sections.isEmpty { Text("没有符合条件的检查项").font(.system(size: 14)).foregroundStyle(XJTheme.muted).padding(32) }
            }
        }.overlayPreferenceValue(CoachAnchors.self) { anchors in
            if showCoach {
                GeometryReader { geometry in
                    XiaodaTutorialOverlay(guide: guidance, target: anchors[coachStep].map { geometry[$0] },
                        swipeCompleted: { advanceCoach(swiped: true) }, decoratedSpeech: true) { advanceCoach() }
                }
            }
        }
            .fullScreenCover(item: $note) { target in
                MPNoteSheet(title: target.title + " · 备注", text: $noteText, readonly: readonly, error: noteError,
                    close: { note = nil }, save: { saveNote(target) })
                    .ignoresSafeArea(.container, edges: .bottom)
                    .presentationBackground(.clear)
            }
            .fullScreenCover(item: $cost) { group in
                MPInputDialog(title: "添加" + group["title"].string, placeholder: "填写费用名称", text: $costText,
                    error: costError, cancel: { cost = nil }, save: { addCost(group) })
                    .presentationBackground(.clear)
            }
            .toolbar { ToolbarItemGroup(placement: .keyboard) {
                if isActive && note == nil && cost == nil {
                Spacer()
                Button("完成") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    .accessibilityIdentifier("checklist.keyboard.done")
                }
            } }
            .onAppear { refresh(); if showCoach { prepareCoach() } }
            .onChange(of: isActive) { if !isActive { coordinator.close(); dismissGuidance() } }
            .onChange(of: showCoach) { if showCoach { prepareCoach() } }
            .onChange(of: coachStep) { if coachStep == 4 { scrollTarget = coachTarget["field"].id } }
            .task(id: guidanceToken) {
                let incoming = guidance["prompt"]
                guard incoming != .null, canPresentGuide else { visiblePrompt = .null; return }
                guard incoming["id"] != visiblePrompt["id"] else { return }
                visiblePrompt = .null
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
                guard !Task.isCancelled, canPresentGuide else { return }
                returnOffset = scrollPosition.offset
                visiblePrompt = incoming; scrollTarget = ""
                do { try await Task.sleep(for: .milliseconds(20)) } catch { return }
                scrollTarget = "xiaoda.guide"
            }
            .onChange(of: viewKey) {
                coordinator.close()
                if !showCoach && guidance["prompt"] != .null { interaction("view", nil); visiblePrompt = .null; returnOffset = nil }
                refresh()
            }
            .onChange(of: workspace.store.status.revision) { refresh() }
            .fullScreenCover(isPresented: Binding(get: { mediaTarget != nil }, set: { if !$0 { mediaTarget = nil } })) {
                if let mediaTarget { MediaPickerSheet(workspace: workspace, houseID: id, fieldID: mediaTarget) }
            }
    }

    private func heading(_ field: JSONValue, foldKey: String, groupRow: JSONValue? = nil) -> some View {
        MPFieldRow(item: ChecklistPresentation.item(field), state: Binding(get: { ChecklistPresentation.state(field) }, set: { new in
            let old = ChecklistPresentation.state(field)
            if new.flagged != old.flagged { flagBinding(field).wrappedValue = new.flagged }
            if let groupRow, new.skipped != old.skipped { group(groupRow, operation: "skip") }
            else if let groupRow, new.selected != old.selected {
                group(groupRow, operation: "result", value: new.selected.first ?? old.selected.first ?? "")
            } else if new.expanded != old.expanded { setFold(foldKey, new.expanded) }
        }), readonly: readonly, coordinator: coordinator,
            note: { openNote(field) }, capture: { interaction(field.id, nil); mediaTarget = field.id }, interaction: interaction)
    }
    @ViewBuilder private func checklistRow(_ row: JSONValue, hideDivider: Bool) -> some View {
        if row["kind"].string == "add-cost" {
            Button("＋") { if !coordinator.consumeTap() { costText = ""; costError = ""; cost = row } }
                .font(.system(size: 24)).foregroundStyle(Color(red: 141/255, green: 149/255, blue: 163/255))
                .frame(width: 44, height: 44).frame(maxWidth: .infinity).buttonStyle(.plain).disabled(readonly)
                .accessibilityLabel("添加" + row["title"].string).accessibilityIdentifier("checklist.cost.\(row.id)")
        } else if row["kind"].string == "group" {
            VStack(spacing: 0) {
                heading(row["swipe"], foldKey: row.id, groupRow: row)
                FieldRelatedMedia(workspace: workspace, houseID: id, fieldID: row["swipe"].id)
            }
        } else {
            InspectionFieldRow(workspace: workspace, houseID: id, field: row, coordinator: coordinator, hideDivider: hideDivider, editNote: openNote, interaction: interaction)
        }
    }
    private func saveNote(_ target: NoteTarget) {
        do {
            try workspace.store.answer(id, field: target.id, property: "note", value: .string(String(noteText.prefix(10000))))
            if !workspace.store.status.error.isEmpty { throw CoreFailure(message: workspace.store.status.error) }
            note = nil
        } catch { noteError = error.localizedDescription }
    }
    private func addCost(_ row: JSONValue) {
        do {
            try workspace.store.call("addCost", ["id": .string(id), "group": .string(row.id), "value": .string(costText)])
            query = ""; filters = []
            if let topic = workspace.store.house(id)["templateTopics"].array.first(where: { $0["path"].array.contains { $0.id == row.id } }) {
                folds[viewKey, default: [:]][topic["category"].string] = true
            }
            folds[viewKey, default: [:]][row.id] = true; refresh(); cost = nil
        } catch { costError = error.localizedDescription }
    }
    private func group(_ row: JSONValue, operation: String, value: String = "") {
        if workspace.perform({ try workspace.store.call("group", ["id": .string(id), "group": .string(row.id), "property": .string(operation), "value": .string(value)]) }) {
            setFold(row.id, true)
        }
    }
    private func flagBinding(_ field: JSONValue) -> Binding<Bool> {
        Binding(get: { field["problem"].bool }, set: { value in
            workspace.perform { try workspace.store.answer(id, field: field.id, property: "issueFlag", value: .bool(value)) }
        })
    }
    private func openNote(_ field: JSONValue) { interaction(field.id, nil); noteText = field["note"].string; noteError = ""; note = NoteTarget(id: field.id, title: field["label"].string) }
    private func setFold(_ key: String, _ value: Bool) { folds[viewKey, default: [:]][key] = value; refresh() }
    private func refresh() {
        workspace.perform {
            sections = try workspace.store.form(id, phase: phase, query: query, filters: filters.sorted(), folds: folds[viewKey] ?? [:])
            guidance = try workspace.store.call("inspectionGuide", ["id": .string(id)])
        }
    }
    private func prepareCoach() {
        do {
            guidance = try workspace.store.call("inspectionGuide", ["id": .string(id)])
            coachTarget = guidance["target"]; coachStep = guidance["tutorial"].int
            showCoach = coachStep > 0
            if coachStep == 2 { showFilters = true; scrollTarget = "top" }
            if coachStep >= 3 {
                if coachSavedFolds == nil { coachSavedFolds = folds }
                phase = "全部"; query = ""; filters = []; showFilters = false
                if case .object(let expanded) = coachTarget["folds"] { folds[viewKey, default: [:]].merge(expanded.mapValues(\.bool), uniquingKeysWith: { _, new in new }) }
                refresh(); scrollTarget = coachTarget["field"].id
                if coachStep == 4 { coordinator.reveal(coachTarget["field"].id) }
            }
        } catch { workspace.error = error.localizedDescription }
    }
    private func advanceCoach(swiped: Bool = false) {
        guard showCoach, (coachStep == 3) == swiped else { return }
        if workspace.perform({ try workspace.store.call("tutorialAdvance", ["id": .string(id), "value": .string(swiped ? "swiped" : "next")]) }) {
            prepareCoach()
            if !showCoach { coordinator.close(); if let saved = coachSavedFolds { folds = saved; coachSavedFolds = nil }; refresh(); scrollTarget = "xiaoda.guide" }
        } else { coordinator.close() }
    }
    private var canPresentGuide: Bool { isActive && !showCoach && editingField == nil && note == nil && cost == nil && mediaTarget == nil && wheelInput?.target == nil }
    private var guidanceToken: String { guidance["prompt"]["id"].string + "|" + String(canPresentGuide) }
    private func dismissGuidance() {
        if visiblePrompt != .null { workspace.perform { try workspace.store.call("guideAction", ["id": .string(id), "value": .string("later")]) } }
        visiblePrompt = .null; returnOffset = nil
    }
    private func interaction(_ field: String, _ focus: Bool?) {
        if let focus { editingField = focus ? field : nil }
        if focus == false { refresh(); return }
        if showCoach || editingField == field && focus == nil || focus == true && visiblePrompt == .null { return }
        if guidance["prompt"] != .null {
            workspace.perform { try workspace.store.call("guideAction", ["id": .string(id), "value": .string("input")]) }
        }
    }
    private func guideAction(_ action: String) {
        let previousOffset = returnOffset
        let previousView = viewKey
        workspace.perform {
            let result = try workspace.store.call("guideAction", ["id": .string(id), "value": .string(action), "property": prompt["id"]])
            visiblePrompt = .null; returnOffset = nil
            if result["back"].bool { returnToHouses(); return }
            if !result["target"].string.isEmpty {
                phase = result["phase"].string; query = ""; filters = []
                let target = result["target"].string
                let topics = workspace.store.house(id)["templateTopics"].array.filter { $0["category"].string == target }
                folds[viewKey, default: [:]][target] = true
                for topic in topics { for group in topic["path"].array { folds[viewKey, default: [:]][group.id] = true } }
                refresh(); scrollTarget = target
            } else {
                refresh()
                if action == "later", let previousOffset {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(20))
                        if isActive && viewKey == previousView && visiblePrompt == .null { scrollPosition.restore(previousOffset) }
                    }
                }
            }
        }
    }
}

extension JSONValue: Identifiable {
    var rowKey: String { self["key"].string }
    var titleKey: String { self["title"].string }
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
