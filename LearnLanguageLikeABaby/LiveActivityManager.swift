import ActivityKit
import Foundation

@available(iOS 16.2, *)
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var activity: Activity<LLLBActivityAttributes>?

    static let enabledKey = "liveActivityEnabled"

    /// Persisted toggle — defaults to false until user explicitly enables.
    var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            if !newValue { end() }
        }
    }

    func start(state: LLLBActivityAttributes.ContentState) {
        guard enabled else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if activity == nil {
            let attributes = LLLBActivityAttributes()
            activity = try? Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
            return
        }
        update(state: state)
    }

    func update(state: LLLBActivityAttributes.ContentState) {
        guard enabled else { return }
        Task {
            await activity?.update(.init(state: state, staleDate: nil))
        }
    }

    func end() {
        Task {
            await activity?.end(nil, dismissalPolicy: .immediate)
            activity = nil
        }
    }
}
