#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../pin-merge-commit.sh"
  WORK="$(mktemp -d)"
  unset MERGE_SHA

  # A repository with three commits on its default branch, run from inside it.
  git init -q "$WORK/repo"
  cd "$WORK/repo"
  git config user.email test@example.com
  git config user.name test
  git config commit.gpgsign false
  for n in 1 2 3; do
    git commit -q --allow-empty -m "commit $n"
  done
  MAIN="$(git branch --show-current)"
  TIP="$(git rev-parse HEAD)"
  MIDDLE="$(git rev-parse HEAD~1)"
}

teardown() {
  rm -rf "$WORK"
}

@test "detaches at an ancestor commit" {
  MERGE_SHA="$MIDDLE" run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Pinned to merge commit $MIDDLE"* ]]
  [ "$(git rev-parse HEAD)" = "$MIDDLE" ]
  [ -z "$(git branch --show-current)" ]
}

@test "the commit at HEAD works" {
  MERGE_SHA="$TIP" run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(git rev-parse HEAD)" = "$TIP" ]
}

@test "SHA comes from the argument" {
  run "$SCRIPT" "$MIDDLE"
  [ "$status" -eq 0 ]
  [ "$(git rev-parse HEAD)" = "$MIDDLE" ]
}

@test "a commit not on the branch fails and leaves HEAD alone" {
  git checkout -q --orphan other
  git commit -q --allow-empty -m "elsewhere"
  other="$(git rev-parse HEAD)"
  git checkout -q "$MAIN"
  MERGE_SHA="$other" run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not on the checked-out branch"* ]]
  [ "$(git rev-parse HEAD)" = "$TIP" ]
  [ "$(git branch --show-current)" = "$MAIN" ]
}

@test "a later commit than HEAD fails" {
  git checkout -q -b ahead
  git commit -q --allow-empty -m "ahead"
  ahead="$(git rev-parse HEAD)"
  git checkout -q "$MAIN"
  MERGE_SHA="$ahead" run "$SCRIPT"
  [ "$status" -eq 1 ]
  [ "$(git rev-parse HEAD)" = "$TIP" ]
}

@test "an unknown commit fails" {
  MERGE_SHA="0123456789abcdef0123456789abcdef01234567" run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not on the checked-out branch"* ]]
  [ "$(git rev-parse HEAD)" = "$TIP" ]
}

@test "malformed SHA fails without touching git" {
  # Stub git so any call is logged and fails.
  mkdir "$WORK/bin"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s"\nexit 1\n' "$WORK/git.log" > "$WORK/bin/git"
  chmod +x "$WORK/bin/git"
  for bad in "${MIDDLE:0:7}" "${MIDDLE^^}" "$MIDDLE " "HEAD" "-$MIDDLE"; do
    PATH="$WORK/bin:$PATH" MERGE_SHA="$bad" run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not a full commit SHA"* ]]
  done
  [ ! -e "$WORK/git.log" ]
  [ "$(git rev-parse HEAD)" = "$TIP" ]
}

@test "missing MERGE_SHA is a usage error" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
  [ "$(git rev-parse HEAD)" = "$TIP" ]
}

@test "shallow clone fails closed" {
  git clone -q --depth 1 "file://$WORK/repo" "$WORK/shallow"
  cd "$WORK/shallow"
  MERGE_SHA="$TIP" run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"fetch-depth: 0"* ]]
  [ "$(git rev-parse HEAD)" = "$TIP" ]
}
