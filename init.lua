local Cron = require("Cron")
local GameUI = require("GameUI")
local GameSettings = require('GameSettings')
local version = "1.7.0"
local cetOpen = false
local toggleNRD = false
local toggleDLSSDPT = true
local toggleFog = true
local toggleFogClouds = true
local volumetricFog = true
local distantVolumetricFog = true
local distantFog = true
local clouds = true
local tonemapping = true
local vehicleCollisions = true
local lensFlares = true
local bloom = true
local rain = true
local rainMap = true
local DOF = false
local chromaticAberration = true
local filmGrain = true
local RIS = false
local motionBlur = false
local graphics = true
local stopVehicleSpawning = true
local vehicleSpawning = true
local crowdSpawning = true
local timeSliderWindowOpen = false
local hasResetOrForced = false
local weatherReset = false
local resetWindow = false
local currentWeatherState = nil
local timeScale = 1.0

local weatherStateNames = {}

local settings =
{
	Current = {
		weatherState = 'None',
		transitionDuration = 0,
		timeSliderWindowOpen = false,
		warningMessages = true,
		notificationMessages = true,
	},
	Default = {
		weatherState = 'None',
		transitionDuration = 0,
		timeSliderWindowOpen = false,
		warningMessages = true,
		notificationMessages = true,
	}
}

local ui = {
	tooltip = function(text)
		if ImGui.IsItemHovered() and text ~= "" then
			ImGui.BeginTooltip()
			ImGui.SetTooltip(text)
			ImGui.EndTooltip()
		end
	end
}

-- Define the weather states
local weatherStates = {
	-- Each state is defined by a list containing the state's ID, name, category, and a flag indicating if it enables DLSSDSeparateParticleColor
 -- { '24h_weather_state_name',     'Localized Name', Category, DLSSD Flag}
	{ '24h_weather_sunny',          'Sunny',          1, 		false },
	{ '24h_weather_light_clouds',   'Light Clouds',   1, 		false },
	{ '24h_weather_cloudy',         'Clouds',         1, 		false },
	{ '24h_weather_heavy_clouds',   'Heavy Clouds',   1, 		false },
	{ '24h_weather_fog',            'Fog',            1, 		false },
	{ '24h_weather_rain',           'Rain',           1, 		true },
	{ '24h_weather_toxic_rain',     'Toxic Rain',     1, 		true },
	{ '24h_weather_pollution',      'Pollution',      1, 		false },
	{ '24h_weather_sandstorm',      'Sandstorm',      1, 		true },
	{ 'q302_light_rain',            'Rain (Quest)',   1, 		true },
	{ '24h_weather_fog_dense',      'Dense Fog',      2, 		false },
	{ '24h_weather_dew',            'Dew',            2, 		true },
	{ '24h_weather_haze',           'Haze',           2, 		false },
	{ '24h_weather_haze_heavy',     'Heavy Haze',     2, 		false },
	{ '24h_weather_haze_pollution', 'Haze Pollution', 2, 		false },
	{ '24h_weather_smog',           'Smog',           2, 		false },
	{ '24h_weather_clear',          'Sunny (Clear)',  2, 		true },
	{ '24h_weather_drizzle',        'Drizzle',        2, 		true },
	{ '24h_weather_windy',          'Windy',          2, 		true },
	{ '24h_weather_sunny_windy',    'Sunny Windy',    2, 		true },
	{ '24h_weather_storm',          'Rain (Storm)',   2, 		true },
	{ '24h_weather_overcast',       'Overcast',       2, 		false },
	{ '24h_weather_drought',        'Drought',        2, 		false },
	{ '24h_weather_humid',          'Humid',          2, 		false },
	{ '24h_weather_fog_wet',        'Wet Fog',        3, 		true },
	{ '24h_weather_fog_heavy',      'Heavy Fog',      3, 		false },
	{ '24h_weather_sunny_sunset',   'Sunset',         3, 		false },
	{ '24h_weather_drizzle_light',  'Light Drizzle',  3, 		true },
	{ '24h_weather_light_rain',     'Light Rain',     3, 		true },
	{ '24h_weather_rain_alt_1',     'Rain (Alt 1)',   3, 		true },
	{ '24h_weather_rain_alt_2',     'Rain (Alt 2)',   3, 		true },
	{ '24h_weather_mist',           'Fog (Mist)',     3, 		true },
	{ '24h_weather_courier_clouds', 'Dense Clouds',   3, 		false },
	{ '24h_weather_downpour',       'Downpour',       4, 		true },
	{ '24h_weather_drizzle_heavy',  'Heavy Drizzle',  4, 		true },
	{ '24h_weather_distant_rain',   'Rain (Distant)', 4, 		true },
	{ '24h_weather_sky_softbox',    'Softbox',        5, 		false },
	{ '24h_weather_blackout',       'Blackout',       5, 		false },
	{ '24h_weather_showroom',       'Showroom',       5, 		false }
}

