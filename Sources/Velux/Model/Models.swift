import Foundation

struct WorkspaceData {
    let name: String
    let version: String
    let scripts: [String: ScriptData]
    let projects: [String: ProjectData]
    let environments: [String: EnvironmentData]
}

struct ScriptData {
    let name: String
    let command: String
    let description: String?
    let workingDir: String
    let dependencies: [String]
}

struct ProjectData {
    let name: String
    let path: String
    let type: String
    let buildConfig: String?
    let dependencies: [String]
}

struct EnvironmentData {
    let name: String
    let variables: [String: String]
    let features: Set<String>
}

struct BuildConfigData {
    let builds: [String: BuildData]
    let globalIncludePaths: [String]
    let globalLibraries: [String]
}

struct BuildData {
    let name: String
    let sources: Set<String>
    let language: LanguageData
    let dependencies: [String]
    let output: String
}

protocol LanguageData {
    var name: String { get }
    var extensions: Set<String> { get }
    var compilerFlags: [String] { get }
}

struct JavaLanguageData: LanguageData {
    let name = "java"
    let extensions: Set<String>
    let compilerFlags: [String]
    let libraries: [String]
    let shade: Bool
    let mainClass: String
}

struct CLanguageData: LanguageData {
    let name = "c"
    let extensions: Set<String>
    let compilerFlags: [String]
    let libraries: [String]
    let includePaths: [String]
    let buildType: String
    let extraFlags: [String]
}

struct CPPLanguageData: LanguageData {
    let name = "cpp"
    let extensions: Set<String>
    let compilerFlags: [String]
    let libraries: [String]
    let includePaths: [String]
    let buildType: String
    let extraFlags: [String]
}

struct GenericLanguageData: LanguageData {
    let name: String
    let extensions: Set<String>
    let compilerFlags: [String]
}