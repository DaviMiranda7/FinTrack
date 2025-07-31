import Foundation
import FirebaseFirestore

class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func saveUser(_ user: User) async throws {
        let userData: [String: Any] = [
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "balance": user.balance,
            "createdAt": user.createdAt
        ]
        try await db.collection("users").document(user.id).setData(userData)
    }
    
    func getUser(id: String) async throws -> User? {
        let document = try await db.collection("users").document(id).getDocument()
        guard let data = document.data() else { return nil }
        
        return User(
            id: data["id"] as? String ?? "",
            name: data["name"] as? String ?? "",
            email: data["email"] as? String ?? "",
            balance: data["balance"] as? Double ?? 0.0,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
    
    func saveTransaction(_ transaction: Transaction) async throws {
        let transactionData: [String: Any] = [
            "id": transaction.id,
            "userId": transaction.userId,
            "amount": transaction.amount,
            "type": transaction.type.rawValue,
            "category": transaction.category.rawValue,
            "description": transaction.description,
            "date": transaction.date
        ]
        try await db.collection("transactions").document(transaction.id).setData(transactionData)
    }
    
    func getTransactions(for userId: String) async throws -> [Transaction] {
        let snapshot = try await db.collection("transactions")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            return Transaction(
                id: data["id"] as? String ?? "",
                userId: data["userId"] as? String ?? "",
                amount: data["amount"] as? Double ?? 0.0,
                type: TransactionType(rawValue: data["type"] as? String ?? "") ?? .expense,
                category: Category(rawValue: data["category"] as? String ?? "") ?? .other,
                description: data["description"] as? String ?? "",
                date: (data["date"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
    }
    
    func updateUserBalance(_ userId: String, newBalance: Double) async throws {
        try await db.collection("users").document(userId).updateData([
            "balance": newBalance
        ])
    }

}
