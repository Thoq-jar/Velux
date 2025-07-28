import Foundation
import PklSwift

struct BuildSystem {
    func loadWorkspace(from path: String) async throws -> WorkspaceData {
        let result = try await PklSwift.withEvaluator { evaluator in
            try await evaluator.evaluateModule(source: .path(path), as: PklWorkspaceRoot.self)
        }

        return result.workspace.toWorkspaceData()
    }

    func loadBuildConfig(from path: String) async throws -> BuildConfigData {
        let result = try await PklSwift.withEvaluator { evaluator in
            try await evaluator.evaluateModule(source: .path(path), as: PklBuildConfigRoot.self)
        }

        return result.toBuildConfigData()
    }

    func executeScript(_ scriptName: String, in workspace: WorkspaceData) throws {
        guard let script = workspace.scripts[scriptName] else {
            throw BuildError.scriptNotFound(scriptName)
        }

        for dependency in script.dependencies {
            try executeScript(dependency, in: workspace)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script.command]
        process.currentDirectoryURL = URL(fileURLWithPath: script.workingDir)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8), !output.isEmpty {
            print(output)
        }

        if process.terminationStatus != 0 {
            throw BuildError.scriptExecutionFailed(scriptName, process.terminationStatus)
        }
    }

    func buildProject(
        _ projectName: String, in workspace: WorkspaceData, buildConfig: BuildConfigData,
        strip: Bool = false, buildType: String
    ) async throws {
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
                let pklFiles = try expandGlob(buildConfigPath, in: ".")
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
                        let projectBuildConfig = try await loadBuildConfig(from: pklFile)

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

                try buildInDependencyOrder(allBuilds, strip: strip, globalBuildType: buildType)
            } else {
                let fullPath = "\(project.path)/\(buildConfigPath)"
                let projectBuildConfig = try await loadBuildConfig(from: fullPath)

                for (_, build) in projectBuildConfig.builds {
                    try executeBuild(
                        build, projectPath: project.path, strip: strip, globalBuildType: buildType)
                }
            }
        }
    }

    private func buildInDependencyOrder(
        _ builds: [(BuildData, String)], strip: Bool = false, globalBuildType: String
    ) throws {
        var buildMap: [String: (BuildData, String)] = [:]
        var builtTargets: Set<String> = []

        for (build, path) in builds {
            buildMap[build.name] = (build, path)
            if !strip {
                pipelinePrint(
                    "Found target \(Colors.cyan)\(build.name)\(Colors.reset) \(Colors.yellow)(\(build.buildType))\(Colors.reset)",
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

            pipelinePrint(
                "Building \(Colors.cyan)\(targetName)\(Colors.reset) \(Colors.yellow)(\(build.buildType))\(Colors.reset)",
                category: "building", strip: strip)
            try executeBuild(
                build, projectPath: path, strip: strip, globalBuildType: globalBuildType)
            builtTargets.insert(targetName)
        }

        let sortedBuilds = builds.sorted { (build1, build2) in
            let priority1 = getBuildPriority(build1.0.buildType)
            let priority2 = getBuildPriority(build2.0.buildType)
            return priority1 < priority2
        }

        for (build, _) in sortedBuilds {
            try buildTarget(build.name)
        }
    }

    private func executeBuild(
        _ build: BuildData, projectPath: String, strip: Bool = false, globalBuildType: String
    ) throws {
        let currentDir = FileManager.default.currentDirectoryPath
        let outputSubdir = getOutputSubdirectory(for: build.buildType)
        let outputDir = "\(currentDir)/velux-out/\(outputSubdir)"

        let createDirProcess = Process()
        createDirProcess.executableURL = URL(fileURLWithPath: "/bin/mkdir")
        createDirProcess.arguments = ["-p", outputDir]

        try createDirProcess.run()
        createDirProcess.waitUntilExit()

        var compileCommand = ["gcc"]
        compileCommand.append(contentsOf: getCompilerFlags(for: globalBuildType))
        compileCommand.append(contentsOf: build.extraFlags)

        for source in build.sources {
            let expandedSources = try expandGlob(source, in: projectPath)
            compileCommand.append(contentsOf: expandedSources)
        }

        for includePath in build.includePaths {
            compileCommand.append("-I\(includePath)")
        }

        for dependency in build.dependencies {
            let sharedLib = "\(currentDir)/velux-out/shared/lib\(dependency).so"
            let staticLib = "\(currentDir)/velux-out/static/lib\(dependency).a"

            if FileManager.default.fileExists(atPath: sharedLib) {
                compileCommand.append("-L\(currentDir)/velux-out/shared")
                compileCommand.append("-l\(dependency)")
                compileCommand.append("-Wl,-rpath,\(currentDir)/velux-out/shared")
            } else if FileManager.default.fileExists(atPath: staticLib) {
                compileCommand.append("-L\(currentDir)/velux-out/static")
                compileCommand.append("-l\(dependency)")
            } else {
                pipelinePrint(
                    "Dependency '\(dependency)' not found in velux-out", category: "warning",
                    strip: strip)
            }
        }

        for library in build.libraries ?? [] {
            if library.hasPrefix("pkg:") {
                let moduleName = String(library.dropFirst(4))
                let (cflags, ldflags) = try runPkgConfig(moduleName)
                compileCommand.append(contentsOf: cflags ?? [])
                compileCommand.append(contentsOf: ldflags)
            } else {
                compileCommand.append("-l\(library)")
            }
        }

        let outputExtension = getOutputExtension(for: build.buildType)
        let outputName = getOutputName(
            build.name, buildType: build.buildType, extension: outputExtension)
        compileCommand.append("-o")
        compileCommand.append("\(outputDir)/\(outputName)")

        let compileProcess = Process()
        compileProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        compileProcess.arguments = compileCommand
        compileProcess.currentDirectoryURL = URL(fileURLWithPath: projectPath)

        let pipe = Pipe()
        compileProcess.standardOutput = pipe
        compileProcess.standardError = pipe

        try compileProcess.run()
        compileProcess.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8), !output.isEmpty {
            print(output)
        }

        if compileProcess.terminationStatus != 0 {
            throw BuildError.buildFailed(build.name)
        }
    }

    private func expandGlob(_ pattern: String, in basePath: String) throws -> [String] {
        let globProcess = Process()

        #if os(Windows)
            globProcess.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\cmd.exe")
            globProcess.arguments = ["/c", "for /r \(basePath) %i in (\(pattern)) do @echo %i"]
        #else
            globProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
            if pattern.contains("**") {
                let fileName = pattern.replacingOccurrences(of: "**/", with: "")
                globProcess.arguments = ["-c", "find \(basePath) -name '\(fileName)' -type f"]
            } else if pattern.contains("*") {
                globProcess.arguments = [
                    "-c",
                    "cd \(basePath) && find . -path '\(pattern)' -type f 2>/dev/null | sed 's|^./||' || true",
                ]
            } else {
                globProcess.arguments = [
                    "-c", "find \(basePath) -path '\(basePath)/\(pattern)' -type f",
                ]
            }
        #endif

        let pipe = Pipe()
        globProcess.standardOutput = pipe

        try globProcess.run()
        globProcess.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }

        let expandedPaths = output.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }

        return expandedPaths.map { path in
            if path.hasPrefix(basePath + "/") {
                return String(path.dropFirst(basePath.count + 1))
            }
            return path
        }
    }

    private func getCompilerFlags(for buildType: String) -> [String] {
        switch buildType.lowercased() {
        case "debug":
            return ["-g"]
        case "release":
            return ["-O2", "-DNDEBUG"]
        case "test":
            return ["-g", "-O0", "-ftest-coverage", "-fprofile-arcs"]
        default:
            return []
        }
    }

    private func getOutputSubdirectory(for buildType: String) -> String {
        switch buildType.lowercased() {
        case "shared":
            return "shared"
        case "static":
            return "static"
        case "debug", "release", "test":
            return "executable"
        default:
            return buildType
        }
    }

    private func getOutputExtension(for buildType: String) -> String {
        switch buildType.lowercased() {
        case "shared":
            #if os(macOS)
                return ".dylib"
            #elseif os(Windows)
                return ".dll"
            #else
                return ".so"
            #endif
        case "static":
            #if os(Windows)
                return ".lib"
            #else
                return ".a"
            #endif
        case "debug", "release", "test":
            #if os(Windows)
                return ".exe"
            #else
                return ""
            #endif
        default:
            return ""
        }
    }

    private func getOutputName(_ name: String, buildType: String, extension ext: String) -> String {
        switch buildType.lowercased() {
        case "static", "shared":
            if !name.hasPrefix("lib") {
                return "lib\(name)\(ext)"
            }
            return "\(name)\(ext)"
        default:
            return "\(name)\(ext)"
        }
    }

    private func getBuildPriority(_ buildType: String) -> Int {
        switch buildType.lowercased() {
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

    private func runPkgConfig(_ moduleName: String) throws -> (cflags: [String], ldflags: [String])
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pkg-config")
        process.arguments = ["--cflags", "--libs", moduleName]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(
                in: .whitespacesAndNewlines)
        else {
            if process.terminationStatus != 0 {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                if let errorOutput = String(data: errorData, encoding: .utf8) {
                    throw BuildError.pkgConfigFailed(moduleName, errorOutput)
                }
            }
            throw BuildError.pkgConfigFailed(moduleName, "No output from pkg-config")
        }

        guard process.terminationStatus == 0 else {
            throw BuildError.pkgConfigFailed(
                moduleName,
                "pkg-config failed with exit code \(process.terminationStatus) for module '\(moduleName)'"
            )
        }

        let components = output.components(separatedBy: .whitespacesAndNewlines).filter {
            !$0.isEmpty
        }

        var cflags: [String] = []
        var ldflags: [String] = []

        for component in components {
            if component.hasPrefix("-I") || component.hasPrefix("-D") {
                cflags.append(component)
            } else if component.hasPrefix("-L") || component.hasPrefix("-l")
                || component.hasPrefix("-Wl,")
            {
                ldflags.append(component)
            } else {
                if !cflags.contains(component) {
                    ldflags.append(component)
                }
            }
        }

        return (cflags, ldflags)
    }
}

enum BuildError: Error, LocalizedError {
    case invalidWorkspaceConfig
    case invalidBuildConfig
    case missingRequiredFields
    case scriptNotFound(String)
    case projectNotFound(String)
    case scriptExecutionFailed(String, Int32)
    case buildFailed(String)
    case pkgConfigFailed(String, String)

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
        }
    }
}
