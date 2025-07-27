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
        _ projectName: String, in workspace: WorkspaceData, buildConfig: BuildConfigData
    ) async throws {
        guard let project = workspace.projects[projectName] else {
            throw BuildError.projectNotFound(projectName)
        }

        for dependency in project.dependencies {
            try await buildProject(dependency, in: workspace, buildConfig: buildConfig)
        }

        if let buildConfigPath = project.buildConfig {
            let fullPath = "\(project.path)/\(buildConfigPath)"
            let projectBuildConfig = try await loadBuildConfig(from: fullPath)

            for (_, build) in projectBuildConfig.builds {
                try executeBuild(build, projectPath: project.path)
            }
        }
    }

    private func executeBuild(_ build: BuildData, projectPath: String) throws {
        let outputDir = "\(projectPath)/build/\(build.buildType)"

        let createDirProcess = Process()
        createDirProcess.executableURL = URL(fileURLWithPath: "/bin/mkdir")
        createDirProcess.arguments = ["-p", outputDir]

        try createDirProcess.run()
        createDirProcess.waitUntilExit()

        var compileCommand = ["gcc"]
        compileCommand.append(contentsOf: build.extraFlags)

        for source in build.sources {
            let expandedSources = try expandGlob(source, in: projectPath)
            compileCommand.append(contentsOf: expandedSources)
        }

        for includePath in build.includePaths {
            compileCommand.append("-I\(includePath)")
        }

        for library in build.libraries {
            compileCommand.append("-l\(library)")
        }

        compileCommand.append("-o")
        compileCommand.append("\(outputDir)/\(build.name)")

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
        let fullPattern = "\(basePath)/\(pattern)"

        let globProcess = Process()
        globProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        globProcess.arguments = ["-c", "echo \(fullPattern)"]

        let pipe = Pipe()
        globProcess.standardOutput = pipe

        try globProcess.run()
        globProcess.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }
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
        }
    }
}
