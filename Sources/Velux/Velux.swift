import ArgumentParser
import Foundation

func pipelinePrint(_ message: String, category: String = "info", strip: Bool = false) {
    if strip {
        print(message)
        return
    }

    let prefix =
        switch category {
        case "building": "\(Colors.brightPurple)▶\(Colors.reset)"
        case "success": "\(Colors.green)✓\(Colors.reset)"
        case "processing": "\(Colors.purple)►\(Colors.reset)"
        case "warning": "\(Colors.yellow)!\(Colors.reset)"
        case "error": "\(Colors.red)✗\(Colors.reset)"
        default: "\(Colors.cyan)•\(Colors.reset)"
        }

    print("\(prefix) \(message)")
}

@main
struct Velux: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A build system using pkl configuration files",
        subcommands: [Build.self, Run.self, List.self, Info.self]
    )
}

func prerun(strip: Bool = false) {
    if strip {
        print("Starting Velux...")
        return
    }
    print("\n\(Colors.brightPurple)\(Colors.bold)Velux Build System\(Colors.reset)")
    print("\(Colors.purple)────────────────────\(Colors.reset)")
}

func postrun(strip: Bool = false) {
    if strip {
        print("Build completed successfully")
        return
    }
    print("\n\(Colors.green)\(Colors.bold)✓ Build completed successfully!\(Colors.reset)")
    print("\(Colors.purple)────────────────────\(Colors.reset)\n")
}

