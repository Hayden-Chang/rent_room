import SwiftUI

// Checklist and automatic issues edit the same canonical field and answer.
struct InspectionFieldRow: View {
    let workspace: AppWorkspace
    let houseID: String
    let field: JSONValue
    var coordinator = MPSwipeCoordinator()
    var hideDivider = false
    var editNote: ((JSONValue) -> Void)? = nil
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
                        workspace.perform { try ChecklistPresentation.write(value, from: field, houseID: houseID, store: workspace.store) }
                    }), readonly: readonly, coordinator: coordinator,
                    note: {
                        if let editNote { editNote(field) }
                        else { noteText = field["note"].string; noteError = ""; editingNote = true }
                    }, capture: { picking = true }, measurement: measurement)
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
        if UtilityField.mode(field.id) != nil { return MeasurementAction(kind: .commute) { commute = true } }
        if field.id == UtilityField.speed { return MeasurementAction(kind: .speed) { speedVisit = UUID(); speed = true } }
        return nil
    }
}
