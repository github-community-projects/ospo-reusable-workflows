#!/usr/bin/env bash
# Resolve a release version from a file in the repository.
#
# Usage: resolve-version.sh <version-file> [version-key]
#
#   version-file  Path to the file holding the version, relative to the
#                 repository root.
#   version-key   yq expression selecting the version inside a JSON, YAML, or
#                 TOML file (for example .version). Omit for a plain-text file
#                 whose first line is the version.
#
# Arguments may also be passed as VERSION_FILE and VERSION_KEY environment
# variables, which is how the release workflows invoke the inline copy.
#
# Prints the bare semver (no leading v) on stdout, and writes version=<semver>
# to GITHUB_OUTPUT when that variable is set. Exits non-zero with a ::error::
# annotation on stderr when the file or key is missing, or when the value is
# not a valid semver. Build metadata (1.2.3+build) is rejected because
# release-drafter's version template drops it and Docker image tags cannot
# contain a plus sign.
set -euo pipefail

file="${1:-${VERSION_FILE:-}}"
key="${2:-${VERSION_KEY:-}}"

if [ -z "$file" ]; then
  echo "::error::usage: resolve-version.sh <version-file> [version-key]" >&2
  exit 1
fi

if [ ! -f "$file" ]; then
  echo "::error::version-file '$file' not found in the repository" >&2
  exit 1
fi

if [ -n "$key" ]; then
  if ! command -v yq >/dev/null 2>&1; then
    echo "::error::yq is required to read '$key' from '$file' but is not on PATH" >&2
    exit 1
  fi
  case "$file" in
    *.toml) raw=$(yq -p toml -o yaml "$key" "$file") ;;
    *) raw=$(yq -o yaml "$key" "$file") ;;
  esac
else
  raw=$(head -n 1 "$file")
fi

# Trim leading and trailing whitespace only, so internal whitespace still
# fails validation below.
raw="${raw#"${raw%%[![:space:]]*}"}"
raw="${raw%"${raw##*[![:space:]]}"}"

if [ -z "$raw" ] || [ "$raw" = "null" ]; then
  echo "::error::no version found at '${key:-first line}' in '$file'" >&2
  exit 1
fi

# Tolerate a leading v; the tag-template in the release-drafter config adds
# the prefix.
version="${raw#v}"

if [[ "$version" == *+* ]]; then
  echo "::error::version '$version' from '$file' contains build metadata, which is not supported (use MAJOR.MINOR.PATCH or MAJOR.MINOR.PATCH-PRERELEASE)" >&2
  exit 1
fi

# semver.org grammar without build metadata. Numeric identifiers cannot have
# leading zeros; prerelease identifiers are dot-separated and non-empty.
num='(0|[1-9][0-9]*)'
ident='(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)'
semver="^${num}\\.${num}\\.${num}(-${ident}(\\.${ident})*)?$"

if ! [[ "$version" =~ $semver ]]; then
  echo "::error::version '$version' from '$file' is not a valid semver (expected MAJOR.MINOR.PATCH or MAJOR.MINOR.PATCH-PRERELEASE)" >&2
  exit 1
fi

printf '%s\n' "$version"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "version=$version" >> "$GITHUB_OUTPUT"
fi
