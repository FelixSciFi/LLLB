import Foundation

/// Mirrors a curated set of UserDefaults keys to NSUbiquitousKeyValueStore so
/// that user progress survives uninstall/reinstall on the same iCloud account.
///
/// **Scope (MVP)**: single-device restore. Multi-device merge is NOT in this
/// version — see project_backlog.md → "iCloud KVS for cross-device + uninstall-
/// survival persistence" for the eventual two-way sync plan.
///
/// **Sync model**: write-through. Every UserDefaults change triggers a 2-second
/// debounced flush of all whitelisted keys to KVS. On launch, if local has no
/// progress data and KVS does, we restore the whitelisted keys from KVS into
/// local UserDefaults *before* any model reads them.
///
/// **Excluded from sync** (intentional):
/// - `cup_minutes_*` — daily playback budget; syncing would let users dodge the
///   cap by hopping devices
/// - `speed_*`, `repeats_*`, `show*_*`, `playMode_*`, `voiceByLanguage`,
///   `interSentencePause`, `*Mode_*` — device-local UI prefs (phone vs iPad)
/// - `pendingUnlock_*`, `pendingCandidates_*`, `pendingRemaining_*`,
///   `knownLibraries_*` — transient or per-device state
@MainActor
final class iCloudSync {
    static let shared = iCloudSync()

    private let local = UserDefaults.standard
    private let cloud = NSUbiquitousKeyValueStore.default

    /// Bump if the synced key shape changes incompatibly with older app
    /// versions (e.g. removing/renaming a synced key, changing its value type).
    /// Older app versions ignore data with a higher schema; current code
    /// only refuses to *restore* data with a different schema.
    private static let schemaVersion: Int64 = 1
    private static let schemaVersionKey = "icloud_schema_version_v1"

    /// Static keys (single string each, no per-language fanout).
    private static let staticSyncedKeys: Set<String> = [
        "selectedLearningLanguage",
        "native_language",
        "candy_balance",
        "owned_lemmas_v3",
        "owned_sentences_v1",
        "candy_initialized_v3",
        "candy_bootstrap_version",
        "daily_free_remaining",
        "daily_free_date",
        "streakCount_v1",
        "streakLastDate_v1",
        "usageTimeByDate_v1",
        "usageBgTimeByDate_v1",
        "onboardingCompleted_v1",
        "achievement_lifetime_v1",
        "achievement_period_v1",
        "achievement_pending_v1",
    ]

    /// Per-language key prefixes — each is expanded to `{prefix}{lang}`
    /// for every supported language.
    private static let perLangPrefixesSynced: [String] = [
        "selectedLibraries_",
        "favoritedIDs_",
        "masteredIDs_",
        "laterIDs_",
        "familiarIDs_",
        "pool_",
        "poolCapacity_",
        "lifetimePlayCounts_",
        "placementShown_",
        "soldIDs_",
    ]

    /// Languages the app supports for content. Adding a new language here
    /// means its per-language progress keys start syncing too.
    private static let supportedLanguages: [String] = [
        "fr", "zh", "en", "es", "ja", "ko", "de", "ar",
    ]

    private static func computeAllSyncedKeys() -> Set<String> {
        var keys = staticSyncedKeys
        for prefix in perLangPrefixesSynced {
            for lang in supportedLanguages {
                keys.insert(prefix + lang)
            }
        }
        return keys
    }

    private let allSyncedKeys: Set<String> = computeAllSyncedKeys()

    private var debounceTask: DispatchWorkItem?
    private var notificationObserver: NSObjectProtocol?

    /// While true, UserDefaults change notifications are ignored — used to
    /// suppress outbound flushes during the inbound restore at boot.
    private var isApplyingRestore = false

    /// Set by `bootstrap()` if a restore actually copied data from KVS.
    /// RootView reads this to decide whether to flash the "已恢复" toast.
    private(set) var didRestoreFromCloud: Bool = false

    private init() {}

    /// Call this **before** any persistence-aware model reads UserDefaults
    /// (i.e. as the first line of AppModel.init). Returns true if a restore
    /// happened.
    @discardableResult
    func bootstrap() -> Bool {
        // Best-effort pull. KVS will continue syncing in background, but
        // values it returns now are good enough for the boot decision.
        cloud.synchronize()

        let cloudHasData = cloud.longLong(forKey: Self.schemaVersionKey) > 0
        // "Has local progress" probe — selectedLearningLanguage is set on
        // first language pick, onboardingCompleted_v1 on welcome flow finish.
        // Either signal means this isn't a fresh install.
        let localHasData = local.string(forKey: "selectedLearningLanguage") != nil
            || local.bool(forKey: "onboardingCompleted_v1")

        if !localHasData && cloudHasData {
            isApplyingRestore = true
            for key in allSyncedKeys {
                if let value = cloud.object(forKey: key) {
                    local.set(value, forKey: key)
                }
            }
            isApplyingRestore = false
            didRestoreFromCloud = true
        }

        // Stamp schema version (idempotent — only writes when different).
        if cloud.longLong(forKey: Self.schemaVersionKey) != Self.schemaVersion {
            cloud.set(Self.schemaVersion, forKey: Self.schemaVersionKey)
        }

        startMonitoring()
        return didRestoreFromCloud
    }

    private func startMonitoring() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: local,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleFlush()
            }
        }
    }

    private func scheduleFlush() {
        guard !isApplyingRestore else { return }
        debounceTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.flushToCloud()
            }
        }
        debounceTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
    }

    private func flushToCloud() {
        for key in allSyncedKeys {
            if let value = local.object(forKey: key) {
                cloud.set(value, forKey: key)
            }
            // Don't `removeObject` for missing local keys — leaves cloud
            // intact so a buggy local wipe can't nuke the user's cloud
            // backup. Multi-device delete propagation is a v2 concern.
        }
        cloud.synchronize()
    }
}
