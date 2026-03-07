import Foundation

public extension Result where Failure == Error {
    static func catching(_ body: () async throws -> Success) async -> Self {
        do {
            return .success(try await body())
        } catch {
            return .failure(error)
        }
    }
}
