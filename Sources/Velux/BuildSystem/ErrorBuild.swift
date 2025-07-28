import Foundation

enum BuildError: Error, LocalizedError {
    case invalidWorkspaceConfig
    case invalidBuildConfig
    case missingRequiredFields
    case scriptNotFound(String)
    case projectNotFound(String)
    case scriptExecutionFailed(String, Int32)
    case buildFailed(String)
    case pkgConfigFailed(String, String)
    case unsupportedLanguage(String)

    var errorDescription: String? {
        switch self {
        case .invalidWorkspaceConfig:
            return "Invalid workspace configuration"
        case .invalidBuildConfig:
            return "Invalid build configuration"
        case .missingRequiredFields:
            return "Missing required fields in configuration"
        case .scriptNotFound(let name):
            return "Script '\(name)' not found"
        case .projectNotFound(let name):
            return "Project '\(name)' not found"
        case .scriptExecutionFailed(let name, let code):
            return "Script '\(name)' failed with exit code \(code)"
        case .buildFailed(let name):
            return "Build '\(name)' failed"
        case .pkgConfigFailed(let moduleName, let reason):
            return "pkg-config failed for module '\(moduleName)': \(reason)"
        case .unsupportedLanguage(let name):
            return "Unsupported language: '\(name)'"
        }
    }
}
