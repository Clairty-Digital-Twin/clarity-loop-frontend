import Foundation

/// Defines the endpoints for the authentication-related API calls.
enum AuthEndpoint: Endpoint {
    case register(dto: UserRegistrationRequestDTO)
    case login(dto: UserLoginRequestDTO)
    case refreshToken(dto: RefreshTokenRequestDTO)
    case logout
    case getCurrentUser
    case verifyEmail(code: String)

    var path: String {
        switch self {
        case .register:
            "/api/v1/auth/register"
        case .login:
            "/api/v1/auth/login"
        case .refreshToken:
            "/api/v1/auth/refresh"
        case .logout:
            "/api/v1/auth/logout"
        case .getCurrentUser:
            "/api/v1/auth/me"
        case .verifyEmail:
            "/api/v1/auth/verify-email"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .register, .login, .refreshToken, .logout:
            .post
        case .getCurrentUser, .verifyEmail:
            .get
        }
    }

    func body(encoder: JSONEncoder) throws -> Data? {
        switch self {
        case let .register(dto):
            try encoder.encode(dto)
        case let .login(dto):
            try encoder.encode(dto)
        case let .refreshToken(dto):
            try encoder.encode(dto)
        default:
            nil
        }
    }
}
