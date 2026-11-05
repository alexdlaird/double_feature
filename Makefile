.PHONY: all install clean test coverage check

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
