import Foundation

struct Transaction: Identifiable, Codable {
    let id = UUID()
    var amount: Double
    var date: Date
    var transactionId: String
    var description: String
    var imageData: Data?
    
    init(amount: Double = 0, date: Date = Date(), transactionId: String = "", description: String = "", imageData: Data? = nil) {
        self.amount = amount
        self.date = date
        self.transactionId = transactionId
        self.description = description
        self.imageData = imageData
    }
}

class TransactionStore: ObservableObject {
    @Published var transactions: [Transaction] = []
    
    func addTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
    }
    
    func saveTransactions() {
        if let encoded = try? JSONEncoder().encode(transactions) {
            UserDefaults.standard.set(encoded, forKey: "SavedTransactions")
        }
    }
    
    func loadTransactions() {
        if let data = UserDefaults.standard.data(forKey: "SavedTransactions"),
           let decoded = try? JSONDecoder().decode([Transaction].self, from: data) {
            transactions = decoded
        }
    }
}
