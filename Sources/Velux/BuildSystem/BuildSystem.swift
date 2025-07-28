import Foundation
import PklSwift

struct BuildSystem {
    func buildProject(
        _ projectName: String, in workspace: WorkspaceData, buildConfig: BuildConfigData,
        strip: Bool = false, buildType: String
    ) async throws {
        let utils = VeluxUtils()
        guard let project = workspace.projects[projectName] else {
            throw BuildError.projectNotFound(projectName)
        }

        for dependency in project.dependencies {
            try await buildProject(
                dependency, in: workspace, buildConfig: buildConfig, strip: strip,
                buildType: buildType)
        }

        if let buildConfigPath = project.buildConfig {
            if buildConfigPath.contains("*") {
                let pklFiles = try utils.expandGlob(buildConfigPath, in: ".")
                pipelinePrint("Scanning project files...", category: "info", strip: strip)
                var allBuilds: [(BuildData, String)] = []

                for pklFile in pklFiles {
                    let fileName = (pklFile as NSString).lastPathComponent
                    if pklFile.hasSuffix(".pkl") && fileName != "workspace.pkl"
                        && fileName != "build.pkl"
                    {
                        pipelinePrint(
                            "Processing \(Colors.cyan)\(pklFile)\(Colors.reset)",
                            category: "processing", strip: strip)
                        let projectBuildConfig = try await utils.loadBuildConfig(from: pklFile)

                        let projectDir = (pklFile as NSString).deletingLastPathComponent
                        let actualProjectPath = projectDir.isEmpty ? "." : projectDir

                        for (_, build) in projectBuildConfig.builds {
                            allBuilds.append((build, actualProjectPath))
                        }
                    } else {
                        if !strip {
                            pipelinePrint("Skipping \(pklFile)", category: "info", strip: strip)
                        }
                    }
                }

                try buildInDependencyOrder(
                    allBuilds, strip: strip, globalBuildType: buildType, buildConfig: buildConfig)
            } else {
                let fullPath = "\(project.path)/\(buildConfigPath)"
                let projectBuildConfig = try await utils.loadBuildConfig(from: fullPath)

                for (_, build) in projectBuildConfig.builds {
                    try executeBuild(
                        build, projectPath: project.path, strip: strip, globalBuildType: buildType,
                        buildConfig: projectBuildConfig)
                }
            }
        }
    }

    private func buildInDependencyOrder(
        _ builds: [(BuildData, String)], strip: Bool = false, globalBuildType: String,
        buildConfig: BuildConfigData
    ) throws {
        var buildMap: [String: (BuildData, String)] = [:]
        var builtTargets: Set<String> = []

        for (build, path) in builds {
            buildMap[build.name] = (build, path)
            if !strip {
                let buildTypeInfo = getBuildTypeInfo(for: build.language)
                pipelinePrint(
                    "Found target \(Colors.cyan)\(build.name)\(Colors.reset) \(Colors.yellow)(\(buildTypeInfo))\(Colors.reset)",
                    category: "info", strip: strip)
            }
        }

        func buildTarget(_ targetName: String) throws {
            if builtTargets.contains(targetName) {
                return
            }

            guard let (build, path) = buildMap[targetName] else {
                pipelinePrint(
                    "Target '\(targetName)' not found in current build set", category: "warning",
                    strip: strip)
                return
            }

            for dependency in build.dependencies {
                try buildTarget(dependency)
            }

            let buildTypeInfo = getBuildTypeInfo(for: build.language)
            pipelinePrint(
                "Building \(Colors.cyan)\(targetName)\(Colors.reset) \(Colors.yellow)(\(buildTypeInfo))\(Colors.reset)",
                category: "building", strip: strip)
            try executeBuild(
                build, projectPath: path, strip: strip, globalBuildType: globalBuildType,
                buildConfig: buildConfig)
            builtTargets.insert(targetName)
        }

        let sortedBuilds = builds.sorted(by: { (build1, build2) in
            let priority1 = getBuildPriority(for: build1.0.language)
            let priority2 = getBuildPriority(for: build2.0.language)
            return priority1 < priority2
        })

        for (build, _) in sortedBuilds {
            try buildTarget(build.name)
        }
    }

    private func executeBuild(
        _ build: BuildData, projectPath: String, strip: Bool = false, globalBuildType: String,
        buildConfig: BuildConfigData
    ) throws {
        switch build.language {
        case let javaLang as JavaLanguageData:
            try executeJavaBuild(
                build, language: javaLang, projectPath: projectPath, strip: strip,
                buildConfig: buildConfig)
        case let cLang as CLanguageData:
            try executeCBuild(
                build, language: cLang, projectPath: projectPath, strip: strip,
                globalBuildType: globalBuildType, buildConfig: buildConfig)
        case let cppLang as CPPLanguageData:
            try executeCPPBuild(
                build, language: cppLang, projectPath: projectPath, strip: strip,
                globalBuildType: globalBuildType, buildConfig: buildConfig)
        default:
            throw BuildError.unsupportedLanguage(build.language.name)
        }
    }

    private func getBuildPriority(for language: LanguageData) -> Int {
        switch language.name.lowercased() {
        case "java":
            return 0
        default:
            if let cLang = language as? CLanguageData {
                switch cLang.buildType.lowercased() {
                case "shared":
                    return 1
                case "static":
                    return 2
                case "debug", "release", "test":
                    return 3
                default:
                    return 4
                }
            } else if let cppLang = language as? CPPLanguageData {
                switch cppLang.buildType.lowercased() {
                case "shared":
                    return 1
                case "static":
                    return 2
                case "debug", "release", "test":
                    return 3
                default:
                    return 4
                }
            }
            return 5
        }
    }

    private func getBuildTypeInfo(for language: LanguageData) -> String {
        switch language {
        case let javaLang as JavaLanguageData:
            return "java" + (javaLang.shade ? " [shaded]" : "")
        case let cLang as CLanguageData:
            return cLang.buildType
        case let cppLang as CPPLanguageData:
            return cppLang.buildType
        default:
            return language.name
        }
    }
}
