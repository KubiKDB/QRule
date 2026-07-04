import CoreGraphics
import Vision

struct ScanResult {
    let payload: String

    private static let openableSchemes: Set<String> = [
        "http", "https", "mailto", "tel", "sms", "facetime", "maps", "geo"
    ]

    var openableURL: URL? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           Self.openableSchemes.contains(scheme) {
            return url
        }
        if trimmed.lowercased().hasPrefix("www."),
           !trimmed.contains(" "),
           let url = URL(string: "https://" + trimmed) {
            return url
        }
        return nil
    }
}

enum DecodeService {
    /// Decodes the first QR code found in the image, or nil if none.
    static func decodeQR(in image: CGImage) async -> ScanResult? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNDetectBarcodesRequest()
                request.symbologies = [.qr, .microQR]

                let handler = VNImageRequestHandler(cgImage: image)
                try? handler.perform([request])

                let payload = request.results?
                    .compactMap(\.payloadStringValue)
                    .first

                continuation.resume(returning: payload.map(ScanResult.init))
            }
        }
    }
}
