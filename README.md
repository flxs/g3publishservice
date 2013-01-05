# Gallery3 Publish Service for Lightroom 3/4 #

This plugin was previously located at [this site](http://felix.sappe.lt/?p=123).

Thanks to Jeffrey Friedl for his JSON.lua script that this plugin is using.

The current version is 0.3.5, download it from [here](https://github.com/flxs/g3publishservice/blob/3c7053a458496ad021e1a04a750a0a418c850d6f/G3PublishService.lrplugin.zip).

Please do contribute, this is (so far) a one-man show and I can't devote much work on this at the moment. I'm always happy to grant pull requests, though, so keep them coming.

For the record, if you fork this, do give credit where credit is due and don't sell any stuff that isn't yours. Just play nice, ok?



## The original Blog Post ##

Inspired by the Flickr integration in Lightroom 3, I've written a plugin to do quite the same for Gallery 3. It comes with both publish service and export dialogue integration and support for nested albums.

![Screenshot 1](http://felix.sappe.lt/wp-content/uploads/2010/09/screenshot1.png)


#### Important Notes ####
* Gallery versions before 3.0 final are not supported, neither are Lightroom versions before 3.0.
* I'm using it and it works for me, but you're using it at your own risk. If you come across a bug, please tell me about it in this [forum thread](http://gallery.menalto.com/node/97832) or use the comment form below.

#### What It Can Do ####

* Upload photos to a Gallery 3 installation   
When used as a publish service, it can update photos in the Gallery when you change their source images in the catalogue
* Save Export settings as presets - push a photo to your Gallery with two clicks
* Handle nested albums
* Create albums unless an album of the respective name already exists
* Delete photos and albums from the Gallery
* Use IPTC metadata for title and description
* Display and add comments to photos from within Lightroom

#### Recent changes ####

* **0.3.2:** Add Account dialogue contains an option to specify the relative path to the RESTful interface base; use only if you use alternative rewrite rules. In this case, set it to the rewritten version of the default value.
* **0.3.2:** Removed options for RC2 compatible uploads and disabling deletion of albums. Neither should be needed anymore.
* **0.3.3:** Repaired deleting albums. This should work now. Deleting existing collections can't be done because the plugin failed to remember whether they were created by itself or not. Deleting collections created with version 0.3.3 onward should work fine.
* **0.3.3:** Updating photos that aren't in the Gallery is handled more gracefully now (user is being prompted whether to delete locally or upload as new)
* **0.3.4:** Comment integration added; this requires the Gallery 3 module user_rest to be installed and activated.
* **0.3.4:** Short info text added to the create album dialog.
* **0.3.5:** Bug fix: Comment integration couldn't be properly disabled in some cases.

#### Known Issues ####

* **Error 400 Bad Content**: Some people experience "Code 400" errors on uploading or updating photos. I couldn't reproduce this yet; further information would be appreciated, especially a Wireshark trace of a failed upload attempt.

#### Naming Collections (this is important.) ####

Collection names correspond to album paths in the Gallery. That way, nested albums can be handled in a sane way, Lightroom sadly doesn't support nested collections. Album paths consist of the **names** of the target album and all parent albums. Album names are **not** the strings you see in the web interface; these are the album titles.

You can find out an album's path easily by looking at its URL (e.g. "xmas/2010" for http://cute-animals.com/g3/index.php/**xmas/2010/**.) Leading and trailing slashes can be omitted.

#### Comments ####

This plugin supports displaying and adding comments to Gallery photos. Since Gallery 3 does not expose all necessary information without an additional module, this feature is disabled by default. If you want to use it, make sure you've installed and activated the **REST User Resource** (user_rest) module (you can get it [here](http://www.gallerymodules.com/).)
Once you have, go into the publish settings dialog and activate the "Enable comment integration" checkbox. The plugin will then look up the admin user to make sure the module is really there and working; after this has finished, Save the settings.
If you now select a photo from a published collection, all comments for the respective photo are being displayed in the "Comments" section in the lower right sidebar. You can add a new comment by typing into the text field above the comments and pressing return.

#### Getting Started ####

Sorry for the German screenshots; if anyone would like to provide me with English ones, please do.

![Screenshot 3](http://felix.sappe.lt/wp-content/uploads/2010/09/screenshot3.png)

For the publish service, find the Gallery 3 entry at the bottom of the left sidebar. Click on "Set up". For the Export dialogue, choose **File, Export**. Add an account by clicking on "Add Account" and enter

* User name and Password for your Gallery account
* The URL to your Gallery 3 installation (no index.php)
* If you're using alternative rewrite rules, you need to enter the rewritten relative path to the REST base, too.

Hit OK. Choose the Account from the dropdown list.

![Screenshot 4](http://felix.sappe.lt/wp-content/uploads/2010/09/screenshot4.png)


If you're in the export dialogue, you have to select a target album now in the section of that name. Note that the dropdown list is empty; since albums don't change too frequently and since presets wouldn't work otherwise, the album structure is not being synchronized automatically. Instead you need to click the "(Re)Load Albums" button. You may then choose an album from the dropdown list and either use that or create a new album inside it (using the "Create Album" button.) I'd like to stress that changes on the server will only be reflected in the album list once you've reloaded the album structure.

Customize all other options to your liking and hit Save/Export. If you're on the Export dialogue, you're done now.

For the publish service, you can now either drag photos to the "Photos in Gallery Root" collection, or create a new collection. To do the latter, right-click on the Publish Service title and select "Create album". Choose the album name carefully; it corresponds to the path of the album that shows up in its URL (e.g. "xmas/2010" for http://cute-animals.com/g3/index.php/**xmas/2010/**.) For that reason, you can only use alphanumeric characters and "_-/". If some of the albums in the specified path don't exist, they will be created later, and you will be asked for an album title then. Drag some photos into your new album, right-click the album and select "Publish". If an album needs to be created, you will now be prompted for a title.

If you make any change to a published photo (like edit the title or add some more brightness) the photo will be marked for being re-published and the server copy updated once you re-publish the corresponding collection.

You can also delete photos and whole albums; if you choose to do so, the deleted photos will be removed from the Gallery on the next publish. Albums are only removed if they were created by the plugin and don't contain any photos that don't belong to the plugin.

#### Other Notes ####

* **Log file:** The plugin writes a rather extensive log file to **My Documents\g3.log** or **~/Documents/g3.log** on Windows and Mac respectively. There shouldn't be anything sensitive in there and the information isn't being sent anywhere or the like, it just sits there in case debug information is needed. I'll disable that once the plugin reaches a certain degree of stability.
