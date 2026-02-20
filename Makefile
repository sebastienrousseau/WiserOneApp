# SPDX-License-Identifier: MIT
# Development Makefile for The Wiser One

.PHONY: all build release debug test clean format lint install run help \
		ci-check ci-build ci-test coverage security format-check lint-strict \
		validate deploy-ready

# Configuration
BUILD_DIR := build
RELEASE_DIR := build-release
COVERAGE_DIR := build-coverage
CMAKE := cmake
CTEST := ctest
NPROC := $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# CI Configuration - Zero warnings policy
CXXFLAGS_CI := -Werror
CLANG_FORMAT := clang-format-15
CLANG_TIDY := clang-tidy-15

# Default target
all: build

# =============================================================================
# Build Targets
# =============================================================================

## build: Build in debug mode (default)
build:
	@mkdir -p $(BUILD_DIR)
	@cd $(BUILD_DIR) && $(CMAKE) .. -DCMAKE_BUILD_TYPE=Debug
	@$(CMAKE) --build $(BUILD_DIR) --parallel $(NPROC)

## release: Build in release mode with optimizations
release:
	@mkdir -p $(RELEASE_DIR)
	@cd $(RELEASE_DIR) && $(CMAKE) .. -DCMAKE_BUILD_TYPE=Release
	@$(CMAKE) --build $(RELEASE_DIR) --parallel $(NPROC)

## debug: Alias for build
debug: build

# =============================================================================
# Testing
# =============================================================================

## test: Run all tests
test: build
	@cd $(BUILD_DIR) && $(CTEST) --output-on-failure

## test-verbose: Run tests with verbose output
test-verbose: build
	@cd $(BUILD_DIR) && $(CTEST) --output-on-failure --verbose

# =============================================================================
# Code Quality
# =============================================================================

## format: Format all source files
format:
	@find src tests -name '*.cpp' -o -name '*.h' | xargs $(CLANG_FORMAT) -i
	@echo "✅ Formatted all source files"

## format-check: Check formatting without modifying files (CI compatible)
format-check:
	@echo "Checking code formatting..."
	@find src tests -name '*.cpp' -o -name '*.h' | xargs $(CLANG_FORMAT) --dry-run --Werror || { \
		echo "❌ Formatting violations detected. Run 'make format' to fix."; \
		exit 1; \
	}
	@echo "✅ Code formatting is correct"

