import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RoutineListView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]
    @Environment(\.modelContext) private var modelContext

    @State private var showCreateRoutine = false
    @State private var routineToEdit: Routine?
    @State private var showFileImporter = false
    @State private var shareURLItem: IdentifiableURL? = nil
    @State private var alertMessage: String? = nil
    @State private var showAlert = false
    @State private var routineToDelete: Routine? = nil
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(routines) { routine in
                            Button {
                                routineToEdit = routine
                            } label: {
                                RoutineRow(
                                    routine: routine,
                                    onExport: {
                                        exportRoutine(routine)
                                    },
                                    onDelete: {
                                        routineToDelete = routine
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    routineToDelete = routine
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)

                                Button {
                                    exportRoutine(routine)
                                } label: {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                }
                                .tint(themeManager.completedColor)
                            }
                            .contextMenu {
                                Button {
                                    exportRoutine(routine)
                                } label: {
                                    Label("Export Routine (.gym.json)", systemImage: "square.and.arrow.up")
                                }
                                Button {
                                    routineToEdit = routine
                                } label: {
                                    Label("Edit Routine", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    routineToDelete = routine
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete Routine", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: deleteRoutines)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Routines")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !routines.isEmpty {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Menu {
                            Button {
                                showCreateRoutine = true
                            } label: {
                                Label("Create New Routine", systemImage: "plus")
                            }
                            Button {
                                showFileImporter = true
                            } label: {
                                Label("Import Routine (.gym.json)", systemImage: "square.and.arrow.down")
                            }
                            if !routines.isEmpty {
                                Button {
                                    exportAllRoutines()
                                } label: {
                                    Label("Export All Routines", systemImage: "square.and.arrow.up")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .fontWeight(.semibold)
                        }

                        Button {
                            showCreateRoutine = true
                        } label: {
                            Image(systemName: "plus")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateRoutine) {
                CreateRoutineView()
            }
            .sheet(item: $routineToEdit) { routine in
                CreateRoutineView(routine: routine)
            }
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
            .confirmationDialog(
                "Delete Routine",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let routine = routineToDelete {
                        modelContext.delete(routine)
                        routineToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    routineToDelete = nil
                }
            } message: {
                if let routine = routineToDelete {
                    Text("Are you sure you want to delete '\(routine.name)'?")
                } else {
                    Text("Are you sure you want to delete this routine?")
                }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Text("No routines yet")
                    .font(.title2.bold())
                Text("Build or import your exercise routines.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 12) {
                Button {
                    showCreateRoutine = true
                } label: {
                    Label("Create Routine", systemImage: "plus.circle.fill")
                        .frame(maxWidth: 280)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    showFileImporter = true
                } label: {
                    Label("Import from File (.gym.json)", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: 280)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            Spacer()
        }
        .padding()
    }

    private func exportRoutine(_ routine: Routine) {
        do {
            let url = try RoutineTransferService.createTemporaryFileURL(for: routine)
            shareURLItem = IdentifiableURL(url: url)
        } catch {
            alertMessage = "Failed to prepare export file: \(error.localizedDescription)"
            showAlert = true
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

    func deleteRoutines(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(routines[index])
        }
    }
}

// MARK: - Routine Row

struct RoutineRow: View {
    @Environment(ThemeManager.self) private var themeManager

    let routine: Routine
    var onExport: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(themeManager.accentColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(themeManager.accentColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(routine.name)
                    .font(.headline)
                Text(
                    "\(routine.exercises.count) exercise\(routine.exercises.count == 1 ? "" : "s")"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()

            HStack(spacing: 14) {
                if let onExport {
                    Button {
                        onExport()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(themeManager.completedColor)
                            .font(.body)
                    }
                    .buttonStyle(.borderless)
                }

                if let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                            .font(.body)
                    }
                    .buttonStyle(.borderless)
                    .tint(.red)
                }
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.footnote.bold())
        }
        .padding(.vertical, 6)
    }
}
