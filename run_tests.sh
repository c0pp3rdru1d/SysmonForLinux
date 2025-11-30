#!/bin/bash
#
# Test runner script for SysmonForLinux
#
# This script provides an easy way to build and run tests with different options
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
BUILD_TYPE="Release"
CLEAN_BUILD=false
RUN_TESTS=true
VERBOSE=false
TEST_FILTER=""

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -c, --clean         Clean build (remove build directory)"
    echo "  -d, --debug         Build in debug mode"
    echo "  -h, --help          Show this help message"
    echo "  -f, --filter FILTER Run specific test filter (gtest format)"
    echo "  -n, --no-tests      Don't run tests after building"
    echo "  -v, --verbose       Verbose output"
    echo ""
    echo "Examples:"
    echo "  $0                           # Standard build and test"
    echo "  $0 -c -d                     # Clean debug build and test"
    echo "  $0 -f \"Process.*\"           # Run only Process tests"
    echo "  $0 -f \"Process.ProcessName\" # Run specific test"
    echo "  $0 -n                        # Build only, no tests"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -d|--debug)
            BUILD_TYPE="Debug"
            shift
            ;;
        -f|--filter)
            TEST_FILTER="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -n|--no-tests)
            RUN_TESTS=false
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check for required tools
print_status "Checking prerequisites..."
MISSING_TOOLS=()

if ! command -v cmake &> /dev/null; then
    MISSING_TOOLS+=("cmake")
fi

if ! command -v make &> /dev/null; then
    MISSING_TOOLS+=("make")
fi

if ! command -v clang &> /dev/null; then
    MISSING_TOOLS+=("clang")
fi

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    print_error "Missing required tools: ${MISSING_TOOLS[*]}"
    exit 1
fi

# Check for git submodules
if [ ! -f "sysmonCommon/manifest.xml" ]; then
    print_warning "Git submodules not initialized, initializing..."
    git submodule update --init --recursive
fi

# Create build directory
if [ "$CLEAN_BUILD" = true ] && [ -d "build" ]; then
    print_status "Cleaning build directory..."
    rm -rf build
fi

if [ ! -d "build" ]; then
    mkdir build
fi

cd build

# Configure build
print_status "Configuring build (${BUILD_TYPE})..."
if [ "$VERBOSE" = true ]; then
    cmake -DCMAKE_BUILD_TYPE=$BUILD_TYPE ..
else
    cmake -DCMAKE_BUILD_TYPE=$BUILD_TYPE .. > /dev/null
fi

# Build
print_status "Building..."
MAKE_ARGS=""
if [ "$VERBOSE" = false ]; then
    MAKE_ARGS="-s"
fi

if make $MAKE_ARGS -j$(nproc); then
    print_success "Build completed successfully"
else
    print_error "Build failed"
    exit 1
fi

# Run tests
if [ "$RUN_TESTS" = true ]; then
    if [ ! -f "./sysmonUnitTests" ]; then
        print_error "Unit test binary not found"
        exit 1
    fi

    print_status "Running tests..."
    
    TEST_CMD="./sysmonUnitTests"
    if [ ! -z "$TEST_FILTER" ]; then
        TEST_CMD="$TEST_CMD --gtest_filter=\"$TEST_FILTER\""
    fi
    
    if [ "$VERBOSE" = true ]; then
        TEST_CMD="$TEST_CMD --gtest_print_time=1"
    fi

    # Run tests
    if eval $TEST_CMD; then
        print_success "All tests passed!"
    else
        print_error "Some tests failed"
        exit 1
    fi
fi

print_success "Script completed successfully"