local Cron = require("Cron")
local GameUI = require("GameUI")
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
    {'24h_weather_sunny', 'Sunny', 1, false},
    {'24h_weather_light_clouds', 'Light Clouds', 1, false},
    {'24h_weather_cloudy', 'Clouds', 1, false},
    {'24h_weather_heavy_clouds', 'Heavy Clouds', 1, false},
    {'24h_weather_fog', 'Fog', 1, false},
    {'24h_weather_rain', 'Rain', 1, true},
    {'24h_weather_toxic_rain', 'Toxic Rain', 1, true},
    {'24h_weather_pollution', 'Pollution', 1, false},
    {'24h_weather_sandstorm', 'Sandstorm', 1, true},
    {'q302_light_rain', 'Rain (Quest)', 1, true},
    {'24h_weather_fog_dense', 'Dense Fog', 2, false},
    {'24h_weather_dew', 'Dew', 2, true},
    {'24h_weather_haze', 'Haze', 2, false},
    {'24h_weather_haze_heavy', 'Heavy Haze', 2, false},
    {'24h_weather_haze_pollution', 'Haze Pollution', 2, false},
    {'24h_weather_smog', 'Smog', 2, false},
    {'24h_weather_clear', 'Sunny (Clear)', 2, true},
    {'24h_weather_drizzle', 'Drizzle', 2, true},
    {'24h_weather_windy', 'Windy', 2, true},
    {'24h_weather_sunny_windy', 'Sunny Windy', 2, true},
    {'24h_weather_storm', 'Rain (Storm)', 2, true},
    {'24h_weather_overcast', 'Overcast', 2, false},
    {'24h_weather_drought', 'Drought', 2, false},
    {'24h_weather_humid', 'Humid', 2, false},
    {'24h_weather_fog_wet', 'Wet Fog', 3, true},
    {'24h_weather_fog_heavy', 'Heavy Fog', 3, false},
    {'24h_weather_sunny_sunset', 'Sunset', 3, false},
    {'24h_weather_drizzle_light', 'Light Drizzle', 3, true},
    {'24h_weather_light_rain', 'Light Rain', 3, true},
    {'24h_weather_rain_alt_1', 'Rain (Alt 1)', 3, true},
    {'24h_weather_rain_alt_2', 'Rain (Alt 2)', 3, true},
    {'24h_weather_mist', 'Fog (Mist)', 3, true},
    {'24h_weather_courier_clouds', 'Dense Clouds', 3, false},
    {'24h_weather_downpour', 'Downpour', 4, true},
    {'24h_weather_drizzle_heavy', 'Heavy Drizzle', 4, true},
    {'24h_weather_distant_rain', 'Rain (Distant)', 4, true},
    {'24h_weather_sky_softbox', 'Softbox', 5, false},
    {'24h_weather_blackout', 'Blackout', 5, false},
    {'24h_weather_showroom', 'Showroom', 5, false}
}

