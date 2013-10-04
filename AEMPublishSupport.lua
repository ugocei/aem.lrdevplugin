local LrHttp = import 'LrHttp'
local logger = import 'LrLogger'( 'AEMPublishService' )
local LrDialogs = import 'LrDialogs'
local LrErrors = import 'LrErrors'
local LrStringUtils = import 'LrStringUtils'
local LrXml = import 'LrXml'
local LrFunctionContext = import 'LrFunctionContext'
local json = require 'DkJson'

local appearsAlive

local publishServiceProvider = {}

publishServiceProvider.small_icon = 'experiencemanager_72.png'

publishServiceProvider.titleForGoToPublishedCollection = LOC "$$$/AEM/TitleForGoToPublishedCollection=Show in AEM"

publishServiceProvider.titleForGoToPublishedPhoto = LOC "$$$/AEM/TitleForGoToPublishedCollection=Show in AEM"


function publishServiceProvider.metadataThatTriggersRepublish( publishSettings )

	return {

		default = false,
		title = true,
		caption = true,
		keywords = true,
		gps = true,
		dateCreated = true,
	}

end

publishServiceProvider.supportsCustomSortOrder = false

function publishServiceProvider.didUpdatePublishService( publishSettings, info )
  LrFunctionContext.callWithContext( 'aem-publish-service', function ( context )
    LrDialogs.attachErrorDialogToFunctionContext( context )
    local authorization = "Basic " .. LrStringUtils.encodeBase64(publishSettings.username .. ':' .. publishSettings.password)
    local headers = {
       { field = 'Authorization', value = authorization },
    }
    local response, hdrs = LrHttp.get( publishSettings.url .. '.1.json', headers )
    logger:info( 'AEM response:', response )
    if not response then
  	  appearsAlive = false
  	  LrErrors.throwUserError(LOC "$$$/AEM/Error/NetworkFailure=Could not contact the AEM web service. Please check your Internet connection.")
  	end

    if hdrs.status ~= 200 then
    	LrErrors.throwUserError(hdrs.status)
    end
  
    local obj, pos, err = json.decode (response, 1, nil)
    if err then
  	  LrErrors.throwUserError(err)
    end
    
    for k,v in pairs(obj) do
      if v['jcr:primaryType'] == 'sling:OrderedFolder' then
        if (not v.hidden) then
          local title = v['jcr:title']
          if (not title) then title = k end
          info.publishService.catalog:withWriteAccessDo('Creating published collection', function( context ) 
            info.publishService:createPublishedCollection(title)
          end)
        end  
      end
    end
	end)
end

function publishServiceProvider.deletePhotosFromPublishedCollection( publishSettings, arrayOfPhotoIds, deletedCallback )

	for i, photoId in ipairs( arrayOfPhotoIds ) do
    logger:debug("Deleting photo " .. photoId)
    local authorization = "Basic " .. LrStringUtils.encodeBase64(publishSettings.username .. ':' .. publishSettings.password)
    local headers = {
       { field = 'Authorization', value = authorization },
    }
    local params = {
      {name = ':operation', value = 'delete'},
    }

    local result, hdrs = LrHttp.postMultipart(photoId, params, headers)
    logger:debug(result)
    if (hdrs.status == 200) then
      deletedCallback(photoId)
    else
      LrErrors.throwUserError(hdrs.status)
  	end
	end
	
end

function publishServiceProvider.getCommentsFromPublishedCollection( publishSettings, arrayOfPhotoInfo, commentCallback )

  local authorization = "Basic " .. LrStringUtils.encodeBase64(publishSettings.username .. ':' .. publishSettings.password)
  local headers = {
     { field = 'Authorization', value = authorization },
  }

	for i, photoInfo in ipairs( arrayOfPhotoInfo ) do
		local comments = {}
	  local response, hdrs = LrHttp.get( photoInfo.url .. '/jcr:content/comments.1.json', headers )
    -- logger:info( 'Comments: ', response )
    if not response then
  	  appearsAlive = false
  	  LrErrors.throwUserError(LOC "$$$/AEM/Error/NetworkFailure=Could not contact the AEM web service. Please check your Internet connection.")
  	end

    if hdrs.status == 200 then
  
      local comments, pos, err = json.decode (response, 1, nil)
      if err then
    	  LrErrors.throwUserError(err)
      end
    
  		local commentList = {}
  		if comments then
  			for k,v in pairs( comments ) do
  			  logger:debug("v = " .. type(v))
  			  if (type(v) == "table" and v["sling:resourceType"] == "granite/comments/components/comment") then
    				table.insert( commentList, {
    								commentId = k,
    								commentText = v["jcr:description"],
    								-- dateCreated = comment.datecreate,
    								username = v.author,
    								-- realname = comment.authorname,
    								-- url = comment.permalink
    							} )
    				logger:debug("Inserted comment: " .. v["jcr:description"])
  			  end
  			end			
  		end	
  		commentCallback{ publishedPhoto = photoInfo, comments = commentList }						    

    end
	end

end

function publishServiceProvider.renamePublishedCollection( publishSettings, info )

	if info.remoteId then
  -- TODO
	end
		
end

function publishServiceProvider.deletePublishedCollection( publishSettings, info )

  -- TODO
  
end

AEMPublishSupport = publishServiceProvider