extension Velux {
    struct Build: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Build projects or run scripts"
        )

        @Option(name: .shortAndLong, help: "Workspace configuration file")
        var workspace: String = "workspace.pkl"

        @Flag(help: "Strip colors and use plain output")
        var strip: Bool = false

        @Flag(help: "Perform a debug build")
        var debug: Bool = false

        @Flag(help: "Perform a release build")
        var release: Bool = false

        @Argument(help: "Project name or script name to build/run")
        var target: String

        @Flag(name: .shortAndLong, help: "Run as script instead of building project")
        var script: Bool = false

        func run() async throws {
            if debug && release {
                throw ValidationError(
                    "Cannot specify both --debug and --release flags simultaneously.")
            }

            let resolvedBuildType: String
            if debug {
                resolvedBuildType = "debug"
            } else if release {
                resolvedBuildType = "release"
            } else {
                resolvedBuildType = "release"
            }

            prerun(strip: strip)
            let buildSystem = BuildSystem()
            let workspaceData = try await buildSystem.loadWorkspace(from: workspace)

            if script {
                try buildSystem.executeScript(target, in: workspaceData)
            } else {
                let buildConfig = try await buildSystem.loadBuildConfig(from: "build.pkl")
                try await buildSystem.buildProject(
                    target, in: workspaceData, buildConfig: buildConfig, strip: strip,
                    buildType: resolvedBuildType)
            }

            postrun(strip: strip)
        }
    }

    struct Run: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Run a script"
        )

        @Option(name: .shortAndLong, help: "Workspace configuration file")
        var workspace: String = "workspace.pkl"

        @Argument(help: "Script name to run")
        var script: String

        @Flag(help: "Strip colors and use plain output")
        var strip: Bool = false

        func run() async throws {
            prerun(strip: strip)
            let buildSystem = BuildSystem()
            let workspaceData = try await buildSystem.loadWorkspace(from: workspace)
            try buildSystem.executeScript(script, in: workspaceData)
            postrun(strip: strip)
        }
    }

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List available projects and scripts"
        )

        @Option(name: .shortAndLong, help: "Workspace configuration file")
        var workspace: String = "workspace.pkl"

        @Flag(help: "Strip colors and use plain output")
        var strip: Bool = false

        func run() async throws {
            prerun(strip: strip)
            let buildSystem = BuildSystem()
            let workspaceData = try await buildSystem.loadWorkspace(from: workspace)

            if strip {
                print("Workspace: \(workspaceData.name) v\(workspaceData.version)")
            } else {
                print(
                    "\n\(Colors.purple)\(Colors.bold)Workspace:\(Colors.reset) \(Colors.cyan)\(workspaceData.name)\(Colors.reset) \(Colors.yellow)v\(workspaceData.version)\(Colors.reset)"
                )
            }

            if !workspaceData.projects.isEmpty {
                if strip {
                    print("Projects:")
                } else {
                    print("\n\(Colors.purple)\(Colors.bold)Projects:\(Colors.reset)")
                }
                for (key, project) in workspaceData.projects.sorted(by: { $0.key < $1.key }) {
                    if strip {
                        print("  \(key): \(project.name) (\(project.type))")
                    } else {
                        print(
                            "  \(Colors.cyan)\(key)\(Colors.reset): \(project.name) \(Colors.yellow)(\(project.type))\(Colors.reset)"
                        )
                    }
                    if !project.dependencies.isEmpty {
                        if strip {
                            print(
                                "    dependencies: \(project.dependencies.joined(separator: ", "))")
                        } else {
                            print(
                                "    \(Colors.purple)dependencies:\(Colors.reset) \(project.dependencies.joined(separator: ", "))"
                            )
                        }
                    }
                }
            }

            if !workspaceData.scripts.isEmpty {
                if strip {
                    print("Scripts:")
                } else {
                    print("\n\(Colors.purple)\(Colors.bold)Scripts:\(Colors.reset)")
                }
                for (key, script) in workspaceData.scripts.sorted(by: { $0.key < $1.key }) {
                    if strip {
                        print("  \(key): \(script.description ?? script.command)")
                    } else {
                        print(
                            "  \(Colors.cyan)\(key)\(Colors.reset): \(script.description ?? script.command)"
                        )
                    }
                    if !script.dependencies.isEmpty {
                        if strip {
                            print(
                                "    dependencies: \(script.dependencies.joined(separator: ", "))")
                        } else {
                            print(
                                "    \(Colors.purple)dependencies:\(Colors.reset) \(script.dependencies.joined(separator: ", "))"
                            )
                        }
                    }
                }
            }

            if !workspaceData.environments.isEmpty {
                if strip {
                    print("Environments:")
                } else {
                    print("\n\(Colors.purple)\(Colors.bold)Environments:\(Colors.reset)")
                }
                for (key, env) in workspaceData.environments.sorted(by: { $0.key < $1.key }) {
                    if strip {
                        print("  \(key): \(env.name)")
                    } else {
                        print("  \(Colors.cyan)\(key)\(Colors.reset): \(env.name)")
                    }
                    if !env.features.isEmpty {
                        if strip {
                            print("    features: \(env.features.joined(separator: ", "))")
                        } else {
                            print(
                                "    \(Colors.purple)features:\(Colors.reset) \(env.features.joined(separator: ", "))"
                            )
                        }
                    }
                }
            }

            postrun(strip: strip)
        }
    }

    struct Info: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show detailed information about a project or script"
        )

        @Option(name: .shortAndLong, help: "Workspace configuration file")
        var workspace: String = "workspace.pkl"

        @Argument(help: "Project or script name")
        var target: String

        @Flag(help: "Strip colors and use plain output")
        var strip: Bool = false

        func run() async throws {
            prerun(strip: strip)
            let buildSystem = BuildSystem()
            let workspaceData = try await buildSystem.loadWorkspace(from: workspace)

            if let project = workspaceData.projects[target] {
                if strip {
                    print("Project: \(project.name)")
                    print("Type: \(project.type)")
                    print("Path: \(project.path)")
                    if let buildConfig = project.buildConfig {
                        print("Build Config: \(buildConfig)")
                    }
                    if !project.dependencies.isEmpty {
                        print("Dependencies: \(project.dependencies.joined(separator: ", "))")
                    }
                } else {
                    print(
                        "\(Colors.purple)\(Colors.bold)Project:\(Colors.reset) \(Colors.cyan)\(project.name)\(Colors.reset)"
                    )
                    print("\(Colors.purple)Type:\(Colors.reset) \(project.type)")
                    print("\(Colors.purple)Path:\(Colors.reset) \(project.path)")
                    if let buildConfig = project.buildConfig {
                        print("\(Colors.purple)Build Config:\(Colors.reset) \(buildConfig)")
                    }
                    if !project.dependencies.isEmpty {
                        print(
                            "\(Colors.purple)Dependencies:\(Colors.reset) \(project.dependencies.joined(separator: ", "))"
                        )
                    }
                }
            } else if let script = workspaceData.scripts[target] {
                if strip {
                    print("Script: \(script.name)")
                    print("Command: \(script.command)")
                    if let description = script.description {
                        print("Description: \(description)")
                    }
                    print("Working Directory: \(script.workingDir)")
                    if !script.dependencies.isEmpty {
                        print("Dependencies: \(script.dependencies.joined(separator: ", "))")
                    }
                } else {
                    print(
                        "\(Colors.purple)\(Colors.bold)Script:\(Colors.reset) \(Colors.cyan)\(script.name)\(Colors.reset)"
                    )
                    print("\(Colors.purple)Command:\(Colors.reset) \(script.command)")
                    if let description = script.description {
                        print("\(Colors.purple)Description:\(Colors.reset) \(description)")
                    }
                    print("\(Colors.purple)Working Directory:\(Colors.reset) \(script.workingDir)")
                    if !script.dependencies.isEmpty {
                        print(
                            "\(Colors.purple)Dependencies:\(Colors.reset) \(script.dependencies.joined(separator: ", "))"
                        )
                    }
                }
            } else {
                if strip {
                    print("Target '\(target)' not found")
                } else {
                    print("\(Colors.yellow)Target '\(target)' not found\(Colors.reset)")
                }
            }

            postrun(strip: strip)
        }
    }
}