function setResolutionPresets(width, height)
	local presets = {
	 -- { 1,    2,    3,  4, 5, 6, 7, 8, 9, 10, 11,   12,  13, 14, 15,   16, 17, 18,  19, 20, 21, 22,  23,  24,  25,   26, 27, 28, 29, 30, 31, 32  },
		{ 3840, 2160, 8,  6, 5, 5, 6, 7, 1, 1,  0.7,  140, 34, 36, 0.62, 1,  6,  320, 33, 12, 6,  650, 250, 336, 7.5,   9,  8,  10, 34, 34, 22, 140 },
		{ 2560, 1440, 8,  6, 1, 3, 6, 7, 1, 1,  0.45, 122, 28, 28, 0.85, 1,  8,  272, 29, 10, 4,  500, 219, 298, 7.5,  8,  8,  10, 32, 32, 18, 125 },
		{ 1920, 1080, 5,  4, 1, 4, 6, 6, 1, 1,  0.5,  100, 24, 24, 0.85, 1,  0,  221, 21, 8,  4,  400, 169, 230, 4.8,  9,  8,  10, 27, 27, 16, 100 },
		{ 0,    0,    5,  4, 1, 4, 6, 6, 1, 1,  0.5,  100, 24, 24, 0.85, 1,  0,  221, 21, 8,  4,  400, 169, 230, 4.8,  9,  8,  10, 27, 27, 16, 100 }
	}

	for _, preset in ipairs(presets) do
		if width >= preset[1] and height >= preset[2] then
			itemSpacingXValue = preset[3]
			itemSpacingYValue = preset[4]
			framePaddingXValue = preset[5]
			framePaddingYValue = preset[6]
			glyphFramePaddingXValue = preset[7]
			glyphFramePaddingYValue = preset[8]
			glyphItemSpacingXValue = preset[9]
			glyphItemSpacingYValue = preset[10]
			glyphAlignYValue = preset[11]
			buttonWidth = preset[12]
			buttonHeight = preset[13]
			unused = preset[14]
			customFontScale = preset[15]
			defaultFontScale = preset[16]
			dummySpacingYValue = preset[17]
			uiMinWidth = preset[18]
			buttonPaddingRight = preset[19]
			searchPaddingXValue = preset[20]
			searchPaddingYValue = preset[21]
			uiTimeMinWidth = preset[22]
			uiTimeMinHeight = preset[23]
			uiTimeMaxHeight = preset[24]
			uiTimeHourRightPadding = preset[25]
			frameTabPaddingXValue = preset[26]
			frameTabPaddingYValue = preset[27]
			itemTabSpacingYValue = preset[28]
			glyphButtonWidth = preset[29]
			glyphButtonHeight = preset[30]
			timeSliderPadding = preset[31]
			toggleSpacingXValue = preset[32]
			break
		end
	end
end

-- Register a CET hotkey to reset weather
registerHotkey('NCTResetWeather', 'Reset Weather', function()
    Game.GetWeatherSystem():ResetWeather(true)
    settings.Current.weatherState = 'None'
    -- settings.Current.nativeWeather = 1
    Game.GetPlayer():SetWarningMessage("Weather reset to default cycles! \nWeather states will progress automatically.")
    GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", true)
    toggleDLSSDPT = true
    SaveSettings()
    weatherReset = true
end)

-- Register a CET hotkey to toggle freeze time
registerHotkey('NCTFreezeToggle', 'Freeze Time Toggle', function()
    if timeScale == 0 then
        timeScale = previousTimeScale or 1.0
        if settings.Current.warningMessages then
            ShowWarningMessage("Time resumed at " .. previousTimeScale .. "x speed!")
        end
        if settings.Current.notificationMessages then
            ShowNotificationMessage("Time resumed at " .. previousTimeScale .. "x speed!")
        end
    else
        if settings.Current.warningMessages then
            ShowWarningMessage("Time frozen!")
        end
        if settings.Current.notificationMessages then
            ShowNotificationMessage("Time frozen!")
        end
        previousTimeScale = timeScale
        timeScale = 0
    end
    Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(timeScale ~= 1)
    if timeScale == 1 then
        Game.GetTimeSystem():UnsetTimeDilation("consoleCommand")
    else
        Game.GetTimeSystem():SetTimeDilation("consoleCommand", timeScale)
    end
end)

-- Register a CET hotkey to increase time scale
registerHotkey('NCTIncreaseTime', 'Increase Time Scale', function()
    if timeScale < 0.01 then
        timeScale = timeScale + 0.001
    elseif timeScale < 0.1 then
        timeScale = timeScale + 0.01
    elseif timeScale < 1.0 then
        timeScale = timeScale + 0.1
    else
        timeScale = timeScale + 1.0
    end
    Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(timeScale ~= 1)
    Game.GetTimeSystem():SetTimeDilation("consoleCommand", timeScale)
    if settings.Current.warningMessages then
        ShowWarningMessage("Time scale increased to " .. timeScale .. "x speed!")
    end
    if settings.Current.notificationMessages then
        ShowNotificationMessage("Time scale increased to " .. timeScale .. "x speed!")
    end
end)

-- Register a CET hotkey to decrease time scale
registerHotkey('NCTDecreaseTime', 'Decrease Time Scale', function()
    if timeScale <= 0.01 then
        timeScale = timeScale - 0.001
        if timeScale < 0.001 then timeScale = 0.001 end -- Prevent time scale from going below 0.001
    elseif timeScale <= 0.1 then
        timeScale = timeScale - 0.01
        if timeScale < 0.01 then timeScale = 0.01 end -- Prevent time scale from going below 0.01
    elseif timeScale <= 1.0 then
        timeScale = timeScale - 0.1
        if timeScale < 0.1 then timeScale = 0.1 end -- Prevent time scale from going below 0.1
    else
        timeScale = timeScale - 1.0
    end
    Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(timeScale ~= 1)
    Game.GetTimeSystem():SetTimeDilation("consoleCommand", timeScale)
    if settings.Current.warningMessages then
        ShowWarningMessage("Time scale decreased to " .. timeScale .. "x speed!")
    end
    if settings.Current.notificationMessages then
        ShowNotificationMessage("Time scale decreased to " .. timeScale .. "x speed!")
    end
end)

-- Register a CET hotkey to reset time scale to 1.0
registerHotkey('NCTResetTime', 'Reset Time Scale', function()
    timeScale = 1.0
    Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(false)
    Game.GetTimeSystem():UnsetTimeDilation("consoleCommand")
    if settings.Current.warningMessages then
        ShowWarningMessage("Time scale reset to 1.0x speed!")
    end
    if settings.Current.notificationMessages then
        ShowNotificationMessage("Time scale reset to 1.0x speed!")
    end
end)

