//
//  TransactionService.swift
//  FinGuard
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

final class TransactionService {

    static let shared = TransactionService()
    private init() {}

    private var db: Firestore { Firestore.firestore() }
    private var col: CollectionReference { db.collection("transactions") }

    // MARK: - Create
    func add(_ tx: Transaction) async throws {
        try col.addDocument(from: tx)
    }

    // MARK: - Read (one-shot)
    /// All transactions for a user, optionally filtered by yyyy-MM month key.
    func fetch(for userId: String, month: String? = nil) async throws -> [Transaction] {
        var q: Query = col.whereField("userId", isEqualTo: userId)
                          .order(by: "date", descending: true)

        if let month { q = q.whereField("month", isEqualTo: month) }

        let snap = try await q.getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Transaction.self) }
    }

    // MARK: - Aggregates (example)
    func sum(for userId: String, month: String? = nil, type: TxType) async throws -> Double {
        let items = try await fetch(for: userId, month: month)
        return items.filter { $0.type == type }.reduce(0) { $0 + $1.amount }
    }

    // MARK: - Live listener (optional)
    func listen(for userId: String,
                month: String? = nil,
                onChange: @escaping ([Transaction]) -> Void) -> ListenerRegistration {

        var q: Query = col.whereField("userId", isEqualTo: userId)
                          .order(by: "date", descending: true)
        if let month { q = q.whereField("month", isEqualTo: month) }

        return q.addSnapshotListener { snap, _ in
            let items = (snap?.documents ?? []).compactMap { try? $0.data(as: Transaction.self) }
            onChange(items)
        }
    }
}
