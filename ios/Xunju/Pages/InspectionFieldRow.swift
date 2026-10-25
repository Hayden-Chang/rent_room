import SwiftUI

// Checklist and automatic issues edit the same canonical field and answer.
struct InspectionFieldRow: View {
    let workspace: AppWorkspace
    let houseID: String
    let field: JSONValue
    var coordinator = MPSwipeCoordinator()
    var hideDivider = false
    var editNote: ((JSONValue) -> Void)? = nil
    @Environment(\.wheelInput) private var wheelInput
    var interaction: (String, Bool?) -> Void = { _, _ in }
    @State private var noteText = ""
    @State private var noteError = ""
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
            } else {
                MPFieldRow(item: ChecklistPresentation.item(field, hideDivider: hideDivider),
                    state: Binding(get: { ChecklistPresentation.state(field) }, set: { value in
                        interaction(field.id, nil)
                        workspace.perform { try ChecklistPresentation.write(value, from: field, houseID: houseID, store: workspace.store) }
                    }), readonly: readonly, coordinator: coordinator,
                    note: {
                        interaction(field.id, nil)
                        if let editNote { editNote(field) }
                        else { noteText = field["note"].string; noteError = ""; editingNote = true }
                    }, capture: { interaction(field.id, nil); picking = true }, measurement: measurement,
                    wheel: { interaction(field.id, nil); wheelInput?.open(houseID: houseID, field: field, store: workspace.store) }, interaction: interaction)
            }
            FieldRelatedMedia(workspace: workspace, houseID: houseID, fieldID: field.id)
        }.fullScreenCover(isPresented: $editingNote) {
            MPNoteSheet(title: field["label"].string + " · 备注", text: $noteText, readonly: readonly, error: noteError,
                close: { editingNote = false }, save: {
                    do {
                        try workspace.store.answer(houseID, field: field.id, property: "note", value: .string(String(noteText.prefix(10000))))
                        if !workspace.store.status.error.isEmpty { throw CoreFailure(message: workspace.store.status.error) }
                        editingNote = false
                    } catch { noteError = error.localizedDescription }
                }).ignoresSafeArea(.container, edges: .bottom).presentationBackground(.clear)
        }.sheet(isPresented: $picking) { MediaPickerSheet(workspace: workspace, houseID: houseID, fieldID: field.id) }
            .navigationDestination(isPresented: $commute) { CommutePage(workspace: workspace, houseID: houseID, fieldID: field.id) }
            .navigationDestination(isPresented: $speed) { SpeedPage(workspace: workspace, houseID: houseID).id(speedVisit) }
    }
    private var measurement: MeasurementAction? {
        if UtilityField.mode(field.id) != nil { return MeasurementAction(kind: .commute) { interaction(field.id, nil); commute = true } }
        if field.id == UtilityField.speed { return MeasurementAction(kind: .speed) { interaction(field.id, nil); speedVisit = UUID(); speed = true } }
        return nil
    }
}
