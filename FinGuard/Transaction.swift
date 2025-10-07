import Foundation
import FirebaseFirestore
import FirebaseStorage

struct Transaction: Identifiable, Codable {
    enum TxType: String, Codable { case income, expense }

    var id: String = UUID().uuidString
    let userId: String
    let type: TxType
    let amount: Double
    let category: String
    let account: String
    let note: String?
    let date: Date
    let month: String    // e.g., "October"
    let year: Int
    var attachmentURL: String?
}

final class TransactionService {
    static let shared = TransactionService()
    private init() {}

    private var db: Firestore { Firestore.firestore() }
    private var storage: Storage { Storage.storage() }

    /// Add a transaction document; if a receipt is provided, upload to Storage and link.
    @discardableResult
    func addTransaction(_ tx: Transaction, receiptData: Data?) async throws -> String {
        var doc = tx
        let docRef = db.collection("transactions").document() // generate ID first
        var attachmentURL: String?

        // Upload receipt if provided
        if let data = receiptData {
            let path = "users/\(tx.userId)/receipts/\(docRef.documentID).jpg"
            let ref = storage.reference().child(path)
            let meta = StorageMetadata()
            meta.contentType = "image/jpeg"
            _ = try await ref.putDataAsync(data, metadata: meta)
            attachmentURL = try await ref.downloadURL().absoluteString
        }

        doc.id = docRef.documentID
        doc.attachmentURL = attachmentURL

        // Firestore encode (manual to ensure control)
        let payload: [String: Any] = [
            "id": doc.id,
            "userId": doc.userId,
            "type": doc.type.rawValue,
            "amount": doc.amount,
            "category": doc.category,
            "account": doc.account,
            "note": doc.note as Any,
            "date": Timestamp(date: doc.date),
            "month": doc.month,
            "year": doc.year,
            "attachmentURL": doc.attachmentURL as Any
        ]

        try await docRef.setData(payload, merge: false)
        return doc.id
    }
}
