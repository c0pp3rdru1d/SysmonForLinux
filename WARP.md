# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Build System

### Prerequisites Installation
The project requires specific prerequisites that vary by Linux distribution:

**Ubuntu/Debian:**
```bash
sudo apt update
dotnet tool install --global dotnet-t4 --version 2.3.1
sudo apt -y install build-essential gcc g++ make cmake libelf-dev llvm clang libxml2 libxml2-dev libzstd1 git libgtest-dev apt-transport-https dirmngr googletest google-mock libgmock-dev libjson-glib-dev libssl-dev
```

**Rocky/RHEL/Azure Linux:**
```bash
sudo dnf update
dotnet tool install --global dotnet-t4 --version 2.3.1
sudo dnf install gcc gcc-c++ make cmake llvm clang elfutils-libelf-devel rpm-build json-glib-devel python3 libxml2-devel gtest-devel gmock gmock-devel openssl-devel perl
```

### Build Process
```bash
# Clean build (recommended when modifying CMakeLists.txt or eBPF code)
rm -rf build
mkdir build
cd build
cmake ..
make

# Regular build
cd build
make
```

### Testing
```bash
# Run unit tests
cd build
./sysmonUnitTests

# Using the test runner script (recommended)
./run_tests.sh                    # Build and run all tests
./run_tests.sh -c -d              # Clean debug build and test
./run_tests.sh -f "Process.*"     # Run only Process tests
./run_tests.sh -f "Process.ProcessName" # Run specific test
./run_tests.sh -n                 # Build only, no tests
```

### Package Creation
```bash
# Create DEB package
make deb

# Create RPM package
make rpm
```

## Architecture Overview

### Core Components

**Main Program (`sysmonforlinux.c`)**
- Entry point and command-line parsing
- Interfaces with Windows-compatible Sysmon shared code
- Manages eBPF program lifecycle and configuration
- Handles event processing and filtering

**eBPF Programs (`ebpfKern/` directory)**
- Kernel-space programs for different kernel versions (4.15, 4.16, 4.17-5.1, 5.2, 5.3-5.5, 5.6+)
- Both traditional and CO-RE (Compile Once, Run Everywhere) versions
- Event-specific programs for process creation, file operations, network activity, etc.

**Linux Compatibility Layer**
- `linuxHelpers.cpp/h` - Platform-specific implementations
- `linuxTypes.h` - Type definitions for Windows compatibility
- `linuxWideChar.c/h` - UTF-16 string handling

**Network Correlation Engine (`networkTracker.cpp/h`)**
- Correlates network events across multiple eBPF tracepoints
- Handles TCP connection state tracking and UDP packet correlation

**Configuration and Output**
- `installer.c/h` - Installation, configuration management, and systemd integration
- `outputxml.c/h` - Formats events for syslog output

### Shared Windows Code
The project shares code with Windows Sysmon via `sysmonCommon/` directory, enabling consistent event schemas and filtering logic.

## Development Workflow

### Adding New Events
1. Identify the Linux syscall or tracepoint that provides the needed information
2. Check `/sys/kernel/debug/tracing/events` for available tracepoints and their parameters
3. Create eBPF programs using the template files (`sysmonTEMPLATE*.c`) or use `makeEvent.sh`
4. Add the programs to all kernel-specific eBPF source files
5. Update the configuration in `sysmonforlinux.c`
6. Add syscall mappings in `SetActiveSyscalls()`
7. Handle event processing in `handle_event()` if correlation is needed

### eBPF Development
- **Debugging**: Enable `DEBUG_K` option in CMakeLists.txt and use `BPF_PRINTK()` 
- **Kernel Compatibility**: Support multiple kernel versions with separate eBPF programs
- **Memory Access**: Store syscall arguments at entry points, retrieve at exit points when userland memory is accessible
- **Verifier Constraints**: All loops must be bounded, array access must be bounded with `& (SIZE - 1)` pattern

### Build Configuration
- **Debug Mode**: Set `CMAKE_BUILD_TYPE Debug` in CMakeLists.txt for symbols
- **eBPF Debug**: Set `DEBUG_K On` to enable kernel debug output to `/sys/kernel/debug/tracing/trace_pipe`

## Runtime and Installation

### Manual Installation
```bash
# Install sysmon with configuration
sudo ./sysmon -i CONFIG_FILE

# Change configuration
sudo /opt/sysmon/sysmon -c CONFIG_FILE

# Uninstall
sudo /opt/sysmon/sysmon -u
```

### Log Monitoring
```bash
# Raw syslog output
sudo tail -f /var/log/syslog

# Formatted output with filtering options
sudo tail -f /var/log/syslog | sudo /opt/sysmon/sysmonLogView
```

### BTF Support
- Automatic kernel offset discovery via BTF (Berkeley Packet Filter Type Format)
- Fallback to manual offset discovery if BTF unavailable
- Support for standalone BTF files with `/BTF` switch

## Key Dependencies

- **libsysinternalsEBPF.so** - Core eBPF functionality
- **.NET SDK** - For T4 text template processing
- **clang/llvm v10+** - eBPF program compilation
- **libxml2** - Configuration and event formatting
- **OpenSSL 3.4.1** - Built from source during compilation

## Package Maintenance

The build system automatically:
- Generates event headers from manifest files
- Compiles eBPF programs for multiple kernel versions
- Embeds all required files into the sysmon binary for portability
- Creates distribution packages (DEB/RPM) with proper systemd integration

## Testing and CI Improvements

### Test Runner Script
The `run_tests.sh` script provides an easy interface for building and testing:
- Supports clean builds, debug/release modes
- Provides test filtering capabilities
- Includes verbose output options
- Automatically handles git submodules

### Memory Management Fixes
Fixed double-free issues in the ProcessName test that were causing crashes during test execution.

### Continuous Integration
GitHub Actions workflow (`.github/workflows/ci.yml`) provides:
- Automated testing on push/PR
- Matrix builds (Debug/Release)
- Dependency installation automation
- Artifact upload for test results and packages
- Note: Requires SysinternalsEBPF library setup for full functionality
