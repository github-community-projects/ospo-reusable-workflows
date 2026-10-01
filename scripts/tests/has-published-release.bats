#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../has-published-release.sh"
  WORK="$(mktemp -d)"
  mkdir "$WORK/bin"
  # Stub gh: log the arguments, print GH_STDOUT (what gh prints after --jq),
  # and exit with GH_EXIT.
  cat > "$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
printf '%s' "${GH_STDOUT:-}"
exit "${GH_EXIT:-0}"
EOF
  chmod +x "$WORK/bin/gh"
  export PATH="$WORK/bin:$PATH"
  export GH_LOG="$WORK/gh.log"
  export GITHUB_OUTPUT="$WORK/output"
  unset GITHUB_REPOSITORY GH_STDOUT GH_EXIT
}

teardown() {
  rm -rf "$WORK"
}

@test "no releases" {
  run "$SCRIPT" owner/repo
  [ "$status" -eq 0 ]
  [ "$output" = "published=false" ]
  grep -qx 'published=false' "$GITHUB_OUTPUT"
}

@test "a published release exists" {
  GH_STDOUT=$'123\n' run "$SCRIPT" owner/repo
  [ "$status" -eq 0 ]
  [ "$output" = "published=true" ]
  grep -qx 'published=true' "$GITHUB_OUTPUT"
}

@test "published releases across pages" {
  GH_STDOUT=$'1\n2\n3\n' run "$SCRIPT" owner/repo
  [ "$status" -eq 0 ]
  [ "$output" = "published=true" ]
}

@test "queries the releases list with pagination and a draft filter" {
  run "$SCRIPT" owner/repo
  [ "$status" -eq 0 ]
  grep -q 'api repos/owner/repo/releases?per_page=100 --paginate --jq .\[\] | select(.draft == false) | .id' "$GH_LOG"
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

@test "no repository" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
  [ ! -e "$GH_LOG" ]
}
