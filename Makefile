PLATFORM_IOS = iOS Simulator,name=iPad mini (A17 Pro)
PLATFORM_MACOS = macOS
PLATFORM_TVOS = tvOS Simulator,name=Apple TV 4K (3rd generation) (at 1080p)
SCHEME = MathParser
DOCC_DIR = ./docs
QUIET = -quiet
WORKSPACE = $(PWD)/$(SCHEME).workspace
SKIPS = -skipMacroValidation -skipPackagePluginValidation
BUILD_FLAGS = $(SKIPS) -scheme $(SCHEME) $(QUIET) -clonedSourcePackagesDirPath "$(WORKSPACE)"

default: test-ios

test-ios: lint
	xcodebuild test \
		$(BUILD_FLAGS) \
		-derivedDataPath "$(PWD)/.DerivedData-ios" \
		-destination platform="$(PLATFORM_IOS)"

test-tvos:
	xcodebuild test \
		$(BUILD_FLAGS) \
		-derivedDataPath "$(PWD)/.DerivedData-tvos" \
		-destination platform="$(PLATFORM_TVOS)"

test-macos:
	xcodebuild test \
		$(BUILD_FLAGS) \
		-derivedDataPath "$(PWD)/.DerivedData-macos" \
		-destination platform="$(PLATFORM_MACOS)" \
		-enableCodeCoverage YES

test-linux: lint
	docker build -t swiftlang -f swiftlang.dockerfile .
	docker run \
		--rm \
		-v "$(PWD):$(PWD)" \
		-w "$(PWD)" \
		swift57 \
		bash -c 'make test-swift'

test-swift: lint
	swift test --parallel

coverage: test-macos
	xcrun xccov view --report --only-targets $(PWD)/.DerivedData-macos/Logs/Test/*.xcresult > coverage.txt
	cat coverage.txt

percentage: coverage
	awk '/ $(SCHEME) / { if ($$3 > 0) print $$4; }' coverage.txt > percentage.txt
	cat percentage.txt

docc:
	DOCC_JSON_PRETTYPRINT="YES" \
	swift package \
		--allow-writing-to-directory $(DOCC_DIR) \
		generate-documentation \
		--target $(SCHEME) \
		--disable-indexing \
		--transform-for-static-hosting \
		--hosting-base-path swift-math-parser \
		--output-path $(DOCC_DIR)

lint: clean
	@if command -v swiftlint; then swiftlint; fi

clean:
	rm -rf "$(PWD)/.DerivedData-macos" "$(PWD)/.DerivedData-ios" "$(PWD)/.DerivedData-tvos" "$(WORKSPACE)"

.PHONY: test test-ios test-macos test-tvos coverage percentage test-linux test-swift
