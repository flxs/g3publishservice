local LrErrors = import 'LrErrors'
local LrHttp = import 'LrHttp'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrFunctionContext = import 'LrFunctionContext'
local LrStringUtils = import 'LrStringUtils'
local LrPath = import 'LrPathUtils'
local LrDate = import 'LrDate'
local bind = LrView.bind
local share = LrView.share
local prefs = import 'LrPrefs'.prefsForPlugin()

local LrLogger = import 'LrLogger'
local logger = LrLogger("g3")
logger:enable( "logfile" )

JSON = (assert(loadfile(LrPath.child(_PLUGIN.path, "JSON.lua"))))()

G3Api = {}
  
 
 --checks headers of a http request for failure/errors, if any are found an error with 
 --error_message is thrown, error_message is written to log and log_message (if any) is written to
 --the log too
 function on_error(headers, error_message, log_message)
	if headers and (headers.error or not (headers.status==200 or headers.status==201)) then

		if headers.status then
			error_message = error_message.." (Code: "..headers.status..")"
		else
			error_message = error_message.." (Error: "..tostring(headers.error)..")"
		end
		
		logger:debug(error_message)
		
		if log_message then
			logger:debug(log_message)
		end
		LrErrors.throwUserError(error_message)
	end	
 end
 
--returns 403 if 403 forbidden is returned, 404 on 404 (so that the login dialog can be shown a second time,
--throws an error on all other error responses and returns the key on success
function G3Api.retrieveKey(url, user, pass, basicauth_active, basicauth_user, basicauth_password )
	local url_rest = url	--.."/index.php/rest/"
	local body = "user="..user.."&password="..pass

	logger:debug("RetrieveKey url="..url_rest..", user="..user..", basicauth_active="..tostring(basicauth_active)..", basicauth_user="..basicauth_user)
	
	local headers = {
		{field = 'X-Gallery-Request-Method', value = "post" },
		{field = 'Content-Type', value = "application/x-www-form-urlencoded" }, 
		{field = 'Content-Length', value = #body },
	}

    if basicauth_active then
       table.insert( headers, 
           { field = 'Authorization', value = 'Basic '..LrStringUtils.encodeBase64(basicauth_user..":"..basicauth_password) }
       )
    end

	local result, hdrs = LrHttp.post( url_rest, body , headers )
	if not result then LrDialogs.message("result is nil.") end
	
	--if 403 FORBIDDEN, return nil.
	if (hdrs and hdrs.status and hdrs.status==403) then
		if hdrs.status == 403 then return 403 end
		if hdrs.status == 404 then return 404 end
	end

	on_error(hdrs, "Failed to retrieve auth key")
	
	local key = string.sub(result, 2, #result-1)
	
	return key
end


--convert id into REST url
function G3Api.url(id, propertyTable, module)
	if not module then module = "item" end
	
	local path_to_rest = "/index.php/rest/"	--fallback if the account settings don't contain a path_to_rest (old accounts don't)
	if propertyTable.selectedAccount and propertyTable.selectedAccount.path_to_rest then
		path_to_rest = propertyTable.selectedAccount.path_to_rest
	end
	
	local url = propertyTable.selectedAccount.url
	url = url_link(url, path_to_rest)
	url = url_link(url, module)
	url = url_link(url, (id or ""))
	
	return url
end


--get request with all the gallery-specific headers set
function G3Api.get(url, propertyTable)
	local headers = {
		{field = 'X-Gallery-Request-Method', value = "get" },
		{field = 'X-Gallery-Request-key', value = propertyTable.selectedAccount.authkey },   
	}

    -- Add Basic Authentication Header
    if propertyTable.selectedAccount.basicauth_active then
       table.insert( headers, 
           { field = 'Authorization', value = 'Basic '..LrStringUtils.encodeBase64(propertyTable.selectedAccount.basicauth_user..":"..propertyTable.selectedAccount.basicauth_password) }
       )
    end
    -- End Basic Authentication Header
	
	local result,hdrs = LrHttp.get( url, headers)
	
	return result,hdrs
end


--get an ID for an item of a given name; only exact matches; if none found, nil is returned.
function G3Api.getIdByName(parentUrl, item_name, propertyTable)
	local result,hdrs = G3Api.get( parentUrl.."?name="..item_name, propertyTable)
	
	logger:debug("GetIdByName parentUrl="..parentUrl..", itemName="..item_name)

	local members = JSON:decode(result).members
	
	local url
	local id
	
	for i=1,#members,1 do
		local result,hdrs = G3Api.get(members[i], propertyTable)
		on_error(hdrs, "Could not fetch album members.", "member: "..members[i])
		
		local entity = (JSON:decode(result)).entity
		local eName = entity.name
		local eType = entity.type
		
		if(eName==item_name and eType=="album") then
			url = members[i]
			id = entity.id
			
			logger:debug("GetIdByName id found: "..id)
			
			return id
		end
	end
	
	return nil
end


--create an album, requests title from user.
function G3Api.createAlbum(parentUrl, name, propertyTable, title)
	
	logger:debug("CreateAlbum pUrl="..parentUrl..", name="..name)
	
	if not title then
		title = G3Dialogs.showCreateAlbumTitleDialog(propertyTable, name)
	end
	
	--[[--request album title from user
	LrFunctionContext.callWithContext( 'FlickrAPI.showApiKeyDialog', function( context )
		local f = LrView.osFactory()
		local properties = LrBinding.makePropertyTable( context )
		
		local contents = f:column {
			bind_to_object = properties,
			spacing = f:control_spacing(),
			fill = 1,
      
			f:static_text {
				title = "The album '"..name.."' needs to be created. Please enter a title for the album.",
				alignment = 'lright',
				width = share 'title_width',
			},
			
			f:edit_field { 
				fill_horizonal = 1,
				width_in_chars = 35, 
				value = bind 'title',
			
			},
		}
		
		local result = LrDialogs.presentModalDialog {
			title = "pony", 
			contents = contents,
		}
		
		if(result=="ok") then
			title = properties.title
		end
	end)]]--
		
	--handle cancel and empty response
	if(not title) then
		LrErrors.throwCanceled()
	end
	
	--build the create request
	local body = {}
	body.name = name
	body.type = "album"
	body.title = title
	
	body = JSON:encode(body)
	body = "entity="..body	
	
	local headers = {
		{field = 'X-Gallery-Request-Method', value = "post" },
		{field = 'X-Gallery-Request-Key', value = propertyTable.selectedAccount.authkey },
		--{field = 'Content-Type', value = "application/json" }, 
		{field = 'Content-Type', value = "application/x-www-form-urlencoded" }, 
		{field = 'Content-Length', value = #body },
	}	
	
    -- Add Basic Authentication Header
    if propertyTable.selectedAccount.basicauth_active then
       table.insert( headers, 
           { field = 'Authorization', value = 'Basic '..LrStringUtils.encodeBase64(propertyTable.selectedAccount.basicauth_user..":"..propertyTable.selectedAccount.basicauth_password) }
       )
    end
    -- End Basic Authentication Header
		
	logger:debug("CreateAlbum body="..body)
	
    local result, hdrs = LrHttp.post( parentUrl, body , headers )
    on_error(hdrs, "Error creating album")
	logger:debug("CreateAlbum result "..hdrs.status.." "..result)
		
	local url = (JSON:decode(result)).url
	
	local result2,hdrs2 = G3Api.get(url, propertyTable)
	on_error(hdrs2, "Error fetching album id.")
	
	local id = (JSON:decode( result2 )).entity.id
	
	-- record album id; we're keeping track of the albums we've created so we
	-- know which ones we may delete.
	--propertyTable.createdAlbumIds[#propertyTable.createdAlbumIds+1] = id
	if propertyTable.LR_isExportForPublish then
		local instanceKey = propertyTable.instanceKey
		
		logger:debug("instanceKey="..instanceKey..", id="..id)
		
		if not prefs.createdAlbums[instanceKey] then
			prefs.createdAlbums[instanceKey] = {id}
		else
			table.insert(prefs.createdAlbums[instanceKey], id)
		end
		
		logger:debug("Added ID "..id.." to prefs.createdAlbums using instanceKey "..instanceKey)
	end
	
	return id
	
end


-- split a album path (something like "/bla/yadda/")
-- takes care of leading/trailing slash
function G3Api.splitPath(path)
	--strip trailing /
	if string.sub(path, #path)=='/' then
		path = string.sub(path,1,#path-1)
	end
	
	--strip leading /
	if string.sub(path, 1,1)=='/' then
		path = string.sub(path,2,#path)
	end
	
	return split(path, "/")
end


-- returns an ID for a album path (e.g. /bla/yadda/); if necessary, albums will be created.
function G3Api.idForAlbumPath(path, propertyTable)
	logger:debug("idForAlbumPath path="..path)

	local names = G3Api.splitPath(path)
	
	--for each single album name try to get an id, if none can be retrieved, then a new album
	--is created and that one's id is used. then this is is converted into a rest url and used
	--as the parent url in the next iteration.
	local parentUrl = G3Api.url(1, propertyTable)
	for i=1,#names,1 do
		local id = G3Api.getIdByName(parentUrl, names[i], propertyTable)
		if not id then
			logger:debug("idForAlbumPath need to create album")
			
			--create album, set id
			id = G3Api.createAlbum(parentUrl, names[i], propertyTable)
		end
		
		parentUrl = G3Api.url(id, propertyTable)
	end
	
	--the last parentUrl is the target album's url
	local result,hdrs = G3Api.get(parentUrl, propertyTable)
	on_error(hdrs, "Error fetching id")
	
	local id = (JSON:decode(result)).entity.id
	
	logger:debug("idForAlbumPath finished; id:"..id.."; name:"..(JSON:decode(result)).entity.name)
	
	return id
end



-- POST or PUT an image (upload or update); 
-- *  for upload (POST), method must be "post", id must be the album id, filepath and filename must be
--    specified.
-- *  for update (PUT), method must be "put", id must be the item's id, filepath must be specified.
function G3Api.uploadImage(targetId, method, filePath, fileName, title, description, propertyTable)
	logger:debug("UploadImage: targetId: '"..(targetId or "-").."', method: '"..method.."', fPath: '"..(filePath or "-"))
	logger:debug("'... fName: '"..(fileName or "-").."', title: '"..(title or "-").."', descr: '"..(description or "-").."'") 
	
	local targetUrl = G3Api.url(targetId, propertyTable)
	logger:debug("target_url: "..targetUrl)
	
	local headers = {
		{field = 'X-Gallery-Request-Method', value = method },
		{field = 'X-Gallery-Request-Key', value = propertyTable.selectedAccount.authkey },
	}	
	
    -- Add Basic Authentication Header
    if propertyTable.selectedAccount.basicauth_active then
       table.insert( headers, 
           { field = 'Authorization', value = 'Basic '..LrStringUtils.encodeBase64(propertyTable.selectedAccount.basicauth_user..":"..propertyTable.selectedAccount.basicauth_password) }
       )
    end
    -- End Basic Authentication Header
    	
	local body = {type="photo"}
	if fileName and fileName~="" then body.name = fileName end
	if title and title~="" then body.title = title end
	if description and description~="" then body.description = description end
	
	body = JSON:encode(body)
	
	local mimeChunks = {
		{ name = "entity", value = body, contentType = "application/json" },
		{ name = 'file', fileName = fileName, filePath = filePath, contentType = 'application/octet-stream' }
	}
	
	logger:debug("UploadImage: url="..targetUrl.."; body="..body.."; method="..method)
	
	local result, hdrs = LrHttp.postMultipart( targetUrl, mimeChunks, headers )
	local debug_hdrs = "headers: "
	for k,v in pairs(hdrs) do
		if(type(v)=="table") then
			debug_hdrs = debug_hdrs..k.."=>["
			for kk,vv in pairs(v) do
				debug_hdrs = debug_hdrs..kk.."=>"..tostring(vv)
			end			
		else
			debug_hdrs = debug_hdrs..k.."=>"..tostring(v)..", "
		end
	end
	logger:debug(debug_hdrs)
	logger:debug("result: '"..tostring(result).."'")
	
	local temp = "uploading"
	if method=="put" then temp = "updating" end
	on_error(hdrs, "Error "..temp.." image.")
	
	
	if method=="put" then
		return targetId
	else
		local url = (JSON:decode(result)).url
	
		local result2,hdrs2 = G3Api.get(url, propertyTable)
		on_error(hdrs2, "Error fetching ID")
		local id = (JSON:decode(result2)).entity.id
	
		logger:debug("UploadImage finished, id of new image: "..id)
	
		return id
	end
end





function G3Api.deleteElement(id, propertyTable)
	local url = G3Api.url(id, propertyTable)

	local headers = {
		{field = 'X-Gallery-Request-Method', value = "delete" },
		{field = 'X-Gallery-Request-Key', value = propertyTable.selectedAccount.authkey },
	}

    -- Add Basic Authentication Header
    if propertyTable.selectedAccount.basicauth_active then
       table.insert( headers, 
           { field = 'Authorization', value = 'Basic '..LrStringUtils.encodeBase64(propertyTable.selectedAccount.basicauth_user..":"..propertyTable.selectedAccount.basicauth_password) }
       )
    end
    -- End Basic Authentication Header

	local result, hdrs = LrHttp.post( url, "" , headers )
	
	logger:debug("DeleteElement id="..id.." status "..hdrs.status)
	
	--if 404 then the element has already been deleted .. mission accomplished.
	if hdrs.status==404 then
		return
	else
		on_error(hdrs, "Could not delete element #"..id)
	end
end


function G3Api.isAlbumEmpty(id, propertyTable)
	local url = G3Api.url(id, propertyTable)
	local result,hdrs = G3Api.get(url, propertyTable)
	on_error(hdrs, "Error retrieving album information.")
	local members = JSON:decode(result).members
	
	if(#members == 0) then
		return true
	else
		return false
	end
end


function G3Api.getParentId(id, propertyTable)
	--LrDialogs.message(id)

	local result,hdrs = G3Api.get(G3Api.url(id, propertyTable), propertyTable)
	on_error(hdrs, "Error during GET request.", "486")
	
	--LrDialogs.message("1")
	
	local parentUrl = JSON:decode(result).entity.parent
	
	--LrDialogs.message("2")
	
	local result2,hdrs2 = G3Api.get(parentUrl, propertyTable)
	on_error(hdrs2, "Error during GET request", "495")
	
	return JSON:decode(result2).entity.id
end


function G3Api.getWebUrl(id, propertyTable)
	local result,hdrs = G3Api.get(G3Api.url(id, propertyTable), propertyTable)
	on_error(hdrs, "Error during GET request", "504")
	
	return JSON:decode(result).entity.web_url
end


function G3Api.fetchAlbums(propertyTable)
	local r = {}
	local startUrl = G3Api.url(1, propertyTable)
	
	r = fetchSubalbums(startUrl, propertyTable, r, "")
	
	return r
end


function fetchSubalbums(url, propertyTable, r, curPath)
	local result,hdrs = G3Api.get(url, propertyTable)
	on_error(hdrs, "Error retrieving album information.")
	
	logger:debug("blah: "..result)
	
	local itemType = JSON:decode(result).entity.type
	if itemType~="album" then
		return r
	end
	logger:debug("blah: "..itemType)
	
	local name = JSON:decode(result).entity.name or ""
	local title = JSON:decode(result).entity.title
	local id = JSON:decode(result).entity.id
	local path = curPath.."/"..name
	path = string.gsub(path, "//", "/")
	
	r[#r+1] = {name=name, title=title, id=id, path=path}
	
	local members = JSON:decode(result).members
	for k,v in pairs(members) do
		local newUrl = v.."?type=album"
		r = fetchSubalbums(newUrl, propertyTable, r, path)
	end
	
	return r
end


--[[function G3Api.reorderAlbum(id, idSequence, propertyTable)
	local result,hdrs = G3Api.get(G3Api.url(id, propertyTable), propertyTable)
	on_error(hdrs, "Error retrieving album information.")
	
	local members = JSON:decode(result).members
		
	-- What to do with items that are /not/ in the gallery?
	
end]]--


function G3Api.getComments(id, propertyTable)

	local result,hdrs = G3Api.get(G3Api.url(id, propertyTable), propertyTable)
	on_error(hdrs, "Error retrieving item information.", "item url: "..G3Api.url(id, propertyTable))
	
	logger:debug(G3Api.url(id, propertyTable))
	
	local commentUrl = JSON:decode(result).relationships.comments.url
	
	result,hdrs = G3Api.get(commentUrl, propertyTable)
	on_error(hdrs, "Error retrieving comment list.", "commentUrl="..commentUrl)
	
	local comments = JSON:decode(result).members
	
	--return
	
	local commentList = {}
	if #comments > 0 then
		for i,url in ipairs(comments) do
			result,hdrs = G3Api.get(url, propertyTable)
			on_error(hdrs, "Error retrieving comment information.")
			logger:debug("comment retrieved: "..result)
			
			local commentData = JSON:decode(result).entity
			
			table.insert( commentList, {
				commentId = commentData.id,	--(comment ID, if any, from service),
				commentText = commentData.text,	--(text of user comment),
				dateCreated = LrDate.timeFromPosixDate(tonumber(commentData.created)),	--(date comment was created, if available; Cocoa date format),
				username = commentData.author_id,	--(user ID, if any, from service),
				realname = commentData.guest_name or G3Api.getUserName(commentData.author_id, propertyTable),	--(user's actual name, if available),
				--url = "n/a"	--(URL, if any, for the comment),
			} )
		end
	end

	return commentList
end 


function G3Api.postComment(id, text, propertyTable)

	--local url = "http://aether.ath.cx/gallery3/index.php/rest/comments/"
	local pt = propertyTable
	--local url = pt.selectedAccount.url.."/"..(pt.selectedAccount.path_to_rest or nil).."/comments"
	local url = G3Api.url(nil, propertyTable, "comments")
	
	local headers = {
		{field = 'X-Gallery-Request-Method', value = "post" },
		{field = 'X-Gallery-Request-Key', value = propertyTable.selectedAccount.authkey },
	}	
	
    -- Add Basic Authentication Header
    if propertyTable.selectedAccount.basicauth_active then
       table.insert( headers, 
           { field = 'Authorization', value = 'Basic '..LrStringUtils.encodeBase64(propertyTable.selectedAccount.basicauth_user..":"..propertyTable.selectedAccount.basicauth_password) }
       )
    end
    -- End Basic Authentication Header
	
	local body = {text=text,
		item=G3Api.url(id, propertyTable)
	}

	body = JSON:encode(body)
	
	local mimeChunks = {
		{ name="entity", value=body },
	}
	
	local result, hdrs = LrHttp.postMultipart( url, mimeChunks, headers )
	on_error(hdrs, "Error posting comment", "url="..url.."; mimeChunks="..tostring(mimeChunks))
	
end


function G3Api.getUserName(userId, propertyTable)
	-- THIS IS NOT OFFICIAL YET!!
	
	local pt = propertyTable
	--local url = pt.selectedAccount.url.."/"..(pt.selectedAccount.path_to_rest or nil).."/user_profile/"..userId
	local url = G3Api.url(userId, propertyTable, "user")
	
	logger:debug("retrieve user info: url="..url)
	
	--local url = propertyTable.selectedAccount.url.."/index.php/rest/user_profile/"..userId

	local result,hdrs = G3Api.get(url, propertyTable)
	on_error(hdrs, "Error retrieving user information.")
	
	logger:debug("result:"..result)
	
	return JSON:decode(result).entity.display_name
end


function G3Api.checkIsItemThere(id, propertyTable)
	local result,hdrs = G3Api.get(G3Api.url(id, propertyTable), propertyTable)
	
	if hdrs.status == 404 then 
		return false
	end
	
	on_error(hdrs, "Error checking item presence for id "..id)
	
	return true
end



function G3Api.getPhotoIds(albumId, propertyTable)
	local url = G3Api.url(albumId, propertyTable)
	local result,hdrs = G3Api.get(url, propertyTable)
	on_error(hdrs, "Error retrieving item list.")
	
	local photos = {}
	
	local members = JSON:decode(result).members
	for k,v in pairs(members) do
		local r,h = G3Api.get(v, propertyTable)
		on_error(h, "Error retrieving member information")
		local itemType = JSON:decode(r).entity.type
		
		if itemType=="photo" then
			local id = JSON:decode(r).entity.id
			photos[id] = v
		end
	end
	
	return photos
end


-- downloads the image file of #photoid and returns a path to the downloaded file plus metadata
-- (title, description, name, id)
-- TO DO: PROPER RANDOMIZED PATH
function G3Api.getImageFile(photoId, propertyTable)
	local result,hdrs = G3Api.get(G3Api.url(photoId, propertyTable), propertyTable)
	on_error(hdrs, "Error retrieving item info", "getImgFile")
	
	logger:debug(result)
	local imageFileUrl = JSON:decode(result).entity.file_url
	local metadata = {
		id = photoId,
		name = JSON:decode(result).entity.name,
		title = JSON:decode(result).entity.title,
		description = JSON:decode(result).entity.description
	}
		
	logger:debug(imageFileUrl)
	
	local result,hdrs = G3Api.get(imageFileUrl, propertyTable)
	on_error(hdrs, "Error retrieving image file", "getImgFile")
	
	-- todo: proper randomized path!
	local path = "c:\\temp\\"..metadata["name"]
	
	-- todo: append .jpg if !! not there already
	
	file = io.open (path,"wb")
	file:write(result)
	file:close() 
	
	logger:debug("file written")
	LrDialogs.message("file written")
	
	return path, metadata
end




-- HELPERS --


--function to split strings, lua doesn't have this built in
function split(str, delimiter)
  local result = { }
  local from  = 1
  local delim_from, delim_to = string.find( str, delimiter, from  )
  while delim_from do
    table.insert( result, string.sub( str, from , delim_from-1 ) )
    from  = delim_to + 1
    delim_from, delim_to = string.find( str, delimiter, from  )
  end
  table.insert( result, string.sub( str, from  ) )
  return result
end


function url_link(a, b)
	a = string.gsub(a, "[\\/]+$", "")
	b = string.gsub(b, "^[\\/]+", "")
	
	return a.."/"..b
end







-- DEPRECATED --

--[[function G3Api.updateImage(id, filePath, fileName, title, description)
	logger:debug("UpdateImage id="..id..", filePath="..filePath..", fileName="..fileName)
	
	local url = G3Api.url(id)
	
	local headers = {
		{field = 'X-Gallery-Request-Method', value = "put" },
		{field = 'X-Gallery-Request-Key', value = prefs.authkey },
	}
    
    -- Add Basic Authentication Header
    if propertyTable.selectedAccount.basicauth_active then
       table.insert( headers, 
           { field = 'Authorization', value = 'Basic '..LrStringUtils.encodeBase64(propertyTable.selectedAccount.basicauth_user..":"..propertyTable.selectedAccount.basicauth_password) }
       )
    end
    -- End Basic Authentication Header
	
	local body = {}
	if title and title~="" then body.title = title end
	if description and description~="" then body.description = description end
	
	body = JSON:encode(body)
	
	logger:debug("UpdateImage: url="..url..", body="..body)
	
	local mimeChunks = {
		{ name="entity", value=body },
		{ name = 'file', fileName = fileName, filePath = filePath, contentType = 'application/octet-stream' }
	}
	
	local result, hdrs = LrHttp.postMultipart( url, mimeChunks, headers )
	on_error(hdrs, "Could not update image.")
	logger:debug("UpdateImage result "..hdrs.status.." "..result)
	
	return id
end]]--

--debug: display a dialog with string s on it.
--[[local function show(s)
	local f = LrView.osFactory()
	
	local contents = f:column {
		bind_to_object = properties,
		spacing = f:control_spacing(),
		fill = 1,
      
		f:static_text {
			title = s,
			alignment = 'lright',
			width = share 'title_width',
		},
	}
		
	LrDialogs.presentModalDialog {
		title = "pony", 
		contents = contents,
	}
end]]--