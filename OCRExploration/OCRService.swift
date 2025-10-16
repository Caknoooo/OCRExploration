import Vision
import UIKit
import Foundation

class OCRService: ObservableObject {
    @Published var extractedData: Transaction = Transaction()
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    func extractDataFromImage(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil
        
        guard let cgImage = image.cgImage else {
            errorMessage = "Gagal memproses gambar"
            isProcessing = false
            return
        }
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                if let error = error {
                    self?.errorMessage = "Error OCR: \(error.localizedDescription)"
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    self?.errorMessage = "Tidak ada teks yang ditemukan"
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: " ")
                
                self?.parseText(recognizedText)
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.errorMessage = "Error processing: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func parseText(_ text: String) {
        var amount: Double = 0
        var date: Date = Date()
        var transactionId: String = ""
        
        let cleanText = text.replacingOccurrences(of: "\n", with: " ")
        
        let amountPatterns = [
            "Rp\\s*([0-9.,]+)",
            "IDR\\s*([0-9.,]+)",
            "\\$\\s*([0-9.,]+)",
            "([0-9.,]+)\\s*rp",
            "([0-9.,]+)\\s*idr"
        ]
        
        for pattern in amountPatterns {
            if let match = cleanText.range(of: pattern, options: .regularExpression) {
                let amountString = String(cleanText[match])
                let numberString = amountString.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
                let cleanNumber = numberString.replacingOccurrences(of: ",", with: "")
                
                if let extractedAmount = Double(cleanNumber) {
                    amount = extractedAmount
                    break
                }
            }
        }
        
        let datePatterns = [
            "([0-9]{1,2})[/-]([0-9]{1,2})[/-]([0-9]{2,4})",
            "([0-9]{1,2})\\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\\s+([0-9]{2,4})",
            "([0-9]{4})[/-]([0-9]{1,2})[/-]([0-9]{1,2})"
        ]
        
        for pattern in datePatterns {
            if let match = cleanText.range(of: pattern, options: .regularExpression) {
                let dateString = String(cleanText[match])
                if let parsedDate = parseDate(from: dateString) {
                    date = parsedDate
                    break
                }
            }
        }
        
        let idPatterns = [
            "ID[\\s:]*([A-Z0-9]{6,})",
            "Ref[\\s:]*([A-Z0-9]{6,})",
            "Txn[\\s:]*([A-Z0-9]{6,})",
            "No[\\s:]*([A-Z0-9]{6,})",
            "([A-Z]{2,}[0-9]{4,})",
            "([0-9]{10,})"
        ]
        
        for pattern in idPatterns {
            if let match = cleanText.range(of: pattern, options: .regularExpression) {
                let idString = String(cleanText[match])
                let cleanId = idString.replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
                if cleanId.count >= 6 {
                    transactionId = cleanId
                    break
                }
            }
        }
        
        extractedData = Transaction(
            amount: amount,
            date: date,
            transactionId: transactionId,
            description: "Transfer masuk"
        )
    }
    
    private func parseDate(from dateString: String) -> Date? {
        let formatters = [
            "dd/MM/yyyy",
            "dd-MM-yyyy",
            "yyyy/MM/dd",
            "yyyy-MM-dd",
            "dd MMM yyyy",
            "dd MMMM yyyy"
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "id_ID")
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
}
