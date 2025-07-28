# Velux Demo Project

A demonstration of the Velux build system using pkl configuration files for C projects.

## Project Structure

```
example/
├── src/
│   ├── core/           # Core library
│   │   ├── core.h      # Library header
│   │   ├── core.c      # Library implementation
│   │   └── core.pkl    # Build configuration
│   └── app/            # Main application
│       ├── main.c      # Application entry point
│       └── app.pkl     # Build configuration
├── tests/              # Test suite
│   ├── test_core.c     # Core library tests
│   └── tests.pkl       # Test build configuration
├── pkl/                # Configuration schemas
│   ├── BuildConfig.pkl
│   └── WorkspaceConfig.pkl
├── build.pkl           # Main build configuration
├── workspace.pkl       # Workspace configuration
└── CMakeLists.txt      # Alternative CMake build
```

## Components

### Core Library
- **core.h/core.c**: A simple C library providing logging, data processing, and version info
- Features:
  - Initialization and cleanup
  - Logging with different levels
  - Data processing functions
  - Memory management utilities

### Main Application
- **main.c**: Command-line application using the core library
- Features:
  - Command-line argument parsing
  - Debug mode support
  - Data processing demonstration
  - Version information display

### Test Suite
- **test_core.c**: Comprehensive tests for the core library
- Tests cover:
  - Initialization/cleanup
  - Logging functionality
  - Data processing
  - Memory management

## Building with Velux

### Prerequisites
- Swift 6.2+ (for Velux build tool)
- GCC or Clang compiler
- pkl-swift package

### Build Commands

Build the Velux tool first:
```bash
cd .. && swift build
```

Then use Velux to build the demo:

```bash
# List available projects and scripts
../build/debug/Velux list

# Build all projects
../build/debug/Velux run build

# Build individual components
../build/debug/Velux run build-core
../build/debug/Velux run build-app
../build/debug/Velux run build-tests

# Run tests
../build/debug/Velux run test

# Run the application
../build/debug/Velux run run

# Run with custom arguments
../build/debug/Velux run run-with-args

# Clean build artifacts
../build/debug/Velux run clean
```

### Manual Building

You can also build manually:

```bash
# Build core library
cd src/core
mkdir -p build/release
gcc -fPIC -shared -std=c99 -Wall -Wextra *.c -o build/release/libcore.so

# Build application
cd ../app
mkdir -p build/release
gcc -std=c99 -Wall -Wextra -I../core *.c -L../core/build/release -lcore -o build/release/velux-app

# Build tests
cd ../../tests
mkdir -p build/debug
gcc -std=c99 -Wall -Wextra -I../src/core *.c -L../src/core/build/release -lcore -o build/debug/test_runner
```

### Alternative: CMake Build

```bash
mkdir build && cd build
cmake ..
make
ctest
```

## Usage

### Running the Application

```bash
# Basic usage
./src/app/build/release/velux-app

# With custom input
./src/app/build/release/velux-app "Hello World"

# Debug mode
./src/app/build/release/velux-app -d "Debug data"

# Show help
./src/app/build/release/velux-app --help

# Show version
./src/app/build/release/velux-app --version
```

### Running Tests

```bash
./tests/build/debug/test_runner
```

## Configuration Files

### workspace.pkl
Defines the overall project structure, scripts, and dependencies. Key features:
- Project organization (core, app, tests)
- Build scripts with dependencies
- Environment configurations
- Development and production settings

### build.pkl
Defines build targets and compilation settings:
- Source file patterns
- Compiler flags
- Library dependencies
- Output configurations

### Individual Project Configs
Each project has its own pkl configuration:
- **src/core/core.pkl**: Shared library build
- **src/app/app.pkl**: Executable build with core dependency
- **tests/tests.pkl**: Test executable build

## Development Environments

The workspace defines two environments:

### Development (dev)
- Debug logging enabled
- Profiling features active
- Verbose output

### Production (prod)
- Optimized builds
- Minimal logging
- Release configuration

## Scripts Available

- **clean**: Remove all build artifacts
- **format**: Format source code with clang-format
- **build**: Build all projects in dependency order
- **build-core**: Build only the core library
- **build-app**: Build only the main application
- **build-tests**: Build only the test suite
- **test**: Run all tests
- **run**: Execute the main application
- **run-with-args**: Run application with debug mode and sample data

## Features Demonstrated

1. **Multi-project workspace**: Organized into library, application, and tests
2. **Dependency management**: Automatic dependency resolution and build ordering
3. **Configuration inheritance**: pkl files extend base configurations
4. **Script dependencies**: Scripts can depend on other scripts
5. **Environment-specific settings**: Different configurations for dev/prod
6. **Language-specific settings**: C compiler flags and standards
7. **Library linking**: Shared library creation and linking
8. **Test integration**: Automated test building and execution