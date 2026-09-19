#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../resolve-version.sh"
  REPO="$(mktemp -d)"
  cd "$REPO"
}

teardown() {
  rm -rf "$REPO"
}

@test "plain text file" {
  printf '1.2.3\n' > VERSION
  run "$SCRIPT" VERSION
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3" ]
}

@test "plain text with surrounding whitespace and leading v" {
  printf '  v2.0.0 \n' > VERSION
  run "$SCRIPT" VERSION
  [ "$status" -eq 0 ]
  [ "$output" = "2.0.0" ]
}

@test "plain text only reads the first line" {
  printf '3.4.5\nextra\n' > VERSION
  run "$SCRIPT" VERSION
  [ "$status" -eq 0 ]
  [ "$output" = "3.4.5" ]
}

@test "json with key" {
  printf '{"name":"x","version":"1.2.3"}\n' > package.json
  run "$SCRIPT" package.json .version
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3" ]
}

@test "json without trailing newline" {
  printf '{"version":"1.2.3"}' > plugin.json
  run "$SCRIPT" plugin.json .version
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3" ]
}

@test "yaml with key" {
  printf 'apiVersion: v2\nversion: 4.5.6\n' > Chart.yaml
  run "$SCRIPT" Chart.yaml .version
  [ "$status" -eq 0 ]
  [ "$output" = "4.5.6" ]
}

@test "toml with nested key" {
  printf '[project]\nname = "x"\nversion = "7.8.9"\n' > pyproject.toml
  run "$SCRIPT" pyproject.toml .project.version
  [ "$status" -eq 0 ]
  [ "$output" = "7.8.9" ]
}

@test "prerelease is accepted" {
  printf '{"version":"1.2.3-rc.1"}\n' > v.json
  run "$SCRIPT" v.json .version
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3-rc.1" ]
}

@test "build metadata is rejected" {
  printf '{"version":"1.2.3+build.5"}\n' > v.json
  run "$SCRIPT" v.json .version
  [ "$status" -eq 1 ]
  [[ "$output" == *"build metadata"* ]]
}

@test "missing file" {
  run "$SCRIPT" nope.json .version
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "missing key" {
  printf '{"version":"1.2.3"}\n' > v.json
  run "$SCRIPT" v.json .nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"no version found"* ]]
}

@test "empty file" {
  : > VERSION
  run "$SCRIPT" VERSION
  [ "$status" -eq 1 ]
  [[ "$output" == *"no version found"* ]]
}

@test "no arguments" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}

@test "non-semver value" {
  printf '{"version":"banana"}\n' > v.json
  run "$SCRIPT" v.json .version
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a valid semver"* ]]
}

@test "internal whitespace is rejected" {
  printf '1.2 .3\n' > VERSION
  run "$SCRIPT" VERSION
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a valid semver"* ]]
}

@test "leading zeros are rejected" {
  printf '01.2.3\n' > VERSION
  run "$SCRIPT" VERSION
  [ "$status" -eq 1 ]
}

@test "numeric prerelease with leading zero is rejected" {
  printf '1.2.3-01\n' > VERSION
  run "$SCRIPT" VERSION
  [ "$status" -eq 1 ]
}

@test "empty prerelease identifier is rejected" {
  printf '1.2.3-alpha..1\n' > VERSION
  run "$SCRIPT" VERSION
  [ "$status" -eq 1 ]
}

@test "two-part version is rejected" {
  printf '1.2\n' > VERSION
  run "$SCRIPT" VERSION
  [ "$status" -eq 1 ]
}

@test "missing yq fails clearly when a key is given" {
  printf '{"version":"1.2.3"}\n' > v.json
  # PATH with bash only, so yq cannot be found.
  bin="$(mktemp -d)"
  ln -s "$(command -v bash)" "$bin/bash"
  PATH="$bin" run "$SCRIPT" v.json .version
  [ "$status" -eq 1 ]
  [[ "$output" == *"yq is required"* ]]
}

@test "arguments can come from the environment" {
  printf '{"version":"1.2.3"}\n' > v.json
  VERSION_FILE=v.json VERSION_KEY=.version run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3" ]
}

@test "writes version to GITHUB_OUTPUT when set" {
  printf '1.2.3\n' > VERSION
  out="$(mktemp)"
  GITHUB_OUTPUT="$out" run "$SCRIPT" VERSION
  [ "$status" -eq 0 ]
  [ "$(cat "$out")" = "version=1.2.3" ]
}
