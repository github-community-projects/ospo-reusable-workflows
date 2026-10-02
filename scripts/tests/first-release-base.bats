#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../first-release-base.sh"
  WORK="$(mktemp -d)"
  mkdir "$WORK/bin"
  # Stub gh: log the arguments, print GH_STDOUT (what gh prints after --jq),
  # and exit with GH_EXIT.
  cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
printf '%s' "${GH_STDOUT:-}"
exit "${GH_EXIT:-0}"
STUB
  chmod +x "$WORK/bin/gh"
  export PATH="$WORK/bin:$PATH"
  export GH_LOG="$WORK/gh.log"
  export GITHUB_OUTPUT="$WORK/output"
  unset GITHUB_REPOSITORY GH_STDOUT GH_EXIT

  # A repository with three commits, run from inside it.
  git init -q "$WORK/repo"
  cd "$WORK/repo"
  git config user.email test@example.com
  git config user.name test
  git config commit.gpgsign false
  for n in 1 2 3; do
    git commit -q --allow-empty -m "commit $n"
  done
  ROOT="$(git rev-list --max-parents=0 HEAD)"
}

teardown() {
  rm -rf "$WORK"
}

@test "no published release prints the root commit" {
  run "$SCRIPT" owner/repo
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "from=$ROOT" ]
  grep -qx "from=$ROOT" "$GITHUB_OUTPUT"
}

@test "a published release prints an empty from" {
  GH_STDOUT=$'123\n' run "$SCRIPT" owner/repo
  [ "$status" -eq 0 ]
  [ "$output" = "from=" ]
  grep -qx 'from=' "$GITHUB_OUTPUT"
}

@test "published releases across pages" {
  GH_STDOUT=$'1\n2\n3\n' run "$SCRIPT" owner/repo
  [ "$status" -eq 0 ]
  [ "$output" = "from=" ]
}

@test "queries the releases list with pagination and a draft filter" {
  run "$SCRIPT" owner/repo
  [ "$status" -eq 0 ]
  grep -q 'api repos/owner/repo/releases?per_page=100 --paginate --jq .\[\] | select(.draft == false) | .id' "$GH_LOG"
}

@test "several roots use the oldest" {
  main="$(git branch --show-current)"
  git checkout -q --orphan other
  GIT_COMMITTER_DATE="2001-01-01T00:00:00Z" GIT_AUTHOR_DATE="2001-01-01T00:00:00Z" \
    git commit -q --allow-empty -m "old root"
  old="$(git rev-parse HEAD)"
  git checkout -q "$main"
  git merge -q --allow-unrelated-histories --no-edit other
  run "$SCRIPT" owner/repo
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "from=$old" ]
}

@test "shallow clone fails closed" {
  git clone -q --depth 1 "file://$WORK/repo" "$WORK/shallow"
  cd "$WORK/shallow"
  run "$SCRIPT" owner/repo
  [ "$status" -eq 1 ]
  [[ "$output" == *"fetch-depth: 0"* ]]
  [ ! -s "$GITHUB_OUTPUT" ]
}

@test "shallow clone is fine when a release exists" {
  git clone -q --depth 1 "file://$WORK/repo" "$WORK/shallow"
  cd "$WORK/shallow"
  GH_STDOUT=$'1\n' run "$SCRIPT" owner/repo
  [ "$status" -eq 0 ]
  [ "$output" = "from=" ]
}

@test "API error fails closed" {
  GH_EXIT=1 run "$SCRIPT" owner/repo
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not list releases"* ]]
  [ ! -s "$GITHUB_OUTPUT" ]
}

@test "repository comes from the environment" {
  GITHUB_REPOSITORY=env/repo run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q 'repos/env/repo/releases' "$GH_LOG"
}

@test "missing repository is a usage error" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
  [ ! -s "$GH_LOG" ]
}

@test "works without GITHUB_OUTPUT" {
  unset GITHUB_OUTPUT
  GH_STDOUT=$'1\n' run "$SCRIPT" owner/repo
  [ "$status" -eq 0 ]
  [ "$output" = "from=" ]
}
