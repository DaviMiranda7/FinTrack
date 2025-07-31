import Foundation

struct User {
    let id: String
    let name: String
    let email: String
    let balance: Double
    let createdAt: Date
    
    init(id: String, name: String, email: String, balance: Double = 0.0, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.email = email
        self.balance = balance
        self.createdAt = createdAt
    }
}
