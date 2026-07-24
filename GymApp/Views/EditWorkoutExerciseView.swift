import SwiftUI
import SwiftData

struct EditWorkoutExerciseView: View {
    @Bindable var exercise: WorkoutExercise

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var sets: Int = 3
    @State private var reps: Int = 10
    @State private var restSeconds: Int = 60

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
                        Stepper("\(reps)", value: $reps, in: 1...200)
                            .fixedSize()
                    }
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
                restSeconds = exercise.restSeconds
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        exercise.name = trimmedName
        exercise.sets = sets
        exercise.reps = reps
        exercise.restSeconds = restSeconds

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
