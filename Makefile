PLATFORM_IOS = iOS Simulator,name=iPhone 14 Pro
PLATFORM_MACOS = macOS
PLATFORM_TVOS = tvOS Simulator,name=Apple TV 4K (3rd generation) (at 1080p)
TARGET = MathParser
DOCC_DIR = ./docs

default: percentage

clean:
	rm -rf "$(PWD)/DerivedData*"

docc:
	DOCC_JSON_PRETTYPRINT="YES" \
	swift package \
		--allow-writing-to-directory $(DOCC_DIR) \
		generate-documentation \
		--target $(TARGET) \
		--disable-indexing \
		--transform-for-static-hosting \
		--hosting-base-path swift-math-parser \
		--output-path $(DOCC_DIR)

lint: clean
	@if command -v swiftlint; then swiftlint; fi

test-ios: lint
	xcodebuild test \
		-scheme $(TARGET) \
		-destination platform="$(PLATFORM_IOS)"

test-tvos: lint
	xcodebuild test \
		-scheme $(TARGET) \
		-destination platform="$(PLATFORM_TVOS)"

test-macos: lint
	xcodebuild build \
		-scheme $(TARGET) \
		-derivedDataPath "$(PWD)/DerivedData-macos" \
		-destination platform="$(PLATFORM_MACOS)"
	xcodebuild test \
		-scheme $(TARGET) \
		-derivedDataPath "$(PWD)/DerivedData-macos" \
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
	swift test --enable-test-discovery --parallel

coverage: test-macos
	xcrun xccov view --report --only-targets $(PWD)/DerivedData-macos/Logs/Test/*.xcresult > coverage.txt
	cat coverage.txt

percentage: coverage
	awk '/ $(TARGET) / { if ($$3 > 0) print $$4; }' coverage.txt > percentage.txt
	cat percentage.txt

test: test-ios test-tvos percentage

.PHONY: test test-ios test-macos test-tvos coverage percentage test-linux test-swift