-- Register an HDR hotkey toggle
registerHotkey('NCTHDRToggle', 'Toggle HDR Mode', function()
    local options, current = GameSettings.Options('/video/display/HDRModes')
    local hdrMode = (current % 2) + 1

    -- Change labels
    local displayOptions = { "SDR", "HDR" }

    GameSettings.Set('/video/display/HDRModes', options[hdrMode])
    GameSettings.Save()
    
    if GameSettings.NeedsConfirmation() then
        GameSettings.Confirm()
    end

    if settings.Current.warningMessages then
        ShowWarningMessage(('Switched display mode from %s to %s'):format(displayOptions[current], displayOptions[hdrMode]))
    end
    if settings.Current.notificationMessages then
        ShowNotificationMessage(('Switched display mode from %s to %s'):format(displayOptions[current], displayOptions[hdrMode]))
    end
end)


function DrawWeatherControl()
	ImGui.Dummy(0, dummySpacingYValue)
	ImGui.Separator()
	ImGui.Text("Weather Control:")

	-- Make the reset button fit the width of the GUI
	local resetButtonWidth = ImGui.GetWindowContentRegionWidth()
	if ImGui.Button('Reset Weather', resetButtonWidth, 30) then
		Game.GetWeatherSystem():ResetWeather(true)
		settings.Current.weatherState = 'None'
		-- settings.Current.nativeWeather = 1
		Game.GetPlayer():SetWarningMessage("Weather reset to default cycles! \nWeather states will progress automatically.")
		GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", true)
		toggleDLSSDPT = true
		SaveSettings()
		weatherReset = true
	end

	ui.tooltip("Reset any manually selected states and returns the weather to \nits default weather cycles, starting with the sunny weather state. \nWeather will continue to advance naturally.")

	local selectedWeatherState = settings.Current.weatherState
	if selectedWeatherState == 'None' then
		selectedWeatherState = 'Default Cycles'
	else
		selectedWeatherState = 'Locked State'
	end
	ImGui.Text("Mode:  " .. selectedWeatherState)
	ui.tooltip("Default Cycles: Weather states will transition automatically. \nLocked State: User selected weather state.")

	ImGui.Text("State:")
	ImGui.SameLine()

	local currentWeatherState = Game.GetWeatherSystem():GetWeatherState().name.value
	for _, state in ipairs(weatherStates) do
		if state[1] == currentWeatherState then
			currentWeatherState = state[2]
			break
		end
	end
	ImGui.Text(currentWeatherState)
end

registerForEvent("onUpdate", function()
	Cron.Update(delta)
	if hasResetOrForced == true then
		local resetorforcedtimer = Cron.After(0.5, function()
			hasResetOrForced = false
		end)
	end
	if not Game.GetPlayer() or Game.GetSystemRequestsHandler():IsGamePaused() then return end
	local newWeatherState = tostring(Game.GetWeatherSystem():GetWeatherState().name.value)
	if newWeatherState ~= currentWeatherState then
		currentWeatherState = newWeatherState
		local localizedState = weatherStateNames[currentWeatherState]
		local messageText = "Weather changed to " .. (localizedState or currentWeatherState)
		-- Only send weather change notifications if the weather has not been reset
		if hasResetOrForced == false and not weatherReset then
			if resetorforcedtimer then
				Cron.Halt(resetorforcedtimer)
				resetorforcedtimer = nil
			end
			if settings.Current.warningMessages then
				ShowWarningMessage(messageText)
			end
			if settings.Current.notificationMessages then
				ShowNotificationMessage(messageText)
			end
		end
		-- Reset the weather reset flag after the weather change notification has been skipped
		weatherReset = false
	end
end)

