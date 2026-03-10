PLATFORM_IOS = iOS Simulator,name=iPad mini (A17 Pro)
PLATFORM_MACOS = macOS
SCHEME = MathParser
DOCC_DIR = ./docs
QUIET = -quiet
WORKSPACE = $(PWD)/$(SCHEME).workspace
SKIPS = -skipMacroValidation -skipPackagePluginValidation
BUILD_FLAGS = $(SKIPS) -scheme $(SCHEME) $(QUIET) -clonedSourcePackagesDirPath "$(WORKSPACE)"
XCCOV = xcrun xccov view --report --only-targets

default: report

test-ios: lint
	rm -rf "${PWD}/.DerivedData-iOS"
	xcodebuild test \
		$(BUILD_FLAGS) \
		-derivedDataPath "$(PWD)/.DerivedData-ios" \
		-destination platform="$(PLATFORM_IOS)" \
		-enableCodeCoverage YES

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

coverage-macos: test-macos
	$(XCCOV) "$(PWD)/.DerivedData-macos/Logs/Test/Test-MathParser-"*.xcresult > coverage_macOS.txt
	echo "macOS Coverage:"
	cat coverage_macOS.txt

percentage-macos: coverage-macos
	awk '/ $(SCHEME) / { if ($$3 > 0) print $$4; }' coverage_macOS.txt > percentage_macOS.txt
	cat percentage_macOS.txt

report: percentage-macos
	@if [[ -n "$$GITHUB_ENV" ]]; then \
		echo "PERCENTAGE=$$(< percentage_macOS.txt)" >> $$GITHUB_ENV; \
	fi

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
