import SwiftUI
import SwiftData

struct EditWorkoutExerciseView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Bindable var exercise: WorkoutExercise

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var sets: Int = 3
    @State private var reps: String = "10"
    @State private var notes: String = ""
    @State private var restSeconds: Int = 60
    @State private var pausePoints: [Int] = []
    @State private var newPauseSeconds: Int = 30

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Name") {
                    TextField("Exercise Name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Sets & Reps") {
                    HStack {
                        Text("Sets")
                        Spacer()
                        Stepper("\(sets)", value: $sets, in: 1...30)
                            .fixedSize()
                    }
                    HStack {
                        Text("Reps")
                        Spacer()
                        TextField("e.g. 10, 5 / 3, 5, 3, 5", text: $reps)
                            .multilineTextAlignment(.leading)
                            .textInputAutocapitalization(.never)
                            .fixedSize()
                    }
                }

                Section("Note") {
                    TextField("Optional note (e.g. Grip width, superset details…)", text: $notes, axis: .vertical)
                }

                Section("Rest Time") {
                    Picker("Rest Time", selection: $restSeconds) {
                        Text("5 sec").tag(5)
                        Text("10 sec").tag(10)
                        Text("15 sec").tag(15)
                        Text("30 sec").tag(30)
                        Text("45 sec").tag(45)
                        Text("1 min").tag(60)
                        Text("1 min 30 sec").tag(90)
                        Text("2 min").tag(120)
                        Text("2 min 30 sec").tag(150)
                        Text("3 min").tag(180)
                        Text("3 min 30 sec").tag(210)
                        Text("4 min").tag(240)
                        Text("4 min 30 sec").tag(270)
                        Text("5 min").tag(300)
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 140)
                    .onChange(of: restSeconds) { _, newRest in
                        pausePoints.removeAll(where: { $0 >= newRest })
                        if newPauseSeconds >= newRest {
                            newPauseSeconds = max(5, newRest - 5)
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Pause after")
                            Spacer()
                            Stepper("\(formatSeconds(newPauseSeconds))", value: $newPauseSeconds, in: 5...max(5, restSeconds - 5), step: 5)
                                .fixedSize()
                        }

                        Button {
                            if !pausePoints.contains(newPauseSeconds) && newPauseSeconds < restSeconds {
                                pausePoints.append(newPauseSeconds)
                                pausePoints.sort()
                            }
                        } label: {
                            Label("Add Pause Point", systemImage: "plus.circle.fill")
                                .foregroundStyle(themeManager.accentColor)
                        }
                        .disabled(pausePoints.contains(newPauseSeconds) || newPauseSeconds >= restSeconds)
                    }

                    if pausePoints.isEmpty {
                        Text("No auto-pause points set")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pausePoints.sorted(), id: \.self) { pp in
                            HStack {
                                Image(systemName: "pause.circle.fill")
                                    .foregroundStyle(themeManager.accentColor)
                                Text("Pause after \(formatSeconds(pp))")
                                    .font(.subheadline)
                                Spacer()
                                Text("(\(formatSeconds(restSeconds - pp)) left)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button(role: .destructive) {
                                    pausePoints.removeAll(where: { $0 == pp })
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .tint(.red)
                            }
                        }
                    }
                } header: {
                    Text("Auto-Pause Points (Superset Rest)")
                } footer: {
                    Text("Automatically pause the rest timer after a set duration. Ideal for supersets (e.g., Push-ups + Pull-ups).")
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = exercise.name
                sets = exercise.sets
                reps = exercise.reps
                notes = exercise.currentNotes
                restSeconds = exercise.restSeconds
                pausePoints = exercise.currentPausePoints
                if let firstValid = (5...max(5, restSeconds - 5)).first(where: { !pausePoints.contains($0) }) {
                    newPauseSeconds = firstValid
                }
            }
        }
    }

    private func formatSeconds(_ seconds: Int) -> String {
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s == 0 ? "\(m) min" : "\(m)m \(s)s"
        }
        return "\(seconds) sec"
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        exercise.name = trimmedName
        exercise.sets = sets
        let trimmedReps = reps.trimmingCharacters(in: .whitespaces)
        exercise.reps = trimmedReps.isEmpty ? "10" : trimmedReps
        exercise.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        exercise.restSeconds = restSeconds
        exercise.pausePoints = pausePoints.filter { $0 < restSeconds }.sorted()

        // Cap completedSets if it exceeds new sets count
        if let currentCompleted = exercise.completedSets, currentCompleted > sets {
            exercise.completedSets = sets
        }

        // Update completion status relative to new set count
        if exercise.currentCompletedSets >= sets {
            exercise.isCompleted = true
        } else if exercise.isCompleted && exercise.currentCompletedSets < sets {
            exercise.isCompleted = false
        }

        dismiss()
    }
}
