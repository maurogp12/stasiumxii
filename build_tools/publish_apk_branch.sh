#!/usr/bin/env bash
# Publish a sideload APK as the download-only branch apk/<version>.
# Its workflow (.github/workflows/publish-apk-release.yml on that branch)
# joins the parts, checks the SHA-256 and publishes the release
# mobile-<version>-debug that the in-game Actualizar button installs.
#
# GitHub refuses any git file over 100 MB, so the APK is always committed as
# 90 MB parts (stasiumxii-mobile-debug.apk.part-00, -01, ...) plus a .sha256.
# Release assets may be up to 2 GB.
#
# Usage: build_tools/publish_apk_branch.sh <version> "<one-line notes>"
#   e.g. build_tools/publish_apk_branch.sh 0.1.58 "Smaller APK"
# Run from the repo root after exporting builds/android/stasiumxii-mobile-debug.apk.
set -euo pipefail

VERSION="${1:?version, e.g. 0.1.58}"
NOTES="${2:?one-line notes}"
APK="builds/android/stasiumxii-mobile-debug.apk"
NAME="stasiumxii-mobile-debug.apk"
PREV="$(git branch -r --list 'origin/apk/*' --sort=-committerdate | head -1 | tr -d ' ')"
SRC="$(git rev-parse --short HEAD)"
CERT="3725b12ee58cf1d911c373bc5ef0b6be3c47afb41421777f2b505bb4aa6063e2"

test -f "$APK"
SHA="$(sha256sum "$APK" | cut -d' ' -f1)"
SIZE="$(stat -c %s "$APK")"
CODE="$(sed -n 's/^version\/code=//p' export_presets.cfg | head -1)"
WT="$(mktemp -d)/apk"

git worktree add -q --detach "$WT" "$PREV"
trap 'git worktree remove --force "$WT"' EXIT
(
	cd "$WT"
	git checkout -q -b "apk/$VERSION"
	git rm -q --ignore-unmatch "$NAME" "$NAME".part-* "$NAME.sha256" >/dev/null
	split -b 90m -d -a 2 "$OLDPWD/$APK" "$NAME.part-"
	echo "$SHA  $NAME" > "$NAME.sha256"
	mkdir -p .github/workflows
	cp "$OLDPWD/build_tools/publish-apk-release.yml" .github/workflows/publish-apk-release.yml
	cat > README.md <<EOF
# STASIUM XII $VERSION-mobile debug APK (sideload)

Download-only branch. It holds no source code.

- Built from claude/stasium-xii-development-6ni8g2 at $SRC
- $NOTES
- Version $VERSION-mobile (code $CODE), arm64-v8a, debug
- Cert SHA-256 $CERT (pinned)
- APK SHA-256 $SHA, $SIZE bytes
- Stored as 90 MB parts; the release workflow joins them and checks the SHA-256
- Full change record: docs/CHANGE_LOG_CLAUDE.md on the work branch
EOF
	git add -A
	# APK_COMMIT_TRAILER: optional extra lines (e.g. Co-Authored-By) for the commit.
	git commit -q -m "APK $VERSION-mobile debug (code $CODE)${APK_COMMIT_TRAILER:+

$APK_COMMIT_TRAILER}"
	git push -u origin "apk/$VERSION"
)
echo "Pushed apk/$VERSION ($SIZE bytes, sha256 $SHA)"
