#!/usr/bin/env bash
#
# Usage: mirror.sh
#
# Run inside a git repository whose origin is the mirror. Brings trunk up to
# date from SourceForge's git mirror and turns every SVN release tag from 4.0.0
# on that is still missing into a git tag. Pushing is left to the caller.
#
# A tag SourceForge keeps failing on is skipped and appended to SKIPPED_FILE,
# so the others can still be pushed and the next run tries it again.

set -euo pipefail

GIT_MIRROR=${GIT_MIRROR:-https://git.code.sf.net/p/sdcc/git-mirror}
SVN=https://svn.code.sf.net/p/sdcc/code
SVN_UUID=4a8a32a2-be11-0410-ad9d-d568d2c75423
TAG_PATTERN='^sdcc-([4-9]|[1-9][0-9]+)\.[0-9]+\.[0-9]+(-rc[0-9]+)?$'
SKIPPED_FILE=${SKIPPED_FILE:-/dev/null}
RETRY_DELAY=${RETRY_DELAY:-30}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
GIT_DIR=$(git rev-parse --absolute-git-dir)
export GIT_DIR

# SourceForge drops connections now and then.
retry() {
  local i
  for i in 1 2 3 4; do
    "$@" && return 0
    echo "Retrying in $((i * RETRY_DELAY))s: $*" >&2
    sleep $((i * RETRY_DELAY))
  done
  "$@"
}

skipped=()
skip() {
  echo "::warning::Skipped $1 for now"
  echo "$1" >> "$SKIPPED_FILE"
  skipped+=("$1")
}

svn_log() { svn log -q --xml -v --stop-on-copy "$SVN/tags/$1/sdcc" > "$WORK/$1.xml"; }
svn_export() { rm -rf "$2" && svn export -q "$1" "$2"; }

# Only history newer than what is already mirrored comes from SourceForge.
if git ls-remote --exit-code origin refs/heads/trunk > /dev/null; then
  git fetch -q origin +refs/heads/trunk:refs/heads/trunk
fi
git fetch -q origin '+refs/tags/sdcc-*:refs/tags/sdcc-*'
# No + here: if SourceForge ever rewrites trunk, stop instead of following it.
retry git fetch -q "$GIT_MIRROR" refs/heads/trunk:refs/heads/trunk

# The trunk commit that holds the state of trunk at SVN revision $1.
trunk_at() {
  git log --first-parent --format='%H %(trailers:key=git-svn-id,valueonly,separator=)' trunk |
    awk -v rev="$1" '!found && match($2, /\/trunk\/sdcc@[0-9]+$/) {
      split($2, a, "@"); if (a[2] + 0 <= rev) { print $1; found = 1 } }'
}

if ! retry svn ls "$SVN/tags/" > "$WORK/tags"; then
  skip "the tag list"
  : > "$WORK/tags"
fi
missing=()
for tag in $(sed 's|/$||' "$WORK/tags" | grep -E "$TAG_PATTERN"); do
  if ! git rev-parse -q --verify "refs/tags/$tag" > /dev/null; then
    missing+=("$tag")
  fi
done

# A tag can be copied from an older one, so import them in the order SVN
# created them.
for tag in "${missing[@]}"; do
  if ! retry svn_log "$tag"; then
    skip "$tag"
    continue
  fi
  python3 - "$WORK/$tag.xml" "/tags/$tag/sdcc" > "$WORK/$tag.info" <<'PY'
import sys, xml.etree.ElementTree as ET
entries = ET.parse(sys.argv[1]).getroot().findall("logentry")
newest, oldest = entries[0], entries[-1]
src = next(p for p in oldest.iter("path")
           if p.get("copyfrom-path") and (sys.argv[2] + "/").startswith(p.text + "/"))
print(oldest.get("revision"), src.get("copyfrom-path"), src.get("copyfrom-rev"),
      newest.get("revision"), newest.findtext("author"),
      newest.findtext("date").split(".")[0] + "Z")
PY
done
ordered=$(for tag in "${missing[@]}"; do
  if [ -f "$WORK/$tag.info" ]; then
    echo "$(cut -d' ' -f1 "$WORK/$tag.info") $tag"
  fi
done | sort -n | cut -d' ' -f2)

for tag in $ordered; do
  read -r created from from_rev rev author date < "$WORK/$tag.info"
  source=
  if [[ $from =~ ^/tags/([^/]+) ]]; then
    source=${BASH_REMATCH[1]}
  fi
  if [ -n "$source" ] && git rev-parse -q --verify "refs/tags/$source" > /dev/null; then
    parent=$(git rev-parse "refs/tags/$source^{commit}")
  elif [ -n "$source" ] && [[ " ${skipped[*]} " == *" $source "* ]]; then
    # Its parent waits for the next run, and so does it.
    skip "$tag"
    continue
  else
    parent=$(trunk_at "$from_rev")
  fi

  # svn export expands $Revision$, so a build from the tag numbers itself
  # the way the official release does.
  if ! retry svn_export "$SVN/tags/$tag/sdcc@$rev" "$WORK/$tag"; then
    rm -rf "$WORK/$tag"
    skip "$tag"
    continue
  fi
  (cd "$WORK/$tag" && GIT_INDEX_FILE="$WORK/index" GIT_WORK_TREE=. git add -A -f)
  tree=$(GIT_INDEX_FILE="$WORK/index" git write-tree)
  rm -rf "$WORK/index" "$WORK/$tag"

  commit=$(GIT_AUTHOR_NAME=$author GIT_AUTHOR_EMAIL=$author@$SVN_UUID GIT_AUTHOR_DATE=$date \
    GIT_COMMITTER_NAME=$author GIT_COMMITTER_EMAIL=$author@$SVN_UUID GIT_COMMITTER_DATE=$date \
    git commit-tree "$tree" -p "$parent" -F - <<EOF
Tag $tag

Imported from tags/$tag/sdcc, which r$created copied from $from@$from_rev.

git-svn-id: $SVN/tags/$tag/sdcc@$rev $SVN_UUID
EOF
  )
  git tag "$tag" "$commit"
  echo "Imported $tag as $commit"
done
