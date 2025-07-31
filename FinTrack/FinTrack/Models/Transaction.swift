import Foundation

struct Transaction: Identifiable {
    let id: String
    let userId: String
    let amount: Double
    let type: TransactionType
    let category: Category
    let description: String
    let date: Date
    
    init(id: String = UUID().uuidString, userId: String, amount: Double, type: TransactionType, category: Category, description: String, date: Date = Date()) {
        self.id = id
        self.userId = userId
        self.amount = amount
        self.type = type
        self.category = category
        self.description = description
        self.date = date
    }
}

enum TransactionType: String, CaseIterable {
    case income = "income"
    case expense = "expense"
    
    var displayName: String {
        switch self {
        case .income: return "Entrada"
        case .expense: return "Saída"
        }
    }
}

enum Category: String, CaseIterable {
    case food = "food"
    case transport = "transport"
    case entertainment = "entertainment"
    case health = "health"
    case salary = "salary"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .food: return "Alimentação"
        case .transport: return "Transporte"
        case .entertainment: return "Entretenimento"
        case .health: return "Saúde"
        case .salary: return "Salário"
        case .other: return "Outros"
        }
    }
}
