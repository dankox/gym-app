import SwiftUI
import UniformTypeIdentifiers
import SwiftData

// MARK: - UTType Extension
extension UTType {
    static var gymJson: UTType {
        UTType(exportedAs: "com.dankox.gymapp.routine", conformingTo: .json)
    }
}

// MARK: - Flexible Reps Decoding
enum FlexibleReps: Codable {
    case string(String)
    case int(Int)

    var stringValue: String {
        switch self {
        case .string(let str): return str
        case .int(let num): return "\(num)"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let num = try? container.decode(Int.self) {
            self = .int(num)
        } else {
            self = .string("10")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str):
            try container.encode(str)
        case .int(let num):
            try container.encode(num)
        }
    }
}

// MARK: - Codable DTOs
struct ExerciseTemplateDTO: Codable {
    var name: String?
    var sets: Int?
    var reps: FlexibleReps?
    var restSeconds: Int?
    var sortOrder: Int?
    var pausePoints: [Int]?
    var notes: String?

    init(from template: ExerciseTemplate) {
        self.name = template.name
        self.sets = template.sets
        self.reps = .string(template.reps)
        self.restSeconds = template.restSeconds
        self.sortOrder = template.sortOrder
        self.pausePoints = template.currentPausePoints
        self.notes = template.notes
    }
}

struct RoutineDTO: Codable {
    var name: String?
    var createdAt: Date?
    var exercises: [ExerciseTemplateDTO]?

    init(from routine: Routine) {
        self.name = routine.name
        self.createdAt = routine.createdAt
        self.exercises = routine.exercises
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { ExerciseTemplateDTO(from: $0) }
    }
}

// MARK: - Custom Errors
enum RoutineImportError: LocalizedError {
    case invalidFormat
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "The selected file is not a valid routine JSON file."
        case .emptyFile:
            return "The file contains no routines."
        }
    }
}

// MARK: - Transfer Service
struct RoutineTransferService {
    static func encode(routine: Routine) throws -> Data {
        let dto = RoutineDTO(from: routine)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(dto)
    }

    static func encode(routines: [Routine]) throws -> Data {
        let dtos = routines.map { RoutineDTO(from: $0) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(dtos)
    }

    static func decodeRoutines(from data: Data) throws -> [Routine] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let dateStr = try? container.decode(String.self) {
                if let date = ISO8601DateFormatter().date(from: dateStr) {
                    return date
                }
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                if let date = formatter.date(from: dateStr) {
                    return date
                }
            } else if let doubleVal = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: doubleVal)
            }
            return Date()
        }

        var dtos: [RoutineDTO] = []

        if let singleDTO = try? decoder.decode(RoutineDTO.self, from: data) {
            dtos = [singleDTO]
        } else if let arrayDTOs = try? decoder.decode([RoutineDTO].self, from: data) {
            dtos = arrayDTOs
        } else {
            throw RoutineImportError.invalidFormat
        }

        if dtos.isEmpty {
            throw RoutineImportError.emptyFile
        }

        return dtos.map { dtoToRoutine($0) }
    }

    private static func dtoToRoutine(_ dto: RoutineDTO) -> Routine {
        let rawName = dto.name?.trimmingCharacters(in: .whitespaces) ?? ""
        let routineName = rawName.isEmpty ? "Imported Routine" : rawName
        let routine = Routine(name: routineName)
        routine.createdAt = dto.createdAt ?? .now

        let exerciseDTOs = dto.exercises ?? []
        for (index, exDTO) in exerciseDTOs.enumerated() {
            let exName = exDTO.name?.trimmingCharacters(in: .whitespaces) ?? ""
            let finalExName = exName.isEmpty ? "Unnamed Exercise" : exName
            let sets = (exDTO.sets ?? 3) > 0 ? (exDTO.sets ?? 3) : 3

            let rawReps = exDTO.reps?.stringValue.trimmingCharacters(in: .whitespaces) ?? ""
            let reps = rawReps.isEmpty ? "10" : rawReps

            let restSeconds = (exDTO.restSeconds ?? 60) > 0 ? (exDTO.restSeconds ?? 60) : 60
            let sortOrder = exDTO.sortOrder ?? index
            let pausePoints = exDTO.pausePoints ?? []
            let notes = exDTO.notes?.trimmingCharacters(in: .whitespacesAndNewlines)

            let template = ExerciseTemplate(
                name: finalExName,
                sets: sets,
                reps: reps,
                restSeconds: restSeconds,
                sortOrder: sortOrder,
                pausePoints: pausePoints,
                notes: notes?.isEmpty == true ? nil : notes
            )
            routine.exercises.append(template)
        }

        return routine
    }

    static func createTemporaryFileURL(for routine: Routine) throws -> URL {
        let data = try encode(routine: routine)
        let sanitizedName = routine.name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let filename = sanitizedName.isEmpty ? "routine.gym.json" : "\(sanitizedName).gym.json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func createTemporaryFileURL(for routines: [Routine]) throws -> URL {
        let data = try encode(routines: routines)
        let filename = "all_routines.gym.json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}

// MARK: - Activity View Controller Helper
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
