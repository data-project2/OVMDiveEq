import SwiftData
import SwiftUI

struct CylinderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let cylinder: Cylinder?
    private let onClose: (() -> Void)?

    @State private var name: String
    @State private var brand: String
    @State private var material: CylinderMaterial
    @State private var volumeLitersText: String
    @State private var colorName: String
    @State private var vipDate: Date?
    @State private var nextVIPDueDate: Date?
    @State private var hydroDate: Date?
    @State private var nextHydroDueDate: Date?
    @State private var notes: String

    init(cylinder: Cylinder? = nil, onClose: (() -> Void)? = nil) {
        self.cylinder = cylinder
        self.onClose = onClose
        _name = State(initialValue: cylinder?.name ?? "")
        _brand = State(initialValue: cylinder?.brand ?? "")
        _material = State(initialValue: cylinder?.material ?? .steel)
        _volumeLitersText = State(initialValue: cylinder?.volumeLiters.map { String($0) } ?? "")
        _colorName = State(initialValue: cylinder?.colorName ?? "")
        _vipDate = State(initialValue: cylinder?.vipDate)
        _nextVIPDueDate = State(initialValue: cylinder?.nextVIPDueDate)
        _hydroDate = State(initialValue: cylinder?.hydroDate)
        _nextHydroDueDate = State(initialValue: cylinder?.nextHydroDueDate)
        _notes = State(initialValue: cylinder?.notes ?? "")
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    editorHeader
                    identitySection
                    maintenanceSection(title: "Hydro", testDate: $hydroDate, dueDate: $nextHydroDueDate)
                    maintenanceSection(title: "VIP", testDate: $vipDate, dueDate: $nextVIPDueDate)
                    notesSection
                    editorActions
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
    }

    private var editorHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(cylinder == nil ? "Add Tank" : "Edit Tank")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(OVMTheme.textPrimary)

                    Text("Store the tank details you actually use before a dive: identity, material, volume, color, and maintenance dates.")
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
                .accessibilityLabel("Close tank editor")
            }

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(OVMTheme.warningBackground.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(OVMTheme.modalHighlight, lineWidth: 1)
                )
                .overlay(alignment: .leading) {
                    Text("Maintenance dates are reminders only. The app does not determine whether a tank is safe to dive.")
                        .font(.subheadline)
                        .foregroundStyle(OVMTheme.modalHighlight)
                        .padding(16)
                }
                .frame(minHeight: 92)
        }
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            editorSectionTitle("Tank")
            editorTextField(title: "Name", text: $name)
            editorTextField(title: "Brand", text: $brand)
            materialPicker
            editorTextField(title: "Volume in liters", text: $volumeLitersText, keyboardType: .decimalPad)
            editorTextField(title: "Color", text: $colorName)
        }
    }

    private var materialPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Material")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(OVMTheme.textTertiary)

            Picker("Material", selection: $material) {
                ForEach(CylinderMaterial.allCases) { material in
                    Text(material.displayName).tag(material)
                }
            }
            .pickerStyle(.segmented)
            .tint(OVMTheme.accent)
        }
    }

    private func maintenanceSection(
        title: String,
        testDate: Binding<Date?>,
        dueDate: Binding<Date?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            editorSectionTitle(LocalizedStringKey(title))
            OptionalDateInput(title: "\(title) Date", date: testDate)
            OptionalDateInput(title: "Next \(title) Date", date: dueDate)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            editorSectionTitle("Notes")

            TextField("Comments", text: $notes, axis: .vertical)
                .lineLimit(4...7)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(editorFieldBackground)
                .foregroundStyle(OVMTheme.textPrimary)
        }
    }

    private var editorActions: some View {
        HStack {
            Button("Cancel") {
                close()
            }
            .buttonStyle(EditorSecondaryButtonStyle())

            Spacer(minLength: 12)

            Button(cylinder == nil ? "Save Tank" : "Update Tank") {
                saveCylinder()
            }
            .buttonStyle(EditorPrimaryButtonStyle())
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    private func saveCylinder() {
        let targetCylinder = cylinder ?? Cylinder(name: normalized(name))

        targetCylinder.name = normalized(name)
        targetCylinder.brand = normalized(brand)
        targetCylinder.material = material
        targetCylinder.volumeLiters = Double(normalized(volumeLitersText))
        targetCylinder.colorName = normalized(colorName)
        targetCylinder.vipDate = vipDate
        targetCylinder.nextVIPDueDate = nextVIPDueDate
        targetCylinder.hydroDate = hydroDate
        targetCylinder.nextHydroDueDate = nextHydroDueDate
        targetCylinder.notes = normalized(notes)
        targetCylinder.updatedAt = .now

        if cylinder == nil {
            modelContext.insert(targetCylinder)
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

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct OptionalDateInput: View {
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

private struct EditorPrimaryButtonStyle: ButtonStyle {
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

private struct EditorSecondaryButtonStyle: ButtonStyle {
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
