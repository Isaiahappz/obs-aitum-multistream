#!/bin/bash
# Build the macOS installer for this fork of Aitum Multistream.
#
#   scripts/build-mac-installer.sh [options]
#
#     --skip-build            Package whatever is already in build_macos/
#     --skip-guide            Reuse dist/OBS-Multistream-Guide.pdf as it is
#     --no-sign               Do not sign the plugin, the uninstaller or the package
#     --notarize              Submit to Apple and staple the tickets
#     --notary-profile NAME   notarytool keychain profile (default: $NOTARY_PROFILE)
#     --team-id ID            Signing team (default: S84JSLP7M7)
#     -h, --help
#
# Produces, in dist/:
#     Aitum Multistream Installer.pkg
#     Uninstall Aitum Multistream.app
#     OBS-Multistream-Guide.pdf        the volunteer guide
#     Aitum-Multistream-mac.zip        all three of the above, plus a README
#
# The package installs into the home folder of whoever runs it, so no
# administrator password is needed, and it refuses to install unless a release
# build of OBS Studio 33.0 or newer is present.

set -euo pipefail

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SOURCE_DIR"

BUILD_DIR="$SOURCE_DIR/build_macos"
DIST_DIR="$SOURCE_DIR/dist"
WORK_DIR="$DIST_DIR/.work"
INSTALLER_DIR="$SOURCE_DIR/installer/macos"
UNINSTALL_SRC="$INSTALLER_DIR/uninstall"

TEAM_ID="S84JSLP7M7"
MACOS_MIN="13.0"
CONFIGURATION="RelWithDebInfo"

skip_build=0
skip_guide=0
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
		--skip-guide) skip_guide=1 ;;
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
			sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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

[[ -n "$PLUGIN_NAME" && -n "$DISPLAY_NAME" && -n "$VERSION" && -n "$BUNDLE_ID" ]] ||
	die "could not read buildspec.json"

