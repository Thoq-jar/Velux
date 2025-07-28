import Foundation

func executeJavaBuild(
    _ build: BuildData, language: JavaLanguageData, projectPath: String, strip: Bool = false,
    buildConfig: BuildConfigData
) throws {
    let currentDir = FileManager.default.currentDirectoryPath
    let outputDir = "\(currentDir)/velux-out/java"
    let classesDir = "\(outputDir)/classes"
    let libDir = "\(outputDir)/lib"
    let utils = VeluxUtils()

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
        let expandedSources = try utils.expandGlob(source, in: projectPath)
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