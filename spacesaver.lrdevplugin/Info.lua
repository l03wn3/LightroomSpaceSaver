--[[----------------------------------------------------------------------------

ADOBE SYSTEMS INCORPORATED
 Copyright 2007 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.

--------------------------------------------------------------------------------

Info.lua
Summary information for Hello World sample plug-in.

Adds menu items to Lightroom.

------------------------------------------------------------------------------]]

return {

	LrSdkVersion = 3.0,
	LrSdkMinimumVersion = 1.3, -- minimum SDK version required by this plug-in

	LrToolkitIdentifier = 'com.adobe.lightroom.sdk.spacesaver',

	LrPluginName = LOC "$$$/Loodin.se/PluginName=SpaceSaver",

	-- Add the menu item to the Library menu.	
	LrLibraryMenuItems = {
		{
		    title = LOC "$$$/Loodin/DialogObserver=SaveSpace",
		    file = "SaveSpace.lua",
		},
	},
	VERSION = { major=0, minor=5, revision=0, build=201909150001 },
}
