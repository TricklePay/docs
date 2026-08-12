#!/usr/bin/env bash
#
# Fail if any relative link in the repository's markdown files points at a file
# or heading that does not exist. External links (http, https, mailto) are not
# checked: they are outside this repository, and checking them would make the
# build depend on the network and on other people's uptime.
set -euo pipefail

cd "$(dirname "$0")/.."

status=0

# The anchor GitHub generates for a heading: lowercase, drop anything that is
# not a letter, digit, space or hyphen, then spaces become hyphens.
slug() {
  printf '%s\n' "$1" |
    tr '[:upper:]' '[:lower:]' |
    sed -e 's/[^a-z0-9 -]//g' -e 's/ /-/g'
}

# Every heading in a markdown file, as anchors, one per line.
anchors() {
  sed -n 's/^#\{1,6\}[[:space:]]\+//p' "$1" | while IFS= read -r heading; do
    slug "$heading"
  done
}

report() {
  printf '%s:%s: broken link: %s\n' "$1" "$2" "$3" >&2
  status=1
}

while IFS= read -r file; do
  in_code=0
  lineno=0

  while IFS= read -r line; do
    lineno=$((lineno + 1))

    # Fenced code blocks hold examples, not links.
    case "$line" in '```'*) in_code=$((1 - in_code)); continue ;; esac
    if [ "$in_code" -eq 1 ]; then continue; fi

    while IFS= read -r target; do
      target=${target#](}
      target=${target%)}
      target=${target%% *} # drop an optional "title" after the target

      case "$target" in '' | http://* | https://* | mailto:*) continue ;; esac

      case "$target" in
        *'#'*) path=${target%%#*} anchor=${target#*#} ;;
        *) path=$target anchor='' ;;
      esac

      # A link is relative to the file holding it, unless it starts at the
      # repository root. A bare "#anchor" points into the file itself.
      case "$path" in
        '') path=$file ;;
        /*) path=".$path" ;;
        *) path="$(dirname "$file")/$path" ;;
      esac

      if [ ! -e "$path" ]; then
        report "$file" "$lineno" "$target"
        continue
      fi

      case "$path" in
        *.md)
          # The membership test is deliberately pipe-free. Piping into
          # `grep -q` makes grep exit at the first match, which hands the
          # producing side SIGPIPE; under `set -o pipefail` that becomes a
          # non-zero pipeline status, and the `!` then reports the link as
          # broken exactly when the anchor was found early enough for the
          # producer to still have output pending.
          if [ -n "$anchor" ]; then
            case $'\n'"$(anchors "$path")"$'\n' in
              *$'\n'"$anchor"$'\n'*) ;;
              *) report "$file" "$lineno" "$target" ;;
            esac
          fi
          ;;
      esac
    done < <(printf '%s\n' "$line" | grep -oE '\]\([^)]*\)' || true)
  done <"$file"
done < <(git ls-files '*.md')

if [ "$status" -eq 0 ]; then
  echo "All relative links resolve."
fi

exit "$status"
