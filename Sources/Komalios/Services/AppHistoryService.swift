import Foundation
import FirebaseAuth
import FirebaseFirestore
#if canImport(UIKit)
import UIKit
#endif

struct AppHistoryEvent: Identifiable {
    let id: String
    let url: String
    let searchQuery: String?
    let action: String
    let category: String?
    let subcategory: String?
    let timestamp: Date
    let userEmail: String?
    let uid: String
    let deviceId: String
    let childName: String?
    let ageGroup: String?
    let emojiResponse: String?
    let pageTitle: String?
    let timezone: String?
}

actor AppHistoryService {
    static let shared = AppHistoryService()
    private let db = Firestore.firestore()
    private init() {}

    @discardableResult
    func logEvent(
        url: String, searchQuery: String? = nil, action: String,
        category: String? = nil, subcategory: String? = nil,
        childName: String? = nil, ageGroup: String? = nil,
        emojiResponse: String? = nil, pageTitle: String? = nil
    ) async -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        #if os(iOS)
        let deviceId = await UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        #else
        let deviceId = "unknown"
        #endif

        var data: [String: Any] = ["url": url, "action": action, "timestamp": Timestamp(), "uid": user.uid, "deviceId": deviceId, "timezone": TimeZone.current.identifier]
        if let v = user.email { data["userEmail"] = v }
        if let v = searchQuery { data["searchQuery"] = v }
        if let v = category { data["category"] = v }
        if let v = subcategory { data["subcategory"] = v }
        if let v = childName { data["childName"] = v }
        if let v = ageGroup { data["ageGroup"] = v }
        if let v = emojiResponse { data["emojiResponse"] = v }
        if let v = pageTitle { data["pageTitle"] = v }

        do {
            return try await db.collection("app-history").document(user.uid).collection("events").addDocument(data: data).documentID
        } catch { return nil }
    }

    func fetchHistory(limit: Int = 200) async -> [AppHistoryEvent] {
        guard let user = Auth.auth().currentUser else { return [] }
        do {
            let snap = try await db.collection("app-history").document(user.uid).collection("events")
                .order(by: "timestamp", descending: true).limit(to: limit).getDocuments()
            return snap.documents.compactMap { doc in
                let d = doc.data()
                guard let url = d["url"] as? String, let action = d["action"] as? String,
                      let uid = d["uid"] as? String, let ts = d["timestamp"] as? Timestamp else { return nil }
                return AppHistoryEvent(id: doc.documentID, url: url, searchQuery: d["searchQuery"] as? String,
                    action: action, category: d["category"] as? String, subcategory: d["subcategory"] as? String,
                    timestamp: ts.dateValue(), userEmail: d["userEmail"] as? String, uid: uid,
                    deviceId: d["deviceId"] as? String ?? "unknown", childName: d["childName"] as? String,
                    ageGroup: d["ageGroup"] as? String, emojiResponse: d["emojiResponse"] as? String, pageTitle: d["pageTitle"] as? String,
                    timezone: d["timezone"] as? String)
            }
        } catch { return [] }
    }

    func updateEmojiResponse(documentId: String, emoji: String) async {
        guard let user = Auth.auth().currentUser else { return }
        try? await db.collection("app-history").document(user.uid).collection("events")
            .document(documentId).updateData(["emojiResponse": emoji, "emojiTimestamp": Timestamp()] as [String: Any])
    }

    func updateAction(documentId: String, newAction: String) async {
        guard let user = Auth.auth().currentUser else { return }
        try? await db.collection("app-history").document(user.uid).collection("events")
            .document(documentId).updateData(["action": newAction] as [String: Any])
    }
}
