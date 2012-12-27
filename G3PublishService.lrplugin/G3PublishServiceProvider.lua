require 'G3Api'
require 'G3Dialogs'

local LrTasks = import 'LrTasks'
local LrView = import 'LrView'
local LrErrors = import 'LrErrors'
local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local LrHttp = import 'LrHttp'
local bind = LrView.bind

local prefs = import 'LrPrefs'.prefsForPlugin()

local LrLogger = import 'LrLogger'
local logger = LrLogger("g3")
logger:enable( "logfile" )

local publishServiceProvider = {}

--publishServiceProvider.exportPresetFields = { { key = 'myPluginSetting', default = 'Initial value' } }
publishServiceProvider.hideSections = { 'exportLocation' }
publishServiceProvider.allowFileFormats = { 'JPEG' , 'TIFF'}
publishServiceProvider.hidePrintResolution = true
publishServiceProvider.canExportVideo = false  --later.
publishServiceProvider.supportsIncrementalPublish = true
publishServiceProvider.small_icon = 'small_icon.png'
publishServiceProvider.titleForPublishedCollection = 'Album'
publishServiceProvider.titleForPublishedSmartCollection = "Smart Album"
publishServiceProvider.supportsCustomSortOrder = false



publishServiceProvider.exportPresetFields = {
	--{key="deleteAlbums", default=false},
	{key="useIPTC", default=true},
	--{key="rc2Compatible", default=false},
	{key="selectedAccount", default=nil},
	{key="createdAlbumIds", default={}},
	{key="albums", default={}},
	{key="openAlbumAfterExport", default=false},
	{key="selectedAlbum", default=nil},
	{key="instanceKey", default=(import 'LrDate').currentTime()},
	{key="commentIntegrationEnabled", default=false}
}


function publishServiceProvider.didCreateNewPublishService( publishSettings, info )
end

function publishServiceProvider.willDeletePublishService( publishSettings, info )
end

function publishServiceProvider.startDialog(propertyTable)
end


function publishServiceProvider.endDialog(propertyTable, why)	
	if why=="ok" then
		if not propertyTable.instanceKey then propertyTable.instanceKey = (import 'LrDate').currentTime() end
	end
end



function publishServiceProvider.sectionsForTopOfDialog(f, propertyTable)
  return G3Dialogs.topSections(f, propertyTable)
end



function publishServiceProvider.sectionsForBottomOfDialog(f, propertyTable)
  return G3Dialogs.bottomSections(f, propertyTable)
end


--function publishServiceProvider.updateExportSettings( exportSettings )
--	LrDialogs.message("updateExportSettings")
--end


