import Foundation

/// A small domain value used by the form-submission integration example.
public struct FormSubmissionDraft: Equatable, Sendable {
    public var title: String
    public var body: String

    public init(title: String = "", body: String = "") {
        self.title = title
        self.body = body
    }

    public var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public enum FormSubmissionState: StateType {
    case idle
    case editing(FormSubmissionDraft)
    case submitting(FormSubmissionDraft)
    case submitted(FormSubmissionDraft)
    case failed(FormSubmissionDraft, message: String)
}

public enum FormSubmissionAction: ActionType {
    case start
    case titleChanged(String)
    case bodyChanged(String)
    case submit
    case succeeded
    case failed(String)
    case retry
    case reset
}

/// The application-facing boundary for the form submission example.
/// Implementations belong to the Infrastructure or outer application layer.
public protocol FormSubmissionUseCaseProtocol: Sendable {
    func submit(_ draft: FormSubmissionDraft) async throws
}

/// Dependencies are assembled at the application edge and passed inward.
public struct FormSubmissionEnvironment: Sendable {
    public let useCase: any FormSubmissionUseCaseProtocol

    public init(useCase: any FormSubmissionUseCaseProtocol) {
        self.useCase = useCase
    }

    public static let preview = Self(useCase: InMemoryFormSubmissionUseCase())
}

/// A deliberately small concrete use case for previews and sample applications.
/// Replace it with a repository-backed implementation in production.
public actor InMemoryFormSubmissionUseCase: FormSubmissionUseCaseProtocol {
    public private(set) var submittedDrafts: [FormSubmissionDraft] = []

    public init() {}

    public func submit(_ draft: FormSubmissionDraft) async throws {
        submittedDrafts.append(draft)
    }
}

public enum FormSubmissionExample {
    public static func canSend(
        state: FormSubmissionState,
        action: FormSubmissionAction
    ) -> Bool {
        switch (state, action) {
        case (.idle, .start):
            return true
        case (.editing, .titleChanged), (.editing, .bodyChanged):
            return true
        case let (.editing(draft), .submit):
            return draft.isValid
        case (.submitting, .succeeded), (.submitting, .failed):
            return true
        case (.submitted, .reset), (.failed, .retry), (.failed, .reset):
            return true
        case (.idle, _), (.editing, _), (.submitting, _), (.submitted, _):
            return false
        case (.failed, _):
            return false
        }
    }

    public static func reduce(
        state: inout FormSubmissionState,
        action: FormSubmissionAction
    ) {
        switch state {
        case .idle:
            switch action {
            case .start:
                state = .editing(FormSubmissionDraft())
            case .titleChanged, .bodyChanged, .submit, .succeeded, .failed, .retry, .reset:
                break
            }

        case .editing(let draft):
            switch action {
            case .titleChanged(let title):
                state = .editing(FormSubmissionDraft(title: title, body: draft.body))
            case .bodyChanged(let body):
                state = .editing(FormSubmissionDraft(title: draft.title, body: body))
            case .submit:
                state = .submitting(draft)
            case .start, .succeeded, .failed, .retry, .reset:
                break
            }

        case .submitting(let draft):
            switch action {
            case .succeeded:
                state = .submitted(draft)
            case .failed(let message):
                state = .failed(draft, message: message)
            case .start, .titleChanged, .bodyChanged, .submit, .retry, .reset:
                break
            }

        case .submitted:
            switch action {
            case .reset:
                state = .idle
            case .start, .titleChanged, .bodyChanged, .submit, .succeeded, .failed, .retry:
                break
            }

        case .failed(let draft, _):
            switch action {
            case .retry:
                state = .submitting(draft)
            case .reset:
                state = .idle
            case .start, .titleChanged, .bodyChanged, .submit, .succeeded, .failed:
                break
            }
        }
    }
}

#if canImport(Observation)
import Observation

@Observable
@MainActor
/// Application-layer example showing a protocol-injected use case around a machine.
public final class FormSubmissionScreenModel {
    @ObservationIgnored
    private let machine: ObservationDrivenStateMachine<FormSubmissionState, FormSubmissionAction>
    @ObservationIgnored
    private let useCase: any FormSubmissionUseCaseProtocol

    public init(environment: FormSubmissionEnvironment = .preview) {
        self.useCase = environment.useCase
        self.machine = ObservationDrivenStateMachine(
            initial: .idle,
            canSend: { state, action in
                FormSubmissionExample.canSend(state: state, action: action)
            },
            reducer: { state, action in
                FormSubmissionExample.reduce(state: &state, action: action)
            }
        )
    }

    public var state: FormSubmissionState {
        machine.state
    }

    public func canSend(_ action: FormSubmissionAction) -> Bool {
        machine.canSend(action)
    }

    /// Fire-and-forget UI entry point.
    public func send(_ action: FormSubmissionAction) {
        Task { [weak self] in
            _ = await self?.sendAndWait(action)
        }
    }

    /// Awaitable entry point for orchestration and deterministic tests.
    @discardableResult
    public func sendAndWait(_ action: FormSubmissionAction) async -> FormSubmissionState {
        switch action {
        case .submit, .retry:
            guard canSend(action), let draft = submissionDraft else {
                return state
            }

            _ = await machine.send(action)
            let result = await Result<Void, Error>.catching {
                try await useCase.submit(draft)
            }

            switch result {
            case .success:
                return await machine.send(.succeeded)
            case .failure(let error):
                return await machine.send(.failed(error.localizedDescription))
            }

        case .succeeded, .failed:
            return state

        case .start, .titleChanged, .bodyChanged, .reset:
            return await machine.send(action)
        }
    }

    private var submissionDraft: FormSubmissionDraft? {
        switch state {
        case .editing(let draft), .failed(let draft, _):
            return draft
        case .idle, .submitting, .submitted:
            return nil
        }
    }
}
#endif
