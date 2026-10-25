#!/bin/sh
# Aitum Multistream - the uninstaller's working half.
#
# All of the looking and all of the deleting happens here; the dialogs live in
# uninstall-app.applescript, which drives this script one subcommand at a time.
# Keeping them apart means this half can be exercised without a single click.
#
#   uninstall-core.sh obs-running      exit 0 if OBS Studio is open
#   uninstall-core.sh survey           report what is installed, as key=value
#   uninstall-core.sh remove-plugin    delete the plugin bundle(s)
#   uninstall-core.sh remove-config    delete the saved outputs and stream keys
#   uninstall-core.sh forget-receipt    drop the installer receipt
#
# Everything is read from $HOME, so nothing here needs an administrator, and
# scenes, profiles and other plugins are never named, let alone removed.

set -u

PLUGIN_NAME="aitum-multistream"
RECEIPT_ID="tv.aitum.multi"
SUPPORT_DIR="$HOME/Library/Application Support/obs-studio"
PLUGINS_DIR="$SUPPORT_DIR/plugins"
CONFIG_DIR="$SUPPORT_DIR/plugin_config/$PLUGIN_NAME"
SYSTEM_BUNDLE="/Library/Application Support/obs-studio/plugins/$PLUGIN_NAME.plugin"

# The only three paths that are ever considered for deletion as "the plugin".
bundle="$PLUGINS_DIR/$PLUGIN_NAME.plugin"
dsym="$PLUGINS_DIR/$PLUGIN_NAME.plugin.dSYM"
legacy="$PLUGINS_DIR/$PLUGIN_NAME"

# Refuse to delete anything whose path is not one of the four we know by name,
# under a directory ending in obs-studio/plugins or obs-studio/plugin_config.
safe_remove() {
	_path="$1"
	case "$_path" in
		*"/obs-studio/plugins/$PLUGIN_NAME.plugin" | \
		*"/obs-studio/plugins/$PLUGIN_NAME.plugin.dSYM" | \
		*"/obs-studio/plugins/$PLUGIN_NAME" | \
		*"/obs-studio/plugin_config/$PLUGIN_NAME") ;;
		*)
			printf 'refused %s\n' "$_path"
			return 1
			;;
	esac
	[ -e "$_path" ] || return 0
	if /bin/rm -rf -- "$_path"; then
		printf 'removed %s\n' "$_path"
	else
		printf 'failed %s\n' "$_path"
		return 1
	fi
}

case "${1-}" in
	obs-running)
		/usr/bin/pgrep -x OBS >/dev/null 2>&1
		;;

	survey)
		printf 'plugins_dir=%s\n' "$PLUGINS_DIR"
		printf 'config_dir=%s\n' "$CONFIG_DIR"
		for _p in "$bundle" "$dsym" "$legacy"; do
			[ -e "$_p" ] && printf 'target=%s\n' "$_p"
		done
		# Ask only if the file is really there: handed a missing path, PlistBuddy
		# prints "File Doesn't Exist, Will Create" on stdout and still exits 0.
		if [ -f "$bundle/Contents/Info.plist" ]; then
			_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
				"$bundle/Contents/Info.plist" 2>/dev/null || printf '')
			[ -n "$_version" ] && printf 'version=%s\n' "$_version"
		fi
		if [ -d "$CONFIG_DIR" ]; then
			printf 'config=yes\n'
		else
			printf 'config=no\n'
		fi
		[ -e "$SYSTEM_BUNDLE" ] && printf 'systemwide=%s\n' "$SYSTEM_BUNDLE"
		exit 0
		;;

	remove-plugin)
		_failed=0
		safe_remove "$bundle" || _failed=1
		safe_remove "$dsym" || _failed=1
		safe_remove "$legacy" || _failed=1
		exit "$_failed"
		;;

	remove-config)
		safe_remove "$CONFIG_DIR" || exit 1
		exit 0
		;;

	forget-receipt)
		/usr/sbin/pkgutil --forget "$RECEIPT_ID" >/dev/null 2>&1 || true
		exit 0
		;;

	*)
		printf 'usage: %s obs-running|survey|remove-plugin|remove-config|forget-receipt\n' \
			"$(basename "$0")" >&2
		exit 2
		;;
esac
