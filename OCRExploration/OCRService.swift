import Vision
import UIKit
import Foundation
import Combine

class OCRService: ObservableObject {
    @Published var extractedData: Transaction = Transaction()
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var recognizedTexts: [VNRecognizedTextObservation] = []
    @Published var processedImage: UIImage?
    
    func extractDataFromImage(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil
        recognizedTexts = []
        processedImage = image
        
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
                
                self?.recognizedTexts = observations
                
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
            "([0-9.,]+)\\s*idr",
            "Rp\\s*([0-9.,]+)\\s*",
            "IDR\\s*([0-9.,]+)\\s*",
            "\\$\\s*([0-9.,]+)\\s*",
            "([0-9.,]+)\\s*rp\\s*",
            "([0-9.,]+)\\s*idr\\s*",
            "Rp\\s*([0-9.,]+)",
            "IDR\\s*([0-9.,]+)",
            "\\$\\s*([0-9.,]+)",
            "([0-9.,]+)\\s*rp",
            "([0-9.,]+)\\s*idr",
            "Rp\\s*([0-9.,]+)\\s*",
            "IDR\\s*([0-9.,]+)\\s*",
            "\\$\\s*([0-9.,]+)\\s*",
            "([0-9.,]+)\\s*rp\\s*",
            "([0-9.,]+)\\s*idr\\s*",
            "Transfer\\s*([0-9.,]+)",
            "Saldo\\s*([0-9.,]+)",
            "Total\\s*([0-9.,]+)",
            "Amount\\s*([0-9.,]+)",
            "Nominal\\s*([0-9.,]+)",
            "Jumlah\\s*([0-9.,]+)",
            "Berhasil\\s*([0-9.,]+)",
            "Sukses\\s*([0-9.,]+)",
            "([0-9.,]+)\\s*berhasil",
            "([0-9.,]+)\\s*sukses",
            "([0-9.,]+)\\s*transfer",
            "([0-9.,]+)\\s*saldo",
            "([0-9.,]+)\\s*total",
            "([0-9.,]+)\\s*amount",
            "([0-9.,]+)\\s*nominal",
            "([0-9.,]+)\\s*jumlah",
            "Rp\\s*([0-9]+)",
            "IDR\\s*([0-9]+)",
            "\\$\\s*([0-9]+)",
            "([0-9]+)\\s*rp",
            "([0-9]+)\\s*idr",
            "Transfer\\s*([0-9]+)",
            "Saldo\\s*([0-9]+)",
            "Total\\s*([0-9]+)",
            "Amount\\s*([0-9]+)",
            "Nominal\\s*([0-9]+)",
            "Jumlah\\s*([0-9]+)",
            "Berhasil\\s*([0-9]+)",
            "Sukses\\s*([0-9]+)",
            "([0-9]+)\\s*berhasil",
            "([0-9]+)\\s*sukses",
            "([0-9]+)\\s*transfer",
            "([0-9]+)\\s*saldo",
            "([0-9]+)\\s*total",
            "([0-9]+)\\s*amount",
            "([0-9]+)\\s*nominal",
            "([0-9]+)\\s*jumlah"
        ]
        
        for pattern in amountPatterns {
            if let match = cleanText.range(of: pattern, options: .regularExpression) {
                let amountString = String(cleanText[match])
                let numberString = amountString.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
                
                let extractedAmount = parseIndonesianNumber(numberString)
                if extractedAmount > 0 {
                    amount = extractedAmount
                    print("OCR Debug - Pattern matched: \(pattern)")
                    print("OCR Debug - Amount string: \(amountString)")
                    print("OCR Debug - Number string: \(numberString)")
                    print("OCR Debug - Extracted amount: \(extractedAmount)")
                    break
                }
            }
        }
        
        if amount == 0 {
            amount = findLargestNumberInText(cleanText)
            print("OCR Debug - Fallback used, largest number found: \(amount)")
        }
        
        print("OCR Debug - Final amount: \(amount)")
        print("OCR Debug - Clean text: \(cleanText)")
        
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
    
    private func findLargestNumberInText(_ text: String) -> Double {
        let numberPattern = "([0-9.,]+)"
        let regex = try? NSRegularExpression(pattern: numberPattern)
        let matches = regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        
        var largestAmount: Double = 0
        
        for match in matches {
            if let range = Range(match.range, in: text) {
                let numberString = String(text[range])
                let amount = parseIndonesianNumber(numberString)
                
                if amount > largestAmount && amount >= 1000 {
                    largestAmount = amount
                }
            }
        }
        
        return largestAmount
    }
    
    private func parseIndonesianNumber(_ numberString: String) -> Double {
        let cleanString = numberString.trimmingCharacters(in: .whitespaces)
        
        if cleanString.isEmpty {
            return 0
        }
        
        let hasComma = cleanString.contains(",")
        let hasDot = cleanString.contains(".")
        
        if hasComma && hasDot {
            let parts = cleanString.components(separatedBy: ",")
            if parts.count == 2 {
                let integerPart = parts[0].replacingOccurrences(of: ".", with: "")
                let decimalPart = parts[1]
                
                if let integer = Double(integerPart), let decimal = Double(decimalPart) {
                    return integer + (decimal / pow(10, Double(decimalPart.count)))
                }
            }
        } else if hasComma && !hasDot {
            let parts = cleanString.components(separatedBy: ",")
            if parts.count == 2 {
                let integerPart = parts[0]
                let decimalPart = parts[1]
                
                if let integer = Double(integerPart), let decimal = Double(decimalPart) {
                    return integer + (decimal / pow(10, Double(decimalPart.count)))
                }
            } else {
                let withoutComma = cleanString.replacingOccurrences(of: ",", with: "")
                return Double(withoutComma) ?? 0
            }
        } else if !hasComma && hasDot {
            let parts = cleanString.components(separatedBy: ".")
            if parts.count == 2 {
                let integerPart = parts[0]
                let decimalPart = parts[1]
                
                if let integer = Double(integerPart), let decimal = Double(decimalPart) {
                    return integer + (decimal / pow(10, Double(decimalPart.count)))
                }
            } else {
                let withoutDot = cleanString.replacingOccurrences(of: ".", with: "")
                return Double(withoutDot) ?? 0
            }
        } else {
            return Double(cleanString) ?? 0
        }
        
        return 0
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
