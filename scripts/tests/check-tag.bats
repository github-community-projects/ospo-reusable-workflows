#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../check-tag.sh"
  WORK="$(mktemp -d)"
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
  # Ignore the developer's global config (signing, tag defaults).
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

  git init -q "$WORK/remote"
  git -C "$WORK/remote" commit -q --allow-empty -m first
  git -C "$WORK/remote" commit -q --allow-empty -m second

  git clone -q "$WORK/remote" "$WORK/local"
  cd "$WORK/local"
  FIRST=$(git rev-parse HEAD~1)
  HEAD_SHA=$(git rev-parse HEAD)
}

teardown() {
  rm -rf "$WORK"
}

@test "tag absent on remote" {
  run "$SCRIPT" v1.0.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "tag exists and points at HEAD" {
  git -C "$WORK/remote" tag v1.0.0 "$HEAD_SHA"
  run "$SCRIPT" v1.0.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"already points at HEAD"* ]]
}

@test "annotated tag pointing at HEAD is compared by commit" {
  git -C "$WORK/remote" tag -a v1.0.0 -m release "$HEAD_SHA"
  run "$SCRIPT" v1.0.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"already points at HEAD"* ]]
}

@test "tag exists and points elsewhere" {
  git -C "$WORK/remote" tag v1.0.0 "$FIRST"
  run "$SCRIPT" v1.0.0
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}

@test "custom tag template prefix is checked as given" {
  git -C "$WORK/remote" tag release-1.0.0 "$FIRST"
  run "$SCRIPT" release-1.0.0
  [ "$status" -eq 1 ]
  run "$SCRIPT" v1.0.0
  [ "$status" -eq 0 ]
}

@test "similar tag names do not match" {
  git -C "$WORK/remote" tag v1.0.0-rc.1 "$FIRST"
  run "$SCRIPT" v1.0.0
  [ "$status" -eq 0 ]
}

@test "remote error fails closed" {
  run "$SCRIPT" v1.0.0 "$WORK/does-not-exist"
  [ "$status" -eq 1 ]
  [[ "$output" == *"git ls-remote failed"* ]]
}

@test "no arguments" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}

@test "arguments can come from the environment" {
  git -C "$WORK/remote" tag v1.0.0 "$FIRST"
  TAG=v1.0.0 REMOTE=origin run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}
