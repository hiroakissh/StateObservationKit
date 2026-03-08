SHELL := /bin/zsh
.SHELLFLAGS := -l -c

XCODE_SCHEME ?= StateObservationKit
XCODE_DESTINATION_ARCH ?= $(shell uname -m)
XCODE_DESTINATION ?= platform=macOS,arch=$(XCODE_DESTINATION_ARCH)

.PHONY: ci test-spm test-xcode test-release-governance format format-check format-check-changed build-examples docs

test-spm:
	./scripts/test_spm.sh

test-xcode:
	xcodebuild -scheme "$(XCODE_SCHEME)" -destination "$(XCODE_DESTINATION)" build
	xcodebuild -scheme "$(XCODE_SCHEME)" -destination "$(XCODE_DESTINATION)" test

test-release-governance:
	./scripts/test_release_version.sh

format:
	./scripts/format.sh format

format-check:
	./scripts/format.sh check

format-check-changed:
	./scripts/format.sh check-changed "$(BASE_REF)" "$(HEAD_REF)"

build-examples:
	./scripts/build_examples.sh

docs:
	./scripts/docs_build.sh

ci: test-spm test-xcode build-examples
