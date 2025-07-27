import ArgumentParser
import Foundation

@main
struct Velux: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A build system using pkl configuration files",
        subcommands: [Build.self, Run.self, List.self, Info.self]
    )
}

extension Velux {
    struct Build: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Build projects or run scripts"
        )

        @Option(name: .shortAndLong, help: "Workspace configuration file")
        var workspace: String = "workspace.pkl"

        @Argument(help: "Project name or script name to build/run")
        var target: String

        @Flag(name: .shortAndLong, help: "Run as script instead of building project")
        var script: Bool = false

        func run() async throws {
            let buildSystem = BuildSystem()
            let workspaceData = try await buildSystem.loadWorkspace(from: workspace)

            if script {
                try buildSystem.executeScript(target, in: workspaceData)
            } else {
                let buildConfig = try await buildSystem.loadBuildConfig(from: "build.pkl")
                try await buildSystem.buildProject(
                    target, in: workspaceData, buildConfig: buildConfig)
            }
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

        func run() async throws {
            let buildSystem = BuildSystem()
            let workspaceData = try await buildSystem.loadWorkspace(from: workspace)
            try buildSystem.executeScript(script, in: workspaceData)
        }
    }

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List available projects and scripts"
        )

        @Option(name: .shortAndLong, help: "Workspace configuration file")
        var workspace: String = "workspace.pkl"

        func run() async throws {
            let buildSystem = BuildSystem()
            let workspaceData = try await buildSystem.loadWorkspace(from: workspace)

            print("Workspace: \(workspaceData.name) v\(workspaceData.version)")
            print()

            if !workspaceData.projects.isEmpty {
                print("Projects:")
                for (key, project) in workspaceData.projects.sorted(by: { $0.key < $1.key }) {
                    print("  \(key): \(project.name) (\(project.type))")
                    if !project.dependencies.isEmpty {
                        print("    dependencies: \(project.dependencies.joined(separator: ", "))")
                    }
                }
                print()
            }

            if !workspaceData.scripts.isEmpty {
                print("Scripts:")
                for (key, script) in workspaceData.scripts.sorted(by: { $0.key < $1.key }) {
                    print("  \(key): \(script.description ?? script.command)")
                    if !script.dependencies.isEmpty {
                        print("    dependencies: \(script.dependencies.joined(separator: ", "))")
                    }
                }
                print()
            }

            if !workspaceData.environments.isEmpty {
                print("Environments:")
                for (key, env) in workspaceData.environments.sorted(by: { $0.key < $1.key }) {
                    print("  \(key): \(env.name)")
                    if !env.features.isEmpty {
                        print("    features: \(env.features.joined(separator: ", "))")
                    }
                }
            }
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

        func run() async throws {
            let buildSystem = BuildSystem()
            let workspaceData = try await buildSystem.loadWorkspace(from: workspace)

            if let project = workspaceData.projects[target] {
                print("Project: \(project.name)")
                print("Type: \(project.type)")
                print("Path: \(project.path)")
                if let buildConfig = project.buildConfig {
                    print("Build Config: \(buildConfig)")
                }
                if !project.dependencies.isEmpty {
                    print("Dependencies: \(project.dependencies.joined(separator: ", "))")
                }
            } else if let script = workspaceData.scripts[target] {
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
                print("Target '\(target)' not found")
            }
        }
    }
}
