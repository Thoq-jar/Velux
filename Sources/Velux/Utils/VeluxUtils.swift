import PklSwift
import Foundation

struct VeluxUtils {
    public func loadWorkspace(from path: String) async throws -> WorkspaceData {
        let result = try await PklSwift.withEvaluator { evaluator in
            try await evaluator.evaluateModule(source: .path(path), as: PklWorkspaceRoot.self)
        }

        return result.workspace.toWorkspaceData()
    }

    public func loadBuildConfig(from path: String) async throws -> BuildConfigData {
        let result = try await PklSwift.withEvaluator { evaluator in
            try await evaluator.evaluateModule(source: .path(path), as: PklBuildConfigRoot.self)
        }

        return result.toBuildConfigData()
    }

    public func executeScript(_ scriptName: String, in workspace: WorkspaceData) throws {
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

    public func expandGlob(_ pattern: String, in basePath: String) throws -> [String] {
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

    public func getOutputSubdirectory(for buildType: String) -> String {
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

    public func getOutputExtension(for buildType: String) -> String {
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

    public func getCompilerFlags(for buildType: String) -> [String] {
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

    public func runPkgConfig(_ moduleName: String) throws -> (cflags: [String], ldflags: [String]) {
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

    public func getOutputName(_ name: String, buildType: String, extension ext: String) -> String {
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
}