import UIKit

/// One-shot haptic feedback helpers. Each call constructs a generator on the
/// fly — fine for discrete tap responses; if a gesture needs sustained feedback
/// (drag tracking etc.) build a long-lived generator instead.
enum Haptics {
    /// Subtle tap — toggle cells, swipe-commit, gesture confirm.
    static func soft()      { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    /// Light click — stepper +/-, library row toggle, token focus, tag chip.
    static func light()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    /// Decisive — play/pause, language card pick, mode change.
    static func medium()    { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    /// Affirmative — like, familiar, archive, milestone collect, unlock pick.
    static func success()   { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    /// Picker-style change between equivalent options.
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}
