#!/bin/bash
# Build the macOS installer for this fork of Aitum Multistream.
#
#   scripts/build-mac-installer.sh [options]
#
#     --skip-build            Package whatever is already in build_macos/
#     --no-sign               Do not sign the plugin or the package
#     --notarize              Submit the package to Apple and staple the ticket
#     --notary-profile NAME   notarytool keychain profile (default: $NOTARY_PROFILE)
#     --team-id ID            Signing team (default: S84JSLP7M7)
#     -h, --help
#
# Produces, in dist/:
#     Aitum Multistream Installer.pkg
#     Uninstall Aitum Multistream.command
#     Aitum-Multistream-mac.zip        both of the above, plus a README
#
# The package installs into the home folder of whoever runs it, so no
# administrator password is needed, and it refuses to install unless OBS
# Studio 33.0 or newer is present.

set -euo pipefail

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SOURCE_DIR"

BUILD_DIR="$SOURCE_DIR/build_macos"
DIST_DIR="$SOURCE_DIR/dist"
WORK_DIR="$DIST_DIR/.work"
INSTALLER_DIR="$SOURCE_DIR/installer/macos"
UNINSTALLER="$INSTALLER_DIR/uninstall/Uninstall Aitum Multistream.command"

TEAM_ID="S84JSLP7M7"
MACOS_MIN="13.0"
CONFIGURATION="RelWithDebInfo"

skip_build=0
want_sign=1
want_notarize=0
notary_profile="${NOTARY_PROFILE:-}"

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m==> %s\033[0m\n' "$*" >&2; }
die() {
	printf '\033[1;31m==> %s\033[0m\n' "$*" >&2
	exit 1
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--skip-build) skip_build=1 ;;
		--no-sign) want_sign=0 ;;
		--notarize) want_notarize=1 ;;
		--notary-profile)
			notary_profile="${2:-}"
			shift
			;;
		--team-id)
			TEAM_ID="${2:-}"
			shift
			;;
		-h | --help)
			sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
			exit 0
			;;
		*) die "unknown option: $1" ;;
	esac
	shift
done

[[ "$(uname -s)" == "Darwin" ]] || die "this script only runs on macOS"

# ---------------------------------------------------------------- metadata --
read_buildspec() {
	/usr/bin/python3 -I - "$SOURCE_DIR/buildspec.json" <<'PY'
import json, sys
spec = json.load(open(sys.argv[1]))
print(spec["name"])
print(spec.get("displayName", spec["name"]))
print(spec["version"])
print(spec["platformConfig"]["macos"]["bundleId"])
PY
}

{
	read -r PLUGIN_NAME
	read -r DISPLAY_NAME
	read -r VERSION
	read -r BUNDLE_ID
} < <(read_buildspec)

[[ -n "$PLUGIN_NAME" && -n "$VERSION" && -n "$BUNDLE_ID" ]] || die "could not read buildspec.json"

PKG_NAME="$DISPLAY_NAME Installer.pkg"
BUNDLE_NAME="$PLUGIN_NAME.plugin"
# The one location OBS 33 loads third-party plugins from on macOS, relative to
# the install domain (the user's home folder).
INSTALL_SUBPATH="Library/Application Support/obs-studio/plugins"

say "$DISPLAY_NAME $VERSION ($BUNDLE_ID)"
note "install path: ~/$INSTALL_SUBPATH/$BUNDLE_NAME"

# ----------------------------------------------------------------- signing --
app_identity=""
installer_identity=""

if ((want_sign)); then
	app_identity="$(security find-identity -v -p codesigning 2>/dev/null |
		sed -n "s/.*\"\(Developer ID Application:[^\"]*(${TEAM_ID})\)\".*/\1/p" | head -1)"
	installer_identity="$(security find-identity -v 2>/dev/null |
		sed -n "s/.*\"\(Developer ID Installer:[^\"]*(${TEAM_ID})\)\".*/\1/p" | head -1)"
