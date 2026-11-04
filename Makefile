.PHONY: all install clean test coverage check validate-release

SHELL := /usr/bin/env bash

all: test check

install:
	flutter pub get

clean:
	flutter clean

test: install
	flutter analyze --no-pub
	flutter test --no-pub

coverage: install
	flutter test --no-pub --coverage

check: install
	flutter pub publish --dry-run

validate-release:
	@if [[ "${VERSION}" == "" ]]; then echo "VERSION is not set" & exit 1 ; fi

	@if [[ $$(grep "^version: ${VERSION}$$" pubspec.yaml) == "" ]] ; then echo "Version not bumped in pubspec.yaml" & exit 1 ; fi

	@if [[ $$(grep "^## \[${VERSION}\]" CHANGELOG.md) == "" ]] ; then echo "CHANGELOG.md missing an entry for ${VERSION}" & exit 1 ; fi
