import SwiftUI

// Checklist and automatic issues edit the same canonical field and answer.
struct InspectionFieldRow: View {
    let workspace: AppWorkspace
    let houseID: String
    let field: JSONValue
    @State private var editingNote = false
    @State private var picking = false
    @State private var commute = false
    @State private var speed = false
    @State private var speedVisit = UUID()
    private var readonly: Bool { workspace.store.house(houseID)["archived"].bool }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if field["map"].bool {
                HousePlaceField(workspace: workspace, id: houseID)
            } else if !field["options"].array.isEmpty && field["inline"].bool && !field["multiple"].bool {
                InspectionChoiceRow(title: field["label"].string, options: field["options"].array.map { $0["value"].string },
                    choiceLabels: Dictionary(uniqueKeysWithValues: field["options"].array.map { ($0["value"].string, $0["label"].string) }),
                    value: answer(), flagged: flag, readonly: readonly, note: { editingNote = true }, capture: { picking = true })
                if !field["note"].string.isEmpty {
                    Button(field["note"].string) { editingNote = true }.font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                }
            } else {
                AnswerInput(field: field, text: answer(), otherText: answer("otherText"), readonly: readonly, showsKeyboardToolbar: false,
                    choose: { value in workspace.perform {
                        try workspace.store.call("choose", ["id": .string(houseID), "field": .string(field.id), "value": .string(value)])
                    } }, action: { action in
                        if action == "备注" { editingNote = true }
                        else if action == "标记问题" { flag.wrappedValue.toggle() }
                        else { picking = true }
                    }, measurement: measurement)
            }
            FieldRelatedMedia(workspace: workspace, houseID: houseID, fieldID: field.id)
        }.sheet(isPresented: $editingNote) {
            NoteEditor(title: field["label"].string + " · 备注", text: field["note"].string, readonly: readonly) { value in
                try workspace.store.answer(houseID, field: field.id, property: "note", value: .string(value))
                if !workspace.store.status.error.isEmpty { throw CoreFailure(message: workspace.store.status.error) }
            }
        }.sheet(isPresented: $picking) { MediaPickerSheet(workspace: workspace, houseID: houseID, fieldID: field.id) }
            .navigationDestination(isPresented: $commute) { CommutePage(workspace: workspace, houseID: houseID, fieldID: field.id) }
            .navigationDestination(isPresented: $speed) { SpeedPage(workspace: workspace, houseID: houseID).id(speedVisit) }
    }
    private func answer(_ property: String = "value") -> Binding<String> {
        Binding(get: { workspace.store.house(houseID)["answers"][field.id][property].string }, set: { value in
            workspace.perform { try workspace.store.answer(houseID, field: field.id, property: property, value: .string(String(value.prefix(10000)))) }
        })
    }
    private var flag: Binding<Bool> {
        Binding(get: { field["problem"].bool }, set: { value in
            workspace.perform { try workspace.store.answer(houseID, field: field.id, property: "issueFlag", value: .bool(value)) }
        })
    }
    private var measurement: MeasurementAction? {
        if UtilityField.mode(field.id) != nil { return MeasurementAction(kind: .commute) { commute = true } }
        if field.id == UtilityField.speed { return MeasurementAction(kind: .speed) { speedVisit = UUID(); speed = true } }
        return nil
    }
}