function DrawButtons()
	-- Check if the CET window is open
	if not cetOpen then
		return
	end

	-- Set window size constraints
	ImGui.SetNextWindowSizeConstraints(uiMinWidth, 10, width / 100 * 50, height / 100 * 90)
	if resetWindow then
		ImGui.SetNextWindowPos(6, 160, ImGuiCond.Always)
		ImGui.SetNextWindowSize(312, 1110, ImGuiCond.Always)
		ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 5)
		ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 5)
		resetWindow = false
	end
	if ImGui.Begin('Nova City Tools - v' .. version, true, ImGuiWindowFlags.NoScrollbar) then
		-- Reset padding
		ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, frameTabPaddingXValue, frameTabPaddingYValue)
		ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, itemTabSpacingYValue)

		-- Set the font scale for the window
		ImGui.SetWindowFontScale(customFontScale)

		local availableWidth = ImGui.GetContentRegionAvail() - buttonPaddingRight

		if ImGui.BeginTabBar("Nova Tabs") then
			ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize('XXX'))

			-- TIME SLIDER TOGGLE ------------------------
			-- Set button text alignment and frame padding
			ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
			ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, glyphFramePaddingXValue, glyphFramePaddingYValue)

			-- Create the button and toggle the time slider window
			if timeSliderWindowOpen then
				ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0.0, 1, 0.7, 1))
				ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0, 0, 0, 1))
				if ImGui.Button(IconGlyphs.ClockOutline, glyphButtonWidth, glyphButtonHeight) then
					timeSliderWindowOpen = false
					settings.Current.timeSliderWindowOpen = timeSliderWindowOpen
					SaveSettings()
				end
				ImGui.PopStyleColor(2)
			else
				if ImGui.Button(IconGlyphs.ClockOutline, glyphButtonWidth, glyphButtonHeight) then
					timeSliderWindowOpen = true
					settings.Current.timeSliderWindowOpen = timeSliderWindowOpen
					SaveSettings()
				end
			end

			-- Show tooltip
			ui.tooltip("Toggles the time slider window.")

			-- Reset style variables
			ImGui.PopStyleVar(2)

			if ImGui.BeginTabItem("Weather") then
				-- Push style variables for frame padding and item spacing INSIDE the tabs
				ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, framePaddingXValue, framePaddingYValue)
				ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, itemSpacingXValue, itemSpacingYValue)

				--if ImGui.BeginTabItem(IconGlyphs.WeatherPartlyCloudy) then
				local categories = { 'Vanilla States', 'Nova Beta States', 'Nova Alpha States', 'Nova Concept States',
					'Creative' }
				for i, category in ipairs(categories) do
					ImGui.Text(category)

					local windowWidth = ImGui.GetWindowWidth()
					local buttonsPerRow = math.floor(windowWidth / buttonWidth)
					local buttonCount = 0
					for _, state in ipairs(weatherStates) do
						local weatherState = state[1]
						local localization = state[2]
						local category = state[3]
						local enableDLSSDPT = state[4] -- Get the DLSSDSeparateParticleColor flag
						if category == i then
							local isActive = settings.Current.weatherState == weatherState
							if isActive then
								ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0.0, 1, 0.7, 1))
								ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0, 0, 0, 1))
							end
							if ImGui.Button(localization, buttonWidth, buttonHeight) then
								if isActive then
									Game.GetWeatherSystem():ResetWeather(true)
									settings.Current.weatherState = 'None'
									Game.GetPlayer():SetWarningMessage(
									"Weather reset to default cycles! \nWeather states will progress automatically.")
									GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", true)
									toggleDLSSDPT = true
									weatherReset = true
								else
									Game.GetWeatherSystem():SetWeather(weatherState, settings.transitionTime, 0)
									settings.Current.weatherState = weatherState
									Game.GetPlayer():SetWarningMessage("Locked weather state to " ..
									localization:lower() .. "!")
									GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", enableDLSSDPT)
									toggleDLSSDPT = enableDLSSDPT
								end
								SaveSettings()
							end
							if isActive then
								ImGui.PopStyleColor(2)
							end

							buttonCount = buttonCount + 1
							if buttonCount % buttonsPerRow ~= 0 then
								ImGui.SameLine()
							end
						end
					end

					if buttonCount % buttonsPerRow ~= 0 then
						ImGui.NewLine() -- Force a new line only if the last button is not on a new line
					end
				end

				DrawWeatherControl()
				ImGui.EndTabItem()
			end

			ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, frameTabPaddingXValue, frameTabPaddingYValue)
			ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, itemTabSpacingYValue)

			if ImGui.BeginTabItem("Toggles") then
				-- Push style variables for frame padding and item spacing INSIDE the tabs
				ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, framePaddingXValue, framePaddingYValue + 2)
				ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, itemSpacingXValue, itemSpacingYValue)

				ImGui.Dummy(0, 2)
				ImGui.Text("Grouped Toggles:")
				ImGui.Separator()

				toggleFogClouds, changed = ImGui.Checkbox('ALL: Volumetrics and Clouds', toggleFogClouds)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", toggleFogClouds)
					GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", toggleFogClouds)
					GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", toggleFogClouds)
					GameOptions.SetBool("Developer/FeatureToggles", "VolumetricClouds", toggleFogClouds)
					distantVolumetricFog = toggleFogClouds
					volumetricFog = toggleFogClouds
					distantFog = toggleFogClouds
					clouds = toggleFogClouds
					SaveSettings()

					-- Ensure ALL: Fog is also enabled/disabled
					toggleFog = toggleFogClouds
					GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", toggleFog)
					GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", toggleFog)
					GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", toggleFog)
					volumetricFog = toggleFog
					distantVolumetricFog = toggleFog
					distantFog = toggleFog
					SaveSettings()
				end
				ui.tooltip(
					"Toggles all fog and clouds: volumetric, distant volumetric, distant fog planes, and volumetric clouds.")

				toggleFog, changed = ImGui.Checkbox('ALL: Fog', toggleFog)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", toggleFog)
					GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", toggleFog)
					GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", toggleFog)
					volumetricFog = toggleFog
					distantVolumetricFog = toggleFog
					distantFog = toggleFog
					SaveSettings()

					if toggleFog and not toggleFogClouds then
						GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", true)
						GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", true)
						GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", true)
						volumetricFog = true
						distantVolumetricFog = true
						distantFog = true
						SaveSettings()
					end
				end
				ui.tooltip("Toggles all fog types: volumetric, distant volumetric, and distant fog plane.")

				ImGui.Dummy(0, dummySpacingYValue)
				ImGui.Text("Weather:")
				ImGui.Separator()

				volumetricFog, changed = ImGui.Checkbox('VFog', volumetricFog)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", volumetricFog)
					SaveSettings()
					if volumetricFog then
						GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", true)
						distantVolumetricFog = true
						SaveSettings()
					else
						GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", false)
						distantVolumetricFog = false
						SaveSettings()
					end
				end
				ui.tooltip("Toggle volumetric fog. Also disables Distant VFog.")

				ImGui.SameLine(toggleSpacingXValue)
				distantVolumetricFog, changed = ImGui.Checkbox('Distant VFog', distantVolumetricFog)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", distantVolumetricFog)
					SaveSettings()
					if distantVolumetricFog and not volumetricFog then
						GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", true)
						volumetricFog = true
						SaveSettings()
					end
				end
				ui.tooltip("Toggle distant volumetric fog. Also enables VFog if it's disabled.")

				distantFog, changed = ImGui.Checkbox('Fog', distantFog)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", distantFog)
					SaveSettings()
				end
				ui.tooltip("Toggle distant fog plane.")
				ImGui.SameLine(toggleSpacingXValue)
				clouds, changed = ImGui.Checkbox('Clouds', clouds)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles", "VolumetricClouds", clouds)
					SaveSettings()
				end
				ui.tooltip("Toggle volumetric clouds.")

				-- Update ALL: Fog and ALL: Volumetrics and Clouds based on individual toggles
				if not volumetricFog and not distantVolumetricFog and not distantFog then
					toggleFog = false
					GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", false)
					GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", false)
					GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", false)
					SaveSettings()
				end

				if not volumetricFog and not distantVolumetricFog and not distantFog and not clouds then
					toggleFogClouds = false
					GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", false)
					GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", false)
					GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", false)
					GameOptions.SetBool("Developer/FeatureToggles", "VolumetricClouds", false)
					SaveSettings()
				end

				-- Enable ALL: Fog if all individual fog toggles are enabled
				if volumetricFog and distantVolumetricFog and distantFog then
					toggleFog = true
					GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", true)
					GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", true)
					GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", true)
					SaveSettings()
				end

				-- Enable ALL: Volumetrics and Clouds if all individual toggles are enabled
				if volumetricFog and distantVolumetricFog and distantFog and clouds then
					toggleFogClouds = true
					GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", true)
					GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", true)
					GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", true)
					GameOptions.SetBool("Developer/FeatureToggles", "VolumetricClouds", true)
					SaveSettings()
				end

				ImGui.Dummy(0, dummySpacingYValue)
				ImGui.Text("Features:")
				ImGui.Separator()

				toggleNRD, changed = ImGui.Checkbox('NRD', toggleNRD)
				if changed then
					GameOptions.SetBool("RayTracing", "EnableNRD", toggleNRD)
					SaveSettings()
				end
				ui.tooltip("Nvidia Realtime Denoiser")
				ImGui.SameLine(toggleSpacingXValue)
				toggleDLSSDPT, changed = ImGui.Checkbox('DLSSDPT', toggleDLSSDPT)
				if changed then
					GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", toggleDLSSDPT)
					SaveSettings()
				end
				ui.tooltip("DLSSD Separate Particle Color - Disabling will reduce \ndistant shimmering but also makes other paricles invisible \nlike rain and debris particles. Disabling is not recommended. \nManually selecting a weather state will enable or disable \nthis as needed.")

				bloom, changed = ImGui.Checkbox('Bloom', bloom)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles", "Bloom", bloom)
					GameOptions.SetBool("Developer/FeatureToggles", "ImageBasedFlares", bloom)
					lensFlares = bloom
					SaveSettings()
				end
				ui.tooltip("Toggles bloom (also removes lens flare).")
				ImGui.SameLine(toggleSpacingXValue)
				lensFlares, changed = ImGui.Checkbox('Lens Flares', lensFlares)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles", "ImageBasedFlares", lensFlares)
					SaveSettings()

					if lensFlares and not bloom then
						GameOptions.SetBool("Developer/FeatureToggles", "Bloom", true)
						bloom = true
						SaveSettings()
					end
				end
				ui.tooltip("Toggles lens flare effect.")

				rainMap, changed = ImGui.Checkbox('Weather', rainMap)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles", "RainMap", rainMap)
					GameOptions.SetBool("Developer/FeatureToggles", "ScreenSpaceRain", rainMap)
					rain = rainMap
					SaveSettings()
				end
				ui.tooltip("Toggles all weather effects such as rain particles and wet surfaces.")
				ImGui.SameLine(toggleSpacingXValue)
				rain, changed = ImGui.Checkbox('SS Rain', rain)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles", "ScreenSpaceRain", rain)
					SaveSettings()

					if rain and not rainMap then
						GameOptions.SetBool("Developer/FeatureToggles", "RainMap", true)
						rainMap = true
						SaveSettings()
					end
				end
				ui.tooltip("Toggles screenspace rain effects, removing wet surfaces.")

				chromaticAberration, changed = ImGui.Checkbox('CA', chromaticAberration)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles", "ChromaticAberration", chromaticAberration)
					SaveSettings()
				end
				ui.tooltip("Toggles chromatic aberration.")
				ImGui.SameLine(toggleSpacingXValue)
				filmGrain, changed = ImGui.Checkbox('Film Grain', filmGrain)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles", "FilmGrain", filmGrain)
					SaveSettings()
				end
				ui.tooltip("Toggles film grain.")

				DOF, changed = ImGui.Checkbox('DOF', DOF)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles", "DepthOfField", DOF)
					SaveSettings()
				end
				ui.tooltip("Toggles depth of field.")
				ImGui.SameLine(toggleSpacingXValue)
				motionBlur, changed = ImGui.Checkbox('Motion Blur', motionBlur)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles", "MotionBlur", motionBlur)
					SaveSettings()
				end
				ui.tooltip("Toggles motion blur.")

				RIS, changed = ImGui.Checkbox('RIS', RIS)
				if changed then
					GameOptions.SetBool("RayTracing/Reference", "EnableRIS", RIS)
					SaveSettings()
				end
				ui.tooltip("Toggles Resampled Importance Sampling.")

				ImGui.Dummy(0, dummySpacingYValue)
				ImGui.Text("Utility:")
				ImGui.Separator()
				vehicleCollisions, changed = ImGui.Checkbox('Vehicle Collisions', vehicleCollisions)
				if changed then
					GameOptions.SetBool("Vehicle", "vehicleVsVehicleCollisions", vehicleCollisions)
					SaveSettings()
				end
				ui.tooltip("Toggles vehicle collisions. Great for driving through \n Night City with Nova City Population density!")
				crowdSpawning, changed = ImGui.Checkbox('Crowd Spawning', crowdSpawning)
				if changed then
					GameOptions.SetBool("Crowd", "Enabled", crowdSpawning)
					SaveSettings()
				end
				ui.tooltip("Toggles vehicle spawning.")
				stopVehicleSpawning, changed = ImGui.Checkbox('Vehicle Spawning', stopVehicleSpawning)
				if changed then
					if stopVehicleSpawning then
						GameOptions.SetBool("Traffic", "StopSpawn", false)
						vehicleSpawning = true
						SaveSettings()
					else
						GameOptions.SetBool("Traffic", "StopSpawn", true)
						vehicleSpawning = false
						SaveSettings()
					end
				end
				ui.tooltip("Toggles vehicle spawning.")

				ImGui.Dummy(0, dummySpacingYValue)
				ImGui.Text("Display:")
				ImGui.Separator()

				-- ImGui toggle button to switch between SDR and HDR
				enableHDR, changed = ImGui.Checkbox("HDR", enableHDR)
				if changed then
					-- do stuff
				end
				--ui.tooltip("Requires CET menu to be closed to complete display mode toggle.")
				ui.tooltip("Currently not working correctly. Use the CET binding hotkey instead.")
				
				ImGui.Dummy(0, dummySpacingYValue)
				ImGui.Text("Useless Toggles:")
				ImGui.Separator()
				tonemapping, changed = ImGui.Checkbox('Tonemapping', tonemapping)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles", "Tonemapping", tonemapping)
					SaveSettings()
				end
				ui.tooltip("This toggle serves absolutely no purpose and toggling \n it does nothing but make the game look bad and kills \n a puppy each time you do.")

					graphics, changed = ImGui.Checkbox('gRaPhiCs', graphics)
				if changed then
					GameOptions.SetBool("", "", graphics)
					SaveSettings()
				end
				ui.tooltip("Coming soon.")

				--DrawWeatherControl()
				ImGui.EndTabItem()
			end

			-- Reset padding
			ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, frameTabPaddingXValue, frameTabPaddingYValue)
			ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, itemTabSpacingYValue)

			if ImGui.BeginTabItem("Misc") then
				-- Push style variables for frame padding and item spacing INSIDE the tabs
				ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, framePaddingXValue, framePaddingYValue)
				ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, itemSpacingXValue, itemSpacingYValue)

				-- Convert the current game time to minutes past midnight
				local currentTime = Game.GetTimeSystem():GetGameTime()
				local totalMinutes = currentTime:Hours() * 60 + currentTime:Minutes()
				-- Convert the total minutes to a 12-hour format
				local hours12 = math.floor(totalMinutes / 60) % 12
				if hours12 == 0 then hours12 = 12 end -- Convert 0 to 12
				local mins = totalMinutes % 60
				local amPm = math.floor(totalMinutes / 60) < 12 and 'AM' or 'PM'
				local timeLabel = string.format('%02d:%02d %s', hours12, mins, amPm)

				ImGui.PushItemWidth(185)
				ImGui.Dummy(0, dummySpacingYValue)
				ImGui.Text("Adjust Game Time:")
				ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 10, 4) -- Slider height
				ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize(timeLabel) + 5)
				ImGui.Text(timeLabel)
				ImGui.Separator()
				ImGui.Dummy(0, 1)

				-- Set the width of the slider to the width of the window minus the padding
				local windowWidth = ImGui.GetWindowWidth()
				ImGui.PushItemWidth(windowWidth - timeSliderPadding - 2)
			 -- ImGui.PushItemWidth(windowWidth - timeSliderPadding - 10) -- 4K

				ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 10, 10)

				-- Create a slider for the total minutes
				totalMinutes, changed = ImGui.SliderInt('##', totalMinutes, 0, 24 * 60 - 1)
				if changed then
					local hours = math.floor(totalMinutes / 60)
					local mins = totalMinutes % 60
					Game.GetTimeSystem():SetGameTimeByHMS(hours, mins, secs)
				end

				ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, framePaddingXValue, framePaddingYValue) -- Reset padding

				-- Add a new section for weather transition duration presets
				ImGui.Dummy(0, 25)
				ImGui.Text("Weather Transition Duration:")

				ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - 10)
				ImGui.Text(tostring(settings.Current.transitionDuration) .. "s")
				ImGui.Separator()
				ImGui.Dummy(0, 1)

				-- Define the preset durations
				local durations = { 0, 5, 10, 15, 30 }

				-- Calculate the button width based on the available width
				local buttonWidth = (ImGui.GetWindowContentRegionWidth() - (#durations - 1) * ImGui.GetStyle().ItemSpacing.x) /
				#durations

				-- Create a button for each preset duration
				for _, duration in ipairs(durations) do
					if settings.Current.transitionDuration == duration then
						ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0.0, 1, 0.7, 1))
						ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0, 0, 0, 1))
					end
					if ImGui.Button(tostring(duration) .. 's', buttonWidth, buttonHeight) then
						settings.Current.transitionDuration = duration
						settings.transitionTime = duration -- Update transitionTime
						SaveSettings()
					end
					if settings.Current.transitionDuration == duration then
						ImGui.PopStyleColor(2)
					end
					ImGui.SameLine()
				end

				ImGui.NewLine() -- Move to the next line after the last button

				ImGui.Dummy(0, 50)
				ImGui.Text("Weather state notifications:")
				ImGui.Separator()
				ImGui.Dummy(0, 1)

				settings.Current.warningMessages, changed = ImGui.Checkbox('Warning Message',
					settings.Current.warningMessages)
				if changed then
					SaveSettings()
				end
				ui.tooltip("Show warning message when naturally progressing to a new weather state. \nNotifications only occur with default cycles during natural transitions. \nManually selected states will always show a warning notification.")
				settings.Current.notificationMessages, changed = ImGui.Checkbox('Notification',
					settings.Current.notificationMessages)
				if changed then
					SaveSettings()
				end
				ui.tooltip("Show side notification when naturally progressing to a new weather state. \nNotifications only occur with default cycles during natural transitions. \nManually selected states will always show a warning notification.")

				ImGui.Dummy(0, 50)
				ImGui.Separator()
				ImGui.Dummy(0, 1)

				-- Make the reset button fit the width of the GUI
				local resetButtonWidth = ImGui.GetWindowContentRegionWidth()
				if ImGui.Button('Reset GUI', resetButtonWidth, buttonHeight) then
					resetWindow = true
				end
				ui.tooltip("Reset GUI to default position and size.")
				--DrawWeatherControl()
				ImGui.EndTabItem()
			end

			ImGui.EndTabBar()
		end
		ImGui.End()
	end
