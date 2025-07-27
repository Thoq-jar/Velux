# Velux

> ⚠️ Notice: Very early stages of development, some things may break!

A fast, powerful, and modern build system for C and C++ projects using [Pkl](https://pkl-lang.org/) configuration files.

## Overview

Velux is a build system that leverages Apple's Pkl configuration language to provide type-safe, declarative build configurations for C and C++ projects. It emphasizes simplicity, maintainability, and powerful workspace management capabilities.

### Key Features

- **Pkl-based Configuration**: Type-safe, declarative build configurations using Apple's Pkl language
- **Multi-project Workspaces**: Organize multiple related projects with automatic dependency resolution
- **Script Management**: Define and execute build scripts with dependency tracking
- **Environment Support**: Multiple build environments (dev, staging, prod) with different settings
- **Language-specific Defaults**: Built-in compiler configurations for C and C++
- **Dependency Resolution**: Automatic build ordering based on project dependencies
- **Cross-platform**: Works on macOS, Linux, and Windows

## Quick Start

### Prerequisites

- Swift 6.2+ (for building Velux)
- GCC or Clang compiler
- Pkl runtime (installed automatically via pkl-swift)

### Installation

Clone and build Velux:

```bash
git clone https://github.com/your-username/Velux.git
cd Velux
swift build -c release
```

The built executable will be at `.build/release/Velux`.

### Basic Usage

1. **Create a workspace configuration** (`workspace.pkl`):
```pkl
amends "pkl/WorkspaceConfig.pkl"

workspace = new Workspace {
  name = "MyProject"
  version = "1.0.0"
  projects = Map(
    "app", new Project {
      name = "app"
      path = "src"
      type = "executable"
      buildConfig = "build.pkl"
    }
  )
  scripts = Map(
    "build", new Script {
      name = "build"
      command = "echo 'Building...'"
      description = "Build the project"
    }
  )
}
```

2. **Create a build configuration** (`build.pkl`):
```pkl
amends "pkl/BuildConfig.pkl"

builds = Map(
  "main", new Build {
    name = "main"
    sources = Set("*.c")
    language = new C {}
    buildType = "release"
    output = "myapp"
  }
)
```

3. **List available projects and scripts**:
```bash
velux list
```

4. **Run a script**:
```bash
velux run build
```

5. **Build a project**:
```bash
velux build main
```

## Configuration

### Workspace Configuration

The workspace configuration (`workspace.pkl`) defines the overall project structure:

```pkl
workspace = new Workspace {
  name = "ProjectName"
  version = "1.0.0"

  // Define projects in the workspace
  projects = Map(
    "core", new Project {
      name = "core"
      path = "src/core"
      type = "library"
      buildConfig = "core.pkl"
    },
    "app", new Project {
      name = "app"
      path = "src/app"
      type = "executable"
      dependencies = List("core")  // Depends on core library
      buildConfig = "app.pkl"
    }
  )

  // Define build scripts
  scripts = Map(
    "clean", new Script {
      name = "clean"
      command = "rm -rf build/"
      description = "Clean build artifacts"
    },
    "test", new Script {
      name = "test"
      command = "./build/test_runner"
      description = "Run tests"
      dependencies = List("build-tests")
    }
  )

  // Define environments
  environments = Map(
    "dev", new Environment {
      name = "dev"
      variables = Map("DEBUG", "1")
      features = Set("debug-logging")
    },
    "prod", new Environment {
      name = "prod"
      variables = Map("OPTIMIZE", "1")
    }
  )
}
```

### Build Configuration

Build configurations define how individual projects are compiled:

```pkl
builds = Map(
  "mylib", new Build {
    name = "mylib"
    sources = Set("*.c", "utils/*.c")
    language = new C {
      compilerFlags = List("-std=c99", "-Wall")
    }
    buildType = "release"
    libraries = List("pthread", "m")
    includePaths = List("include", "../common")
    extraFlags = List("-fPIC", "-shared")
    output = "libmylib.so"
  }
)
```

### Language Support

Velux comes with built-in support for C and C++:

#### C Language
```pkl
language = new C {
  // Default: extensions = Set(".c", ".h")
  // Default: compilerFlags = List("-std=c99", "-Wall", "-Wextra")
}
```

#### C++ Language
```pkl
language = new CPP {
  // Default: extensions = Set(".cpp", ".cxx", ".cc", ".hpp", ".hxx", ".h")
  // Default: compilerFlags = List("-std=c++17", "-Wall", "-Wextra")
}
```

You can override defaults:
```pkl
language = new C {
  compilerFlags = List("-std=c11", "-Wall", "-Wextra", "-pedantic")
}
```

## Commands

### `velux list`
List all available projects, scripts, and environments in the workspace.

```bash
velux list [--workspace workspace.pkl]
```

### `velux run <script>`
Execute a named script from the workspace configuration.

```bash
velux run build
velux run test
velux run clean
```

### `velux build <project>`
Build a specific project (deprecated in favor of script-based builds).

```bash
velux build core
velux build app
```

### `velux info <target>`
Show detailed information about a project or script.

```bash
velux info core
velux info build-script
```

## Project Structure

A typical Velux workspace might look like:

```
my-project/
├── pkl/                    # Schema definitions
│   ├── BuildConfig.pkl
│   └── WorkspaceConfig.pkl
├── src/
│   ├── core/
│   │   ├── core.c
│   │   ├── core.h
│   │   └── core.pkl        # Build config for core
│   └── app/
│       ├── main.c
│       └── app.pkl         # Build config for app
├── tests/
│   ├── test_core.c
│   └── tests.pkl           # Build config for tests
├── workspace.pkl           # Main workspace config
└── build.pkl              # Optional global build config
```

## Examples

### Multi-project C Library and Application

See the complete example in the [`example/`](example/) directory, which demonstrates:

- A shared C library (`core`)
- A command-line application (`app`) that uses the library
- A test suite (`tests`) for the library
- Build scripts with dependency management
- Environment-specific configurations
- Integration with both Velux and CMake build systems

### Key features demonstrated:

1. **Dependency Management**: The app depends on core, tests depend on core
2. **Script Dependencies**: The `test` script depends on `build-tests`
3. **Environment Variables**: Different settings for dev vs prod
4. **Library Linking**: Proper shared library creation and linking
5. **Build Ordering**: Automatic resolution of build dependencies

## Advanced Usage

### Custom Build Scripts

Create complex build workflows:

```pkl
scripts = Map(
  "full-build", new Script {
    name = "full-build"
    command = "echo 'Starting full build pipeline'"
    description = "Complete build and test pipeline"
    dependencies = List("clean", "build-all", "test", "package")
  },
  "build-all", new Script {
    name = "build-all"
    command = "echo 'Building all projects'"
    dependencies = List("build-core", "build-app", "build-tests")
  }
)
```

### Environment-specific Builds

Use different configurations for different environments:

```pkl
environments = Map(
  "debug", new Environment {
    name = "debug"
    variables = Map(
      "CFLAGS", "-g -O0 -DDEBUG",
      "BUILD_TYPE", "debug"
    )
    features = Set("assertions", "debug-symbols")
  },
  "release", new Environment {
    name = "release"
    variables = Map(
      "CFLAGS", "-O3 -DNDEBUG",
      "BUILD_TYPE", "release"
    )
  }
)
```

### Cross-platform Scripts

Define platform-specific behavior:

```pkl
"build", new Script {
  name = "build"
  command = if (System.getProperty("os.name").contains("Windows"))
    then "build.bat"
    else "./build.sh"
  platforms = Set("linux", "macos", "windows")
}
```

## Integration

### With CMake

Velux can coexist with CMake. Use Velux for high-level project management and CMake for detailed build configuration:

```pkl
scripts = Map(
  "cmake-build", new Script {
    name = "cmake-build"
    command = "mkdir -p build && cd build && cmake .. && make"
    description = "Build using CMake"
  }
)
```

### With Other Tools

Integrate with formatters, linters, and other development tools:

```pkl
scripts = Map(
  "format", new Script {
    name = "format"
    command = "find . -name '*.c' -o -name '*.h' | xargs clang-format -i"
    description = "Format source code"
  },
  "lint", new Script {
    name = "lint"
    command = "cppcheck --enable=all src/"
    description = "Run static analysis"
  }
)
```

## Why Velux?

### Advantages over Traditional Build Systems

1. **Type Safety**: Pkl provides compile-time validation of build configurations
2. **Declarative**: Focus on what to build, not how to build it
3. **Composable**: Inherit and extend configurations easily
4. **Maintainable**: Clear, readable configuration files
5. **IDE Support**: Full IDE support for Pkl configuration files
6. **Validation**: Built-in validation prevents configuration errors

### Comparison with Other Build Systems

| Feature | Velux | Make | CMake | Bazel |
|---------|-------|------|-------|-------|
| Type Safety | ✅ | ❌ | ❌ | ❌ |
| Multi-project | ✅ | ❌ | ⚠️  | ✅ |
| Script Management | ✅ | ❌ | ⚠️  | ❌ |
| Learning Curve | Low | Medium | High | High |
| IDE Support | ❌ | ❌ | ✅  | ✅ |
| Configuration Language | Pkl | Make | CMake | Starlark |

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

Copyright © 2025 [Thoq-jar](https://thoq.dev)

See the [LICENSE](LICENSE.md) file for details.

## Support

- [Documentation](docs/)
- [Examples](example/)
- [Issue Tracker](https://github.com/thoq-jar/Velux/issues)
- [Discussions](https://github.com/thoq-jar/Velux/discussions)
