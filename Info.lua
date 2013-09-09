--[[----------------------------------------------------------------------------

Info.lua
Summary information for AEM Publish Service plug-in

--------------------------------------------------------------------------------

ADOBE SYSTEMS INCORPORATED
 Copyright 2013 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.

------------------------------------------------------------------------------]]

return {

	LrSdkVersion = 4.0,
	LrSdkMinimumVersion = 4.0, -- minimum SDK version required by this plug-in

	LrToolkitIdentifier = 'com.adobe.lightroom.export.aem',
	LrPluginName = LOC "$$$/AEM DAM/PluginName=AEM DAM",
	
	LrExportServiceProvider = {
		title = LOC "$$$/AEM DAM/AEM DAM-title=AEM DAM",
		file = 'AEMExportServiceProvider.lua',
	},
	
	VERSION = { major=0, minor=0, revision=1, build=1, },

}