end

function DrawTimeSliderWindow()
	if not cetOpen or not timeSliderWindowOpen then
		return
	end

	-- Set window size constraints and position
	ImGui.SetNextWindowSizeConstraints(uiTimeMinWidth, uiTimeMinHeight, width / 100 * 99, uiTimeMaxHeight)
	ImGui.SetNextWindowPos(200, 200, ImGuiCond.FirstUseEver)
	ImGui.SetNextWindowSize(uiTimeMinWidth, uiTimeMaxHeight, ImGuiCond.FirstUseEver)
	ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, itemSpacingXValue, itemSpacingYValue)
	ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, framePaddingXValue, framePaddingYValue)

	if ImGui.Begin('Time Slider', ImGuiWindowFlags.NoScrollbar) then
		-- Set the custom font scale
		ImGui.SetWindowFontScale(customFontScale)

		-- Get current game time
		local currentTime = Game.GetTimeSystem():GetGameTime()
		local totalMinutes = currentTime:Hours() * 60 + currentTime:Minutes()
		local hours12 = math.floor(totalMinutes / 60) % 12
		if hours12 == 0 then hours12 = 12 end
		local mins = totalMinutes % 60
		local amPm = math.floor(totalMinutes / 60) < 12 and 'AM' or 'PM'
		local timeLabel = string.format('%02d:%02d %s', hours12, mins, amPm)

		ImGui.Text("Adjust Game Time:")
		ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 10, 6) -- Slider height
		ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize(timeLabel))
		ImGui.Text(timeLabel)
		ImGui.SetNextItemWidth(-1)
		totalMinutes, changed = ImGui.SliderInt('##', totalMinutes, 0, 24 * 60 - 1)
		if changed then
			--local hours = math.floor(totalMinutes / 60)
			--local mins = totalMinutes % 60
			--Game.GetTimeSystem():SetGameTimeByHMS(hours, mins, secs)
			if totalMinutes < 1439 then
				local hours = math.floor(totalMinutes / 60)
				local mins = totalMinutes % 60
				Game.GetTimeSystem():SetGameTimeByHMS(hours, mins, secs)
			else
				local hours = math.floor(totalMinutes / 60)
				local mins = totalMinutes % 60 + 1
				Game.GetTimeSystem():SetGameTimeByHMS(hours, mins, secs)
			end
		end
		ImGui.PopStyleVar(1) -- Reset padding

		-- Add hour buttons
		ImGui.Dummy(0, dummySpacingYValue)
		ImGui.Separator()
		ImGui.Text("Set Hour:")
		
		local hourButtonWidth = ImGui.GetWindowContentRegionWidth() / 12 - uiTimeHourRightPadding
		for i = 1, 24 do
			if ImGui.Button(tostring(i), hourButtonWidth, buttonHeight) then
				Game.GetTimeSystem():SetGameTimeByHMS(i, 0, secs)
			end
			if i % 12 ~= 0 then
				ImGui.SameLine()
			end
		end
		

		ImGui.Dummy(0, 4)
		-- Add time scale slider
		ImGui.Separator()
		ImGui.Text("Time Scale:")

		-- Add reset button
		ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
		ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, glyphFramePaddingXValue - 0.5, glyphFramePaddingYValue)
		if ImGui.Button(IconGlyphs.History, glyphButtonWidth, glyphButtonHeight) then
			timeScale = 1.0
			Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(false)
			Game.GetTimeSystem():UnsetTimeDilation("consoleCommand")
			if settings.Current.warningMessages then
				ShowWarningMessage("Time scale reset!")
			end
			if settings.Current.notificationMessages then
				ShowNotificationMessage("Time scale reset!")
			end
		end
		ui.tooltip("Reset time scale to 1")
		ImGui.SameLine()

		ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 10, 6) -- Slider height

		-- Calculate available width for the slider
		local availableWidth = ImGui.GetWindowContentRegionWidth() - 2 * glyphButtonWidth -	2 * ImGui.GetStyle().ItemSpacing.x - 4
		ImGui.SetNextItemWidth(availableWidth)
		timeScale, changed = ImGui.SliderFloat('##TimeScale', timeScale, 0.001, 10.0, '%.003f')
		if changed then
			Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(timeScale ~= 1)
			if timeScale == 1 then
				Game.GetTimeSystem():UnsetTimeDilation("consoleCommand")
			else
				Game.GetTimeSystem():SetTimeDilation("consoleCommand", timeScale)
			end
		end
		ui.tooltip("Scaling above 1.0 does not affect vehicles.\n0.001 is REALLY slow but it's working, I promise.")

		ImGui.PopStyleVar(3) -- Reset slider height

		-- Add snowflake button
		ImGui.SameLine()

		ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
		ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, glyphFramePaddingXValue, glyphFramePaddingYValue)

		if timeScale == 0 then
			ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0.0, 1, 0.7, 1))
			ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0, 0, 0, 1))
			if ImGui.Button(IconGlyphs.Snowflake, glyphButtonWidth, glyphButtonHeight) then
				if timeScale == 0 then
					timeScale = previousTimeScale or 1.0
					if settings.Current.warningMessages then
						ShowWarningMessage("Time resumed at "..previousTimeScale.."x speed!")
					end
					if settings.Current.notificationMessages then
						ShowNotificationMessage("Time resumed at "..previousTimeScale.."x speed!")
					end
				else
					if settings.Current.warningMessages then
						ShowWarningMessage("Time frozen!")
					end
					if settings.Current.notificationMessages then
						ShowNotificationMessage("Time frozen!")
					end
					previousTimeScale = timeScale
					timeScale = 0
				end
				Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(timeScale ~= 1)
				if timeScale == 1 then
					Game.GetTimeSystem():UnsetTimeDilation("consoleCommand")
				else
					Game.GetTimeSystem():SetTimeDilation("consoleCommand", timeScale)
				end
			end
			ImGui.PopStyleColor(2)
		else
			if ImGui.Button(IconGlyphs.Snowflake, glyphButtonWidth, glyphButtonHeight) then
				if timeScale == 0 then
					timeScale = previousTimeScale or 1.0
					if settings.Current.warningMessages then
						ShowWarningMessage("Time resumed at "..previousTimeScale.."x speed!")
					end
					if settings.Current.notificationMessages then
						ShowNotificationMessage("Time resumed at "..previousTimeScale.."x speed!")
					end
				else
					if settings.Current.warningMessages then
						ShowWarningMessage("Time frozen!")
					end
					if settings.Current.notificationMessages then
						ShowNotificationMessage("Time frozen!")
					end
					previousTimeScale = timeScale
					timeScale = 0
				end
				Game.GetTimeSystem():SetIgnoreTimeDilationOnLocalPlayerZero(timeScale ~= 1)
				if timeScale == 1 then
					Game.GetTimeSystem():UnsetTimeDilation("consoleCommand")
				else
					Game.GetTimeSystem():SetTimeDilation("consoleCommand", timeScale)
				end
			end
		end

		ui.tooltip("Freeze time (toggle)")

		ImGui.PopStyleVar(3)

		ImGui.End()
	end
