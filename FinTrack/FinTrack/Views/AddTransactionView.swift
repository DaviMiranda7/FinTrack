import SwiftUI
import FirebaseAuth

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var description = ""
    @State private var selectedType: TransactionType = .expense
    @State private var selectedCategory: Category = .other
    @State private var date = Date()
    
    let onSave: (Transaction) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Tipo") {
                    Picker("Tipo", selection: $selectedType) {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Detalhes") {
                    TextField("Valor", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    TextField("Descrição", text: $description)
                    
                    Picker("Categoria", selection: $selectedCategory) {
                        ForEach(Category.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("Nova Transação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salvar") {
                        saveTransaction()
                    }
                    .disabled(amount.isEmpty)
                }
            }
        }
    }
    
    private func saveTransaction() {
        guard let amountValue = Double(amount),
              let userId = Auth.auth().currentUser?.uid else { return }
        
        let transaction = Transaction(
            userId: userId,
            amount: amountValue,
            type: selectedType,
            category: selectedCategory,
            description: description,
            date: date
        )
        
        onSave(transaction)
        dismiss()
    }
}
