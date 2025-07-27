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
}

struct BuildData {
    let name: String
    let sources: Set<String>
    let buildType: String
    let libraries: [String]
    let includePaths: [String]
    let extraFlags: [String]
    let dependencies: [String]
}