function publishServiceProvider.processRenderedPhotos( functionContext, exportContext )
	logger:debug("is publish? "..tostring(exportContext.propertyTable.LR_isExportForPublish))
	
	logger:debug("START: processRenderedPhotos invoked")
	local temp = ""
	for k,v in exportContext.propertyTable:pairs() do temp = temp.."propT:"..k.."=>"..tostring(v).."\n" end
	logger:debug(temp)
  
	local exportSession = exportContext.exportSession
	local exportSettings = assert( exportContext.propertyTable )
	local nPhotos = exportSession:countRenditions()
		
	local progressScope = exportContext:configureProgress {
		title = "Publishing "..nPhotos.." photos to Gallery3"
	}
 
 
	local collectionId

	if exportSettings.LR_isExportForPublish then
	
		--locate/create album
		local collectionInfo = exportContext.publishedCollectionInfo
		collectionId = collectionInfo.remoteId
		
		
		local collectionUrl
		if(collectionId) then
			collectionUrl = G3Api.url(collectionId, exportSettings)
			logger:debug("collection ID present: "..collectionId)		
		else
			--handle default collection
			if(collectionInfo.isDefaultCollection) then
				logger:debug("default collection; doesn't have id yet. setting id=1")
				collectionId = "1"
				collectionUrl = G3Api.url(collectionId, exportSettings)
			else		
				logger:debug("collection ID missing; attempting to localize or create album '"..collectionInfo.name.."'")
				--locate album if possible; album names should be in /bla/yadda format
				--so it should be possible to locate the album bla in root and the album
				--yadda within bla.
				collectionId = G3Api.idForAlbumPath(collectionInfo.name, exportSettings)
				collectionUrl = G3Api.url(collectionId, exportSettings)
			end
			
			logger:debug("collection id: "..collectionId)
			exportSession:recordRemoteCollectionId(collectionId)
			
			local webUrl = G3Api.getWebUrl(collectionId, exportSettings)
			exportSession:recordRemoteCollectionUrl(webUrl)		
			
		end
	
	-- set ID if we're only exporting, not publishing
	else
		collectionId = exportSettings.selectedAlbum.id
	end
	
	
	
	--upload/replace images
	
	logger:debug("Processing "..nPhotos.." photos...")
	for i, rendition in exportContext.exportSession:renditions() do
	repeat	--pointless repeat loop that can eat breaks to emulate a 'continue/next' keyword
		logger:debug("BEGINNING OF FOR LOOP ITERATION")
	
	
		--progress scope
		local photoName = rendition.photo:getFormattedMetadata("fileName")
		progressScope:setPortionComplete( ( i - 1 ) / nPhotos )
		progressScope:setCaption("Exporting "..photoName.."("..i.."/"..nPhotos..")")
		
		--render the photo
		local success, pathOrMessage = rendition:waitForRender()
		if not success then LrErrors.throwUserError("Error during rendering. ("..pathOrMessage..")") end
		
		-- Update progress scope again once we've got rendered photo.
		progressScope:setPortionComplete( ( i - 0.5 ) / nPhotos )
		-- Check for cancellation again after photo has been rendered.
		if progressScope:isCanceled() then LrError.throwCanceled() end
		
		--prepare metadata
		local filePath = rendition.destinationPath
		local fileName = LrPathUtils.leafName( filePath )
		local fileNameNoExt = LrPathUtils.removeExtension( fileName )
		local title
		local description
		if exportSettings.useIPTC then
			title = rendition.photo:getFormattedMetadata("title")
			description = rendition.photo:getFormattedMetadata("caption")
		end
		
		
		
		if exportSettings.LR_isExportForPublish then
			-- Publish; this is the more involved action.
			
			local photoId = rendition.publishedPhotoId
		
			-- find out whether to update or to upload as new.
			if photoId and not G3Api.checkIsItemThere(photoId, exportSettings) then
				-- it's not there. ask what to do.
				-- either delete and call break or set photoId to nil so it'll be reuploaded

				logger:debug("photo "..photoId.." isn't there. what do we do?")
				
				local what
				local collection = exportContext.publishedCollection
				--smart collection? always re-upload.
				if collection:isSmartCollection() then
					what = "reupload"
				else
					what = G3Dialogs.showMissingPhotoDialog(photoId, fileName)
				end
				
				logger:debug("action: "..what.."; is collection smart? "..tostring(collection:isSmartCollection()))
				
				-- now that we know what to do, do it.
				if what=="delete" then
					--delete from collection, break
					local catalog = (import 'LrApplication').activeCatalog()
					catalog:withWriteAccessDo( "removeMissingPhoto", function( context ) 
						exportContext.publishedCollection:removePhotos({rendition.photo})
					end ) 
					
					logger:debug("deleted photo from collection. continue'ing.")					
					break	--pointless repeat loop eats this; effet is that of "continue/next"
				elseif what=="reupload" then
					--set photoId=nil to trigger upload as new
					photoId = nil
					logger:debug("set photoId to "..tostring(photoId).."; that'll trigger upload as new")
				end
			end
			
			
			-- now do the actual upload
			if photoId then
				-- update; the id doesn't change, so we don't need to get it
				logger:debug("Update photo id "..photoId..", filePath "..filePath)
				G3Api.uploadImage(photoId, "put", filePath, fileName, title, description, exportSettings)
			else
				-- upload newly, set photoId
				logger:debug("Upload photo into collectionId "..collectionId..", filePath "..filePath)
				photoId = G3Api.uploadImage(collectionId, "post", filePath, fileName, title, description, exportSettings) 
			end
			
			--save id (photoId)
			rendition:recordPublishedPhotoId(photoId)
			--save url (trivial)
			local webUrl = G3Api.getWebUrl(photoId, exportSettings)
			rendition:recordPublishedPhotoUrl(webUrl)
			
			logger:debug("Saved URL "..webUrl.." and id "..photoId)
			
		else
			-- Export only. just upload and be done.
			logger:debug("Export into "..collectionId..", filePath = "..filePath)
			photoId = G3Api.uploadImage(collectionId, "post", filePath, fileName, title, description, exportSettings) 
		end
		
		logger:debug("END OF FOR LOOP ITERATION")
		
	until true	--end of pointless repeat loop
	end
	
	
	progressScope:done()
	
	if exportSettings.openAlbumAfterExport then
		local webUrl = G3Api.getWebUrl(collectionId, exportSettings)
		logger:debug("webUrl of album: "..(webUrl or "nil"))
		if webUrl then LrHttp.openUrlInBrowser( webUrl ) end
	end
	
		
	logger:debug("END of processRenderedPhotos")
end





function publishServiceProvider.viewForCollectionSettings( f, publishSettings, info )

	local help_text = ""
	help_text = help_text.."Please enter a path consisting of album names; you can find out the path of an existing album by \n"
	help_text = help_text.."looking at its URL (/xmas/2010 for http://example.com/gallery/index.php/xmas/2010); if the album path \n"
	help_text = help_text.."you enter does not exist, it will be created and you will be prompted for album titles."
	

	return f:group_box {
		title = "Cute little ponies",
		size = 'small',
		fill_horizontal = 1,
		bind_to_object = assert( info.collectionSettings ),
		
		f:column {
			fill_horizontal = 1,
			spacing = f:label_spacing(),

			f:static_text {
				title = help_text,
			},
			
		},
		
	}
	
