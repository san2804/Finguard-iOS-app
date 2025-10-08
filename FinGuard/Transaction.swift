//
//  Transaction.swift
//  FinGuard
//
//  Created by Sandil on 2025-10-07.
//

import Foundation
import FirebaseFirestore

// MARK: - Transaction Model

struct Transaction: Identifiable, Codable {
    enum TxType: String, Codable, CaseIterable {
        case income
        case expense
    }

    var id: String = UUID().uuidString
    let userId: String
    let type: TxType
    let amount: Double
    let category: String
    let account: String
    let note: String?
    let date: Date
    let month: String    // e.g. "October"
    let year: Int
    var attachmentURL: String?
}
