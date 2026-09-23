import SwiftUI
import UIKit
import VisionKit

struct EquipmentPhotoPreview: View {
    let photoData: Data?
    let emptyTitle: LocalizedStringKey
    let emptyMessage: LocalizedStringKey

    var body: some View {
        Group {
            if let photoImage {
                Image(uiImage: photoImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(OVMTheme.card.opacity(0.82))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(OVMTheme.border, lineWidth: 1)
                    )
                    .frame(height: 180)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.viewfinder")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(OVMTheme.accent)

                            Text(emptyTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(OVMTheme.textPrimary)

                            Text(emptyMessage)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(OVMTheme.textSecondary)
                                .padding(.horizontal, 20)
                        }
                    }
            }
        }
    }

    private var photoImage: UIImage? {
        guard let photoData else {
            return nil
        }

        return UIImage(data: photoData)
    }
}

struct OptionalDateInput: View {
    let title: LocalizedStringKey
    @Binding var date: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(OVMTheme.textTertiary)

                Spacer(minLength: 0)

                if date != nil {
                    Button("Clear") {
                        date = nil
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OVMTheme.accent)
                }
            }

            DatePicker(
                "",
                selection: nonOptionalDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(editorFieldBackground)
            .overlay(alignment: .trailing) {
                Button {
                    if date == nil {
                        date = .now
                    }
                } label: {
                    Text(date == nil ? "Set" : "")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(OVMTheme.accent)
                        .padding(.trailing, 14)
                }
            }
            .opacity(date == nil ? 0.58 : 1)
        }
    }

    private var nonOptionalDate: Binding<Date> {
        Binding(
            get: { date ?? .now },
            set: { date = $0 }
        )
    }

    private var editorFieldBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(OVMTheme.card.opacity(0.78))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(OVMTheme.border.opacity(0.95), lineWidth: 1)
            )
    }
}

struct EditorPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(OVMTheme.background)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(OVMTheme.accent.opacity(configuration.isPressed ? 0.75 : 1))
            )
    }
}

struct EditorSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(OVMTheme.textPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(OVMTheme.card.opacity(configuration.isPressed ? 0.6 : 0.9))
            )
            .overlay(
                Capsule()
                    .stroke(OVMTheme.border, lineWidth: 1)
            )
    }
}

struct EditorDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(OVMTheme.danger)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(OVMTheme.dangerBackground.opacity(configuration.isPressed ? 0.7 : 1))
            )
            .overlay(
                Capsule()
                    .stroke(OVMTheme.danger.opacity(0.6), lineWidth: 1)
            )
    }
}

struct CameraCaptureView: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImagePicked: (UIImage) -> Void
        private let onCancel: () -> Void

        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            } else {
                onCancel()
            }
        }
    }
}

struct SerialNumberScannerView: View {
    let onRecognized: (String) -> Void
    let onCancel: () -> Void

    @State private var guidanceText = "Align the serial number or invoice text, then tap the highlighted match."
    @State private var unavailableMessage: String?

    var body: some View {
        ZStack(alignment: .top) {
            SerialScannerRepresentable(
                onRecognized: onRecognized,
                onGuidanceChange: { guidanceText = $0 },
                onUnavailable: { unavailableMessage = $0 }
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Spacer()

                    Button("Close") {
                        onCancel()
                    }
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.55), in: Capsule())
                }

                Text(guidanceText)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
        }
        .alert("Scanner Not Available", isPresented: unavailableAlertBinding) {
            Button("OK", role: .cancel) {
                onCancel()
            }
        } message: {
            Text(unavailableMessage ?? "This device cannot scan text right now.")
        }
    }

    private var unavailableAlertBinding: Binding<Bool> {
        Binding(
            get: { unavailableMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    unavailableMessage = nil
                }
            }
        )
    }
}

private struct SerialScannerRepresentable: UIViewControllerRepresentable {
    let onRecognized: (String) -> Void
    let onGuidanceChange: (String) -> Void
    let onUnavailable: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onRecognized: onRecognized,
            onGuidanceChange: onGuidanceChange,
            onUnavailable: onUnavailable
        )
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator

        do {
            try controller.startScanning()
        } catch {
            context.coordinator.handleUnavailable(error)
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onRecognized: (String) -> Void
        private let onGuidanceChange: (String) -> Void
        private let onUnavailable: (String) -> Void

        init(
            onRecognized: @escaping (String) -> Void,
            onGuidanceChange: @escaping (String) -> Void,
            onUnavailable: @escaping (String) -> Void
        ) {
            self.onRecognized = onRecognized
            self.onGuidanceChange = onGuidanceChange
            self.onUnavailable = onUnavailable
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard allItems.isEmpty == false else {
                onGuidanceChange("Align the serial number or invoice text, then tap the highlighted match.")
                return
            }

            onGuidanceChange("Tap the highlighted serial number you want to use.")
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            guard case let .text(text) = item else {
                return
            }

            let transcript = text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard transcript.isEmpty == false else {
                return
            }

            onRecognized(transcript)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: any Error) {
            handleUnavailable(error)
        }

        func handleUnavailable(_ error: any Error) {
            if let unavailable = error as? DataScannerViewController.ScanningUnavailable {
                switch unavailable {
                case .unsupported:
                    onUnavailable("This device does not support live text scanning.")
                default:
                    onUnavailable("Text scanning is currently unavailable. Check camera access and try again.")
                }
            } else {
                onUnavailable("Text scanning is currently unavailable. Check camera access and try again.")
            }
        }
    }
}

extension UIImage {
    func normalizedPhotoData(maxDimension: CGFloat = 1600, compressionQuality: CGFloat = 0.82) -> Data? {
        let largestSide = max(size.width, size.height)
        let resizeRatio = min(1, maxDimension / largestSide)
        let targetSize = CGSize(
            width: size.width * resizeRatio,
            height: size.height * resizeRatio
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return rendered.jpegData(compressionQuality: compressionQuality)
    }
}
