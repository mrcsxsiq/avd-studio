.DEFAULT_GOAL := help
SHELL := /bin/bash

GRADLE  := ./gradlew
DERIVED := build/xcode
APP     := $(DERIVED)/Build/Products/Release/AVD Studio.app
SWIFT_SOURCES := macos/Sources macos/Tests macos/App macos/Package.swift scripts/generate-icon.swift

.PHONY: help bootstrap core generate app run install cli test test-kotlin test-swift test-unit \
        record-snapshots lint format icon clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make <target>\n\n"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

bootstrap: ## Install the developer tools from the Brewfile
	brew bundle

core: ## Build the Kotlin core and install the XCFramework into macos/Frameworks
	$(GRADLE) :core:installXCFramework

generate: core ## Generate macos/AVDStudio.xcodeproj
	./scripts/generate-project.sh

app: generate ## Build the app (Release, Apple Silicon)
	xcodebuild -project macos/AVDStudio.xcodeproj -scheme AVDStudio -configuration Release \
		-destination 'platform=macOS,arch=arm64' -derivedDataPath $(DERIVED) build

run: app ## Build and open the app
	open "$(APP)"

install: app ## Build and copy the app to /Applications
	ditto "$(APP)" "/Applications/AVD Studio.app"

cli: ## Build the release command-line tool (cli/build/bin/macosArm64/releaseExecutable)
	$(GRADLE) :cli:linkReleaseExecutableMacosArm64

test-kotlin: ## Kotlin unit tests (core + CLI)
	$(GRADLE) :core:macosArm64Test :cli:macosArm64Test

test-swift: core ## Swift unit, bridge and screenshot tests
	cd macos && swift test

test-unit: core ## Swift tests without the screenshot tests (what CI treats as blocking)
	cd macos && swift test --skip AVDStudioSnapshotTests

test: test-kotlin test-swift ## Everything

record-snapshots: core ## Re-record the screenshot references after an intentional UI change
	cd macos && SNAPSHOT_RECORD=1 swift test --filter AVDStudioSnapshotTests || true
	cd macos && swift test --filter AVDStudioSnapshotTests

lint: ## ktlint and swift format (no changes)
	$(GRADLE) ktlintCheck
	swift format lint --strict --recursive $(SWIFT_SOURCES)

format: ## Fix formatting in place
	$(GRADLE) ktlintFormat
	swift format format --in-place --recursive $(SWIFT_SOURCES)

icon: ## Re-render the app icon
	swift scripts/generate-icon.swift

clean: ## Remove build output
	$(GRADLE) clean
	rm -rf build macos/.build macos/Frameworks macos/AVDStudio.xcodeproj
