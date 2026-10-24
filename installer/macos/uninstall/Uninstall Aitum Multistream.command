#!/bin/sh
# Aitum Multistream - uninstaller.
#
# Double-click this file. It removes the Aitum Multistream plugin from your own
# OBS plugins folder and nothing else. Your scenes, profiles and stream keys are
# left alone unless you explicitly ask for the keys to go too.

set -u

PLUGIN_NAME="aitum-multistream"
SUPPORT_DIR="$HOME/Library/Application Support/obs-studio"
PLUGINS_DIR="$SUPPORT_DIR/plugins"
CONFIG_DIR="$SUPPORT_DIR/plugin_config/$PLUGIN_NAME"

bold=$(printf '\033[1m')
dim=$(printf '\033[2m')
plain=$(printf '\033[0m')

printf '%s\n' "${bold}Uninstall Aitum Multistream${plain}"
printf '%s\n\n' "${dim}Nothing is deleted until you say so.${plain}"

# --- is OBS open? ----------------------------------------------------------
if /usr/bin/pgrep -x OBS >/dev/null 2>&1; then
	printf '%s\n' "${bold}OBS Studio is open.${plain}"
	printf '%s\n\n' "Please quit OBS, then run this uninstaller again."
	printf '%s' "Press Return to close this window. "
	read -r _ || true
	exit 1
fi

# --- what is actually here? ------------------------------------------------
# Only these exact paths are ever considered for deletion.
bundle="$PLUGINS_DIR/$PLUGIN_NAME.plugin"
dsym="$PLUGINS_DIR/$PLUGIN_NAME.plugin.dSYM"
legacy="$PLUGINS_DIR/$PLUGIN_NAME"

targets=''
add_target() {
	[ -e "$1" ] || return 0
	targets="$targets$1
"
}
add_target "$bundle"
add_target "$dsym"
add_target "$legacy"

if [ -z "$targets" ]; then
	printf '%s\n' "Aitum Multistream is not installed for this user."
	printf '%s\n\n' "${dim}Looked in: $PLUGINS_DIR${plain}"
	if [ -e "/Library/Application Support/obs-studio/plugins/$PLUGIN_NAME.plugin" ]; then
		printf '%s\n' "There is a machine-wide copy at:"
		printf '%s\n' "  /Library/Application Support/obs-studio/plugins/$PLUGIN_NAME.plugin"
		printf '%s\n\n' "Removing that one needs an administrator and is not done here."
	fi
	printf '%s' "Press Return to close this window. "
	read -r _ || true
	exit 0
fi

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
	"$bundle/Contents/Info.plist" 2>/dev/null || printf '')
if [ -n "$version" ]; then
	printf '%s\n\n' "Installed version: $version"
fi

printf '%s\n' "${bold}These will be removed:${plain}"
printf '%s' "$targets" | while IFS= read -r t; do
	[ -n "$t" ] && printf '  %s\n' "$t"
done
printf '\n'

printf '%s\n' "${bold}These will be kept:${plain}"
printf '%s\n' "  Your scenes, sources and profiles"
printf '%s\n' "  Every other OBS plugin"
if [ -d "$CONFIG_DIR" ]; then
	printf '%s\n' "  Your Aitum outputs and stream keys  ($CONFIG_DIR)"
fi
printf '\n'

ask_yes_no() {
	# ask_yes_no PROMPT DEFAULT(y|n) -> 0 for yes
	_prompt="$1"
	_default="$2"
	if [ "$_default" = "y" ]; then
		_hint="[Y/n]"
	else
		_hint="[y/N]"
	fi
	printf '%s %s ' "$_prompt" "$_hint"
	read -r _answer || _answer=''
	[ -z "$_answer" ] && _answer="$_default"
	case "$_answer" in
		y | Y | yes | YES | Yes) return 0 ;;
		*) return 1 ;;
	esac
}

if ! ask_yes_no "Remove the Aitum Multistream plugin?" n; then
	printf '\n%s\n\n' "Nothing was changed."
	printf '%s' "Press Return to close this window. "
	read -r _ || true
	exit 0
fi

remove_config=1
if [ -d "$CONFIG_DIR" ]; then
	printf '\n'
	printf '%s\n' "${bold}One more question.${plain}"
	printf '%s\n' "Your saved Aitum outputs and stream keys live in:"
	printf '%s\n' "  $CONFIG_DIR"
	printf '%s\n' "Keeping them means they come back if you reinstall the plugin."
	printf '%s\n\n' "${bold}Removing them cannot be undone.${plain}"
	if ask_yes_no "Also remove my outputs and stream keys?" n; then
		remove_config=0
	fi
fi

printf '\n'

# Guard: refuse to delete anything whose path is not one of the three names we
# listed, under a directory ending in obs-studio/plugins.
safe_remove() {
	_path="$1"
	case "$_path" in
		*"/obs-studio/plugins/$PLUGIN_NAME.plugin" | \
		*"/obs-studio/plugins/$PLUGIN_NAME.plugin.dSYM" | \
		*"/obs-studio/plugins/$PLUGIN_NAME" | \
		*"/obs-studio/plugin_config/$PLUGIN_NAME") ;;
		*)
			printf '%s\n' "Refused to remove an unexpected path: $_path"
			return 1
			;;
	esac
	[ -e "$_path" ] || return 0
	if /bin/rm -rf -- "$_path"; then
		printf '%s\n' "Removed  $_path"
	else
		printf '%s\n' "Could NOT remove  $_path"
		return 1
	fi
}

failed=0
safe_remove "$bundle" || failed=1
safe_remove "$dsym" || failed=1
safe_remove "$legacy" || failed=1
if [ "$remove_config" -eq 0 ]; then
	safe_remove "$CONFIG_DIR" || failed=1
else
	printf '%s\n' "Kept     $CONFIG_DIR"
fi

# Drop the installer receipt if there is one. Harmless if this fails.
/usr/sbin/pkgutil --forget tv.aitum.multi >/dev/null 2>&1 || true

printf '\n'
if [ "$failed" -eq 0 ]; then
	printf '%s\n' "${bold}Done.${plain} Aitum Multistream has been removed."
else
	printf '%s\n' "${bold}Finished with problems.${plain} See the lines above."
fi
printf '%s\n\n' "Your scenes and profiles were not touched."
printf '%s' "Press Return to close this window. "
read -r _ || true
exit "$failed"
