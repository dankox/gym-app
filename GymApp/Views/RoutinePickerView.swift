import SwiftUI
import SwiftData

struct RoutinePickerView: View {
    @Environment(ThemeManager.self) private var themeManager
    let date: Date

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]
    @Query private var workoutDays: [WorkoutDay]

    @State private var showCreateRoutine = false

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
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Text("No routines saved")
                    .font(.title2.bold())
                Text("Create your first routine to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showCreateRoutine = true
            } label: {
                Label("Create New Routine", systemImage: "plus.circle.fill")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding()
    }

    // MARK: - Import Logic

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
                pausePoints: template.currentPausePoints
            )
            workoutDay.exercises.append(exercise)
        }

        dismiss()
    }
}
