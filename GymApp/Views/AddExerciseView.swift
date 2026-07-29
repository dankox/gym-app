import SwiftUI

struct AddExerciseView: View {
    @Environment(ThemeManager.self) private var themeManager
    var draft: ExerciseDraft?
    var onSave: (ExerciseDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    @FocusState private var isFieldFocused: Bool

    @State private var name = ""
    @State private var sets = 3
    @State private var reps = "10"
    @State private var notes = ""
    @State private var restSeconds = 60
    @State private var pausePoints: [Int] = []
    @State private var newPauseSeconds = 30

    private var isEditing: Bool { draft != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Name") {
                    TextField("e.g. Bench Press + Push-up (Superset)", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($isFieldFocused)
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
                            .focused($isFieldFocused)
                    }
                }

                Section("Note") {
                    TextField("Optional note (e.g. Grip width, superset details…)", text: $notes, axis: .vertical)
                        .focused($isFieldFocused)
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
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(isEditing ? "Edit Exercise" : "Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isFieldFocused = false
                    }
                    .fontWeight(.semibold)
                }
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
                    notes = draft.notes
                    restSeconds = draft.restSeconds
                    pausePoints = draft.pausePoints
                    if let firstValid = (5...max(5, restSeconds - 5)).first(where: { !pausePoints.contains($0) }) {
                        newPauseSeconds = firstValid
                    }
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

    func save() {
        var result = draft ?? ExerciseDraft()
        result.name = name.trimmingCharacters(in: .whitespaces)
        result.sets = sets
        let trimmedReps = reps.trimmingCharacters(in: .whitespaces)
        result.reps = trimmedReps.isEmpty ? "10" : trimmedReps
        result.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        result.restSeconds = restSeconds
        result.pausePoints = pausePoints.filter { $0 < restSeconds }.sorted()
        onSave(result)
        dismiss()
    }
}
