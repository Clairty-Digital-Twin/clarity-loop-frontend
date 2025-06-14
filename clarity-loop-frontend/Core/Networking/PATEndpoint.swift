import Foundation

enum PATEndpoint {
    case analyzeStepData(dto: StepDataRequestDTO)
    case analyzeActigraphy(dto: DirectActigraphyRequestDTO)
    case getAnalysis(id: String)
    case getServiceHealth
}

extension PATEndpoint: Endpoint {
    var path: String {
        switch self {
        case .analyzeStepData:
            "/api/v1/pat/analyze-step-data"
        case .analyzeActigraphy:
            "/api/v1/pat/analyze"
        case let .getAnalysis(id):
            "/api/v1/pat/analysis/\(id)"
        case .getServiceHealth:
            "/api/v1/pat/health"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .analyzeStepData, .analyzeActigraphy:
            .post
        case .getAnalysis, .getServiceHealth:
            .get
        }
    }

    func body(encoder: JSONEncoder) throws -> Data? {
        switch self {
        case let .analyzeStepData(dto):
            try encoder.encode(dto)
        case let .analyzeActigraphy(dto):
            try encoder.encode(dto)
        case .getAnalysis, .getServiceHealth:
            nil
        }
    }
}
