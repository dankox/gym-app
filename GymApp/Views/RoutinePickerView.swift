import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RoutinePickerView: View {
    @Environment(ThemeManager.self) private var themeManager
    let date: Date

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]
    @Query private var workoutDays: [WorkoutDay]

    @State private var showCreateRoutine = false
    @State private var showFileImporter = false
    @State private var alertMessage: String? = nil
    @State private var showAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty {
                    emptyState
                } else {
                    routineList
                }
            }
            .navigationTitle("Import Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateRoutine = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showCreateRoutine) {
                CreateRoutineView()
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.json, .gymJson, UTType(importedAs: "public.json")],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert("Routine Import", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    // MARK: - Routine List

    var routineList: some View {
        List {
            Section {
                Button {
                    showCreateRoutine = true
                } label: {
                    Label("Create New Routine", systemImage: "plus.circle.fill")
                        .foregroundStyle(themeManager.accentColor)
                        .fontWeight(.medium)
                }

                Button {
                    showFileImporter = true
                } label: {
                    Label("Import from File (.gym.json)", systemImage: "square.and.arrow.down.fill")
                        .foregroundStyle(themeManager.accentColor)
                        .fontWeight(.medium)
                }
            }

            Section("Saved Routines") {
                ForEach(routines) { routine in
                    Button {
                        importRoutine(routine)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(routine.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(
                                    "\(routine.exercises.count) exercise\(routine.exercises.count == 1 ? "" : "s")"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "square.and.arrow.down")
                                .foregroundStyle(themeManager.accentColor)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Text("No routines saved")
                    .font(.title2.bold())
                Text("Create a routine or import one from a file.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 12) {
                Button {
                    showCreateRoutine = true
                } label: {
                    Label("Create New Routine", systemImage: "plus.circle.fill")
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

    // MARK: - Import Logic

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
                    importRoutine(r)
                }
            } catch {
                alertMessage = "Failed to import routine: \(error.localizedDescription)"
                showAlert = true
            }
        case .failure(let error):
            alertMessage = "File selection error: \(error.localizedDescription)"
            showAlert = true
        }
    }

    func importRoutine(_ routine: Routine) {
        let workoutDay: WorkoutDay
        if let existing = workoutDays.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }) {
            workoutDay = existing
            if workoutDay.routineName.isEmpty {
                workoutDay.routineName = routine.name
            } else if !workoutDay.routineName.components(separatedBy: ", ").contains(routine.name) {
                workoutDay.routineName += ", \(routine.name)"
            }
        } else {
            workoutDay = WorkoutDay(date: date, routineName: routine.name)
            modelContext.insert(workoutDay)
        }

        let currentMaxSort = workoutDay.exercises.map(\.sortOrder).max() ?? -1
        let sortedExercises = routine.exercises.sorted { $0.sortOrder < $1.sortOrder }
        for (index, template) in sortedExercises.enumerated() {
            let exercise = WorkoutExercise(
                name: template.name,
                sets: template.sets,
                reps: template.reps,
                restSeconds: template.restSeconds,
                sortOrder: currentMaxSort + 1 + index,
                routineName: routine.name,
                pausePoints: template.currentPausePoints,
                notes: template.currentNotes
            )
            workoutDay.exercises.append(exercise)
        }

        dismiss()
    }
}
