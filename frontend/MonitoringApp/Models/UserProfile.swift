import Foundation

/// User profile data model
/// Maps to user_profile table in database
struct UserProfile: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var role: UserRole
    var name: String?
    var age: Int?
    var sex: Sex?
    var heightCm: Double?
    var weightKg: Double?
    var exerciseFrequency: Int?
    var activityLevel: ActivityLevel?
    var restingHeartRate: Double?
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case role
        case name
        case age
        case sex
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case exerciseFrequency = "exercise_frequency"
        case activityLevel = "activity_level"
        case restingHeartRate = "resting_heart_rate"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Validation
    
    /// Validates age is within acceptable range (1-149)
    static func isValidAge(_ age: Int) -> Bool {
        age >= 1 && age <= 149
    }
    
    /// Validates height is within acceptable range (0-300 cm)
    static func isValidHeight(_ height: Double) -> Bool {
        height >= 0 && height <= 300
    }
    
    /// Validates weight is within acceptable range (0-500 kg)
    static func isValidWeight(_ weight: Double) -> Bool {
        weight >= 0 && weight <= 500
    }
    
    /// Validates exercise frequency is within acceptable range (0-21 per week)
    static func isValidExerciseFrequency(_ frequency: Int) -> Bool {
        frequency >= 0 && frequency <= 21
    }
    
    /// Validates all profile fields
    var isValid: Bool {
        if let age = age, !Self.isValidAge(age) { return false }
        if let height = heightCm, !Self.isValidHeight(height) { return false }
        if let weight = weightKg, !Self.isValidWeight(weight) { return false }
        if let freq = exerciseFrequency, !Self.isValidExerciseFrequency(freq) { return false }
        return true
    }
}
