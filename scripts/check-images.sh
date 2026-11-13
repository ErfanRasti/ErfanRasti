#!/usr/bin/env bash
# Check that every image referenced in README.md (src= and srcset=) resolves.
#   - local paths must exist and contain an <svg> (or be a non-empty file)
#   - remote URLs must return HTTP 200 with an image/* content type
# Usage: ./scripts/check-images.sh [README.md]
set -uo pipefail

readme="${1:-README.md}"
root="$(cd "$(dirname "$readme")" && pwd)"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

red=$'\e[31m' green=$'\e[32m' reset=$'\e[0m'
fail=0 total=0

mapfile -t refs < <(grep -oE '(src|srcset)="?[^" >]+' "$readme" | sed -E 's/^(src|srcset)="?//' | sort -u)

for ref in "${refs[@]}"; do
  total=$((total + 1))
  if [[ $ref == http* ]]; then
    result=$(curl -sL -m 30 -o "$tmp" -w '%{http_code} %{content_type}' "$ref")
    code=${result%% *} type=${result#* }
    if [[ $code == 200 && $type == image/* ]]; then
      echo "${green}OK  ${reset} $ref"
    else
      echo "${red}FAIL${reset} [$code $type] $ref"
      fail=$((fail + 1))
    fi
  else
    file="$root/${ref#./}"
    if [[ -s $file ]] && { [[ $file != *.svg ]] || head -c 500 "$file" | grep -q '<svg'; }; then
      echo "${green}OK  ${reset} $ref"
    else
      echo "${red}FAIL${reset} [missing or invalid] $ref"
      fail=$((fail + 1))
    fi
  fi
done

echo
echo "$((total - fail))/$total images OK"
[[ $fail -eq 0 ]]