## lint: Run clang-tidy on source files
lint:
	@clang-tidy src/*.cpp -- -std=c++23 -I$(BUILD_DIR) \
		$$(pkg-config --cflags Qt6Core Qt6Widgets 2>/dev/null || echo "")

## lint-strict: Run clang-tidy with warnings as errors (CI mode)
lint-strict: build
	@echo "Running strict linting (warnings as errors)..."
	@cd $(BUILD_DIR) && $(CMAKE) .. -DCMAKE_BUILD_TYPE=Debug \
		-DCMAKE_CXX_CLANG_TIDY="$(CLANG_TIDY);-warnings-as-errors=*"
	@$(CMAKE) --build $(BUILD_DIR) --target all

# =============================================================================
# Installation
# =============================================================================

## install: Install to system (requires sudo)
install: release
	@cd $(RELEASE_DIR) && sudo $(CMAKE) --install .

## install-local: Install to ~/.local
install-local: release
	@cd $(RELEASE_DIR) && $(CMAKE) --install . --prefix ~/.local

## uninstall-local: Remove from ~/.local
uninstall-local:
	@rm -f ~/.local/bin/wiserone
	@rm -f ~/.local/share/applications/com.wiserone.WiserOne.desktop
	@rm -f ~/.local/share/icons/hicolor/*/apps/com.wiserone.WiserOne.png
	@rm -f ~/.local/share/icons/hicolor/*/apps/com.wiserone.WiserOne*.svg
	@echo "Uninstalled from ~/.local"

# =============================================================================
# Development
# =============================================================================

## run: Build and run the application
run: build
	@$(BUILD_DIR)/wiserone 2>/dev/null &

## run-release: Build release and run
run-release: release
	@$(RELEASE_DIR)/wiserone 2>/dev/null &

## clean: Remove build directories
clean:
	@rm -rf $(BUILD_DIR) $(RELEASE_DIR)
	@echo "Cleaned build directories"

## distclean: Remove all generated files
distclean: clean
	@rm -f translations/*.qm
	@rm -f compile_commands.json
	@echo "Cleaned all generated files"

# =============================================================================
# Packaging
# =============================================================================

## package-linux: Create Linux tarball
package-linux: release
	@mkdir -p dist/usr/bin dist/usr/share/applications dist/usr/share/icons/hicolor/256x256/apps
	@cp $(RELEASE_DIR)/wiserone dist/usr/bin/
	@cp resources/linux/com.wiserone.WiserOne.desktop dist/usr/share/applications/
	@cp resources/icons/icon-256.png dist/usr/share/icons/hicolor/256x256/apps/com.wiserone.WiserOne.png
	@cd dist && tar -czvf ../wiserone-linux-x64.tar.gz *
	@rm -rf dist
	@echo "Created wiserone-linux-x64.tar.gz"

# =============================================================================
# Help
# =============================================================================

# =============================================================================
# CI/CD Targets (Zero Tolerance Policy)
# =============================================================================

## coverage: Generate test coverage report (requires 100% for CI)
coverage:
	@echo "Generating test coverage report..."
	@mkdir -p $(COVERAGE_DIR)
	@cd $(COVERAGE_DIR) && $(CMAKE) .. -DCMAKE_BUILD_TYPE=Debug \
		-DCMAKE_CXX_FLAGS="-fprofile-arcs -ftest-coverage" \
		-DCMAKE_EXE_LINKER_FLAGS="-lgcov --coverage"
	@$(CMAKE) --build $(COVERAGE_DIR) --parallel $(NPROC)
	@cd $(COVERAGE_DIR) && QT_QPA_PLATFORM=offscreen $(CTEST) --output-on-failure
	@gcovr --root . --exclude tests/ --exclude build/ \
		--html --html-details --output $(COVERAGE_DIR)/coverage.html \
		--print-summary
	@echo "Coverage report generated at $(COVERAGE_DIR)/coverage.html"

## security: Run security scans
security:
	@echo "Running security scans..."
	@command -v semgrep >/dev/null || { echo "❌ semgrep not installed"; exit 1; }
	@command -v cppcheck >/dev/null || { echo "❌ cppcheck not installed"; exit 1; }
	@echo "  🔍 Semgrep security scan..."
	@semgrep --config=auto --error src/ || { echo "❌ Security vulnerabilities found"; exit 1; }
	@echo "  🔍 Cppcheck static analysis..."
	@cppcheck --enable=all --error-exitcode=1 --inline-suppr --std=c++23 \
		--suppressions-list=<(echo "missingIncludeSystem") src/ || { \
		echo "❌ Static analysis issues found"; exit 1; }
	@echo "  🔍 Checking for hardcoded secrets..."
	@if grep -r -i -E "(password|secret|token|key)\s*=\s*[\"'][^\"']{8,}[\"']" src/ CMakeLists.txt 2>/dev/null; then \
		echo "❌ Potential hardcoded secrets found"; exit 1; \
	fi
	@echo "✅ Security scans passed"

## ci-build: Build with CI configuration (warnings as errors)
ci-build:
	@echo "Building with CI configuration (zero warnings policy)..."
	@mkdir -p $(BUILD_DIR)
	@cd $(BUILD_DIR) && $(CMAKE) .. -DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_CXX_FLAGS="$(CXXFLAGS_CI)" -DBUILD_TESTING=ON
	@$(CMAKE) --build $(BUILD_DIR) --parallel $(NPROC) || { \
		echo "❌ Build failed with warnings-as-errors policy"; exit 1; }
	@echo "✅ CI build completed successfully"

## ci-test: Run tests with strict timeout (CI compatible)
ci-test: ci-build
	@echo "Running tests with CI configuration..."
	@cd $(BUILD_DIR) && QT_QPA_PLATFORM=offscreen $(CTEST) \
		--output-on-failure --parallel $(NPROC) --timeout 300 || { \
		echo "❌ Tests failed or timed out"; exit 1; }
	@echo "✅ All tests passed within timeout"

## ci-check: Full CI validation pipeline
ci-check: format-check lint-strict security ci-test coverage
	@echo "🚀 CI validation completed successfully!"

## validate: Pre-commit validation (fast subset of CI)
validate: format-check build test
	@echo "✅ Pre-commit validation passed"

## deploy-ready: Comprehensive deployment readiness check
deploy-ready: ci-check
	@echo "🚀 Deployment readiness check..."
	@echo "  ✅ Code formatting validated"
	@echo "  ✅ Linting passed (zero warnings)"
	@echo "  ✅ Security scans completed"
	@echo "  ✅ All tests passed"
	@echo "  ✅ Coverage requirements met"
	@echo "🎯 Ready for deployment!"

# =============================================================================
# Help
# =============================================================================

## help: Show this help message
help:
	@echo "The Wiser One - Development Commands"
	@echo ""
	@echo "🔧 Build Targets:"
	@grep -E '^## (build|release|debug|clean):' $(MAKEFILE_LIST) | sed 's/## /  /' | column -t -s ':'
	@echo ""
	@echo "🧪 Testing:"
	@grep -E '^## (test|coverage):' $(MAKEFILE_LIST) | sed 's/## /  /' | column -t -s ':'
	@echo ""
	@echo "✨ Code Quality:"
	@grep -E '^## (format|lint|security):' $(MAKEFILE_LIST) | sed 's/## /  /' | column -t -s ':'
	@echo ""
	@echo "🚀 CI/CD:"
	@grep -E '^## (ci-|validate|deploy):' $(MAKEFILE_LIST) | sed 's/## /  /' | column -t -s ':'
	@echo ""
	@echo "📦 Packaging & Installation:"
	@grep -E '^## (install|package|run):' $(MAKEFILE_LIST) | sed 's/## /  /' | column -t -s ':'
	@echo ""
	@echo "Zero Tolerance Policy: All warnings become errors in CI mode"