end

function ShowWarningMessage(message)
	if settings.Current.warningMessages == false then return end
	local text = SimpleScreenMessage.new()
	text.duration = 1.0
	text.message = message
	text.isInstant = true
	text.isShown = true
	Game.GetBlackboardSystem():Get(GetAllBlackboardDefs().UI_Notifications):SetVariant(
		GetAllBlackboardDefs().UI_Notifications.WarningMessage, ToVariant(text), true)
end

function ShowNotificationMessage(message)
	if settings.Current.notificationMessages == false then return end
	local text = SimpleScreenMessage.new()
	text.duration = 4.0
	text.message = message
	text.isInstant = true
	text.isShown = true
	Game.GetBlackboardSystem():Get(GetAllBlackboardDefs().UI_Notifications):SetVariant(
		GetAllBlackboardDefs().UI_Notifications.OnscreenMessage, ToVariant(text), true)
end

registerForEvent("onInit", function()
	LoadSettings()

	-- Create a mapping from weather state IDs to localized names
	for _, weatherState in ipairs(weatherStates) do
		local id, localization = table.unpack(weatherState)
		weatherStateNames[id] = localization
	end

	--[[ -- Handle session start
    GameUI.OnSessionStart(function()
        Cron.After(0.25, function()
            -- Apply active weather state
            if settings.Current.weatherState ~= 'None' then
                Game.GetWeatherSystem():SetWeather(settings.Current.weatherState, settings.transitionTime, 0)
                Game.GetPlayer():SetWarningMessage("Locked weather state to " .. weatherStateNames[settings.Current.weatherState]:lower() .. "!")
            end
        end)
    end)

    GameUI.OnSessionEnd(function()
        -- Handle end
    end) ]]
end)

