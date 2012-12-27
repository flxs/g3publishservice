local prefs = import 'LrPrefs'.prefsForPlugin()

if not prefs.createdAlbums then prefs.createdAlbums = {} end
if not prefs.accounts then prefs.accounts = {} end

local LrLogger = import 'LrLogger'
local logger = LrLogger("g3")
logger:enable( "logfile" )
logger:debug("Init script finished.")