import SwiftUI
import UIKit
import Vision

/// Camera capture for the insurance card. In the free tier the image is used
/// once for on-device text recognition and then discarded; nothing is written
/// to disk. Premium can hand the same image to the vault.
struct CameraCapture: UIViewControllerRepresentable {
    var onImage: (UIImage?) -> Void

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = Self.isAvailable ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage?) -> Void
        init(onImage: @escaping (UIImage?) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onImage(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onImage(nil) }
    }
}

/// On-device text recognition and light parsing for insurance cards.
enum CardScanner {
    struct Result {
        var carrier = ""
        var memberID = ""
        var groupNumber = ""
        var phone = ""
        var rawLines: [String] = []
    }

    static func recognize(_ image: UIImage) async -> Result {
        guard let cgImage = image.cgImage else { return Result() }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let lines = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                continuation.resume(returning: parse(lines: lines))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation(image.imageOrientation))
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) } catch { continuation.resume(returning: Result()) }
            }
        }
    }

    /// Pulls carrier, member ID, group and phone out of recognized lines.
    /// Heuristics only; the user always sees and can edit the result.
    static func parse(lines: [String]) -> Result {
        var result = Result(rawLines: lines)
        let knownCarriers = ["Aetna", "Anthem", "Blue Cross", "Blue Shield", "BCBS", "Cigna", "Humana", "Kaiser", "UnitedHealthcare", "United Healthcare", "UHC", "Oscar", "Molina", "Centene", "Ambetter", "Medicaid", "Medicare", "Tricare", "Delta Dental", "MetLife", "Guardian"]

        for line in lines {
            let lower = line.lowercased()
            if result.carrier.isEmpty, let carrier = knownCarriers.first(where: { lower.contains($0.lowercased()) }) {
                result.carrier = carrier
            }
            if result.memberID.isEmpty, lower.contains("member") || lower.contains("id#") || lower.contains("id:") || lower.contains("subscriber") {
                result.memberID = trailingToken(in: line)
            }
            if result.groupNumber.isEmpty, lower.contains("group") || lower.contains("grp") {
                result.groupNumber = trailingToken(in: line)
            }
            if result.phone.isEmpty, let phone = firstPhone(in: line) {
                result.phone = phone
            }
        }
        if result.carrier.isEmpty, let first = lines.first, first.count <= 40 {
            result.carrier = first
        }
        return result
    }

    private static func trailingToken(in line: String) -> String {
        let parts = line.split(whereSeparator: { $0 == ":" || $0 == "#" || $0 == " " }).map(String.init)
        guard let last = parts.last else { return "" }
        let cleaned = last.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return cleaned.count >= 4 && cleaned.contains(where: \.isNumber) ? cleaned : ""
    }

    private static func firstPhone(in line: String) -> String? {
        let pattern = #"(?:\+?1[\s.-]?)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range, in: line) else { return nil }
        return String(line[range])
    }

    private static func cgOrientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
