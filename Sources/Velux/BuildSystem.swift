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

                try buildInDependencyOrder(allBuilds, strip: strip, globalBuildType: buildType, buildConfig: buildConfig)
            } else {
                let fullPath = "\(project.path)/\(buildConfigPath)"
                let projectBuildConfig = try await loadBuildConfig(from: fullPath)

                for (_, build) in projectBuildConfig.builds {
                    try executeBuild(
                        build, projectPath: project.path, strip: strip, globalBuildType: buildType, buildConfig: projectBuildConfig)
                }
            }
        }
    }

    private func buildInDependencyOrder(
        _ builds: [(BuildData, String)], strip: Bool = false, globalBuildType: String, buildConfig: BuildConfigData
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
                build, projectPath: path, strip: strip, globalBuildType: globalBuildType, buildConfig: buildConfig)
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
        _ build: BuildData, projectPath: String, strip: Bool = false, globalBuildType: String, buildConfig: BuildConfigData
    ) throws {
        switch build.language {
        case let javaLang as JavaLanguageData:
            try executeJavaBuild(build, language: javaLang, projectPath: projectPath, strip: strip, buildConfig: buildConfig)
        case let cLang as CLanguageData:
            try executeCBuild(build, language: cLang, projectPath: projectPath, strip: strip, globalBuildType: globalBuildType, buildConfig: buildConfig)
        case let cppLang as CPPLanguageData:
            try executeCPPBuild(build, language: cppLang, projectPath: projectPath, strip: strip, globalBuildType: globalBuildType, buildConfig: buildConfig)
        default:
            throw BuildError.unsupportedLanguage(build.language.name)
        }
    }

    private func executeJavaBuild(
        _ build: BuildData, language: JavaLanguageData, projectPath: String, strip: Bool = false, buildConfig: BuildConfigData
    ) throws {
        let currentDir = FileManager.default.currentDirectoryPath
        let outputDir = "\(currentDir)/velux-out/java"
        let classesDir = "\(outputDir)/classes"
        let libDir = "\(outputDir)/lib"

        let createDirProcess = Process()
        createDirProcess.executableURL = URL(fileURLWithPath: "/bin/mkdir")
        createDirProcess.arguments = ["-p", classesDir, libDir]
        try createDirProcess.run()
        createDirProcess.waitUntilExit()

        var compileCommand = ["javac"]
        compileCommand.append(contentsOf: language.compilerFlags)

        if !language.libraries.isEmpty {
            let classpath = language.libraries.joined(separator: ":")
            compileCommand.append("-cp")
            compileCommand.append(classpath)
        }

        compileCommand.append("-d")
        compileCommand.append(classesDir)

        for source in build.sources {
            let expandedSources = try expandGlob(source, in: projectPath)
            compileCommand.append(contentsOf: expandedSources)
        }

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

        let jarName = "\(build.output).jar"
        let jarPath = "\(outputDir)/\(jarName)"

        var jarCommand = ["jar", "cf", jarPath, "-C", classesDir, "."]

        if !language.mainClass.isEmpty {
            let manifestPath = "\(outputDir)/MANIFEST.MF"
            let manifestContent = """
                Manifest-Version: 1.0
                Main-Class: \(language.mainClass)

                """

            try manifestContent.write(toFile: manifestPath, atomically: true, encoding: .utf8)
            jarCommand = ["jar", "cfm", jarPath, manifestPath, "-C", classesDir, "."]
        }

        if language.shade {
            for library in language.libraries {
                if library.hasSuffix(".jar") {
                    let extractProcess = Process()
                    extractProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    extractProcess.arguments = ["jar", "xf", library]
                    extractProcess.currentDirectoryURL = URL(fileURLWithPath: classesDir)

                    try extractProcess.run()
                    extractProcess.waitUntilExit()
                }
            }
        }

        let jarProcess = Process()
        jarProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        jarProcess.arguments = jarCommand
        jarProcess.currentDirectoryURL = URL(fileURLWithPath: projectPath)

        let jarPipe = Pipe()
        jarProcess.standardOutput = jarPipe
        jarProcess.standardError = jarPipe

        try jarProcess.run()
        jarProcess.waitUntilExit()

        let jarData = jarPipe.fileHandleForReading.readDataToEndOfFile()
        if let jarOutput = String(data: jarData, encoding: .utf8), !jarOutput.isEmpty {
            print(jarOutput)
        }

        if jarProcess.terminationStatus != 0 {
            throw BuildError.buildFailed(build.name)
        }

        pipelinePrint("Java build completed: \(jarPath)", category: "success", strip: strip)
    }

    private func executeCBuild(
        _ build: BuildData, language: CLanguageData, projectPath: String, strip: Bool = false, globalBuildType: String, buildConfig: BuildConfigData
    ) throws {
        let currentDir = FileManager.default.currentDirectoryPath
        let outputSubdir = getOutputSubdirectory(for: language.buildType)
        let outputDir = "\(currentDir)/velux-out/\(outputSubdir)"

        let createDirProcess = Process()
        createDirProcess.executableURL = URL(fileURLWithPath: "/bin/mkdir")
        createDirProcess.arguments = ["-p", outputDir]

        try createDirProcess.run()
        createDirProcess.waitUntilExit()

        var compileCommand = ["clang"]
        compileCommand.append(contentsOf: getCompilerFlags(for: globalBuildType))
        compileCommand.append(contentsOf: language.compilerFlags)
        compileCommand.append(contentsOf: language.extraFlags)

        for source in build.sources {
            let expandedSources = try expandGlob(source, in: projectPath)
            compileCommand.append(contentsOf: expandedSources)
        }

        for includePath in language.includePaths {
            compileCommand.append("-I\(includePath)")
        }

        for includePath in buildConfig.globalIncludePaths {
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

        for library in language.libraries {
            if library.hasPrefix("pkg:") {
                let moduleName = String(library.dropFirst(4))
                let (cflags, ldflags) = try runPkgConfig(moduleName)
                compileCommand.append(contentsOf: cflags)
                compileCommand.append(contentsOf: ldflags)
            } else {
                compileCommand.append("-l\(library)")
            }
        }

        for library in buildConfig.globalLibraries {
            compileCommand.append("-l\(library)")
        }

        let outputExtension = getOutputExtension(for: language.buildType)
        let outputName = getOutputName(
            build.name, buildType: language.buildType, extension: outputExtension)
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

    private func executeCPPBuild(
        _ build: BuildData, language: CPPLanguageData, projectPath: String, strip: Bool = false, globalBuildType: String, buildConfig: BuildConfigData
    ) throws {
        let currentDir = FileManager.default.currentDirectoryPath
        let outputSubdir = getOutputSubdirectory(for: language.buildType)
        let outputDir = "\(currentDir)/velux-out/\(outputSubdir)"

        let createDirProcess = Process()
        createDirProcess.executableURL = URL(fileURLWithPath: "/bin/mkdir")
        createDirProcess.arguments = ["-p", outputDir]

        try createDirProcess.run()
        createDirProcess.waitUntilExit()

        var compileCommand = ["clang++"]
        compileCommand.append(contentsOf: getCompilerFlags(for: globalBuildType))
        compileCommand.append(contentsOf: language.compilerFlags)
        compileCommand.append(contentsOf: language.extraFlags)

        for source in build.sources {
            let expandedSources = try expandGlob(source, in: projectPath)
            compileCommand.append(contentsOf: expandedSources)
        }

        for includePath in language.includePaths {
            compileCommand.append("-I\(includePath)")
        }

        for includePath in buildConfig.globalIncludePaths {
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

        for library in language.libraries {
            if library.hasPrefix("pkg:") {
                let moduleName = String(library.dropFirst(4))
                let (cflags, ldflags) = try runPkgConfig(moduleName)
                compileCommand.append(contentsOf: cflags)
                compileCommand.append(contentsOf: ldflags)
            } else {
                compileCommand.append("-l\(library)")
            }
        }

        for library in buildConfig.globalLibraries {
            compileCommand.append("-l\(library)")
        }

        let outputExtension = getOutputExtension(for: language.buildType)
        let outputName = getOutputName(
            build.name, buildType: language.buildType, extension: outputExtension)
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