PKG_NAME="$DISPLAY_NAME Installer.pkg"
BUNDLE_NAME="$PLUGIN_NAME.plugin"
UNINSTALLER_NAME="Uninstall $DISPLAY_NAME.app"
UNINSTALLER_ID="$BUNDLE_ID.uninstaller"
ZIP_NAME="Aitum-Multistream-mac.zip"
GUIDE_NAME="OBS-Multistream-Guide.pdf"
GUIDE_BUILDER="$SOURCE_DIR/docs/guide/build-guide.py"
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
	say "signing the plugin and the uninstaller with: $app_identity"
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
	[[ -n "$app_identity" ]] || die "--notarize needs a signed uninstaller, and there is no Developer ID Application identity"
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
#
# Read with /usr/bin/file rather than lipo. lipo lives behind an Xcode Command
# Line Tools stub, and the same reading has to work in postinstall, which runs
# on volunteers' Macs where that stub would raise the "install the command
# line developer tools" prompt. Using one method in both places means the
# check that gates the build is the check that runs on their machines.
bundle_arches() {
	/usr/bin/file -b "$1" | /usr/bin/sed -n '1p' | /usr/bin/awk '
		/Mach-O universal/ {
			while (match($0, /\[[A-Za-z0-9_.]+:/)) {
				name = substr($0, RSTART + 1, RLENGTH - 2)
				if (!(name in seen)) {
					seen[name] = 1
					list = list (list ? " " : "") name
				}
				$0 = substr($0, RSTART + RLENGTH)
			}
			next
		}
		/Mach-O/ { list = $NF }
		END { printf "%s", (list ? list : "unknown") }'
}

arches="$(bundle_arches "$PLUGIN_BUNDLE/Contents/MacOS/$PLUGIN_NAME")"
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

# ------------------------------------------------------------- uninstaller --
# A double-clickable app rather than a .command: volunteers get native dialogs
# instead of a Terminal window, and an app bundle can be notarized and stapled,
# which a bare script cannot.
plist_set() {
	# plist_set FILE KEY TYPE VALUE...  (replaces the key if it is already there)
	local file="$1" key="$2" type="$3"
	shift 3
	/usr/libexec/PlistBuddy -c "Delete :$key" "$file" >/dev/null 2>&1 || true
	/usr/libexec/PlistBuddy -c "Add :$key $type $*" "$file" >/dev/null
}

say "building $UNINSTALLER_NAME"
mkdir -p "${WORK_DIR:?}"
UNINSTALLER_APP="$WORK_DIR/$UNINSTALLER_NAME"
rm -rf "${UNINSTALLER_APP:?}"
osacompile -o "$UNINSTALLER_APP" "$UNINSTALL_SRC/uninstall-app.applescript"

ditto "$UNINSTALL_SRC/uninstall-core.sh" "$UNINSTALLER_APP/Contents/Resources/uninstall-core.sh"
chmod 755 "$UNINSTALLER_APP/Contents/Resources/uninstall-core.sh"

uninstaller_plist="$UNINSTALLER_APP/Contents/Info.plist"
plist_set "$uninstaller_plist" CFBundleIdentifier string "$UNINSTALLER_ID"
plist_set "$uninstaller_plist" CFBundleName string "Uninstall $DISPLAY_NAME"
plist_set "$uninstaller_plist" CFBundleDisplayName string "Uninstall $DISPLAY_NAME"
plist_set "$uninstaller_plist" CFBundleShortVersionString string "$VERSION"
plist_set "$uninstaller_plist" CFBundleVersion string "$VERSION"
plist_set "$uninstaller_plist" LSMinimumSystemVersion string "$MACOS_MIN"
plist_set "$uninstaller_plist" NSHighResolutionCapable bool true
# osacompile stocks the plist with permission prompts for the camera, the
# microphone, Siri and the rest. This uninstaller asks the system for none of
# them, and a volunteer should never see a string suggesting otherwise.
/usr/libexec/PlistBuddy -c 'Delete :LSMinimumSystemVersionByArchitecture' \
	"$uninstaller_plist" >/dev/null 2>&1 || true
for usage in AppleEvents AppleMusic Calendars Camera Contacts HomeKit Microphone \
	PhotoLibrary Reminders Siri SystemAdministration; do
	/usr/libexec/PlistBuddy -c "Delete :NS${usage}UsageDescription" \
		"$uninstaller_plist" >/dev/null 2>&1 || true
done

if [[ -n "$app_identity" ]]; then
	codesign --force --sign "$app_identity" --identifier "$UNINSTALLER_ID" \
		--options runtime --timestamp "$UNINSTALLER_APP"
	codesign --verify --deep --strict --verbose=1 "$UNINSTALLER_APP"
else
	codesign --force --sign - --identifier "$UNINSTALLER_ID" "$UNINSTALLER_APP"
fi

# ----------------------------------------------------------------- payload --
say "assembling the payload"
mkdir -p "$WORK_DIR/payload/$INSTALL_SUBPATH" "$WORK_DIR/pkgs" "$WORK_DIR/scripts"

# ditto, not cp: it keeps the bundle's signature and symlinks intact.
rm -rf "${WORK_DIR:?}/payload/${INSTALL_SUBPATH:?}/${BUNDLE_NAME:?}"
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

mkdir -p "${DIST_DIR:?}"
rm -f "${DIST_DIR:?}/${PKG_NAME:?}"

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
	say "submitting the package to Apple (profile: $notary_profile)"
	xcrun notarytool submit "$DIST_DIR/$PKG_NAME" \
		--keychain-profile "$notary_profile" --wait

	# An app has to travel to the notary service inside an archive; the ticket
	# is then stapled to the app itself, not to the archive.
	say "submitting the uninstaller to Apple"
	rm -f "${WORK_DIR:?}/uninstaller-notarize.zip"
	ditto -c -k --sequesterRsrc --keepParent "$UNINSTALLER_APP" "$WORK_DIR/uninstaller-notarize.zip"
	xcrun notarytool submit "$WORK_DIR/uninstaller-notarize.zip" \
		--keychain-profile "$notary_profile" --wait

	say "stapling the tickets"
	xcrun stapler staple "$DIST_DIR/$PKG_NAME"
	xcrun stapler staple "$UNINSTALLER_APP"
fi

# ------------------------------------------------------------------- guide --
# The volunteer guide travels in the zip alongside the installer, so whoever
# hands it out has one file to send. Its source is docs/guide/build-guide.py -
# keep it there, in the repository, rather than regenerating it from memory.
GUIDE_PDF="$DIST_DIR/$GUIDE_NAME"
mkdir -p "${DIST_DIR:?}"

if ((skip_guide)); then
	say "skipping the guide"
	[[ -f "$GUIDE_PDF" ]] || die "--skip-guide needs an existing $GUIDE_PDF"
else
	say "building $GUIDE_NAME"
	[[ -f "$GUIDE_BUILDER" ]] || die "no guide builder at $GUIDE_BUILDER"

	# reportlab is not part of any system Python, so find an interpreter that
	# actually has it rather than guessing.
	guide_python=""
	for candidate in "${GUIDE_PYTHON:-}" python3 /usr/local/bin/python3 /opt/homebrew/bin/python3; do
		[[ -n "$candidate" ]] || continue
		if command -v "$candidate" > /dev/null 2>&1 &&
			"$candidate" -c 'import reportlab' > /dev/null 2>&1; then
			guide_python="$candidate"
			break
		fi
	done
	[[ -n "$guide_python" ]] ||
		die "no Python with reportlab installed - 'python3 -m pip install reportlab', or pass --skip-guide"

	"$guide_python" "$GUIDE_BUILDER" --output "$GUIDE_PDF"
	[[ -f "$GUIDE_PDF" ]] || die "the guide builder produced no $GUIDE_NAME"
	note "$(basename "$guide_python") / reportlab $("$guide_python" -c 'import reportlab; print(reportlab.Version)')"
fi

# --------------------------------------------------------------------- zip --
say "assembling dist/"
rm -rf "${DIST_DIR:?}/${UNINSTALLER_NAME:?}"
ditto "$UNINSTALLER_APP" "$DIST_DIR/$UNINSTALLER_NAME"

STAGE="$WORK_DIR/zip/$DISPLAY_NAME for OBS"
rm -rf "${WORK_DIR:?}/zip"
mkdir -p "$STAGE"
ditto "$DIST_DIR/$PKG_NAME" "$STAGE/$PKG_NAME"
ditto "$UNINSTALLER_APP" "$STAGE/$UNINSTALLER_NAME"
ditto "$GUIDE_PDF" "$STAGE/$GUIDE_NAME"

cat > "$STAGE/READ ME FIRST.txt" <<READ_ME
$DISPLAY_NAME $VERSION for OBS Studio

START HERE
  "$GUIDE_NAME" is the step-by-step guide: updating OBS, installing
  this plugin, and going live on YouTube and Facebook. Read section 2 before
  you update OBS - there are two old items to remove first.

TO INSTALL
  1. Make sure OBS Studio 33.0 or newer is installed. The installer checks,
     and will stop if the version is older, or if it is a beta or release
     candidate build of OBS.
  2. Quit OBS Studio.
  3. Open "$PKG_NAME" and follow the steps.
     No administrator password is needed.
  4. Open OBS, then choose Docks in the menu bar and tick $DISPLAY_NAME.

TO REMOVE IT LATER
  1. Quit OBS Studio.
  2. Open "$UNINSTALLER_NAME".
     It asks before it deletes anything, and it keeps your outputs and stream
     keys unless you tell it otherwise.

WHAT IS AND IS NOT CHANGED
  Installed:  ~/$INSTALL_SUBPATH/$BUNDLE_NAME
  Untouched:  your scenes, sources, profiles, stream keys and saved outputs,
              and every other OBS plugin.
  Log:        ~/Library/Logs/$DISPLAY_NAME Installer.log
              It records the OBS version that was found, where the plugin
              went, and which architectures it was built for.
READ_ME

rm -f "${DIST_DIR:?}/${ZIP_NAME:?}"
ditto -c -k --sequesterRsrc --keepParent "$STAGE" "$DIST_DIR/$ZIP_NAME"

rm -rf "${WORK_DIR:?}"

say "done"
note "$DIST_DIR/$PKG_NAME"
note "$DIST_DIR/$UNINSTALLER_NAME"
note "$GUIDE_PDF"
note "$DIST_DIR/$ZIP_NAME"
if [[ -z "$installer_identity" ]]; then
	printf '\n'
	warn "the package is UNSIGNED and not notarized"
	note "to fix: create a 'Developer ID Installer' certificate for team $TEAM_ID"
	note "at developer.apple.com, install it in the login keychain, then re-run"
	note "this script with --notarize --notary-profile <name>."
elif ((!want_notarize)); then
	printf '\n'
	warn "signed, but NOT notarized - pass --notarize --notary-profile <name>"
fi
