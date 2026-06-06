import SwiftUI

struct AddExerciseView: View {
    var draft: ExerciseDraft?
    var onSave: (ExerciseDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var sets = 3
    @State private var reps = 10
    @State private var restSeconds = 60

    private var isEditing: Bool { draft != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Name") {
                    TextField("e.g. Bench Press, Squat, Pull-up…", text: $name)
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
                        Text("15 sec").tag(15)
                        Text("30 sec").tag(30)
                        Text("45 sec").tag(45)
                        Text("1 min").tag(60)
                        Text("1 min 30 sec").tag(90)
                        Text("2 min").tag(120)
                        Text("3 min").tag(180)
                        Text("5 min").tag(300)
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 140)
                }
            }
            .navigationTitle(isEditing ? "Edit Exercise" : "Add Exercise")
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
                if let draft {
                    name = draft.name
                    sets = draft.sets
                    reps = draft.reps
                    restSeconds = draft.restSeconds
                }
            }
        }
    }

    func save() {
        var result = draft ?? ExerciseDraft()
        result.name = name.trimmingCharacters(in: .whitespaces)
        result.sets = sets
        result.reps = reps
        result.restSeconds = restSeconds
        onSave(result)
        dismiss()
    }
}
