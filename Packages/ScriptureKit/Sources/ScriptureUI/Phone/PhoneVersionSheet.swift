#if os(iOS)
import SwiftUI

/// A kept version whose note is gone, over the Notes tab (spec 4.2): the reference as the title,
/// its text with Restore as a Note and Discard, and Done in the confirmation slot. It closes by
/// itself once the choice is made. `.medium` and `.large`, on `paper.page`, as the note sheet is.
public struct PhoneVersionSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let id: UUID
    private let reference: String
    private let model: NoteVersionsModel
    private let undoManager: UndoManager?

    public init(id: UUID, reference: String, model: NoteVersionsModel, undoManager: UndoManager?) {
        self.id = id
        self.reference = reference
        self.model = model
        self.undoManager = undoManager
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                NoteVersionsView(subject: .orphan(id), model: model, undoManager: undoManager) { dismiss() }
                    .padding(AppSpacing.md)
            }
            .containerBackground(Color.paperPage, for: .navigation)
            .navigationTitle(reference)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
            // The sheet holds no first responder, and a shake asks the first responder for its undo
            // manager: this one answers with the tab's, so a Discard comes back.
            .background { UndoResponder(undoManager: undoManager).frame(width: 0, height: 0) }
        }
        .presentationDetents([.medium, .large])
        .tint(Color.accent)
    }
}
#endif
