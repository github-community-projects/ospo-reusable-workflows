#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../strip-baseline-warning.sh"
  WORK="$(mktemp -d)"
  mkdir "$WORK/bin"
  # Stub gh: log the arguments. A GET prints $GH_RELEASE; a PATCH saves its
  # --input file to $WORK/patched.json. GH_GET_EXIT and GH_PATCH_EXIT set the
  # exit codes.
  cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
if [ "$3" = "PATCH" ]; then
  cp "$6" "$WORK/patched.json"
  exit "${GH_PATCH_EXIT:-0}"
fi
cat "$GH_RELEASE"
exit "${GH_GET_EXIT:-0}"
STUB
  chmod +x "$WORK/bin/gh"
  export PATH="$WORK/bin:$PATH" WORK
  export GH_LOG="$WORK/gh.log"
  export GH_RELEASE="$WORK/release.json"
  export GITHUB_OUTPUT="$WORK/output"
  export GITHUB_REPOSITORY=owner/repo FROM=abc123 RELEASE_ID=42
  unset GH_GET_EXIT GH_PATCH_EXIT

  notes=$'# Changelog\n## Features\n\n- feat: add widget @someone (#1)\n'
  warning=$'\n---\n> [!WARNING]\n> Release Drafter could not find a previous **published release** for `owner/repo`. This draft was created **without a comparison baseline**.\n\n> [!IMPORTANT]\n> Treat this draft as a manual starting point.\n\nIf you did not expect this to happen, [open an issue](https://example.com).\n---\n'
  jq -n --arg body "$notes$warning" '{body: $body}' > "$GH_RELEASE"
  NOTES="$notes"
}

teardown() {
  rm -rf "$WORK"
}

@test "removes the warning and keeps the notes" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed the missing-baseline warning from release 42"* ]]
  [ "$(jq -r '.body' "$WORK/patched.json")" = "${NOTES%$'\n'}" ]
  grep -q 'api --method PATCH repos/owner/repo/releases/42' "$GH_LOG"
}

@test "keeps a footer after the warning" {
  jq '.body += "Footer text\n"' "$GH_RELEASE" > "$WORK/r.json" && mv "$WORK/r.json" "$GH_RELEASE"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  jq -r '.body' "$WORK/patched.json" | grep -qx 'Footer text'
  ! jq -r '.body' "$WORK/patched.json" | grep -q 'WARNING'
}

@test "writes the new body to GITHUB_OUTPUT" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q '^body<<body_' "$GITHUB_OUTPUT"
  grep -q 'feat: add widget' "$GITHUB_OUTPUT"
  ! grep -q 'WARNING' "$GITHUB_OUTPUT"
}

@test "not a first release makes no API calls" {
  FROM="" run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Not a first release"* ]]
  [ ! -e "$GH_LOG" ]
  [ ! -s "$GITHUB_OUTPUT" ]
}

@test "body without the warning is left alone" {
  jq -n --arg body "$NOTES" '{body: $body}' > "$GH_RELEASE"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No missing-baseline warning"* ]]
  ! grep -q PATCH "$GH_LOG"
  [ ! -s "$GITHUB_OUTPUT" ]
}

@test "other warnings are left alone" {
  jq -n '{body: "notes\n\n---\n> [!WARNING]\n> Something else entirely.\n---\n"}' > "$GH_RELEASE"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  ! grep -q PATCH "$GH_LOG"
}

@test "null body is left alone" {
  echo '{"body": null}' > "$GH_RELEASE"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  ! grep -q PATCH "$GH_LOG"
}

@test "read error fails closed" {
  GH_GET_EXIT=1 run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not read release 42"* ]]
}

@test "update error fails closed" {
  GH_PATCH_EXIT=1 run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not update the body of release 42"* ]]
  [ ! -s "$GITHUB_OUTPUT" ]
}

@test "non-numeric release id is rejected" {
  RELEASE_ID=abc run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"RELEASE_ID must be a numeric"* ]]
  [ ! -e "$GH_LOG" ]
}

@test "missing repository is rejected" {
  GITHUB_REPOSITORY="" run "$SCRIPT"
  [ "$status" -eq 1 ]
  [ ! -e "$GH_LOG" ]
}
