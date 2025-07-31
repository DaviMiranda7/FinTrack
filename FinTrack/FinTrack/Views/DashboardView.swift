import SwiftUI
import FirebaseAuth

struct DashboardView: View {
    @StateObject private var authService = AuthService()
    @State private var transactions: [Transaction] = []
    @State private var showingAddTransaction = false
    @State private var balance: Double = 0.0
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Card do Saldo
                VStack {
                    Text("Saldo Atual")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("R$ \(balance, specifier: "%.2f")")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(balance >= 0 ? .green : .red)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(15)
                .padding(.horizontal)
                
                // Resumo
                HStack(spacing: 20) {
                    VStack {
                        Text("Entradas")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("R$ \(totalIncome, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    
                    VStack {
                        Text("Saídas")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("R$ \(totalExpense, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                
                // Lista de Transações
                VStack(alignment: .leading) {
                    Text("Últimas Transações")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else if transactions.isEmpty {
                        Text("Nenhuma transação ainda")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        List(transactions.prefix(5)) { transaction in
                            TransactionRowView(transaction: transaction)
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                
                Spacer()
            }
            .navigationTitle("FinTrack")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sair") {
                        try? authService.signOut()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("+") {
                        showingAddTransaction = true
                    }
                    .font(.title2)
                }
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView { transaction in
                saveTransaction(transaction)
            }
        }
        .onAppear {
            loadTransactions()
        }
    }
    
    private var totalIncome: Double {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }
    
    private var totalExpense: Double {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    
    private func loadTransactions() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        Task {
            do {
                // Carregar usuário e saldo
                if let user = try await FirestoreService.shared.getUser(id: userId) {
                    await MainActor.run {
                        self.balance = user.balance
                    }
                }
                
                // Carregar transações
                let loadedTransactions = try await FirestoreService.shared.getTransactions(for: userId)
                await MainActor.run {
                    self.transactions = loadedTransactions
                    self.updateBalance()
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("Erro ao carregar dados: \(error)")
            }
        }
    }
    
    private func saveTransaction(_ transaction: Transaction) {
        Task {
            // Validar segurança da transação
            let isSecure = await SecurityService.shared.validateTransaction(transaction)
            guard isSecure else {
                await MainActor.run {
                    // Mostrar alerta de segurança
                }
                return
            }
            
            do {
                try await FirestoreService.shared.saveTransaction(transaction)
                await MainActor.run {
                    transactions.insert(transaction, at: 0)
                    updateBalance()
                }
            } catch {
                print("Erro ao salvar transação: \(error)")
            }
        }
    }

    
    private func updateBalance() {
        let oldBalance = balance
        let newBalance = totalIncome - totalExpense
        balance = newBalance
        
        // Enviar notificação se houve mudança
        if oldBalance != newBalance, let lastTransaction = transactions.first {
            NotificationService.shared.sendBalanceNotification(
                oldBalance: oldBalance,
                newBalance: newBalance,
                transaction: lastTransaction
            )
        }
        
        // Atualizar no Firebase
        guard let userId = Auth.auth().currentUser?.uid else { return }
        Task {
            do {
                try await FirestoreService.shared.updateUserBalance(userId, newBalance: newBalance)
            } catch {
                print("Erro ao atualizar saldo no Firebase: \(error)")
            }
        }
    }



}

struct TransactionRowView: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            Text(transaction.category.displayName)
                .font(.headline)
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(transaction.type == .income ? "+" : "-")R$ \(transaction.amount, specifier: "%.2f")")
                    .font(.headline)
                    .foregroundColor(transaction.type == .income ? .green : .red)
                
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
