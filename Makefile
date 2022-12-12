PLATFORM_IOS = iOS Simulator,name=iPhone 11 Pro
PLATFORM_MACOS = macOS
PLATFORM_TVOS = tvOS Simulator,name=Apple TV 4K (at 1080p)

default: percentage

test-ios:
	rm -rf "$(PWD)/DerivedData-iOS"
	xcodebuild test \
		-scheme MathParser \
		-destination platform="$(PLATFORM_IOS)"

test-macos:
	rm -rf "$(PWD)/DerivedData-macOS"
	xcodebuild test \
		-scheme MathParser \
		-destination platform="$(PLATFORM_MACOS)" \
		-enableCodeCoverage YES \
		-xcconfig command-line.xcconfig \
		-derivedDataPath "$(PWD)/DerivedData-macOS"

test-tvos:
	rm -rf "$(PWD)/DerivedData-tvOS"
	xcodebuild test \
		-scheme MathParser \
		-destination platform="$(PLATFORM_TVOS)"

coverage: test-macos
	xcrun xccov view --report --only-targets $(PWD)/DerivedData-macOS/Logs/Test/*.xcresult > coverage.txt

percentage: coverage
	awk '/ MathParser / { print $$4; }' coverage.txt > percentage.txt

test-linux:
	docker build -t swiftlang -f swiftlang.dockerfile .
	docker run \
		--rm \
		-v "$(PWD):$(PWD)" \
		-w "$(PWD)" \
		swift57 \
		bash -c 'make test-swift'

test-swift:
	swift test --parallel

.PHONY: test-ios test-macos test-tvos coverage percentage test-linux test-swift