end






function publishServiceProvider.deletePhotosFromPublishedCollection( publishSettings, arrayOfPhotoIds, deletedCallback )
	--TODO delete images from server
		
	for i=1,#arrayOfPhotoIds,1 do
		local id = arrayOfPhotoIds[i]
		
		--logger:debug(G3Api.get(G3Api.url(id)))
		
		G3Api.deleteElement(id, publishSettings)
		
		deletedCallback(id)
	end

end



function publishServiceProvider.renamePublishedCollection( publishSettings, info )
	--get id for new name, move all photos over, delete old album if empty
	--DISABLED FOR NOW, but:
	--TODO gotta implement this
	LrDialogs.message("renamePublishedCollection")
end



function publishServiceProvider.deletePublishedCollection( publishSettings, info )
	import 'LrFunctionContext'.callWithContext( 'publishServiceProvider.deletePublishedCollection', function( context )
	
	local iKey = publishSettings.instanceKey
		
	--delete all publishedPhotos from the server album
	if info and info.publishedCollection then
		local photos = info.publishedCollection:getPublishedPhotos()

		for i=1,#photos,1 do
			local photoId = photos[i]:getRemoteId()
			
			logger:debug("Deleting photo "..photoId)
			
			G3Api.deleteElement(photoId, publishSettings)
			
		end
	end
		
	
	if info and info.remoteId then
		local names = G3Api.splitPath(info.name)
		
		local curId = info.remoteId
		for i=#names,1,-1 do
			logger:debug("deleteCollection: can we delete "..names[i].." "..curId)
		
			--don't delete non-empty albums
			if not G3Api.isAlbumEmpty(curId, publishSettings) then
				logger:debug("not empty; break.")
				break
			end
			
			local nextId = G3Api.getParentId(curId, publishSettings)
			logger:debug("iKey: "..tostring(iKey))
			
			--output all album ids that were created by this plugin instance
			local debug_ids = "ids created by plugin: "
			for i=1,#(prefs.createdAlbums[iKey]),1 do 
				debug_ids = debug_ids..(prefs.createdAlbums[iKey][i])..","
			end
			logger:debug(debug_ids)
			
			--check if curId is among those album ids that were created by this plugin instance
			local created_by_us = false
			for i=1,#prefs.createdAlbums[iKey],1 do
				if prefs.createdAlbums[iKey][i] == curId then 
					created_by_us = true
					logger:debug("Album was created by this plugin.")
					break
				end
			end
			
			--if it was created by the plugin, delete it.
			if created_by_us then
				G3Api.deleteElement(curId, publishSettings)
				logger:debug("deleted; nextId: "..nextId)
			else
				logger:debug("not created by us; wont be deleted. nextId: "..nextId)
			end
			
			curId = nextId
		end
		
	end
			
	end)
	
end



function publishServiceProvider.getCommentsFromPublishedCollection( settings, arrayOfPhotoInfo, commentCallback ) 
	if not settings.commentIntegrationEnabled then return end
	
	for i, photoInfo in ipairs( arrayOfPhotoInfo ) do
		local id = photoInfo.remoteId
		local commentList  = G3Api.getComments(id, settings)
		
		-- Call Lightroom's callback function to register comments.
		commentCallback { publishedPhoto = photoInfo, comments = commentList }
	end 
 end
 
 
function publishServiceProvider.addCommentToPublishedPhoto( publishSettings, remotePhotoId, commentText )
	G3Api.postComment(remotePhotoId, commentText, publishSettings)	
	return true
end

 
function publishServiceProvider.canAddCommentsToService( publishSettings )
	logger:debug("G3 requirements for comments met? - "..tostring(publishSettings.commentIntegrationEnabled))
	return publishSettings.commentIntegrationEnabled
end





--[[function publishServiceProvider.imposeSortOrderOnPublishedCollection( publishSettings, info, remoteIdSequence )
	local r = ""
	
	for i,v in ipairs(remoteIdSequence) do
		r = r..v..","
	end
	
	logger:debug(r)
	
	if info and info.remoteId then
		G3Api.reorderAlbum(info.remoteId, remoteIdSequence, publishSettings)
	end
	
end]]--



function publishServiceProvider.validatePublishedCollectionName( proposedName )
	if string.match(proposedName, "^[%w%_%-%/]+$") then
		return true
	else
		return false, "Please use only alphanumeric characters and '-_/'"
	end
end



function publishServiceProvider.getCollectionBehaviorInfo( publishSettings )
	return {
		defaultCollectionName = "Photos in Gallery Root",
		defaultCollectionCanBeDeleted = false,
		canAddCollection = true,
		maxCollectionSetDepth = 0, --I'd love to use this, but it has no effect
	}
end


publishServiceProvider.disableRenamePublishedCollection = true;

return publishServiceProvider


















































