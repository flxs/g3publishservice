require 'G3Api'

local prefs = import 'LrPrefs'.prefsForPlugin()
local LrView = import 'LrView'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrErrors = import 'LrErrors'
local bind = LrView.bind
local share = LrView.share

local LrLogger = import 'LrLogger'
local logger = LrLogger("g3")
logger:enable( "logfile" )

G3Dialogs = {}


function G3Dialogs.topSections(f, propertyTable)

	local sections = {
	{
		title = "Gallery 3 Account Information",
		synopsis = "Location of your Gallery 3 installation and credentials.",
		
		f:row {
			f:static_text {
				title = "Account: "
			},
		
			f:popup_menu {
				value = bind 'selectedAccount',
				items = bind {key = 'accounts', bind_to_object = prefs, transform=function(v,t)
					local r = {}
					for k,v in pairs(prefs.accounts) do
						r[#r+1] = {title = k, value = v}
					end
					return r
				end},
				fill_horizontal = 1
			},
			
			f:push_button {
				title = "Renew Key",
				action = function() renew_key(propertyTable.selectedAccount) end
			},
			
			f:push_button {
				title = "Delete",
				action = function() delete_account(propertyTable.selectedAccount) end
			},
			
			f:separator {
				fill_vertical = 1
			},
			
			f:push_button {
				title = "Add Account",
				action = add_account
			},
			
			
		}
	}}

	
	-- ALBUM SELECTOR
	
	if not propertyTable.LR_isExportForPublish then
	table.insert( sections, {
		title = "Target Album",
		synopsis = "Where to place the exported images",
		
		
		f:row {
			f:popup_menu {
					value = bind 'selectedAlbum',
					items = bind {key = 'albums',
						transform=function(v,t)
							local r = {}
							for i,v in ipairs(propertyTable.albums) do
								r[#r+1] = {title = v.path, value = v}
							end
							return r
						end
					},
					fill_horizontal = 1
				},
			f:push_button {
				title = "(Re)Load Albums",
				action = function() 
					LrTasks.startAsyncTask( function()
						propertyTable.albums = G3Api.fetchAlbums(propertyTable)
						LrDialogs.message("Finished fetching albums.")
					end)
				end
			},
			f:push_button {
				title = "Create Album",
				action = function() 
					LrTasks.startAsyncTask( function()
						local name, title
						while(not name or not title) do
							name, title = G3Dialogs.showCreateAlbumDialog(propertyTable)
						end
						
						G3Api.createAlbum(
							G3Api.url(propertyTable.selectedAlbum.id, propertyTable), name, propertyTable, title)
						
						LrTasks.startAsyncTask( function()
							propertyTable.albums = G3Api.fetchAlbums(propertyTable) 
						end)
						
						LrDialogs.message("Album created successfully.")
					end)
				end
			},
		}
	}
	)
	end
	--}
	--end
	
	return sections

end


function get_account_keys()
	local r = {}
	for k,v in pairs(prefs.accounts) do
		r[#r+1] = k
	end
	return r
end


function add_account()
	LrTasks.startAsyncTask( function()

		local authKey,url,user,path_to_rest = G3Dialogs.showLoginDialogAndLogin()
		--handle cancel
		if not authKey then 
			return
		end
		
		local k = url.." - "..user.." - "..string.sub(authKey, 1, 10).."..."
		--prefs.accounts = {}
		prefs.accounts[k] = {authkey = authKey, user = user, url = url, identifier = k, path_to_rest = path_to_rest}
		
		--force the observable table to propagate the change
		prefs.accounts = prefs.accounts
		
		LrDialogs.message("Account added.")
	end)
end


function delete_account(account)
	
	
	LrDialogs.confirm( "Confirm", "Are you sure you want to proceed?", "Yeah", "Cancel")
	
	prefs.accounts[account.identifier] = nil
	
	LrDialogs.message("Account deleted.")
	
	--force the observable table to propagate the change
	prefs.accounts = prefs.accounts
end


function renew_key(account)
	LrTasks.startAsyncTask( function()
		
		LrFunctionContext.callWithContext( 'login dialog', function( context )
			local f = LrView.osFactory()
			local properties = LrBinding.makePropertyTable( context )
			local contents = f:column {
				bind_to_object = properties,
				spacing = f:control_spacing(),
				fill = 1,
			  
				f:static_text {
					title = "Password:",
					width = share 'title_width',
				},
				f:password_field { 
					width_in_chars = 35, 
					value = bind 'pass',
				},
			}
			
			local result = LrDialogs.presentModalDialog {
				title = "Password", 
				contents = contents,
			}
			
			if result=="ok"  then
				--attempt to fetch key
				local key = G3Api.retrieveKey(account.url, account.user, properties.pass or "")
				if key==403 or key==404 then LrDialogs.message("Error", "Wrong URL or credentials.")
				else
					prefs.accounts[account.identifier].authkey = key
					LrDialogs.message("Auth Key renewed.")
				end
			end
		end)
		
	end)
end


function G3Dialogs.showCreateAlbumTitleDialog(propertyTable, name)
	local title
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
	end)
	
	return title
end


function G3Dialogs.showCreateAlbumDialog(propertyTable)
	local title
	local name
	LrFunctionContext.callWithContext( 'FlickrAPI.showApiKeyDialog', function( context )
		local f = LrView.osFactory()
		local properties = LrBinding.makePropertyTable( context )
		
		local contents = f:column {
			bind_to_object = properties,
			spacing = f:control_spacing(),
			fill = 1,
      
			f:row {
				f:static_text {
					title = "Title: ",
					alignment = 'lright',
					width = share 'title_width',
				},
				
				f:edit_field { 
					fill_horizonal = 1,
					width_in_chars = 35, 
					value = bind 'title',
				
				},
			},
			
			f:row {
				f:static_text {
					title = "Name: ",
					alignment = 'lright',
					width = share 'title_width',
				},
				
				f:edit_field { 
					fill_horizonal = 1,
					width_in_chars = 35, 
					value = bind 'name',
				
				},
			},
		}
		
		local result = LrDialogs.presentModalDialog {
			title = "pony", 
			contents = contents,
		}
		
		if(result=="ok") then
			title = properties.title
			name = properties.name
		else
			LrErrors.throwCanceled()
		end
	end)
	
	return name,title
end


function G3Dialogs.showLoginDialogAndLogin()
	return LrFunctionContext.callWithContext( 'login dialog', function( context )
	local key
	local url

	local f = LrView.osFactory()
	local properties = LrBinding.makePropertyTable( context )
	properties.rest_path = "/index.php/rest/"
	--properties.url = prefs.url
	--properties.user = prefs.user


	local contents = f:column {
		bind_to_object = properties,
		spacing = f:control_spacing(),
		fill = 1,
      
		f:row {
			spacing = f:label_spacing(),
			f:static_text {
				title = "User",
				alignment = 'lright',
				width = share 'title_width',
			},
			f:edit_field { 
				fill_horizonal = 1,
				width_in_chars = 35, 
				value = bind 'user',
			},
		},
      
		f:row {
			spacing = f:label_spacing(),
			f:static_text {
				title = "Password",
				alignment = 'lright',
				width = share 'title_width',
			},
			f:password_field { 
				fill_horizonal = 1,
				width_in_chars = 35, 
				value = bind 'pass',
			},
		},
      
		f:row {
			spacing = f:label_spacing(),
			f:static_text {
				title = "Gallery URL",
				alignment = 'lright',
				width = share 'title_width',
			},
			f:edit_field { 
				fill_horizonal = 1,
				width_in_chars = 35, 
				value = bind 'url',
			},
		},
		
		f:row {
			spacing = f:label_spacing(),
			f:static_text {
				title = "Path to REST base:",
				alignment = 'lright',
				width = share 'title_width',
			},
			f:edit_field { 
				fill_horizonal = 1,
				width_in_chars = 35, 
				value = bind 'rest_path',
			},
		},
		
		--[[f:row {
			spacing = f:label_spacing(),
			f:checkbox { 
				title = "URL to RESTful interface (like http://bla.com/g3/index.php/rest/)",
				fill_horizonal = 1,
				width_in_chars = 35, 
				value = bind 'url_is_rest',
			},
		},]]--
    }
    
	
	while true do
	local result = LrDialogs.presentModalDialog {
		title = "Login", 
		contents = contents,
	}
	
	if result == 'ok' then
		--strip trailing slash off url
		if string.sub(properties.url, #properties.url) == "/" then
			properties.url = string.sub(properties.url, 1, #properties.url-1)
		end
		--strip any trailing index.php
		if string.sub(properties.url, #properties.url-9, #properties.url) == "/index.php" then
			properties.url = string.sub(properties.url, 1, #properties.url-9)
		end
		
		--attempt to fetch key
		local key = G3Api.retrieveKey(properties.url.."/"..properties.rest_path, properties.user, properties.pass or "")
		--if forbidden, then credentials are wrong
		if key==403 then LrDialogs.message("Error", "Wrong user name or password.")
		--if 404, then the url is wrong
		elseif key==404 then LrDialogs.message("Error", "Wrong Gallery URL.")
		else
			--prefs.authkey = key
			--prefs.url = properties.url
			--prefs.user = properties.user

			return key, properties.url, properties.user, properties.rest_path
		end
	else
		LrErrors.throwCanceled()	
	end
      end
  end)
end



function G3Dialogs.bottomSections(f, propertyTable)
	local sections = {
      {
        title = "Gallery Publish Options",
        
        synopsis = "Other options",

        --[[f:row {
          spacing = f:control_spacing(),

          f:checkbox {
            title = "When a collection is deleted, remove the corresponding album and all (empty) parent albums that were created by this plugin instance",
			value = bind {key="deleteAlbums"}
          },
		  
		},]]--
		
		f:row {
          spacing = f:control_spacing(),

          f:checkbox {
            title = "Extract title and description from IPTC metadata",
			value = bind {key="useIPTC"}
          },
		  
		},
		
		f:row {
          spacing = f:control_spacing(),

          f:checkbox {
            title = "Open album in browser after export",
			value = bind {key="openAlbumAfterExport"}
          },
		  
		},
		
		f:row {
          spacing = f:control_spacing(),

          f:checkbox {
            title = "Enable comment integration (Gallery module user_rest must be enabled!)",
			visible = propertyTable.LR_isExportForPublish or false,
			value = bind {key="commentIntegrationEnabled"},
          },
		  
		},
      },
	}
	
	
	-- add a validate mechanism that checks if enabling comments can be done (if user_rest is active)
	propertyTable:addObserver( "commentIntegrationEnabled", function(tbl, key, val)
		if val==false then return end	-- don't do any checks when disabling comments
		
		LrTasks.startAsyncTask( function() --so we can wait (for http requests)
			LrFunctionContext.callWithContext( 'yadda', function( context )	--we need a context obj for the progress dialog
				local progressScope = LrDialogs.showModalProgressDialog {
					title = "Cuddle with Pony",
					caption = "Checking whether user information can be accessed or not.",
					functionContext = context }	
				
				local result, hdrs = G3Api.get(G3Api.url(1, propertyTable, "user"), propertyTable)
				if hdrs.status and hdrs.status==200 then
					logger:debug("OK, can retrieve user info")
				else
					logger:debug("Can't retrieve user info")
					progressScope:done()
					
					propertyTable.commentIntegrationEnabled = false
					LrDialogs.message("Can't retrieve user information. Please make sure the module user_rest is enabled in your Gallery 3 installation.")
				end
				
			end)--end of call with context
		
		end)--end of async task
	end)	
	
	
	
	return sections
	
end


-- returns either "delete" or "reupload"
function G3Dialogs.showMissingPhotoDialog(photoId, photoName)
	local pony = LrDialogs.confirm( 
		"Missing Photo", 
		"The photo "..photoName.." with ID "..photoId.." is missing from the Gallery. What do you want to do?",
		"Upload as new", 
		"Cancel", 
		"Remove from local album"
	)

	if pony=="ok" then	-- upload as new
		return "reupload"
	elseif pony=="other" then	-- delete
		return "delete"
	else
		LrErrors.throwCanceled()
	end
	
	
end




































