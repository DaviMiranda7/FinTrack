import Foundation

// Representa uma transação financeira, como entrada ou saída de dinheiro
struct Transaction: Identifiable {
    let id: String
    let userId: String
    let amount: Double
    let type: TransactionType
    let category: Category
    let description: String
    let date: Date
    
    // Inicializador que cria uma transação, gerando um id único se não for passado
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

// Define os tipos possíveis de transação: entrada ou saída
enum TransactionType: String, CaseIterable {
    case income = "income"
    case expense = "expense"
    
    // Nome amigável para exibir na interface do usuário
    var displayName: String {
        switch self {
        case .income: return "Entrada"
        case .expense: return "Saída"
        }
    }
}

// Define as categorias possíveis para classificar uma transação
enum Category: String, CaseIterable {
    case food = "food"
    case transport = "transport"
    case entertainment = "entertainment"
    case health = "health"
    case salary = "salary"
    case other = "other"             
    
    // Nome amigável para mostrar ao usuário
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
