import FirebaseFirestore
import Foundation

struct UserReflection: Codable, Identifiable {
  @DocumentID var id: String?
  let userId: String
  let programId: String
  let dayNumber: Int
  let text: String
  let savedAt: Timestamp

  init(userId: String, programId: String, dayNumber: Int, text: String) {
    self.userId = userId
    self.programId = programId
    self.dayNumber = dayNumber
    self.text = text
    self.savedAt = Timestamp()
  }
}

final class ReflectionService {
  static let shared = ReflectionService()
  private let db = Firestore.firestore()

  private init() {}

  func saveReflection(userId: String, programId: String, dayNumber: Int, text: String) async throws {
    let docId = "\(userId)_\(programId)_day\(dayNumber)"
    let ref = db.collection("reflections").document(docId)
    let reflection = UserReflection(
      userId: userId,
      programId: programId,
      dayNumber: dayNumber,
      text: text
    )
    try ref.setData(from: reflection)
  }

  func loadReflection(userId: String, programId: String, dayNumber: Int) async throws -> UserReflection? {
    let docId = "\(userId)_\(programId)_day\(dayNumber)"
    let doc = try await db.collection("reflections").document(docId).getDocument()
    return try? doc.data(as: UserReflection.self)
  }

  func loadAllReflections(userId: String, programId: String) async throws -> [UserReflection] {
    let snapshot = try await db.collection("reflections")
      .whereField("userId", isEqualTo: userId)
      .whereField("programId", isEqualTo: programId)
      .getDocuments()
    return snapshot.documents.compactMap { try? $0.data(as: UserReflection.self) }
  }
}
