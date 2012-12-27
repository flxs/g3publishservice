local LrView = import "LrView"
local LrHttp = import "LrHttp"
local bind = import "LrBinding"
local app = import 'LrApplication'

 return {
	--[[sectionsForTopOfDialog = function(f, p)
		return {
			-- section for the top of the dialog
			{
				title = "Custom Metadata Sample",
				f:row {
					spacing = f:control_spacing(),
					f:static_text {
						title = 'Click the button to find out more about Adobe',
						alignment = 'left',
						fill_horizontal = 1,
					},
					f:push_button {
						width = 150,
						title = 'Connect to Adobe',
						enabled = true,
						action = function()
							LrHttp.openUrlInBrowser(_G.URL)
						end,
					},
				},
			},
		}
	end]]--
}