fi

if [[ -n "$app_identity" ]]; then
	say "signing the plugin with: $app_identity"
else
	warn "no 'Developer ID Application' identity for team $TEAM_ID - the plugin will be ad-hoc signed"
fi

if [[ -n "$installer_identity" ]]; then
	say "signing the package with: $installer_identity"
else
	warn "no 'Developer ID Installer' identity for team $TEAM_ID - the package will be UNSIGNED"
	note "an unsigned package is still installable, but macOS will warn about it"
	note "when it has been downloaded; right-click the .pkg and choose Open."
fi

if ((want_notarize)); then
	[[ -n "$installer_identity" ]] || die "--notarize needs a signed package, and there is no Developer ID Installer identity"
	[[ -n "$notary_profile" ]] || die "--notarize needs --notary-profile NAME (or \$NOTARY_PROFILE)"
fi

# ------------------------------------------------------------------- build --
if ((skip_build)); then
	say "skipping the build"
else
	say "building the plugin (universal: arm64 + x86_64)"
	if [[ -n "$app_identity" ]]; then
		export CODESIGN_IDENT="$app_identity"
		export CODESIGN_TEAM="$TEAM_ID"
	else
		unset CODESIGN_IDENT CODESIGN_TEAM || true
	fi
	cmake --preset macos
	cmake --build --preset macos
fi

PLUGIN_BUNDLE="$BUILD_DIR/$CONFIGURATION/$BUNDLE_NAME"
[[ -d "$PLUGIN_BUNDLE" ]] || die "no plugin bundle at $PLUGIN_BUNDLE"

# Refuse to ship a single-architecture build - half the volunteers are on Intel.
arches="$(lipo -archs "$PLUGIN_BUNDLE/Contents/MacOS/$PLUGIN_NAME")"
say "built architectures: $arches"
for required in arm64 x86_64; do
	[[ " $arches " == *" $required "* ]] || die "the bundle is missing the $required slice (got: $arches)"
done

built_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
	"$PLUGIN_BUNDLE/Contents/Info.plist" 2>/dev/null || true)"
if [[ "$built_version" != "$VERSION" ]]; then
	warn "the built bundle says $built_version but buildspec.json says $VERSION"
	note "re-run without --skip-build to pick up the version change"
fi

# ----------------------------------------------------------------- payload --
say "assembling the payload"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/payload/$INSTALL_SUBPATH" "$WORK_DIR/pkgs" "$WORK_DIR/scripts"

# ditto, not cp: it keeps the bundle's signature and symlinks intact.
ditto "$PLUGIN_BUNDLE" "$WORK_DIR/payload/$INSTALL_SUBPATH/$BUNDLE_NAME"
xattr -dr com.apple.quarantine "$WORK_DIR/payload" >/dev/null 2>&1 || true

ditto "$INSTALLER_DIR/scripts/preinstall" "$WORK_DIR/scripts/preinstall"
ditto "$INSTALLER_DIR/scripts/postinstall" "$WORK_DIR/scripts/postinstall"
chmod 755 "$WORK_DIR/scripts/preinstall" "$WORK_DIR/scripts/postinstall"

if [[ -n "$app_identity" ]]; then
	say "verifying the plugin signature"
	codesign --verify --deep --strict --verbose=1 "$WORK_DIR/payload/$INSTALL_SUBPATH/$BUNDLE_NAME"
fi

# -------------------------------------------------------------- component --
say "pkgbuild"
pkgbuild \
	--identifier "$BUNDLE_ID" \
	--version "$VERSION" \
	--root "$WORK_DIR/payload" \
	--scripts "$WORK_DIR/scripts" \
	--ownership recommended \
	"$WORK_DIR/pkgs/$PLUGIN_NAME.pkg"

