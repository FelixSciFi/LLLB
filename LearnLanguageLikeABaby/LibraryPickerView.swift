import SwiftUI

// MARK: - Library Picker Overlay

struct LibraryPickerView: View {
    @ObservedObject var session: LessonSessionModel
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            // ── Tap-outside backdrop ──────────────────────────────────
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // ── Card ─────────────────────────────────────────────────
            VStack(spacing: 0) {
                Text(L("选择句库", "Library", nativeLanguage: session.nativeLanguage))
                    .font(.headline)
                    .padding(.top, 22)
                    .padding(.bottom, 18)

                VStack(spacing: 8) {
                    ForEach(session.availableLibraries) { library in
                        levelButton(library)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 54)
        }
    }

    // MARK: - Level button

    private func levelButton(_ library: LibraryOption) -> some View {
        let isSelected = session.selectedLibraries.contains(library.id)
        let count = session.poolSentences.filter { $0.cefr == library.id }.count

        return Button {
            if isSelected {
                guard session.selectedLibraries.count > 1 else { return }
                session.selectedLibraries.remove(library.id)
            } else {
                session.selectedLibraries.insert(library.id)
            }
            session.saveLibrarySelection()
            session.reloadWithCurrentLibrary()
        } label: {
            HStack(spacing: 0) {
                Text(library.name)
                    .font(.headline)
                Spacer()
                Text("\(count)")
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.75) : Color.lllbSecondaryText)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .padding(.leading, 8)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(
                isSelected
                    ? Color.lllbAccent
                    : Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 13)
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
