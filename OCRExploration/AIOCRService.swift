import Vision
import UIKit
import Foundation
import Combine
import NaturalLanguage
import CoreML

class AIOCRService: ObservableObject {
    @Published var extractedData: Transaction = Transaction()
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var recognizedTexts: [VNRecognizedTextObservation] = []
    @Published var processedImage: UIImage?
    @Published var aiAnalysis: String = ""
    
    private var learnedPatterns: [String: Float] = [:]
    private var patternCount: [String: Int] = [:]
    
    init() {
        loadLearnedPatterns()
    }
    
    func extractDataFromImage(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil
        recognizedTexts = []
        processedImage = image
        aiAnalysis = ""
        
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
                self?.processWithAI(observations)
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        
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
    
    private func processWithAI(_ observations: [VNRecognizedTextObservation]) {
        let allText = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }.joined(separator: " ")
        
        print("🔍 AI OCR Debug - Full Text:")
        print("📝 \(allText)")
        print("")
        
        aiAnalysis = "AI Analysis:\n"
        aiAnalysis += "Full text: \(allText)\n\n"
        
        let extractedData = extractTransactionDataWithAdvancedAI(allText, observations)
        
        self.extractedData = extractedData
        
        print("💰 AI OCR Debug - Extracted Data:")
        print("💵 Amount: \(extractedData.amount)")
        print("📅 Date: \(extractedData.date)")
        print("🆔 Transaction ID: \(extractedData.transactionId)")
        print("")
        
        aiAnalysis += "Extracted Amount: \(extractedData.amount)\n"
        aiAnalysis += "Extracted Date: \(extractedData.date)\n"
        aiAnalysis += "Extracted ID: \(extractedData.transactionId)\n"
        
        aiAnalysis += "\nAI Reasoning:\n"
        aiAnalysis += "Using advanced NLP to understand context and extract financial data intelligently.\n"
    }
    
    private func extractTransactionDataWithAdvancedAI(_ text: String, _ observations: [VNRecognizedTextObservation]) -> Transaction {
        let nlpProcessor = NLProcessor()
        
        let amount = nlpProcessor.extractAmount(from: text)
        let date = nlpProcessor.extractDate(from: text)
        let transactionId = nlpProcessor.extractTransactionId(from: text)
        
        aiAnalysis += "NLP Analysis:\n"
        aiAnalysis += "- Amount detected: \(amount)\n"
        aiAnalysis += "- Date detected: \(date)\n"
        aiAnalysis += "- Transaction ID detected: \(transactionId)\n"
        
        return Transaction(
            amount: amount,
            date: date,
            transactionId: transactionId,
            description: "Transfer masuk"
        )
    }
    
    private func extractTransactionDataWithAI(_ text: String, _ observations: [VNRecognizedTextObservation]) -> Transaction {
        var amount: Double = 0
        var date: Date = Date()
        var transactionId: String = ""
        
        let cleanText = text.lowercased()
        
        amount = extractAmountWithAI(cleanText, observations)
        date = extractDateWithAI(cleanText)
        transactionId = extractTransactionIdWithAI(cleanText)
        
        return Transaction(
            amount: amount,
            date: date,
            transactionId: transactionId,
            description: "Transfer masuk"
        )
    }
    
    private func extractAmountWithAI(_ text: String, _ observations: [VNRecognizedTextObservation]) -> Double {
        var candidates: [(Double, Float, String)] = []
        
        for observation in observations {
            guard let recognizedText = observation.topCandidates(1).first else { continue }
            
            let text = recognizedText.string.lowercased()
            let confidence = recognizedText.confidence
            
            if let amount = parseAmountFromText(text) {
                let contextScore = calculateCurrencyContextScore(text)
                let learnedScore = getLearnedScore(text)
                let finalScore = confidence * contextScore * (0.7 + learnedScore * 0.3)
                candidates.append((amount, finalScore, text))
            }
        }
        
        candidates.sort { $0.1 > $1.1 }
        
        if let bestCandidate = candidates.first {
            aiAnalysis += "Amount candidates: \(candidates.map { "\($0.0) (score: \(Int($0.1 * 100))%) - '\($0.2)'" }.joined(separator: ", "))\n"
            return bestCandidate.0
        }
        
        return 0
    }
    
