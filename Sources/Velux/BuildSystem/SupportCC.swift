import Foundation

func executeCPPBuild(
    _ build: BuildData, language: CPPLanguageData, projectPath: String, strip: Bool = false,
    globalBuildType: String, buildConfig: BuildConfigData
) throws {
    let utils = VeluxUtils()
    let currentDir = FileManager.default.currentDirectoryPath
    let outputSubdir = utils.getOutputSubdirectory(for: language.buildType)
    let outputDir = "\(currentDir)/velux-out/\(outputSubdir)"

    let createDirProcess = Process()
    createDirProcess.executableURL = URL(fileURLWithPath: "/bin/mkdir")
    createDirProcess.arguments = ["-p", outputDir]

    try createDirProcess.run()
    createDirProcess.waitUntilExit()

    var compileCommand = ["clang++"]
    compileCommand.append(contentsOf: utils.getCompilerFlags(for: globalBuildType))
    compileCommand.append(contentsOf: language.compilerFlags)
    compileCommand.append(contentsOf: language.extraFlags)

    for source in build.sources {
        let expandedSources = try utils.expandGlob(source, in: projectPath)
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
            let (cflags, ldflags) = try utils.runPkgConfig(moduleName)
            compileCommand.append(contentsOf: cflags)
            compileCommand.append(contentsOf: ldflags)
        } else {
            compileCommand.append("-l\(library)")
        }
    }

    for library in buildConfig.globalLibraries {
        compileCommand.append("-l\(library)")
    }

    let outputExtension = utils.getOutputExtension(for: language.buildType)
    let outputName = utils.getOutputName(
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