-- Aitum Multistream - the uninstaller's dialogs.
--
-- Compiled by scripts/build-mac-installer.sh into
-- "Uninstall Aitum Multistream.app". The looking and the deleting are done by
-- uninstall-core.sh, which sits next to this script in the app's Resources;
-- everything here is the part a volunteer sees.
--
-- Nothing is deleted until two questions have been answered.

property myTitle : "Uninstall Aitum Multistream"

on run
	set core to quoted form of (POSIX path of (path to resource "uninstall-core.sh"))

	-- Two copies of a plugin loading at once is exactly what we are here to
	-- prevent, so never pull one out from under a running OBS.
	if (do shell script core & " obs-running; echo $?") is "0" then
		activate
		display dialog "OBS Studio is open." & return & return & ¬
			"Please quit OBS Studio, then open this uninstaller again." ¬
			with title myTitle buttons {"OK"} default button "OK" with icon stop
		return
	end if

	set survey to paragraphs of (do shell script core & " survey")
	set pluginsDir to my valueOf(survey, "plugins_dir=", "")
	set configDir to my valueOf(survey, "config_dir=", "")
	set theVersion to my valueOf(survey, "version=", "")
	set hasConfig to (my valueOf(survey, "config=", "no") is "yes")
	set systemWide to my valueOf(survey, "systemwide=", "")
	set targets to my allValuesOf(survey, "target=")

	-- Nothing of ours here. Say so plainly and stop.
	if (count of targets) is 0 then
		set msg to "Aitum Multistream is not installed for this user." & return & return & ¬
			"Looked in:" & return & "    " & pluginsDir
		if systemWide is not "" then
			set msg to msg & return & return & ¬
				"There is a copy installed for all users at:" & return & "    " & systemWide & ¬
				return & return & "Removing that one needs an administrator and is not done here."
		end if
		activate
		display dialog msg with title myTitle buttons {"OK"} default button "OK" with icon note
		return
	end if

	-- First question: the plugin itself.
	set msg to "Remove Aitum Multistream from OBS?"
	if theVersion is not "" then
		set msg to msg & "  (version " & theVersion & ")"
	end if
	set msg to msg & return & return & "This will be removed:"
	repeat with t in targets
		set msg to msg & return & "    " & t
	end repeat
	set msg to msg & return & return & "This will be kept:" & return & ¬
		"    Your scenes, sources and profiles" & return & ¬
		"    Every other OBS plugin"
	if hasConfig then
		set msg to msg & return & "    Your Aitum outputs and stream keys"
	end if

	activate
	display dialog msg with title myTitle buttons {"Cancel", "Remove Plugin"} ¬
		default button "Cancel" cancel button "Cancel" with icon caution

	-- Second question: the outputs and stream keys, asked only if there are any.
	set removeConfig to false
	if hasConfig then
		activate
		display dialog "Your saved Aitum outputs and stream keys are in:" & return & ¬
			"    " & configDir & return & return & ¬
			"Keeping them means they come back if you install the plugin again." & return & return & ¬
			"Removing them cannot be undone." ¬
			with title myTitle buttons {"Cancel", "Remove Everything", "Keep My Outputs"} ¬
			default button "Keep My Outputs" cancel button "Cancel" with icon caution
		if (button returned of result) is "Remove Everything" then set removeConfig to true
	end if

	-- Do it.
	set report to ""
	set failed to false

	set outcome to my runCore(core & " remove-plugin")
	set report to report & (item 1 of outcome)
	if (item 2 of outcome) is not 0 then set failed to true

	if removeConfig then
		set outcome to my runCore(core & " remove-config")
		set report to report & (item 1 of outcome)
		if (item 2 of outcome) is not 0 then set failed to true
	else if hasConfig then
		set report to report & "Kept      " & configDir & return
	end if

	do shell script core & " forget-receipt"

	if failed then
		set msg to "Aitum Multistream was not completely removed." & return & return & report & ¬
			return & "Your scenes, profiles and stream keys were not touched."
		set theIcon to 0 -- stop
	else
		set msg to "Aitum Multistream has been removed." & return & return & report & ¬
			return & "Your scenes and profiles were not touched." & return & return & ¬
			"If OBS was open, the dock will be gone the next time you start it."
		set theIcon to 1 -- note
	end if

	activate
	display dialog msg with title myTitle buttons {"Done"} default button "Done" with icon theIcon
end run

-- Run one subcommand, turning its printed lines into something a volunteer can
-- read and handing back the exit status alongside.
on runCore(theCommand)
	set raw to do shell script theCommand & " 2>&1; echo \"status=$?\""
	set pretty to ""
	set theStatus to 0
	repeat with aLine in (paragraphs of raw)
		set aLine to aLine as text
		if my startsWith(aLine, "status=") then
			set theStatus to (text 8 thru -1 of aLine) as integer
		else if my startsWith(aLine, "removed ") then
			set pretty to pretty & "Removed   " & (text 9 thru -1 of aLine) & return
		else if my startsWith(aLine, "failed ") then
			set pretty to pretty & "COULD NOT REMOVE  " & (text 8 thru -1 of aLine) & return
		else if my startsWith(aLine, "refused ") then
			set pretty to pretty & "Refused to touch  " & (text 9 thru -1 of aLine) & return
		else if aLine is not "" then
			set pretty to pretty & aLine & return
		end if
	end repeat
	return {pretty, theStatus}
end runCore

on startsWith(theText, thePrefix)
	if (count of theText) < (count of thePrefix) then return false
	return (text 1 thru (count of thePrefix) of theText) is thePrefix
end startsWith

on valueOf(theLines, theKey, theDefault)
	repeat with aLine in theLines
		set aLine to aLine as text
		if my startsWith(aLine, theKey) then
			if (count of aLine) is (count of theKey) then return theDefault
			return text ((count of theKey) + 1) thru -1 of aLine
		end if
	end repeat
	return theDefault
end valueOf

on allValuesOf(theLines, theKey)
	set found to {}
	repeat with aLine in theLines
		set aLine to aLine as text
		if my startsWith(aLine, theKey) and (count of aLine) > (count of theKey) then
			set end of found to text ((count of theKey) + 1) thru -1 of aLine
		end if
	end repeat
	return found
end allValuesOf
