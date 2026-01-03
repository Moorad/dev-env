#!/usr/bin/env bash

if ! brew bundle check --verbose --no-upgrade; then
	brew bundle install --no-upgrade
fi