function setResolutionPresets(width, height)
	local presets = {
	 -- { 1,    2,    3,  4, 5, 6, 7, 8, 9, 10, 11,   12, 13, 14, 15,   16, 17, 18,  19, 20, 21, 22,  23,  24,  25 },
		{ 3840, 2160, 10, 6, 1, 1, 1, 1, 1, 1,  0.7,  24, 36, 36, 0.7,  1,  6,  320, 33, 12, 6,  650, 280, 280, 15 },
		{ 2560, 1440, 8,  6, 1, 2, 1, 1, 1, 1,  0.45, 20, 32, 28, 0.85, 1,  8,  310, 29, 10, 4,  500, 200, 200, 9.5 },
		{ 1920, 1080, 5,  4, 1, 4, 1, 1, 1, 1,  0.5,  18, 24, 24, 0.85, 1,  0,  300, 21, 8,  4,  400, 160, 160, 7.5 },
		{ 0,    0,    5,  4, 1, 4, 1, 1, 1, 1,  0.5,  18, 24, 24, 0.85, 1,  0,  300, 21, 8,  4,  400, 160, 160, 7.5 },
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
            invisibleButtonWidth = preset[12]
            invisibleButtonHeight = preset[13]
            buttonHeight = preset[14]
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
            break
        end
    end
end

function DrawWeatherControl()
    ImGui.Dummy(0, dummySpacingYValue)
    ImGui.Separator()
    ImGui.Text("Weather Control:")

    if ImGui.Button('Reset Weather', 290, 30) then
        Game.GetWeatherSystem():ResetWeather(true)
        settings.Current.weatherState = 'None'
        -- settings.Current.nativeWeather = 1
        Game.GetPlayer():SetWarningMessage("Weather reset to default cycles. \n\nWeather states will progress automatically.")
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
    ImGui.Text('Mode:  ' .. selectedWeatherState)
    ui.tooltip("Default Cycles: Weather states will transition automatically. \nLocked State: User selected weather state.")

    ImGui.Text('State:')
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

		-- Push style variables for frame padding and item spacing
        ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, framePaddingXValue, framePaddingYValue)
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, itemSpacingXValue, itemSpacingYValue)

		-- Set the font scale for the window
        ImGui.SetWindowFontScale(customFontScale)

		local availableWidth = ImGui.GetContentRegionAvail() - buttonPaddingRight

        if ImGui.BeginTabBar("Nova Tabs") then
            
			ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize('XX'))

            --if ImGui.Button(">", 30, 29) then
			ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
            if ImGui.Button(IconGlyphs.ClockOutline, 32, 28) then
				timeSliderWindowOpen = not timeSliderWindowOpen
				settings.Current.timeSliderWindowOpen = timeSliderWindowOpen
				SaveSettings()
			end
			ui.tooltip("Toggles the time slider window.")

            if ImGui.BeginTabItem("Weather") then
				
			--if ImGui.BeginTabItem(IconGlyphs.WeatherPartlyCloudy) then
                local categories = {'Vanilla States', 'Nova Beta States', 'Nova Alpha States', 'Nova Concept States', 'Creative'}
				for i, category in ipairs(categories) do
					ImGui.Text(category)
					local buttonWidth = 140
					local windowWidth = ImGui.GetWindowWidth()
					local buttonsPerRow = math.floor(windowWidth / buttonWidth)
					local buttonCount = 0
					for _, state in ipairs(weatherStates) do
						local weatherState = state[1]
						local localization = state[2]
						local category = state[3]
						local enableDLSSDPT = state[4]  -- Get the DLSSDSeparateParticleColor flag
						if category == i then
							local isActive = settings.Current.weatherState == weatherState
							if isActive then
								ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0.0, 1, 0.7, 1))
								ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0, 0, 0, 1))
							end
							if ImGui.Button(localization, 140, buttonHeight) then
								if isActive then
									Game.GetWeatherSystem():ResetWeather(true)
									settings.Current.weatherState = 'None'
									Game.GetPlayer():SetWarningMessage("Weather reset to default cycles. \n\nWeather states will progress automatically.")
									GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", true)
									toggleDLSSDPT = true
									weatherReset = true
								else
									Game.GetWeatherSystem():SetWeather(weatherState, settings.transitionTime, 0)
									settings.Current.weatherState = weatherState
									Game.GetPlayer():SetWarningMessage("Locked weather state to " .. localization:lower() .. "!")
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
						ImGui.NewLine()  -- Force a new line only if the last button is not on a new line
					end
				end
				
				DrawWeatherControl()
				ImGui.EndTabItem()
			end

			if ImGui.BeginTabItem("Toggles") then

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
				ui.tooltip("Toggles all fog and clouds: volumetric, distant volumetric, distant fog planes, and volumetric clouds.")

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
				ImGui.SameLine(130)
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
				ImGui.SameLine(130)
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
					GameOptions.SetBool("RayTracing","EnableNRD", toggleNRD)
					SaveSettings()
				end
				ui.tooltip("Nvidia Realtime Denoiser")
				ImGui.SameLine(130)
				toggleDLSSDPT, changed = ImGui.Checkbox('DLSSDPT', toggleDLSSDPT)
				if changed then
					GameOptions.SetBool("Rendering","DLSSDSeparateParticleColor", toggleDLSSDPT)
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
				ImGui.SameLine(130)
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
				ImGui.SameLine(130)
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
					GameOptions.SetBool("Developer/FeatureToggles","ChromaticAberration", chromaticAberration)
					SaveSettings()
				end
				ui.tooltip("Toggles chromatic aberration.")
				ImGui.SameLine(130)
				filmGrain, changed = ImGui.Checkbox('Film Grain', filmGrain)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles","FilmGrain", filmGrain)
					SaveSettings()
				end
				ui.tooltip("Toggles film grain.")

				DOF, changed = ImGui.Checkbox('DOF', DOF)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles","DepthOfField", DOF)
					SaveSettings()
				end
				ui.tooltip("Toggles depth of field.")
				ImGui.SameLine(130)
				motionBlur, changed = ImGui.Checkbox('Motion Blur', motionBlur)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles","MotionBlur", motionBlur)
					SaveSettings()
				end
				ui.tooltip("Toggles motion blur.")

				RIS, changed = ImGui.Checkbox('RIS', RIS)
				if changed then
					GameOptions.SetBool("RayTracing/Reference","EnableRIS", RIS)
					SaveSettings()
				end
				ui.tooltip("Toggles Resampled Importance Sampling.")

				ImGui.Dummy(0, dummySpacingYValue)
				ImGui.Text("Utility:")
				ImGui.Separator()
				vehicleCollisions, changed = ImGui.Checkbox('Vehicle Collisions', vehicleCollisions)
				if changed then
					GameOptions.SetBool("Vehicle","vehicleVsVehicleCollisions", vehicleCollisions)
					SaveSettings()
				end
				ui.tooltip("Toggles vehicle collisions. Great for driving through \n Night City with Nova City Population density!")
				crowdSpawning, changed = ImGui.Checkbox('Crowd Spawning', crowdSpawning)
				if changed then
					GameOptions.SetBool("Crowd","Enabled", crowdSpawning)
					SaveSettings()
				end
				ui.tooltip("Toggles vehicle spawning.")
				stopVehicleSpawning, changed = ImGui.Checkbox('Vehicle Spawning', stopVehicleSpawning)
				if changed then
					if stopVehicleSpawning then
						GameOptions.SetBool("Traffic","StopSpawn", false)
						vehicleSpawning = true
						SaveSettings()
					else
						GameOptions.SetBool("Traffic","StopSpawn", true)
						vehicleSpawning = false
						SaveSettings()
					end
				end
				ui.tooltip("Toggles vehicle spawning.")

				ImGui.Dummy(0, dummySpacingYValue)
				ImGui.Text("Useless Toggles:")
				ImGui.Separator()
				tonemapping, changed = ImGui.Checkbox('Tonemapping', tonemapping)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles","Tonemapping", tonemapping)
					SaveSettings()
				end
				ui.tooltip("This toggle serves absolutely no purpose and toggling \n it does nothing but make the game look bad and kills \n a puppy each time you do.")

				graphics, changed = ImGui.Checkbox('gRaPhiCs', graphics)
				if changed then
					GameOptions.SetBool("","", graphics)
					SaveSettings()
				end
				ui.tooltip("Coming soon.")
				--DrawWeatherControl()
				ImGui.EndTabItem()
			end

			if ImGui.BeginTabItem("Misc") then
				
				-- Convert the current game time to minutes past midnight
				local currentTime = Game.GetTimeSystem():GetGameTime()
				local totalMinutes = currentTime:Hours() * 60 + currentTime:Minutes()
				-- Convert the total minutes to a 12-hour format
				local hours12 = math.floor(totalMinutes / 60) % 12
				if hours12 == 0 then hours12 = 12 end  -- Convert 0 to 12
				local mins = totalMinutes % 60
				local amPm = math.floor(totalMinutes / 60) < 12 and 'AM' or 'PM'
				local timeLabel = string.format('%02d:%02d %s', hours12, mins, amPm)

				ImGui.PushItemWidth(185)
				ImGui.Dummy(0, dummySpacingYValue)
				ImGui.Text('Adjust Game Time:                ' .. timeLabel)
				ImGui.Separator()
				ImGui.Dummy(0, 1)

				-- Set the width of the slider to the width of the window minus the padding
				local windowWidth = ImGui.GetWindowWidth()
				local padding = 22  -- Adjust this value as needed
				ImGui.PushItemWidth(windowWidth - padding)

				-- Create a slider for the total minutes
				totalMinutes, changed = ImGui.SliderInt('##', totalMinutes, 0, 24 * 60 - 1)
				if changed then
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
				
				--[[ if ImGui.Button('Toggle Time Slider Window', 290, 30) then
					timeSliderWindowOpen = not timeSliderWindowOpen
					settings.Current.timeSliderWindowOpen = timeSliderWindowOpen
					SaveSettings()
				end ]]

				-- Add a new section for weather transition duration presets
				ImGui.Dummy(0, 25)
				ImGui.Text("Weather Transition Duration:         "  .. tostring(settings.Current.transitionDuration) .. "s")
				ImGui.Separator()
				ImGui.Dummy(0, 1)
				
				-- Define the preset durations
				local durations = {0, 5, 10, 15, 30}

				-- Create a button for each preset duration
				for _, duration in ipairs(durations) do
					if ImGui.Button(tostring(duration) .. 's', 49, 30) then
						settings.Current.transitionDuration = duration
						settings.transitionTime = duration  -- Update transitionTime
						SaveSettings()
					end
					ImGui.SameLine()
				end

				ImGui.Dummy(0, 50)
				ImGui.Text('Weather state notifications:')
				ImGui.Separator()
				ImGui.Dummy(0, 1)

                                settings.Current.warningMessages, changed = ImGui.Checkbox('Warning Message', settings.Current.warningMessages)
                                if changed then
                                    SaveSettings()
                                end
								ui.tooltip("Show warning message when naturally progressing to a new weather state. \nNotifications only occur with default cycles during natural transitions. \nManually selected states will always show a warning notification.")
                                settings.Current.notificationMessages, changed = ImGui.Checkbox('Notification', settings.Current.notificationMessages)
                                if changed then
                                    SaveSettings()
                                end
								ui.tooltip("Show side notification when naturally progressing to a new weather state. \nNotifications only occur with default cycles during natural transitions. \nManually selected states will always show a warning notification.")

				ImGui.Dummy(0, 50)
				ImGui.Separator()
				ImGui.Dummy(0, 1)

				if ImGui.Button('Reset GUI', 290, 30) then
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

	ImGui.SetNextWindowSizeConstraints(uiTimeMinWidth, uiTimeMinHeight, width / 100 * 99, uiTimeMaxHeight)
	
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(320, 120, ImGuiCond.FirstUseEver)
    if ImGui.Begin('Time Slider', ImGuiWindowFlags.NoScrollbar) then
        -- Set the custom font scale
        ImGui.SetWindowFontScale(customFontScale)

        local currentTime = Game.GetTimeSystem():GetGameTime()
        local totalMinutes = currentTime:Hours() * 60 + currentTime:Minutes()
        local hours12 = math.floor(totalMinutes / 60) % 12
        if hours12 == 0 then hours12 = 12 end
        local mins = totalMinutes % 60
        local amPm = math.floor(totalMinutes / 60) < 12 and 'AM' or 'PM'
        local timeLabel = string.format('%02d:%02d %s', hours12, mins, amPm)

        ImGui.Text('Adjust Game Time:')
        ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize(timeLabel))
        ImGui.Text(timeLabel)
        ImGui.Separator()
        ImGui.SetNextItemWidth(-1)
        totalMinutes, changed = ImGui.SliderInt('##', totalMinutes, 0, 24 * 60 - 1)
        if changed then
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

        -- Add hour buttons
        ImGui.Separator()
        ImGui.Text('Set Hour:')
        local buttonWidth = ImGui.GetWindowContentRegionWidth() / 12 - uiTimeHourRightPadding
        for i = 1, 24 do
            if ImGui.Button(tostring(i), buttonWidth, buttonHeight) then
                local hours = i
                local mins = 0
                Game.GetTimeSystem():SetGameTimeByHMS(hours, mins, secs)
            end
            if i % 12 ~= 0 then
                ImGui.SameLine()
            end
        end

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
    Game.GetBlackboardSystem():Get(GetAllBlackboardDefs().UI_Notifications):SetVariant(GetAllBlackboardDefs().UI_Notifications.WarningMessage, ToVariant(text), true)
end

function ShowNotificationMessage(message)
    if settings.Current.notificationMessages == false then return end
    local text = SimpleScreenMessage.new()
    text.duration = 4.0
    text.message = message
    text.isInstant = true
    text.isShown = true
    Game.GetBlackboardSystem():Get(GetAllBlackboardDefs().UI_Notifications):SetVariant(GetAllBlackboardDefs().UI_Notifications.OnscreenMessage, ToVariant(text), true)
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
