PLATFORM_IOS = iOS Simulator,name=iPhone 11 Pro
PLATFORM_MACOS = macOS
PLATFORM_TVOS = tvOS Simulator,name=Apple TV 4K (at 1080p)

default: test

test:
	xcodebuild test \
		-scheme MathParser \
		-destination platform="$(PLATFORM_IOS)"
	xcodebuild test \
		-scheme MathParser \
		-destination platform="$(PLATFORM_MACOS)"
	xcodebuild test \
		-scheme MathParser \
		-destination platform="$(PLATFORM_TVOS)"

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

.PHONY: test test-linux test-swift
