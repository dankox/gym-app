import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]

    @State private var showFileImporter = false
    @State private var shareURLItem: IdentifiableURL? = nil
    @State private var alertMessage: String? = nil
    @State private var showAlert = false

    var body: some View {
        NavigationStack {
            Form {
                // Appearance Section
                Section {
                    Picker("Appearance", selection: Bindable(themeManager).appearance) {
                        ForEach(AppAppearance.allCases) { mode in
                            Label(mode.rawValue, systemImage: mode.iconName)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Appearance")
                } footer: {
                    if themeManager.appearance == .oledDark {
                        Text("OLED Black mode optimizes contrast for OLED displays.")
                    }
                }

                // Accent Color Presets
                Section("Theme Accent Color") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                        spacing: 12
                    ) {
                        ForEach(PresetThemeColor.presets) { preset in
                            Button {
                                themeManager.accentColorHex = preset.hex
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(preset.color)
                                            .frame(width: 44, height: 44)

                                        if themeManager.accentColorHex.uppercased() == preset.hex.uppercased() {
                                            Image(systemName: "checkmark")
                                                .font(.headline.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    Text(preset.name)
                                        .font(.caption2)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Custom Color Pickers
                Section("Theme Colors") {
                    ColorPicker(
                        "Accent Color",
                        selection: Binding(
                            get: { themeManager.accentColor },
                            set: { themeManager.accentColor = $0 }
                        ),
                        supportsOpacity: false
                    )

                    ColorPicker(
                        "Pause / Secondary Color",
                        selection: Binding(
                            get: { themeManager.secondaryColor },
                            set: { themeManager.secondaryColor = $0 }
                        ),
                        supportsOpacity: false
                    )

                    ColorPicker(
                        "Completed Status Color",
                        selection: Binding(
                            get: { themeManager.completedColor },
                            set: { themeManager.completedColor = $0 }
                        ),
                        supportsOpacity: false
                    )
                }

                // Theme Preview
                Section("Theme Preview") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(themeManager.accentColor)
                                    .frame(width: 36, height: 36)
                                Text("15")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Push Day Routine")
                                    .font(.headline)
                                Text("4 exercises • 3 sets each")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(themeManager.completedColor)
                        }

                        HStack {
                            Button("Action Button") {}
                                .buttonStyle(.borderedProminent)
                                .tint(themeManager.accentColor)

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "pause.circle.fill")
                                Text("Paused Timer")
                            }
                            .font(.subheadline.bold())
                            .foregroundStyle(themeManager.secondaryColor)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Reset Section
                Section {
                    Button(role: .destructive) {
                        themeManager.resetToDefaults()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset Theme to Default")
                            Spacer()
                        }
                    }
                }

                // Routines Export / Import
                Section("Routines Data") {
                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Import Routine (.gym.json)", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        exportAllRoutines()
                    } label: {
                        Label("Export All Routines (.gym.json)", systemImage: "square.and.arrow.up")
                    }
                    .disabled(routines.isEmpty)
                }
            }
            .navigationTitle("Settings & Theme")
            .sheet(item: $shareURLItem) { item in
                ActivityView(activityItems: [item.url])
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.json, .gymJson, UTType(importedAs: "public.json")],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert("Routine Import/Export", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func exportAllRoutines() {
        do {
            let url = try RoutineTransferService.createTemporaryFileURL(for: Array(routines))
            shareURLItem = IdentifiableURL(url: url)
        } catch {
            alertMessage = "Failed to prepare export file: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                alertMessage = "Permission denied to access file."
                showAlert = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                let importedRoutines = try RoutineTransferService.decodeRoutines(from: data)
                for r in importedRoutines {
                    modelContext.insert(r)
                }
                if importedRoutines.count == 1 {
                    alertMessage = "Successfully imported routine: '\(importedRoutines[0].name)'"
                } else {
                    alertMessage = "Successfully imported \(importedRoutines.count) routines."
                }
                showAlert = true
            } catch {
                alertMessage = "Failed to import routine: \(error.localizedDescription)"
                showAlert = true
            }
        case .failure(let error):
            alertMessage = "File selection error: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
