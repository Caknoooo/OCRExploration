import SwiftUI
import PhotosUI

struct TransactionFormView: View {
    @StateObject private var ocrService = OCRService()
    @StateObject private var transactionStore = TransactionStore()
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var amount: String = ""
    @State private var date = Date()
    @State private var transactionId: String = ""
    @State private var description: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Upload Bukti Transfer")) {
                    VStack {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 150)
                                .overlay(
                                    VStack {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                        Text("Tap untuk upload foto")
                                            .foregroundColor(.gray)
                                    }
                                )
                        }
                        
                        HStack {
                            Button("Kamera") {
                                showingCamera = true
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Galeri") {
                                showingImagePicker = true
                            }
                            .buttonStyle(.bordered)
                            
                            if selectedImage != nil {
                                Button("Hapus") {
                                    selectedImage = nil
                                    resetForm()
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                if ocrService.isProcessing {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Memproses OCR...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Detail Transaksi")) {
                    HStack {
                        Text("Jumlah")
                        Spacer()
                        TextField("0", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    DatePicker("Tanggal", selection: $date, displayedComponents: .date)
                    
                    HStack {
                        Text("ID Transaksi")
                        Spacer()
                        TextField("Auto dari OCR", text: $transactionId)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Deskripsi")
                        Spacer()
                        TextField("Transfer masuk", text: $description)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section {
                    Button("Simpan Transaksi") {
                        saveTransaction()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(amount.isEmpty || transactionId.isEmpty)
                }
            }
            .navigationTitle("Form Pemasukan")
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .sheet(isPresented: $showingCamera) {
                CameraPicker(selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) { image in
                if let image = image {
                    ocrService.extractDataFromImage(image)
                }
            }
            .onChange(of: ocrService.extractedData) { extractedData in
                if !ocrService.isProcessing {
                    amount = String(format: "%.0f", extractedData.amount)
                    date = extractedData.date
                    transactionId = extractedData.transactionId
                    description = extractedData.description
                }
            }
            .alert("Info", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            transactionStore.loadTransactions()
        }
    }
    
    private func resetForm() {
        amount = ""
        date = Date()
        transactionId = ""
        description = ""
        ocrService.extractedData = Transaction()
    }
    
    private func saveTransaction() {
        guard let amountValue = Double(amount), amountValue > 0 else {
            alertMessage = "Jumlah harus lebih dari 0"
            showingAlert = true
            return
        }
        
        let transaction = Transaction(
            amount: amountValue,
            date: date,
            transactionId: transactionId,
            description: description.isEmpty ? "Transfer masuk" : description,
            imageData: selectedImage?.jpegData(compressionQuality: 0.8)
        )
        
        transactionStore.addTransaction(transaction)
        transactionStore.saveTransactions()
        
        alertMessage = "Transaksi berhasil disimpan!"
        showingAlert = true
        
        resetForm()
        selectedImage = nil
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        
        init(_ parent: CameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
