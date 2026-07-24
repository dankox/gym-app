import SwiftUI
import SwiftData

// MARK: - Day Detail View (outer shell, queries for the day)

struct DayDetailView: View {
    let date: Date

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var workoutDays: [WorkoutDay]

    @State private var showRoutinePicker = false
    @State private var showDeleteConfirmation = false

    private var workoutDay: WorkoutDay? {
        workoutDays.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let day = workoutDay {
                    WorkoutDayEditor(day: day)
                } else {
                    emptyContent
                }
            }
            .navigationTitle(
                date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if workoutDay != nil {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                        Button {
                            showRoutinePicker = true
                        } label: {
                            Label(
                                workoutDay == nil ? "Import Routine" : "Change Routine",
                                systemImage: "square.and.arrow.down"
                            )
                        }
                    }
                }
            }
            .sheet(isPresented: $showRoutinePicker) {
                RoutinePickerView(date: date)
            }
            .confirmationDialog(
                "Remove Logged Workout",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    if let day = workoutDay {
                        modelContext.delete(day)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to remove the logged workout for this day?")
            }
        }
    }

    // MARK: - Empty State

    var emptyContent: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Text("No workout yet")
                    .font(.title2.bold())
                Text("Import a saved routine to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showRoutinePicker = true
            } label: {
                Label("Import Exercise Routine", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding()
    }
}

// MARK: - Workout Day Editor (uses @Bindable for notes binding)

struct WorkoutDayEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var day: WorkoutDay

    private var sortedExercises: [WorkoutExercise] {
        day.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var completedCount: Int {
        day.exercises.filter(\.isCompleted).count
    }

    // Bridge optional String? to the String that TextEditor requires.
    private var notesBinding: Binding<String> {
        Binding(
            get: { day.notes ?? "" },
            set: { day.notes = $0.isEmpty ? nil : $0 }
        )
    }

    private var hasNotes: Bool { !(day.notes ?? "").isEmpty }

    var body: some View {
        List {
            // Routine badge
            if !day.routineName.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "list.bullet.clipboard.fill")
                            .foregroundStyle(Color.accentColor)
                        Text(day.routineName)
                            .font(.headline)
                    }
                } header: {
                    Text("Routine")
                }
            }

            // Exercises
            Section {
                if sortedExercises.isEmpty {
                    Text("No exercises")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(sortedExercises) { exercise in
                        WorkoutExerciseRow(exercise: exercise)
                    }
                    .onDelete(perform: deleteExercises)
                }
            } header: {
                exercisesSectionHeader
            }

            // Notes
            Section {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: notesBinding)
                        .frame(minHeight: 110)
                    if !hasNotes {
                        Text("Add notes for this workout…")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
            } header: {
                Text("Notes")
            }
        }
        .listStyle(.insetGrouped)
    }

    var exercisesSectionHeader: some View {
        HStack {
            Text("Exercises")
            Spacer()
            if !day.exercises.isEmpty {
                Text("\(completedCount) / \(day.exercises.count) done")
                    .font(.caption)
                    .foregroundStyle(completedCount == day.exercises.count ? Color.green : .secondary)
                    .fontWeight(completedCount == day.exercises.count ? .semibold : .regular)
            }
        }
    }

    private func deleteExercises(at offsets: IndexSet) {
        for index in offsets {
            let exercise = sortedExercises[index]
            modelContext.delete(exercise)
        }
    }
}

// MARK: - Workout Exercise Row

struct WorkoutExerciseRow: View {
    let exercise: WorkoutExercise

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Completion toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    exercise.isCompleted.toggle()
                }
            } label: {
                Image(
                    systemName: exercise.isCompleted
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.title2)
                .foregroundStyle(exercise.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)

            // Exercise details
            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name)
                    .font(.headline)
                    .strikethrough(exercise.isCompleted, color: .secondary)
                    .foregroundStyle(exercise.isCompleted ? .secondary : .primary)
                    .animation(.easeInOut(duration: 0.2), value: exercise.isCompleted)

                HStack(spacing: 20) {
                    statBadge(icon: "repeat", label: "\(exercise.sets) sets")
                    statBadge(icon: "number", label: "\(exercise.reps) reps")
                    statBadge(icon: "timer", label: restLabel)
                }
                .opacity(exercise.isCompleted ? 0.5 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: exercise.isCompleted)
            }
        }
        .padding(.vertical, 4)
    }

    func statBadge(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var restLabel: String {
        if exercise.restSeconds >= 60 {
            let mins = exercise.restSeconds / 60
            let secs = exercise.restSeconds % 60
            return secs == 0 ? "\(mins)m rest" : "\(mins)m\(secs)s rest"
        }
        return "\(exercise.restSeconds)s rest"
    }
}
