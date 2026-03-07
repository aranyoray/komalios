#if os(iOS)
import Foundation
import FirebaseAuth
import FirebaseFirestore
import os.log

private let log = Logger(subsystem: "com.komalkids.komal", category: "FirestoreSync")

/// Central Firestore sync coordinator.
/// Offline-first: local storage is primary, Firestore is cloud backup.
/// Uploads fire-and-forget after local saves; downloads merge on login.
actor FirestoreSyncService {
    static let shared = FirestoreSyncService()
    private let db = Firestore.firestore()
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Upload: Settings

    /// Upload content filter prefs, profile, retention, account mode to `users/{uid}/sync/settings`
    func uploadSettings(
        uid: String,
        filterPrefs: ContentFilterPreferences,
        profile: ChildProfile,
        retention: RetentionState,
        accountMode: AccountMode,
        parentSettings: ParentSettings
    ) {
        let path = "users/\(uid)/sync/settings"
        do {
            let encoder = JSONEncoder()
            let filterData = try encoder.encode(filterPrefs)
            let profileData = try encoder.encode(profile)
            let retentionData = try encoder.encode(retention)
            let accountModeData = try encoder.encode(accountMode)
            let parentData = try encoder.encode(parentSettings)

            let payload: [String: Any] = [
                "filterPrefs": filterData.base64EncodedString(),
                "profile": profileData.base64EncodedString(),
                "retention": retentionData.base64EncodedString(),
                "accountMode": accountModeData.base64EncodedString(),
                "parentSettings": parentData.base64EncodedString(),
                "lastModified": FieldValue.serverTimestamp()
            ]
            let payloadSize = filterData.count + profileData.count + retentionData.count + accountModeData.count + parentData.count
            db.collection("users").document(uid).collection("sync").document("settings")
                .setData(payload, merge: true)
            log.info("UPLOAD \(path) — \(payloadSize) bytes (settings)")
        } catch {
            log.error("UPLOAD FAILED \(path) — encode error: \(error.localizedDescription)")
        }
    }

    // MARK: - Upload: Mood Data

    func uploadMoodData(uid: String, entries: MoodEntriesData) {
        let path = "users/\(uid)/sync/mood-data"
        do {
            let data = try JSONEncoder().encode(entries)
            let payload: [String: Any] = [
                "data": data.base64EncodedString(),
                "lastModified": FieldValue.serverTimestamp()
            ]
            db.collection("users").document(uid).collection("sync").document("mood-data")
                .setData(payload, merge: true)
            log.info("UPLOAD \(path) — \(data.count) bytes (\(entries.entries.count) entries)")
        } catch {
            log.error("UPLOAD FAILED \(path) — encode error: \(error.localizedDescription)")
        }
    }

    // MARK: - Upload: Growth Data

    func uploadGrowthData(uid: String, data growthData: GrowthData) {
        let path = "users/\(uid)/sync/growth-data"
        do {
            let encoded = try JSONEncoder().encode(growthData)
            let payload: [String: Any] = [
                "data": encoded.base64EncodedString(),
                "lastModified": FieldValue.serverTimestamp()
            ]
            db.collection("users").document(uid).collection("sync").document("growth-data")
                .setData(payload, merge: true)
            log.info("UPLOAD \(path) — \(encoded.count) bytes (\(growthData.dailyActivities.count) activities, \(growthData.milestones.count) milestones)")
        } catch {
            log.error("UPLOAD FAILED \(path) — encode error: \(error.localizedDescription)")
        }
    }

    // MARK: - Upload: Conversation Meta

    func uploadConversationMeta(
        uid: String,
        entities: [ConversationEntity],
        signals: [DevelopmentalSignal]
    ) {
        let path = "users/\(uid)/sync/conversation-meta"
        do {
            let encoder = JSONEncoder()
            let entitiesData = try encoder.encode(entities)
            let signalsData = try encoder.encode(signals)

            let payload: [String: Any] = [
                "entities": entitiesData.base64EncodedString(),
                "signals": signalsData.base64EncodedString(),
                "lastModified": FieldValue.serverTimestamp()
            ]
            db.collection("users").document(uid).collection("sync").document("conversation-meta")
                .setData(payload, merge: true)
            let totalSize = entitiesData.count + signalsData.count
            log.info("UPLOAD \(path) — \(totalSize) bytes (\(entities.count) entities, \(signals.count) signals)")
        } catch {
            log.error("UPLOAD FAILED \(path) — encode error: \(error.localizedDescription)")
        }
    }

    // MARK: - Upload: Browsing Session

    func uploadBrowsingSession(uid: String, session: BrowsingSession) {
        let path = "users/\(uid)/browsing-sessions/\(session.id.uuidString)"
        do {
            let data = try JSONEncoder().encode(session)
            let payload: [String: Any] = [
                "data": data.base64EncodedString(),
                "startTime": Timestamp(date: session.startTime),
                "lastModified": FieldValue.serverTimestamp()
            ]
            db.collection("users").document(uid)
                .collection("browsing-sessions").document(session.id.uuidString)
                .setData(payload, merge: true)
            log.info("UPLOAD \(path) — \(data.count) bytes (\(session.events.count) events)")
        } catch {
            log.error("UPLOAD FAILED \(path) — encode error: \(error.localizedDescription)")
        }
    }

    // MARK: - Upload: Conversation Session

    func uploadConversationSession(uid: String, session: ConversationSession) {
        guard session.memoryTier == .fullText || session.memoryTier == .summarized else {
            log.debug("UPLOAD SKIP users/\(uid)/conversation-sessions/\(session.id.uuidString) — tier=\(session.memoryTier.rawValue)")
            return
        }
        let path = "users/\(uid)/conversation-sessions/\(session.id.uuidString)"
        do {
            let data = try JSONEncoder().encode(session)
            let payload: [String: Any] = [
                "data": data.base64EncodedString(),
                "startTime": Timestamp(date: session.startTime),
                "lastModified": FieldValue.serverTimestamp()
            ]
            db.collection("users").document(uid)
                .collection("conversation-sessions").document(session.id.uuidString)
                .setData(payload, merge: true)
            log.info("UPLOAD \(path) — \(data.count) bytes (\(session.messages.count) messages, tier=\(session.memoryTier.rawValue))")
        } catch {
            log.error("UPLOAD FAILED \(path) — encode error: \(error.localizedDescription)")
        }
    }

    // MARK: - Upload: SEL Record

    func uploadSELRecord(uid: String, record: SELDailyRecord) {
        let path = "users/\(uid)/sel-records/\(record.date)"
        do {
            let data = try JSONEncoder().encode(record)
            let payload: [String: Any] = [
                "data": data.base64EncodedString(),
                "date": record.date,
                "lastModified": FieldValue.serverTimestamp()
            ]
            db.collection("users").document(uid)
                .collection("sel-records").document(record.date)
                .setData(payload, merge: true)
            log.info("UPLOAD \(path) — \(data.count) bytes (\(record.checkResults.count) checks)")
        } catch {
            log.error("UPLOAD FAILED \(path) — encode error: \(error.localizedDescription)")
        }
    }

    // MARK: - Download: Settings

    func downloadSettings(uid: String) async -> (
        filterPrefs: ContentFilterPreferences,
        profile: ChildProfile,
        retention: RetentionState,
        accountMode: AccountMode,
        parentSettings: ParentSettings
    )? {
        let path = "users/\(uid)/sync/settings"
        do {
            let doc = try await db.collection("users").document(uid)
                .collection("sync").document("settings").getDocument()
            guard let docData = doc.data() else {
                log.info("DOWNLOAD \(path) — no document found")
                return nil
            }

            let decoder = JSONDecoder()
            guard let filterB64 = docData["filterPrefs"] as? String,
                  let profileB64 = docData["profile"] as? String,
                  let retentionB64 = docData["retention"] as? String,
                  let accountModeB64 = docData["accountMode"] as? String,
                  let parentB64 = docData["parentSettings"] as? String,
                  let filterData = Data(base64Encoded: filterB64),
                  let profileData = Data(base64Encoded: profileB64),
                  let retentionData = Data(base64Encoded: retentionB64),
                  let accountModeData = Data(base64Encoded: accountModeB64),
                  let parentData = Data(base64Encoded: parentB64)
            else {
                log.warning("DOWNLOAD \(path) — malformed document data")
                return nil
            }

            let filterPrefs = try decoder.decode(ContentFilterPreferences.self, from: filterData)
            let profile = try decoder.decode(ChildProfile.self, from: profileData)
            let retention = try decoder.decode(RetentionState.self, from: retentionData)
            let accountMode = try decoder.decode(AccountMode.self, from: accountModeData)
            let parentSettings = try decoder.decode(ParentSettings.self, from: parentData)

            let totalSize = filterData.count + profileData.count + retentionData.count + accountModeData.count + parentData.count
            log.info("DOWNLOAD \(path) — \(totalSize) bytes (settings)")
            return (filterPrefs, profile, retention, accountMode, parentSettings)
        } catch {
            log.error("DOWNLOAD FAILED \(path) — \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Download: Mood Data

    func downloadMoodData(uid: String) async -> MoodEntriesData? {
        let path = "users/\(uid)/sync/mood-data"
        do {
            let doc = try await db.collection("users").document(uid)
                .collection("sync").document("mood-data").getDocument()
            guard let docData = doc.data(),
                  let b64 = docData["data"] as? String,
                  let data = Data(base64Encoded: b64) else {
                log.info("DOWNLOAD \(path) — no document found")
                return nil
            }
            let result = try JSONDecoder().decode(MoodEntriesData.self, from: data)
            log.info("DOWNLOAD \(path) — \(data.count) bytes (\(result.entries.count) entries)")
            return result
        } catch {
            log.error("DOWNLOAD FAILED \(path) — \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Download: Growth Data

    func downloadGrowthData(uid: String) async -> GrowthData? {
        let path = "users/\(uid)/sync/growth-data"
        do {
            let doc = try await db.collection("users").document(uid)
                .collection("sync").document("growth-data").getDocument()
            guard let docData = doc.data(),
                  let b64 = docData["data"] as? String,
                  let data = Data(base64Encoded: b64) else {
                log.info("DOWNLOAD \(path) — no document found")
                return nil
            }
            let result = try JSONDecoder().decode(GrowthData.self, from: data)
            log.info("DOWNLOAD \(path) — \(data.count) bytes (\(result.dailyActivities.count) activities)")
            return result
        } catch {
            log.error("DOWNLOAD FAILED \(path) — \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Download: Conversation Meta

    func downloadConversationMeta(uid: String) async -> (
        entities: [ConversationEntity],
        signals: [DevelopmentalSignal]
    )? {
        let path = "users/\(uid)/sync/conversation-meta"
        do {
            let doc = try await db.collection("users").document(uid)
                .collection("sync").document("conversation-meta").getDocument()
            guard let docData = doc.data(),
                  let entitiesB64 = docData["entities"] as? String,
                  let signalsB64 = docData["signals"] as? String,
                  let entitiesData = Data(base64Encoded: entitiesB64),
                  let signalsData = Data(base64Encoded: signalsB64)
            else {
                log.info("DOWNLOAD \(path) — no document found")
                return nil
            }

            let decoder = JSONDecoder()
            let entities = try decoder.decode([ConversationEntity].self, from: entitiesData)
            let signals = try decoder.decode([DevelopmentalSignal].self, from: signalsData)
            let totalSize = entitiesData.count + signalsData.count
            log.info("DOWNLOAD \(path) — \(totalSize) bytes (\(entities.count) entities, \(signals.count) signals)")
            return (entities, signals)
        } catch {
            log.error("DOWNLOAD FAILED \(path) — \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Download: Browsing Sessions

    func downloadBrowsingSessions(uid: String, limit: Int = 50) async -> [BrowsingSession] {
        let path = "users/\(uid)/browsing-sessions"
        do {
            let snapshot = try await db.collection("users").document(uid)
                .collection("browsing-sessions")
                .order(by: "startTime", descending: true)
                .limit(to: limit)
                .getDocuments()

            let decoder = JSONDecoder()
            let results = snapshot.documents.compactMap { doc -> BrowsingSession? in
                guard let b64 = doc.data()["data"] as? String,
                      let data = Data(base64Encoded: b64) else { return nil }
                return try? decoder.decode(BrowsingSession.self, from: data)
            }
            log.info("DOWNLOAD \(path) — \(snapshot.documents.count) docs fetched, \(results.count) decoded")
            return results
        } catch {
            log.error("DOWNLOAD FAILED \(path) — \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Download: Conversation Sessions

    func downloadConversationSessions(uid: String) async -> [ConversationSession] {
        let path = "users/\(uid)/conversation-sessions"
        do {
            let snapshot = try await db.collection("users").document(uid)
                .collection("conversation-sessions")
                .order(by: "startTime", descending: true)
                .getDocuments()

            let decoder = JSONDecoder()
            let results = snapshot.documents.compactMap { doc -> ConversationSession? in
                guard let b64 = doc.data()["data"] as? String,
                      let data = Data(base64Encoded: b64) else { return nil }
                return try? decoder.decode(ConversationSession.self, from: data)
            }
            log.info("DOWNLOAD \(path) — \(snapshot.documents.count) docs fetched, \(results.count) decoded")
            return results
        } catch {
            log.error("DOWNLOAD FAILED \(path) — \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Download: SEL Records

    func downloadSELRecords(uid: String, days: Int = 90) async -> [SELDailyRecord] {
        let path = "users/\(uid)/sel-records"
        do {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let cutoffStr = Self.dateFormatter.string(from: cutoffDate)

            let snapshot = try await db.collection("users").document(uid)
                .collection("sel-records")
                .whereField("date", isGreaterThanOrEqualTo: cutoffStr)
                .getDocuments()

            let decoder = JSONDecoder()
            let results = snapshot.documents.compactMap { doc -> SELDailyRecord? in
                guard let b64 = doc.data()["data"] as? String,
                      let data = Data(base64Encoded: b64) else { return nil }
                return try? decoder.decode(SELDailyRecord.self, from: data)
            }
            log.info("DOWNLOAD \(path) — \(snapshot.documents.count) docs fetched, \(results.count) decoded (cutoff=\(cutoffStr))")
            return results
        } catch {
            log.error("DOWNLOAD FAILED \(path) — \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Full Sync on Login

    /// Orchestrates downloading all cloud data and merging with local services.
    /// Called once after successful Firebase Auth login.
    /// `appState` is passed in because it's not a singleton — it's owned by SwiftUI.
    func syncOnLogin(uid: String, appState: AppState) async {
        log.info("SYNC START for uid=\(uid)")

        // Download all data in parallel
        async let settingsTask = downloadSettings(uid: uid)
        async let moodTask = downloadMoodData(uid: uid)
        async let growthTask = downloadGrowthData(uid: uid)
        async let conversationMetaTask = downloadConversationMeta(uid: uid)
        async let browsingTask = downloadBrowsingSessions(uid: uid)
        async let conversationTask = downloadConversationSessions(uid: uid)
        async let selTask = downloadSELRecords(uid: uid)

        let settings = await settingsTask
        let moodData = await moodTask
        let growthData = await growthTask
        let conversationMeta = await conversationMetaTask
        let browsingSessions = await browsingTask
        let conversationSessions = await conversationTask
        let selRecords = await selTask

        // Merge with local services (must happen on MainActor for @Published properties)
        await MainActor.run {
            if let s = settings {
                appState.applyCloudSettings(
                    filterPrefs: s.filterPrefs,
                    profile: s.profile,
                    retention: s.retention,
                    accountMode: s.accountMode,
                    parentSettings: s.parentSettings
                )
                log.info("MERGE settings applied")
            }

            if let mood = moodData {
                MoodTrackingService.shared.mergeCloudData(mood)
                log.info("MERGE mood data — \(mood.entries.count) cloud entries")
            }

            if let growth = growthData {
                GrowthTrackingService.shared.mergeCloudData(growth)
                log.info("MERGE growth data — \(growth.dailyActivities.count) cloud activities")
            }

            if let meta = conversationMeta {
                ConversationMemoryService.shared.mergeCloudData(
                    sessions: conversationSessions,
                    entities: meta.entities,
                    signals: meta.signals
                )
                log.info("MERGE conversation data — \(conversationSessions.count) sessions, \(meta.entities.count) entities, \(meta.signals.count) signals")
            } else if !conversationSessions.isEmpty {
                ConversationMemoryService.shared.mergeCloudData(
                    sessions: conversationSessions,
                    entities: [],
                    signals: []
                )
                log.info("MERGE conversation sessions only — \(conversationSessions.count) sessions (no meta)")
            }

            if !browsingSessions.isEmpty {
                BrowsingHistoryService.shared.mergeCloudSessions(browsingSessions)
                log.info("MERGE browsing sessions — \(browsingSessions.count) cloud sessions")
            }

            if !selRecords.isEmpty {
                SELAssessmentService.shared.mergeCloudRecords(selRecords)
                log.info("MERGE SEL records — \(selRecords.count) cloud records")
            }
        }

        log.info("SYNC COMPLETE for uid=\(uid)")
    }

    // MARK: - Account Deletion

    /// Deletes all synced Firestore data for a user (COPPA requirement).
    func deleteAllUserData(uid: String) async {
        log.info("DELETE START for uid=\(uid)")

        // Delete sync documents
        let syncDocs = ["settings", "mood-data", "growth-data", "conversation-meta"]
        for docName in syncDocs {
            try? await db.collection("users").document(uid)
                .collection("sync").document(docName).delete()
            log.info("DELETE users/\(uid)/sync/\(docName)")
        }

        // Delete browsing-sessions subcollection
        await deleteSubcollection(path: "users/\(uid)/browsing-sessions")

        // Delete conversation-sessions subcollection
        await deleteSubcollection(path: "users/\(uid)/conversation-sessions")

        // Delete sel-records subcollection
        await deleteSubcollection(path: "users/\(uid)/sel-records")

        // Delete app-history events subcollection (COPPA: browsing history)
        await deleteSubcollection(path: "app-history/\(uid)/events")
        try? await db.collection("app-history").document(uid).delete()
        log.info("DELETE app-history/\(uid)")

        log.info("DELETE COMPLETE for uid=\(uid)")
    }

    // MARK: - Helpers

    /// Batch-delete all documents in a subcollection (chunked to stay within Firestore's 500-op batch limit).
    private func deleteSubcollection(path: String) async {
        do {
            let snapshot = try await db.collection(path).getDocuments()
            guard !snapshot.documents.isEmpty else {
                log.info("DELETE \(path) — empty, nothing to delete")
                return
            }

            let batchLimit = 500
            var deleted = 0
            for chunkStart in stride(from: 0, to: snapshot.documents.count, by: batchLimit) {
                let chunkEnd = min(chunkStart + batchLimit, snapshot.documents.count)
                let chunk = snapshot.documents[chunkStart..<chunkEnd]
                let batch = db.batch()
                for doc in chunk {
                    batch.deleteDocument(doc.reference)
                }
                try await batch.commit()
                deleted += chunk.count
            }
            log.info("DELETE \(path) — \(deleted) docs deleted")
        } catch {
            log.error("DELETE FAILED \(path) — \(error.localizedDescription)")
        }
    }
}
#endif