    private func calculateCurrencyContextScore(_ text: String) -> Float {
        var score: Float = 0.3
        
        let currencyPatterns: [String: Float] = [
            "rp\\s*[0-9.,]+": 1.0,
            "idr\\s*[0-9.,]+": 1.0,
            "rupiah\\s*[0-9.,]+": 1.0,
            "\\$\\s*[0-9.,]+": 0.9
        ]
        
        for (pattern, weight) in currencyPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                score += weight
                break
            }
        }
        
        let currencyKeywords: [String: Float] = [
            "rp": 1.0, "idr": 1.0, "rupiah": 1.0, "rupia": 0.9,
            "transfer": 0.9, "saldo": 0.9, "total": 0.8, "amount": 0.8,
            "nominal": 0.9, "jumlah": 0.8, "berhasil": 0.7, "sukses": 0.7,
            "masuk": 0.8, "keluar": 0.8, "debit": 0.7, "kredit": 0.7,
            "pembayaran": 0.8, "pembelian": 0.8, "belanja": 0.8,
            "topup": 0.8, "isi": 0.7, "deposit": 0.8, "withdraw": 0.8,
            "tarik": 0.8, "setor": 0.8, "tunai": 0.7, "cash": 0.7
        ]
        
        let transactionKeywords: [String: Float] = [
            "bank": 0.6, "atm": 0.6, "bca": 0.6, "mandiri": 0.6,
            "bri": 0.6, "bni": 0.6, "flip": 0.7, "gopay": 0.7,
            "dana": 0.7, "ovo": 0.7, "shopeepay": 0.7, "linkaja": 0.7
        ]
        
        let negativeKeywords: [String: Float] = [
            "id": -0.5, "no": -0.3, "ref": -0.3, "txn": -0.3,
            "tanggal": -0.2, "date": -0.2, "jam": -0.2, "time": -0.2,
            "nama": -0.2, "name": -0.2, "alamat": -0.2, "address": -0.2
        ]
        
        for (keyword, weight) in currencyKeywords {
            if text.contains(keyword) {
                score += weight * 0.3
            }
        }
        
        for (keyword, weight) in transactionKeywords {
            if text.contains(keyword) {
                score += weight * 0.2
            }
        }
        
        for (keyword, weight) in negativeKeywords {
            if text.contains(keyword) {
                score += weight
            }
        }
        
        let numberPattern = "([0-9.,]+)"
        let regex = try? NSRegularExpression(pattern: numberPattern)
        let matches = regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        
        if matches.count == 1 {
            score += 0.2
        } else if matches.count > 1 {
            score -= 0.1
        }
        
        let amount = Float(extractNumbersFromText(text).first ?? 0)
        if amount >= 1_000 && amount <= 1_000_000_000 {
            score += 0.3
        } else if amount < 1_000 {
            score -= 0.2
        } else if amount > 1_000_000_000 {
            score -= 0.1
        }
        
        return max(0.1 as Float, min(1.0 as Float, score))
    }
    
    private func loadLearnedPatterns() {
        if let data = UserDefaults.standard.data(forKey: "LearnedPatterns"),
           let patterns = try? JSONDecoder().decode([String: Float].self, from: data) {
            learnedPatterns = patterns
        }
        
        if let data = UserDefaults.standard.data(forKey: "PatternCount"),
           let counts = try? JSONDecoder().decode([String: Int].self, from: data) {
            patternCount = counts
        }
    }
    
    private func saveLearnedPatterns() {
        if let data = try? JSONEncoder().encode(learnedPatterns) {
            UserDefaults.standard.set(data, forKey: "LearnedPatterns")
        }
        
        if let data = try? JSONEncoder().encode(patternCount) {
            UserDefaults.standard.set(data, forKey: "PatternCount")
        }
    }
    
    func learnFromPattern(_ text: String, isCorrect: Bool) {
        let normalizedText = text.lowercased()
        let words = normalizedText.components(separatedBy: .whitespacesAndNewlines)
        
        for word in words {
            if word.count > 2 {
                let currentCount = patternCount[word] ?? 0
                patternCount[word] = currentCount + 1
                
                let currentWeight = learnedPatterns[word] ?? 0.5
                let learningRate: Float = 0.1
                let adjustment: Float = isCorrect ? learningRate : -learningRate
                
                learnedPatterns[word] = max(0.0, min(1.0, currentWeight + adjustment))
            }
        }
        
        saveLearnedPatterns()
        aiAnalysis += "Learned from pattern: \(text) (correct: \(isCorrect))\n"
    }
    
    private func getLearnedScore(_ text: String) -> Float {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var totalScore: Float = 0
        var wordCount = 0
        
        for word in words {
            if word.count > 2, let learnedWeight = learnedPatterns[word] {
                totalScore += learnedWeight
                wordCount += 1
            }
        }
        
        return wordCount > 0 ? totalScore / Float(wordCount) : 0.5
    }
    
    private func parseAmountFromText(_ text: String) -> Double? {
        let currencyPatterns = [
            "rp\\s*([0-9.,]+)",
            "idr\\s*([0-9.,]+)",
            "rupiah\\s*([0-9.,]+)",
            "\\$\\s*([0-9.,]+)"
        ]
        
        for pattern in currencyPatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchString = String(text[match])
                let numberString = matchString.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
                let amount = parseIndonesianNumber(numberString)
                if amount > 0 {
                    return amount
                }
            }
        }
        
        let amountKeywords = ["transfer", "saldo", "total", "amount", "nominal", "jumlah", "berhasil", "sukses"]
        
        for keyword in amountKeywords {
            if text.contains(keyword) {
                let numbers = extractNumbersFromText(text)
                if let amount = numbers.max() {
                    return amount
                }
            }
        }
        
        let numbers = extractNumbersFromText(text)
        return numbers.max()
    }
    
    private func extractNumbersFromText(_ text: String) -> [Double] {
        let numberPattern = "([0-9.,]+)"
        let regex = try? NSRegularExpression(pattern: numberPattern)
        let matches = regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        
        var numbers: [Double] = []
        
        for match in matches {
            if let range = Range(match.range, in: text) {
                let numberString = String(text[range])
                let amount = parseIndonesianNumber(numberString)
                if amount >= 1000 {
                    numbers.append(amount)
                }
            }
        }
        
        return numbers
    }
    
    private func extractDateWithAI(_ text: String) -> Date {
        let datePatterns = [
            "([0-9]{1,2})[/-]([0-9]{1,2})[/-]([0-9]{2,4})",
            "([0-9]{1,2})\\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\s+([0-9]{2,4})",
            "([0-9]{4})[/-]([0-9]{1,2})[/-]([0-9]{1,2})"
        ]
        
        for pattern in datePatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let dateString = String(text[match])
                if let parsedDate = parseDate(from: dateString) {
                    return parsedDate
                }
            }
        }
        
        return Date()
    }
    
    private func extractTransactionIdWithAI(_ text: String) -> String {
        let idPatterns = [
            "id[\\s:]*([a-z0-9]{6,})",
            "ref[\\s:]*([a-z0-9]{6,})",
            "txn[\\s:]*([a-z0-9]{6,})",
            "no[\\s:]*([a-z0-9]{6,})",
            "([a-z]{2,}[0-9]{4,})",
            "([0-9]{10,})"
        ]
        
        for pattern in idPatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let idString = String(text[match])
                let cleanId = idString.replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
                if cleanId.count >= 6 {
                    return cleanId.uppercased()
                }
            }
        }
        
        return ""
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
                
                if decimalPart.count <= 2 {
                    if let integer = Double(integerPart), let decimal = Double(decimalPart) {
                        return integer + (decimal / pow(10, Double(decimalPart.count)))
                    }
                } else {
                    let withoutDot = cleanString.replacingOccurrences(of: ".", with: "")
                    return Double(withoutDot) ?? 0
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

class NLProcessor {
    private let tokenizer = NLTokenizer(unit: .word)
    private let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    
    func extractAmount(from text: String) -> Double {
        let cleanText = text.lowercased()
        
        print("🔍 NLP Debug - Extracting Amount from: '\(cleanText)'")
        
        let amountPatterns = [
            "rp\\s*([0-9.,]+)",
            "idr\\s*([0-9.,]+)",
            "rupiah\\s*([0-9.,]+)",
            "\\$\\s*([0-9.,]+)"
        ]
        
        var allCurrencyMatches: [(Double, String, Int)] = []
        
        for (index, pattern) in amountPatterns.enumerated() {
            let regex = try? NSRegularExpression(pattern: pattern)
            let matches = regex?.matches(in: cleanText, range: NSRange(cleanText.startIndex..., in: cleanText)) ?? []
            
            for match in matches {
                if let range = Range(match.range, in: cleanText) {
                    let matchString = String(cleanText[range])
                    let numberString = matchString.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
                    let amount = parseIndonesianNumber(numberString)
                    if amount > 0 {
                        let position = cleanText.distance(from: cleanText.startIndex, to: range.lowerBound)
                        allCurrencyMatches.append((amount, matchString, position))
                        print("✅ NLP Debug - Currency Pattern \(index + 1) found: '\(matchString)' -> \(amount) at position \(position)")
                    }
                }
            }
        }
        
        if !allCurrencyMatches.isEmpty {
            let bestMatch = selectBestAmountMatch(allCurrencyMatches, from: cleanText)
            print("🎯 NLP Debug - Selected best match: \(bestMatch.0) from '\(bestMatch.1)'")
            return bestMatch.0
        }
        
        print("⚠️ NLP Debug - No currency pattern matched, trying contextual analysis...")
        let contextualAmounts = extractContextualAmounts(from: cleanText)
        let result = contextualAmounts.max() ?? 0
        print("📊 NLP Debug - Contextual amounts found: \(contextualAmounts), selected: \(result)")
        return result
    }
    
    private func selectBestAmountMatch(_ matches: [(Double, String, Int)], from text: String) -> (Double, String) {
        print("🔍 NLP Debug - Selecting best match from \(matches.count) candidates")
        
        var scoredMatches: [(Double, String, Double)] = []
        
        for (amount, matchString, position) in matches {
            var score: Double = 0
            
            print("📊 NLP Debug - Evaluating: \(amount) from '\(matchString)'")
            
            if amount >= 10000 && amount <= 1000000000 {
                score += 50
                print("✅ NLP Debug - Amount in good range (10K-1B): +50 points")
            } else if amount >= 1000 {
                score += 30
                print("✅ NLP Debug - Amount in acceptable range (1K-10K): +30 points")
            } else {
                score -= 20
                print("❌ NLP Debug - Amount too small (<1K): -20 points")
            }
            
            let contextScore = calculateContextScore(for: matchString, in: text, at: position)
            score += contextScore
            print("🎯 NLP Debug - Context score: +\(contextScore) points")
            
            scoredMatches.append((amount, matchString, score))
            print("📈 NLP Debug - Total score for \(amount): \(score)")
        }
        
        scoredMatches.sort { $0.2 > $1.2 }
        
        if let bestMatch = scoredMatches.first {
            print("🏆 NLP Debug - Best match selected: \(bestMatch.0) with score \(bestMatch.2)")
            return (bestMatch.0, bestMatch.1)
        }
        
        return matches.first.map { ($0.0, $0.1) } ?? (0, "")
    }
    
    private func calculateContextScore(for matchString: String, in text: String, at position: Int) -> Double {
        var score: Double = 0
        
        let contextStart = max(0, position - 50)
        let contextEnd = min(text.count, position + matchString.count + 50)
        let contextRange = text.index(text.startIndex, offsetBy: contextStart)..<text.index(text.startIndex, offsetBy: contextEnd)
        let context = String(text[contextRange])
        
        print("🔍 NLP Debug - Analyzing context: '\(context)'")
        
        let positiveKeywords = [
            "transfer", "berhasil", "sukses", "masuk", "total", "nominal", 
            "jumlah", "amount", "saldo", "pembayaran", "pembelian"
        ]
        
        let negativeKeywords = [
            "saved", "save", "diskon", "discount", "cashback", "bonus", 
            "fee", "biaya", "admin", "ongkos"
        ]
        
        for keyword in positiveKeywords {
            if context.contains(keyword) {
                score += 10
                print("✅ NLP Debug - Found positive keyword '\(keyword)': +10 points")
            }
        }
        
        for keyword in negativeKeywords {
            if context.contains(keyword) {
                score -= 15
                print("❌ NLP Debug - Found negative keyword '\(keyword)': -15 points")
            }
        }
        
        return score
    }
    
    func extractDate(from text: String) -> Date {
        let datePatterns = [
            "([0-9]{1,2})[/-]([0-9]{1,2})[/-]([0-9]{2,4})",
            "([0-9]{1,2})\\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\s+([0-9]{2,4})",
            "([0-9]{4})[/-]([0-9]{1,2})[/-]([0-9]{1,2})"
        ]
        
        for pattern in datePatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let dateString = String(text[match])
                if let parsedDate = parseDate(from: dateString) {
                    return parsedDate
                }
            }
        }
        
        return Date()
    }
    
    func extractTransactionId(from text: String) -> String {
        let idPatterns = [
            "id[\\s:]*([a-z0-9]{6,})",
            "ref[\\s:]*([a-z0-9]{6,})",
            "txn[\\s:]*([a-z0-9]{6,})",
            "no[\\s:]*([a-z0-9]{6,})",
            "([a-z]{2,}[0-9]{4,})",
            "([0-9]{10,})"
        ]
        
        for pattern in idPatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let idString = String(text[match])
                let cleanId = idString.replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
                if cleanId.count >= 6 {
                    return cleanId.uppercased()
                }
            }
        }
        
        return ""
    }
    
    private func extractContextualAmounts(from text: String) -> [Double] {
        var amounts: [Double] = []
        
        print("🔍 NLP Debug - Starting contextual analysis...")
        
        let financialKeywords = [
            "transfer", "saldo", "total", "amount", "nominal", "jumlah", 
            "berhasil", "sukses", "masuk", "keluar", "debit", "kredit",
            "pembayaran", "pembelian", "belanja", "topup", "isi", "deposit"
        ]
        
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?;"))
        print("📝 NLP Debug - Found \(sentences.count) sentences")
        
        for (index, sentence) in sentences.enumerated() {
            let lowerSentence = sentence.lowercased()
            print("📄 NLP Debug - Analyzing sentence \(index + 1): '\(lowerSentence)'")
            
            for keyword in financialKeywords {
                if lowerSentence.contains(keyword) {
                    print("🎯 NLP Debug - Found financial keyword '\(keyword)' in sentence")
                    let numbers = extractNumbersFromText(sentence)
                    print("🔢 NLP Debug - Numbers found in sentence: \(numbers)")
                    amounts.append(contentsOf: numbers)
                }
            }
        }
        
        let filteredAmounts = amounts.filter { $0 >= 1000 && $0 <= 1000000000 }
        print("✅ NLP Debug - Filtered amounts (1000-1B range): \(filteredAmounts)")
        return filteredAmounts
    }
    
    private func extractNumbersFromText(_ text: String) -> [Double] {
        let numberPattern = "([0-9.,]+)"
        let regex = try? NSRegularExpression(pattern: numberPattern)
        let matches = regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        
        print("🔢 NLP Debug - Extracting numbers from: '\(text)'")
        print("🔍 NLP Debug - Found \(matches.count) number matches")
        
        var numbers: [Double] = []
        
        for (index, match) in matches.enumerated() {
            if let range = Range(match.range, in: text) {
                let numberString = String(text[range])
                let amount = parseIndonesianNumber(numberString)
                print("📊 NLP Debug - Match \(index + 1): '\(numberString)' -> \(amount)")
                if amount > 0 {
                    numbers.append(amount)
                }
            }
        }
        
        print("✅ NLP Debug - Final numbers array: \(numbers)")
        return numbers
    }
    
    private func parseIndonesianNumber(_ numberString: String) -> Double {
        let cleanString = numberString.trimmingCharacters(in: .whitespaces)
        
        print("🔢 NLP Debug - Parsing Indonesian number: '\(cleanString)'")
        
        if cleanString.isEmpty {
            return 0
        }
        
        let hasComma = cleanString.contains(",")
        let hasDot = cleanString.contains(".")
        
        if hasComma && hasDot {
            let dotPosition = cleanString.lastIndex(of: ".")!
            let commaPosition = cleanString.lastIndex(of: ",")!
            
            if dotPosition > commaPosition {
                let integerPart = cleanString[..<dotPosition].replacingOccurrences(of: ",", with: "")
                let decimalPart = String(cleanString[cleanString.index(after: dotPosition)...])
                
                if let integer = Double(integerPart), let decimal = Double(decimalPart) {
                    let result = integer + (decimal / pow(10, Double(decimalPart.count)))
                    print("✅ NLP Debug - Parsed as international format (comma=thousand, dot=decimal): \(result)")
                    return result
                }
            } else {
                let integerPart = cleanString[..<commaPosition].replacingOccurrences(of: ".", with: "")
                let decimalPart = String(cleanString[cleanString.index(after: commaPosition)...])
                
                if let integer = Double(integerPart), let decimal = Double(decimalPart) {
                    let result = integer + (decimal / pow(10, Double(decimalPart.count)))
                    print("✅ NLP Debug - Parsed as Indonesian format (dot=thousand, comma=decimal): \(result)")
                    return result
                }
            }
        } else if hasComma && !hasDot {
            let parts = cleanString.components(separatedBy: ",")
            if parts.count == 2 {
                let integerPart = parts[0]
                let decimalPart = parts[1]
                
                if let integer = Double(integerPart), let decimal = Double(decimalPart) {
                    let result = integer + (decimal / pow(10, Double(decimalPart.count)))
                    print("✅ NLP Debug - Parsed as decimal with comma: \(result)")
                    return result
                }
            } else {
                let withoutComma = cleanString.replacingOccurrences(of: ",", with: "")
                let result = Double(withoutComma) ?? 0
                print("✅ NLP Debug - Parsed as integer (removed comma): \(result)")
                return result
            }
        } else if !hasComma && hasDot {
            let parts = cleanString.components(separatedBy: ".")
            if parts.count == 2 {
                let integerPart = parts[0]
                let decimalPart = parts[1]
                
                if decimalPart.count <= 2 {
                    if let integer = Double(integerPart), let decimal = Double(decimalPart) {
                        let result = integer + (decimal / pow(10, Double(decimalPart.count)))
                        print("✅ NLP Debug - Parsed as decimal with dot: \(result)")
                        return result
                    }
                } else {
                    let withoutDot = cleanString.replacingOccurrences(of: ".", with: "")
                    let result = Double(withoutDot) ?? 0
                    print("✅ NLP Debug - Parsed as integer (removed dot): \(result)")
                    return result
                }
            } else {
                let withoutDot = cleanString.replacingOccurrences(of: ".", with: "")
                let result = Double(withoutDot) ?? 0
                print("✅ NLP Debug - Parsed as integer (removed dot): \(result)")
                return result
            }
        } else {
            let result = Double(cleanString) ?? 0
            print("✅ NLP Debug - Parsed as integer: \(result)")
            return result
        }
        
        print("❌ NLP Debug - Failed to parse number")
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
