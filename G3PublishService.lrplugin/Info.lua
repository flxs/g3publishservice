

return {

	LrSdkVersion = 3.0,
	LrSdkMinimumVersion = 3.0, -- minimum SDK version required by this plug-in

	LrToolkitIdentifier = 'net.nesciens.publish.gallery3',
	LrPluginName = "Gallery 3 Publish Service",
	LrPluginInfoUrl = "http://felix.nesciens.net/?p=123",
	
	LrExportServiceProvider = {
		title = "Gallery 3",
		file = 'G3PublishServiceProvider.lua',
	},
	
	LrPluginInfoProvider = 'LRInfoProvider.lua',
	
	VERSION = { major=0, minor=3, revision=6, build=0, },
	
	LrInitPlugin = 'LRInitPlugin.lua'

}