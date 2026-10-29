import XCTest

extension XCUIElement {
    @MainActor func replacePromptText(_ text: String) {
        tap()
        let existing = value as? String ?? ""
        if !existing.isEmpty { typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count)) }
        typeText(text)
    }
}
