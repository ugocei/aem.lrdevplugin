--[[----------------------------------------------------------------------------

AEMExportServiceProvider.lua
Export service provider description for Lightroom AEM DAM uploader

--------------------------------------------------------------------------------

ADOBE SYSTEMS INCORPORATED
 Copyright 2013 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.

------------------------------------------------------------------------------]]

	-- Lightroom SDK
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrView = import 'LrView'
local LrStringUtils = import 'LrStringUtils'
local LrErrors = import 'LrErrors'
local LrTasks = import 'LrTasks'
local LrHttp = import 'LrHttp'

local logger = import 'LrLogger'( 'AEMPublishService' )
logger:enable( "print" )

	-- Common shortcuts
local bind = LrView.bind
local share = LrView.share

require 'AEMPublishSupport'

local exportServiceProvider = {}

for name, value in pairs( AEMPublishSupport ) do
	exportServiceProvider[ name ] = value
end

exportServiceProvider.supportsIncrementalPublish = 'only'

exportServiceProvider.exportPresetFields = {
	{ key = 'username', default = "" },
	{ key = 'password', default = "" },
	{ key = 'url', default = "http://localhost:4502/content/dam" },
}

exportServiceProvider.hideSections = { 'exportLocation' }

exportServiceProvider.hidePrintResolution = true

function exportServiceProvider.sectionsForTopOfDialog( f, propertyTable )

	return {
	
		{
			title = LOC "$$$/AEM/ExportDialog/Account=AEM Account",
			
			synopsis = bind { key = 'url', object = propertyTable },

			f:row {
				spacing = f:label_spacing(),
        f:static_text {
          title = "URL:",
          alignment = 'right',
          width = LrView.share 'label_width',
        },
        f:edit_field {
          fill_horizonal = 1,
          width_in_chars = 40,
          value = bind 'url',
          immediate = false,
        },
      },

      f:row {
			  spacing = f:label_spacing(),
        f:static_text {
          title = "Username:",
          alignment = 'right', 
          width = LrView.share 'label_width',
        },
        f:edit_field {
          fill_horizonal = 1,
          width_in_chars = 20,
          value = bind 'username',
          immediate = false,
        },
      },

      f:row {
		    spacing = f:label_spacing(),
        f:static_text {
          title = "Password:",
          alignment = 'right', 
          width = LrView.share 'label_width',
        },
        f:password_field {
          fill_horizonal = 1,
          width_in_chars = 20,
          value = bind 'password',
          immediate = false,
        },
      },
      
      --[[
      f:row {
				f:push_button {
					title = 'Login',
					enabled = true,
					action = function()
            LrDialogs.message( "URL: ", propertyTable.url)
					end,
				},

			},
			--]]
		},
	}

end

function exportServiceProvider.processRenderedPhotos( functionContext, exportContext )
	
	local exportSession = exportContext.exportSession

	-- Make a local reference to the export parameters.
	
	local exportSettings = assert( exportContext.propertyTable )

  local authorization = "Basic " .. LrStringUtils.encodeBase64(exportSettings.username .. ':' .. exportSettings.password)
        
  -- Create the folder (if necessary)
  local url = exportSettings.url .. '/' .. exportContext.publishedCollectionInfo.name
  createFolderIfNecessary(exportContext.publishedCollectionInfo.name, url, authorization)
	
	-- Get the # of photos.
	
	local nPhotos = exportSession:countRenditions()
	
	-- Set progress title.
	
	local progressScope = exportContext:configureProgress {
						title = nPhotos > 1
									and LOC( "$$$/Flickr/Publish/Progress=Publishing ^1 photos to AEM", nPhotos )
									or LOC "$$$/Flickr/Publish/Progress/One=Publishing one photo to AEM",
					}
					
  for i, rendition in exportContext:renditions { stopIfCanceled = true } do
	  progressScope:setPortionComplete( ( i - 1 ) / nPhotos )
	
	  if not rendition.wasSkipped then
	    -- Get next photo.
	    local photo = rendition.photo
			local success, pathOrMessage = rendition:waitForRender()
			
			-- Update progress scope again once we've got rendered photo.
			
			progressScope:setPortionComplete( ( i - 0.5 ) / nPhotos )
			
			-- Check for cancellation again after photo has been rendered.
			
			if progressScope:isCanceled() then break end
			
			if success then
			  postFile(pathOrMessage, url, authorization, rendition)
      end
    end
  end
end

function postFile(path, url, authorization, rendition)
  local fileName = LrPathUtils.leafName(path)
  local contentType = 'application/octet-stream'
  local headers = {
     { field = 'Authorization', value = authorization },
  }
  local params = {
    {name = 'jcr:primaryType', value = 'dam:Asset'},
    {name = 'file', filePath = path, fileName = fileName, contentType = contentType },
  }

  logger:debug('Posting Asset. File = ' .. path .. ', URL = ' .. url)
  local result, hdrs = LrHttp.postMultipart(url .. '.createasset.html', params, headers)
  logger:debug("Status = " .. hdrs.status)

	if hdrs.status ~= 200 then
      logger:error(result)
		  LrErrors.throwUserError("Error publishing photo: " .. hdrs.status)
	end
	rendition:recordPublishedPhotoId(url .. '/' .. fileName)
	rendition:recordPublishedPhotoUrl(url .. '/' .. fileName)
	LrFileUtils.delete(path)
end

function createFolderIfNecessary(name, url, authorization)
  local headers = {
     { field = 'Authorization', value = authorization },
  }
  local result, hdrs = LrHttp.get(url .. '.json', headers)
  if (hdrs.status ~= 200) then
    logger:debug('Folder ' .. name .. ' does not exist. Creating it.')
    local folderParams = {
      {name = 'jcr:primaryType', value = 'sling:OrderedFolder'},
    }
    LrHttp.postMultipart(url, folderParams, headers)
  end
end

return exportServiceProvider

