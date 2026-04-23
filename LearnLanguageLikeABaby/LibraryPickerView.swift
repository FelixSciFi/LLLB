import SwiftUI

// MARK: - Library Picker

struct LibraryPickerView: View {
    @ObservedObject var session: LessonSessionModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        let nl = session.nativeLanguage
        return NavigationStack {
            let libraries = session.availableLibraries
            List {
                ForEach(Array(libraries.enumerated()), id: \.offset) { _, library in
                    HStack {
                        Text(library.name)
                            .font(.body)
                        Spacer()
                        if session.selectedLibraries.contains(library.id) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.lllbAccent)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if session.selectedLibraries.contains(library.id) {
                            if session.selectedLibraries.count > 1 {
                                session.selectedLibraries.remove(library.id)
                                session.saveLibrarySelection()
                            }
                        } else {
                            session.selectedLibraries.insert(library.id)
                            session.saveLibrarySelection()
                        }
                        session.reloadWithCurrentLibrary()
                    }
                }
            }
            .navigationTitle(L("选择句库", "Choose libraries", nativeLanguage: nl))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("完成", "Done", nativeLanguage: nl)) { dismiss() }
                }
            }
        }
    }
}