registerForEvent('onDraw', function()
	if timeSliderWindowOpen == true then
		DrawTimeSliderWindow()
	end
	DrawButtons()
end)

registerForEvent('onOverlayOpen', function()
	LoadSettings()
	cetOpen = true
	width, height = GetDisplayResolution()
	setResolutionPresets(width, height)

	--[[  local currentWeatherState = Game.GetWeatherSystem():GetWeatherState().name.value
    local selectedWeatherState = settings.Current.weatherState
    if selectedWeatherState == 'Locked State' then
        settings.Current.weatherState = currentWeatherState
        for _, state in ipairs(weatherStates) do
            if state[1] == currentWeatherState then
                settings.Current.weatherState = state[1]
                break
            end
        end
    end ]]
end)

registerForEvent('onOverlayClose', function()
    cetOpen = false
    SaveSettings()
end)

function SaveSettings()
	local saveData = {
		transitionDuration = settings.Current.transitionDuration,
		timeSliderWindowOpen = settings.Current.timeSliderWindowOpen,
		weatherState = settings.Current.weatherState,
		-- nativeWeather = settings.Current.nativeWeather,
		warningMessages = settings.Current.warningMessages,
		notificationMessages = settings.Current.notificationMessages
	}
	local file = io.open('settings.json', 'w')
	if file then
		local jsonString = json.encode(saveData)
		local formattedJsonString = jsonString:gsub(',"', ',\n    "'):gsub('{', '{\n    '):gsub('}', '\n}')
		file:write(formattedJsonString)
		file:close()
	end
end

function LoadSettings()
	local file = io.open('settings.json', 'r')
	if file then
		local content = file:read('*all')
		file:close()
		settings.Current = json.decode(content)
		timeSliderWindowOpen = settings.Current.timeSliderWindowOpen
	elseif not file then
		return
	end
end
