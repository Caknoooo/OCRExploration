import SwiftUI

struct TransactionListView: View {
    @StateObject private var transactionStore = TransactionStore()
    @State private var showingForm = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(transactionStore.transactions) { transaction in
                    TransactionRowView(transaction: transaction)
                }
                .onDelete(perform: deleteTransaction)
            }
            .navigationTitle("Daftar Transaksi")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Tambah") {
                        showingForm = true
                    }
                }
            }
            .sheet(isPresented: $showingForm) {
                TransactionFormView()
            }
        }
        .onAppear {
            transactionStore.loadTransactions()
        }
    }
    
    private func deleteTransaction(offsets: IndexSet) {
        transactionStore.transactions.remove(atOffsets: offsets)
        transactionStore.saveTransactions()
    }
}

struct TransactionRowView: View {
    let transaction: Transaction
    @State private var showingImage = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Rp \(String(format: "%.0f", transaction.amount))")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text(transaction.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(transaction.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(transaction.transactionId)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            if transaction.imageData != nil {
                Button("Lihat Bukti Transfer") {
                    showingImage = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingImage) {
            if let imageData = transaction.imageData,
               let uiImage = UIImage(data: imageData) {
                ImageViewerView(image: uiImage)
            }
        }
    }
}

struct ImageViewerView: View {
    let image: UIImage
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .navigationTitle("Bukti Transfer")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Tutup") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            TransactionFormView()
                .tabItem {
                    Image(systemName: "plus.circle")
                    Text("Tambah")
                }
            
            TransactionListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Daftar")
                }
        }
    }
}
