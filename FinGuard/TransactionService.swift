//
//  TransactionService.swift
//  FinGuard
//
//  Created by Sandil on 2025-10-07.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage

// MARK: - TransactionService

final class TransactionService {

    // Singleton instance
    static let shared = TransactionService()
    private init() {}

    // Firebase references
    private var db: Firestore { Firestore.firestore() }
    private var storage: Storage { Storage.storage() }
    private var col: CollectionReference { db.collection("transactions") }

    // MARK: - Add Transaction
    @discardableResult
    func add(_ tx: Transaction, receiptData: Data? = nil) async throws -> String {
        var doc = tx
        let docRef = col.document()
        var attachmentURL: String?

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

        try await docRef.setData(payload)
        print("✅ Transaction added: \(doc.id)")
        return doc.id
    }

    // MARK: - Fetch (One-shot)
    func fetch(for userId: String, month: String? = nil) async throws -> [Transaction] {
        var q: Query = col.whereField("userId", isEqualTo: userId)
        if let month { q = q.whereField("month", isEqualTo: month) }

        let snap = try await q.getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Transaction.self) }
    }

    // MARK: - Sum Helper
    func sum(for userId: String, month: String? = nil, type: Transaction.TxType) async throws -> Double {
        let items = try await fetch(for: userId, month: month)
        return items.filter { $0.type == type }.reduce(0) { $0 + $1.amount }
    }

    // MARK: - Live Monthly Listener
    // MARK: - Live Monthly Listener (now by date range)
    func listen(for userId: String,
                month: String? = nil,
                onChange: @escaping ([Transaction]) -> Void) -> ListenerRegistration {

        var q: Query = col.whereField("userId", isEqualTo: userId)

        if let month, let start = Date.fromYearMonthKey(month) {
            // Use the 'date' field to include all docs for this month, regardless of how "month" string is stored.
            let end = Calendar.current.date(byAdding: .month, value: 1, to: start)!
            q = q
                .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: start))
                .whereField("date", isLessThan: Timestamp(date: end))
        } else if let month {
            // Fallback to old behavior if a non "yyyy-MM" string is ever passed in.
            q = q.whereField("month", isEqualTo: month)
        }

        return q.addSnapshotListener { snap, err in
            if let err = err {
                print("❌ Listen error:", err.localizedDescription)
                onChange([])
                return
            }
            guard let docs = snap?.documents else { onChange([]); return }

            // Use Codable decoding
            let items: [Transaction] = docs.compactMap { try? $0.data(as: Transaction.self) }
            onChange(items)
        }
    }


    // MARK: - Yearly Listener (for StatsView)
    func listenYear(for userId: String, year: Int, onChange: @escaping ([Transaction]) -> Void) -> ListenerRegistration {
        let q = col
            .whereField("userId", isEqualTo: userId)
            .whereField("year", isEqualTo: year)

        return q.addSnapshotListener { snap, err in
            if let err = err {
                print("❌ listenYear error:", err.localizedDescription)
                onChange([])
                return
            }

            guard let docs = snap?.documents else {
                onChange([])
                return
            }

            let txs = docs.compactMap { d -> Transaction? in
                let data = d.data()
                guard
                    let typeStr = data["type"] as? String,
                    let type = Transaction.TxType(rawValue: typeStr),
                    let amount = data["amount"] as? Double,
                    let category = data["category"] as? String,
                    let account = data["account"] as? String,
                    let date = (data["date"] as? Timestamp)?.dateValue(),
                    let month = data["month"] as? String,
                    let year = data["year"] as? Int
                else { return nil }

                return Transaction(
                    id: d.documentID,
                    userId: userId,
                    type: type,
                    amount: amount,
                    category: category,
                    account: account,
                    note: data["note"] as? String,
                    date: date,
                    month: month,
                    year: year,
                    attachmentURL: data["attachmentURL"] as? String
                )
            }

            print("📈 listenYear fetched \(txs.count) transactions for year \(year)")
            onChange(txs)
        }
    }
}
// MARK: - Year-Month parsing
extension Date {
    /// Parse "yyyy-MM" -> first day of that month at 00:00
    static func fromYearMonthKey(_ key: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.timeZone = .current
        guard let d = f.date(from: key) else { return nil }
        return Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: d))
    }
}
