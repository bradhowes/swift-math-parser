FROM swiftlang/swift:nightly-focal
RUN apt-get update && apt-get install -y --no-install-recommends make