# ------------------------------------------------------------ distribution --
say "productbuild"
sed -e "s|@DISPLAY_NAME@|$DISPLAY_NAME|g" \
	-e "s|@BUNDLE_ID@|$BUNDLE_ID|g" \
	-e "s|@PLUGIN_NAME@|$PLUGIN_NAME|g" \
	-e "s|@VERSION@|$VERSION|g" \
	-e "s|@MACOS_MIN@|$MACOS_MIN|g" \
	"$INSTALLER_DIR/distribution.xml.in" > "$WORK_DIR/distribution.xml"

mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR/$PKG_NAME"

productbuild_args=(
	--distribution "$WORK_DIR/distribution.xml"
	--package-path "$WORK_DIR/pkgs"
	--resources "$INSTALLER_DIR/resources"
)
if [[ -n "$installer_identity" ]]; then
	productbuild_args+=(--sign "$installer_identity" --timestamp)
fi
productbuild "${productbuild_args[@]}" "$DIST_DIR/$PKG_NAME"

# ---------------------------------------------------------------- notarize --
if ((want_notarize)); then
	say "submitting to Apple for notarization (profile: $notary_profile)"
	xcrun notarytool submit "$DIST_DIR/$PKG_NAME" \
		--keychain-profile "$notary_profile" --wait
	say "stapling the ticket"
	xcrun stapler staple "$DIST_DIR/$PKG_NAME"
	xcrun stapler validate "$DIST_DIR/$PKG_NAME"
fi

# --------------------------------------------------------------------- zip --
say "assembling dist/"
ditto "$UNINSTALLER" "$DIST_DIR/$(basename "$UNINSTALLER")"
chmod 755 "$DIST_DIR/$(basename "$UNINSTALLER")"

STAGE="$WORK_DIR/zip/$DISPLAY_NAME for OBS"
mkdir -p "$STAGE"
ditto "$DIST_DIR/$PKG_NAME" "$STAGE/$PKG_NAME"
ditto "$UNINSTALLER" "$STAGE/$(basename "$UNINSTALLER")"
chmod 755 "$STAGE/$(basename "$UNINSTALLER")"

cat > "$STAGE/READ ME FIRST.txt" <<READ_ME
$DISPLAY_NAME $VERSION for OBS Studio

TO INSTALL
  1. Make sure OBS Studio 33.0 or newer is installed. The installer checks,
     and will stop if the version is older.
  2. Quit OBS Studio.
  3. Open "$PKG_NAME" and follow the steps.
     No administrator password is needed.
  4. Open OBS, then choose Docks in the menu bar and tick $DISPLAY_NAME.

IF macOS REFUSES TO OPEN THE INSTALLER
  Right-click (or Control-click) the installer, choose Open, then Open again.

TO REMOVE IT LATER
  Double-click "$(basename "$UNINSTALLER")". It asks before it
  deletes anything, and it keeps your outputs and stream keys unless you tell
  it otherwise.

WHAT IS AND IS NOT CHANGED
  Installed:  ~/$INSTALL_SUBPATH/$BUNDLE_NAME
  Untouched:  your scenes, sources, profiles, stream keys and saved outputs,
              and every other OBS plugin.
  Log:        ~/Library/Logs/$DISPLAY_NAME Installer.log
READ_ME

rm -f "$DIST_DIR/Aitum-Multistream-mac.zip"
ditto -c -k --sequesterRsrc --keepParent "$STAGE" "$DIST_DIR/Aitum-Multistream-mac.zip"

rm -rf "$WORK_DIR"

say "done"
note "$DIST_DIR/$PKG_NAME"
note "$DIST_DIR/$(basename "$UNINSTALLER")"
note "$DIST_DIR/Aitum-Multistream-mac.zip"
if [[ -z "$installer_identity" ]]; then
	printf '\n'
	warn "the package is UNSIGNED and not notarized"
	note "to fix: create a 'Developer ID Installer' certificate for team $TEAM_ID"
	note "at developer.apple.com, install it in the login keychain, then re-run"
	note "this script with --notarize --notary-profile <name>."
fi
