import Foundation

struct PklWorkspaceRoot: Decodable {
    let workspace: PklWorkspace
}

struct PklWorkspace: Decodable {
    let name: String
    let version: String
    let scripts: [String: PklScript]
    let projects: [String: PklProject]
    let environments: [String: PklEnvironment]
}

struct PklScript: Decodable {
    let name: String
    let command: String
    let description: String?
    let workingDir: String?
    let dependencies: [String]?
}

struct PklProject: Decodable {
    let name: String
    let path: String
    let type: String
    let buildConfig: String?
    let dependencies: [String]?
}

struct PklEnvironment: Decodable {
    let name: String
    let variables: [String: String]?
    let features: [String]?
}

struct PklBuildConfigRoot: Decodable {
    let builds: [String: PklBuild]
    let globalIncludePaths: [String]?
    let globalLibraries: [String]?
}

struct PklBuild: Decodable {
    let name: String
    let sources: [String]
    let language: PklLanguage
    let dependencies: [String]?
    let output: String?
}

struct PklLanguage: Decodable {
    let name: String?
    let extensions: [String]?
    let compilerFlags: [String]?
    let libraries: [String]?
    let includePaths: [String]?
    let buildType: String?
    let extraFlags: [String]?

    let shade: Bool?
    let mainClass: String?
}

extension PklWorkspace {
    func toWorkspaceData() -> WorkspaceData {
        let convertedScripts = scripts.mapValues { script in
            ScriptData(
                name: script.name,
                command: script.command,
                description: script.description,
                workingDir: script.workingDir ?? ".",
                dependencies: script.dependencies ?? []
            )
        }

        let convertedProjects = projects.mapValues { project in
            ProjectData(
                name: project.name,
                path: project.path,
                type: project.type,
                buildConfig: project.buildConfig,
                dependencies: project.dependencies ?? []
            )
        }

        let convertedEnvironments = environments.mapValues { env in
            EnvironmentData(
                name: env.name,
                variables: env.variables ?? [:],
                features: Set(env.features ?? [])
            )
        }

        return WorkspaceData(
            name: name,
            version: version,
            scripts: convertedScripts,
            projects: convertedProjects,
            environments: convertedEnvironments
        )
    }
}

extension PklBuildConfigRoot {
    func toBuildConfigData() -> BuildConfigData {
        let convertedBuilds = builds.mapValues { build in
            BuildData(
                name: build.name,
                sources: Set(build.sources),
                language: build.language.toLanguageData(),
                dependencies: build.dependencies ?? [],
                output: build.output ?? build.name
            )
        }

        return BuildConfigData(
            builds: convertedBuilds,
            globalIncludePaths: globalIncludePaths ?? [],
            globalLibraries: globalLibraries ?? []
        )
    }
}

extension PklLanguage {
    func toLanguageData() -> LanguageData {
        let languageName = name?.lowercased() ?? "unknown"

        switch languageName {
        case "java":
            return JavaLanguageData(
                extensions: Set(extensions ?? [".java"]),
                compilerFlags: compilerFlags ?? [],
                libraries: libraries ?? [],
                shade: shade ?? false,
                mainClass: mainClass ?? ""
            )
        case "c":
            return CLanguageData(
                extensions: Set(extensions ?? [".c", ".h"]),
                compilerFlags: compilerFlags ?? ["-std=c99", "-Wall", "-Wextra"],
                libraries: libraries ?? [],
                includePaths: includePaths ?? [],
                buildType: buildType ?? "debug",
                extraFlags: extraFlags ?? []
            )
        case "cpp", "c++":
            return CPPLanguageData(
                extensions: Set(extensions ?? [".cpp", ".cxx", ".cc", ".hpp", ".hxx", ".h"]),
                compilerFlags: compilerFlags ?? ["-std=c++17", "-Wall", "-Wextra"],
                libraries: libraries ?? [],
                includePaths: includePaths ?? [],
                buildType: buildType ?? "debug",
                extraFlags: extraFlags ?? []
            )
        default:
            return GenericLanguageData(
                name: languageName,
                extensions: Set(extensions ?? []),
                compilerFlags: compilerFlags ?? []
            )
        }
    }
}