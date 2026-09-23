import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import VisionKit

struct RegulatorEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let regulator: Regulator?
    private let externalDraft: Binding<RegulatorDraft>?
    private let onClose: (() -> Void)?
    private let showsActionButtons: Bool

    @State private var draft: RegulatorDraft
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isPresentingCamera = false
    @State private var isShowingCameraUnavailableAlert = false
    @State private var isPresentingSerialScanner = false
    @State private var serialScannerUnavailableMessage: String?

    init(
        regulator: Regulator? = nil,
        draft: Binding<RegulatorDraft>? = nil,
        showsActionButtons: Bool = true,
        onClose: (() -> Void)? = nil
    ) {
        self.regulator = regulator
        self.externalDraft = draft
        self.showsActionButtons = showsActionButtons
        self.onClose = onClose
        _draft = State(initialValue: draft?.wrappedValue ?? RegulatorDraft(regulator: regulator))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    editorHeader
                    photoSection
                    identitySection
                    maintenanceSection
                    if showsActionButtons {
                        editorActions
                    }
                }
                .padding(22)
                .frame(maxWidth: 620)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(OVMTheme.modalSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(OVMTheme.modalBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
                .padding(.horizontal, 20)
                .padding(.vertical, 32)
            }
            .scrollIndicators(.hidden)
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else {
                return
            }

            Task {
                await loadPhoto(from: newValue)
            }
        }
        .fullScreenCover(isPresented: $isPresentingCamera) {
            CameraCaptureView { image in
                activeDraft.photoData.wrappedValue = image.normalizedPhotoData()
                isPresentingCamera = false
            } onCancel: {
                isPresentingCamera = false
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $isPresentingSerialScanner) {
            SerialNumberScannerView { scannedText in
                activeDraft.serialNumber.wrappedValue = scannedText
                isPresentingSerialScanner = false
            } onCancel: {
                isPresentingSerialScanner = false
            }
        }
        .alert("Camera Not Available", isPresented: $isShowingCameraUnavailableAlert) {
            Button("OK", role: .cancel) {
            }
        } message: {
            Text("This device does not currently offer a camera source.")
        }
        .alert("Scanner Not Available", isPresented: serialScannerAlertBinding) {
            Button("OK", role: .cancel) {
            }
        } message: {
            Text(serialScannerUnavailableMessage ?? "This device cannot scan text right now.")
        }
    }

    private var editorHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(regulator == nil ? "Add First Stage" : "Edit First Stage")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(OVMTheme.textPrimary)

                    Text("Store the first stage details you need before a dive: brand, type, service dates, serial, and a reference photo.")
                        .font(.subheadline)
                        .foregroundStyle(OVMTheme.textSecondary)
                }

                Spacer(minLength: 0)

                Button {
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(OVMTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(OVMTheme.card.opacity(0.8))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close first stage editor")
            }

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(OVMTheme.warningBackground.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(OVMTheme.modalHighlight, lineWidth: 1)
                )
                .overlay(alignment: .leading) {
                    Text("Service dates are reminders only. Always follow the first stage manufacturer and technician service requirements.")
                        .font(.subheadline)
                        .foregroundStyle(OVMTheme.modalHighlight)
                        .padding(16)
                }
                .frame(minHeight: 92)
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            editorSectionTitle("Picture")

            EquipmentPhotoPreview(
                photoData: activeDraft.photoData.wrappedValue,
                emptyTitle: "No first stage photo yet",
                emptyMessage: "Choose one from the photo library or take a new photo directly."
            )

            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(
                        activeDraft.photoData.wrappedValue == nil ? "Choose Photo" : "Replace Photo",
                        systemImage: "photo.on.rectangle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(EditorSecondaryButtonStyle())

                Button {
                    openCamera()
                } label: {
                    Label("Take Photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EditorSecondaryButtonStyle())
            }

            if activeDraft.photoData.wrappedValue != nil {
                Button(role: .destructive) {
                    activeDraft.photoData.wrappedValue = nil
                    selectedPhotoItem = nil
                } label: {
                    Text("Remove Photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EditorDangerButtonStyle())
            }
        }
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            editorSectionTitle("First Stage")
            editorTextField(title: "Brand", text: binding(\.brand))
            editorTextField(title: "Type", text: binding(\.type))
            serialNumberField
        }
    }

    private var serialNumberField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Serial Number")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(OVMTheme.textTertiary)

            HStack(spacing: 12) {
                TextField("", text: binding(\.serialNumber))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .foregroundStyle(OVMTheme.textPrimary)

                Button {
                    openSerialScanner()
                } label: {
                    Image(systemName: "viewfinder")
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(OVMTheme.accent)
                .accessibilityLabel("Scan serial number")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(editorFieldBackground)
        }
    }

    private var maintenanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            editorSectionTitle("Service")
            OptionalDateInput(title: "Service Date", date: binding(\.serviceDate))
            OptionalDateInput(title: "Next Service Date", date: binding(\.nextServiceDate))
        }
    }

    private var editorActions: some View {
        HStack {
            Button("Cancel") {
                close()
            }
            .buttonStyle(EditorSecondaryButtonStyle())

            Spacer(minLength: 12)

            Button(regulator == nil ? "Save First Stage" : "Update First Stage") {
                saveRegulator()
            }
            .buttonStyle(EditorPrimaryButtonStyle())
            .disabled(activeDraft.wrappedValue.isValid == false)
        }
        .padding(.top, 6)
    }

    private var editorFieldBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(OVMTheme.card.opacity(0.78))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(OVMTheme.border.opacity(0.95), lineWidth: 1)
            )
    }

    private func editorSectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(OVMTheme.textTertiary)
    }

    private func editorTextField(
        title: LocalizedStringKey,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(OVMTheme.textTertiary)

            TextField("", text: text)
                .keyboardType(keyboardType)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(editorFieldBackground)
                .foregroundStyle(OVMTheme.textPrimary)
        }
    }

    private func saveRegulator() {
        let currentDraft = activeDraft.wrappedValue

        if let regulator {
            currentDraft.apply(to: regulator)
        } else {
            modelContext.insert(currentDraft.makeRegulator())
        }

        close()
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private var activeDraft: Binding<RegulatorDraft> {
        if let externalDraft {
            externalDraft
        } else {
            $draft
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<RegulatorDraft, Value>) -> Binding<Value> {
        Binding(
            get: {
                activeDraft.wrappedValue[keyPath: keyPath]
            },
            set: { newValue in
                activeDraft.wrappedValue[keyPath: keyPath] = newValue
            }
        )
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            isShowingCameraUnavailableAlert = true
            return
        }

        isPresentingCamera = true
    }

    private func openSerialScanner() {
        guard DataScannerViewController.isSupported else {
            serialScannerUnavailableMessage = "This device does not support live text scanning."
            return
        }

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            serialScannerUnavailableMessage = "This device does not currently offer a camera source."
            return
        }

        isPresentingSerialScanner = true
    }

    private func loadPhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }

        await MainActor.run {
            activeDraft.photoData.wrappedValue = image.normalizedPhotoData()
        }
    }

    private var serialScannerAlertBinding: Binding<Bool> {
        Binding(
            get: { serialScannerUnavailableMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    serialScannerUnavailableMessage = nil
                }
            }
        )
    }
}
