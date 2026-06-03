//
//  ReceiptTextExtractor.swift
//  Rubradar
//

import Foundation
import Vision
import PDFKit
#if canImport(UIKit)
import UIKit
#endif

enum ReceiptTextError: Error {
    case couldNotDecodeImage
    case noText
}

/// Turns a receipt source (image data, PDF data, or plain text) into raw text.
/// Images and scanned PDFs go through Vision OCR; text-based PDFs use PDFKit.
enum ReceiptTextExtractor {

    static func text(fromImageData data: Data) async throws -> String {
        guard let cgImage = downsampledCGImage(from: data, maxPixel: 2500) else {
            throw ReceiptTextError.couldNotDecodeImage
        }
        return try await recognizeText(in: cgImage)
    }

    static func text(fromPDFData data: Data) async throws -> String {
        guard let document = PDFDocument(data: data) else { throw ReceiptTextError.noText }

        // Prefer the embedded text layer when present.
        if let embedded = document.string?.trimmingCharacters(in: .whitespacesAndNewlines),
           !embedded.isEmpty {
            return embedded
        }

        // Otherwise OCR the first few rendered pages (scanned PDF).
        var pieces: [String] = []
        for index in 0..<min(document.pageCount, 3) {
            guard let page = document.page(at: index),
                  let cgImage = render(page: page) else { continue }
            if let text = try? await recognizeText(in: cgImage) { pieces.append(text) }
        }
        let joined = pieces.joined(separator: "\n")
        guard !joined.isEmpty else { throw ReceiptTextError.noText }
        return joined
    }

    // MARK: - Vision OCR

    private static func recognizeText(in image: CGImage) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let observations = try await request.perform(on: image)
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        guard !lines.isEmpty else { throw ReceiptTextError.noText }
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// Decodes and downsamples image data off the full-resolution path to keep
    /// memory flat while staying sharp enough for OCR.
    private static func downsampledCGImage(from data: Data, maxPixel: CGFloat) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func render(page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        return image.cgImage
        #else
        return nil
        #endif
    }
}
