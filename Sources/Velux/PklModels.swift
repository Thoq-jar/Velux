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
}

struct PklBuild: Decodable {
    let name: String
    let sources: [String]
    let buildType: String
    let libraries: [String]?
    let includePaths: [String]?
    let extraFlags: [String]?
    let output: String?
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
                buildType: build.buildType,
                libraries: build.libraries ?? [],
                includePaths: build.includePaths ?? [],
                extraFlags: build.extraFlags ?? []
            )
        }

        return BuildConfigData(builds: convertedBuilds)
    }
}
