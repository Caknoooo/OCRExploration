import SwiftUI
import Vision
import UIKit
import Combine

struct OCRCanvasView: View {
    let image: UIImage
    let recognizedTexts: [VNRecognizedTextObservation]
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                
                ForEach(Array(recognizedTexts.enumerated()), id: \.offset) { index, observation in
                    if let recognizedText = observation.topCandidates(1).first {
                        Text(recognizedText.string)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                            .background(Color.yellow.opacity(0.3))
                            .padding(2)
                            .position(
                                x: geometry.size.width * observation.boundingBox.midX,
                                y: geometry.size.height * (1 - observation.boundingBox.midY)
                            )
                            .scaleEffect(scale)
                            .offset(offset)
                    }
                }
            }
            .clipped()
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = value
                    }
                    .onEnded { value in
                        scale = max(0.5, min(3.0, scale))
                    }
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation
                    }
            )
        }
        .background(Color.black)
        .cornerRadius(8)
    }
}

struct OCRResultView: View {
    let image: UIImage
    let recognizedTexts: [VNRecognizedTextObservation]
    @State private var showingCanvas = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Hasil OCR")
                    .font(.headline)
                Spacer()
                Button("Lihat Canvas") {
                    showingCanvas = true
                }
                .buttonStyle(.bordered)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(recognizedTexts.enumerated()), id: \.offset) { index, observation in
                        if let recognizedText = observation.topCandidates(1).first {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Text \(index + 1):")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(recognizedText.string)
                                    .font(.body)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                                
                                Text("Confidence: \(Int(recognizedText.confidence * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .sheet(isPresented: $showingCanvas) {
            NavigationView {
                OCRCanvasView(image: image, recognizedTexts: recognizedTexts)
                    .navigationTitle("OCR Canvas")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Tutup") {
                                showingCanvas = false
                            }
                        }
                    }
            }
        }
    }
}

class OCRCanvasService: ObservableObject {
    @Published var recognizedTexts: [VNRecognizedTextObservation] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    func processImage(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil
        recognizedTexts = []
        
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
}
