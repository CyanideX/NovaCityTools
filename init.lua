local Cron = require("Cron")
local version = "1.7.0"
local cetopen = false
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
local weatherFX = true
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

local settings =
{
	Current = {
		weatherState = 'None',
		mywindowhidden = false,
		transitionDuration = 0,  -- Default value
	},
	Default = {
		weatherState = 'None',
		mywindowhidden = false,
		transitionDuration = 0,  -- Default value
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
    {'24h_weather_humid', 'Drought (Humid)', 2, false},
    {'24h_weather_fog_wet', 'Wet Fog', 3, true},
    {'24h_weather_fog_heavy', 'Heavy Fog', 3, false},
    {'24h_weather_sunny_sunset', 'Sunset', 3, false},
    {'24h_weather_drizzle_light', 'Light Drizzle', 3, true},
    {'24h_weather_light_rain', 'Light Rain', 3, true},
    {'24h_weather_rain_alt_1', 'Rain (Alt 1)', 3, true},
    {'24h_weather_rain_alt_2', 'Rain (Alt 2)', 3, true},
    {'24h_weather_mist', 'Fog (Mist)', 3, true},
    {'24h_weather_courier_clouds', 'Dense Clouds', 3, false},
    {'24h_weather_downpour', 'Rain (Downpour)', 4, true},
    {'24h_weather_drizzle_heavy', 'Heavy Drizzle', 4, true},
    {'24h_weather_distant_rain', 'Rain (Distant)', 4, true},
    {'24h_weather_sky_softbox', 'Softbox', 5, false},
    {'24h_weather_blackout', 'Blackout', 5, false},
    {'24h_weather_showroom', 'Showroom', 5, false}
}

function SaveSettings()
	local file = io.open('settings.json', 'w')
	if file then
		file:write(json.encode(settings.Current))
		file:close()
	end
end

function LoadSettings()
	local file = io.open('settings.json', 'r')
	if file then
		local content = file:read('*all')
		file:close()
		settings.Current = json.decode(content)
	elseif not file then
		return
	end
end

-- Flag to indicate if the window position and size should be reset
local resetWindow = false

local currentWeatherState = nil

-- Create a mapping from weather state IDs to localized names
local weatherStateNames = {}
for _, weatherState in ipairs(weatherStates) do
    local id, localization = table.unpack(weatherState)
    weatherStateNames[id] = localization
end

function ShowWarningMessage(message)
    local text = SimpleScreenMessage.new()
    text.duration = 1.0
    text.message = message
    text.isInstant = true
    text.isShown = true
    Game.GetBlackboardSystem():Get(GetAllBlackboardDefs().UI_Notifications):SetVariant(GetAllBlackboardDefs().UI_Notifications.WarningMessage, ToVariant(text), true)
end

function ShowNotificationMessage(message)
    local text = SimpleScreenMessage.new()
    text.duration = 4.0
    text.message = message
    text.isInstant = true
    text.isShown = true
    Game.GetBlackboardSystem():Get(GetAllBlackboardDefs().UI_Notifications):SetVariant(GetAllBlackboardDefs().UI_Notifications.OnscreenMessage, ToVariant(text), true)
end

registerForEvent("onUpdate", function()
    if not Game.GetPlayer() or Game.GetSystemRequestsHandler():IsGamePaused() then return end
    local newWeatherState = tostring(Game.GetWeatherSystem():GetWeatherState().name.value)
    if newWeatherState ~= currentWeatherState then
        currentWeatherState = newWeatherState
        -- Use the mapping to get the localized name
        local localizedState = weatherStateNames[currentWeatherState]
        local messageText = "Weather changed to " .. (localizedState or currentWeatherState)
        ShowWarningMessage(messageText)
        ShowNotificationMessage(messageText)
    end
end)

function DrawButtons()
    if not cetopen or settings.Current.mywindowhidden == true then
        return
    end
    -- If the reset flag is set, reset the window position and size
    if resetWindow then
        ImGui.SetNextWindowPos(6, 160, ImGuiCond.Always)
        ImGui.SetNextWindowSize(312, 1100, ImGuiCond.Always)
        resetWindow = false
    end
    if ImGui.Begin('Nova City Tools - v' .. version, true) then
        if ImGui.BeginTabBar("Nova Tabs") then
            if ImGui.BeginTabItem("Weather") then
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
							if ImGui.Button(localization, 140, 30) then
								Game.GetWeatherSystem():SetWeather(weatherState, settings.transitionTime, 0)
								settings.Current.weatherState = weatherState
								Game.GetPlayer():SetWarningMessage("Locked weather state to " .. localization:lower() .. "!")
					
								-- Set the DLSSDSeparateParticleColor option based on the flag
								GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", enableDLSSDPT)
								toggleDLSSDPT = enableDLSSDPT  -- Update the checkbox status
								SaveSettings()
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
				
				ImGui.Dummy(0, 10)
                ImGui.Separator()
                ImGui.Text("Weather Control:")

                if ImGui.Button('Reset Weather', 290, 30) then
					Game.GetWeatherSystem():ResetWeather(true)
					settings.Current.weatherState = 'None'
					settings.Current.nativeWeather = 1
					Game.GetPlayer():SetWarningMessage("Weather reset to default cycles. \n\nWeather states will progress automatically.")
					-- Enable DLSSDSeparateParticleColor
					GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", true)
					toggleDLSSDPT = true  -- Update the checkbox status
					SaveSettings()
				end
				
                
                ui.tooltip("Reset any manually selected states and returns \nthe weather to its default weather cycles, \n\nWeather will continue to advance naturally.")

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

                ImGui.EndTabItem()
			end

			if ImGui.BeginTabItem("Toggles") then

				ImGui.Dummy(0, 2)
				ImGui.Text("Grouped Toggles:")
				ImGui.Separator()

				toggleFog, changed = ImGui.Checkbox('ALL: Fog', toggleFog)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles","VolumetricFog", toggleFog)
					if toggleFog then
						GameOptions.SetBool("Developer/FeatureToggles","VolumetricFog", true)
						GameOptions.SetBool("Developer/FeatureToggles","DistantVolFog", true)
						GameOptions.SetBool("Developer/FeatureToggles","DistantFog", true)
						volumetricFog = true
						distantVolumetricFog = true
						distantFog = true
						SaveSettings()
					else
						GameOptions.SetBool("Developer/FeatureToggles","VolumetricFog", false)
						GameOptions.SetBool("Developer/FeatureToggles","DistantVolFog", false)
						GameOptions.SetBool("Developer/FeatureToggles","DistantFog", false)
						volumetricFog = false
						distantVolumetricFog = false
						distantFog = false
						SaveSettings()
					end
				end
				ui.tooltip("Toggles all fog types: volumetic, distant volumetric, and distant fog plane.")

				toggleFogClouds, changed = ImGui.Checkbox('ALL: Volumetrics and Clouds', toggleFogClouds)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles","VolumetricFog", toggleFogClouds)
					if toggleFogClouds then
						GameOptions.SetBool("Developer/FeatureToggles","DistantVolFog", true)
						GameOptions.SetBool("Developer/FeatureToggles","DistantFog", true)
						GameOptions.SetBool("Developer/FeatureToggles","VolumetricClouds", true)
						distantVolumetricFog = true
						volumetricFog = true
						distantFog = true
						clouds = true
						SaveSettings()
					else
						GameOptions.SetBool("Developer/FeatureToggles","DistantVolFog", false)
						GameOptions.SetBool("Developer/FeatureToggles","DistantFog", false)
						GameOptions.SetBool("Developer/FeatureToggles","VolumetricClouds", false)
						distantVolumetricFog = false
						volumetricFog = false
						distantFog = false
						clouds = false
						SaveSettings()
					end
				end
				ui.tooltip("Toggles all fog and clouds: volumetic, distant volumetric, distant fog planes, and volumetic clouds.")
				
				ImGui.Dummy(0, 10)
				ImGui.Text("Weather:")
				ImGui.Separator()
				
				volumetricFog, changed = ImGui.Checkbox('VFog', volumetricFog)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles","VolumetricFog", volumetricFog)
					SaveSettings()
					if volumetricFog then
						GameOptions.SetBool("Developer/FeatureToggles","DistantVolFog", true)
						distantVolumetricFog = true
						SaveSettings()
					else
						GameOptions.SetBool("Developer/FeatureToggles","DistantVolFog", false)
						distantVolumetricFog = false
						SaveSettings()
					end
				end
				ui.tooltip("Toggle volumetric fog.")
				ImGui.SameLine(130)
				distantVolumetricFog, changed = ImGui.Checkbox('Distant VFog', distantVolumetricFog)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles","DistantVolFog", distantVolumetricFog)
					SaveSettings()
				end
				ui.tooltip("Toggle distant volumetric fog.")
				
				distantFog, changed = ImGui.Checkbox('Fog', distantFog)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles","DistantFog", distantFog)
					SaveSettings()
				end
				ui.tooltip("Toggle distant fog plane.")
				ImGui.SameLine(130)
				clouds, changed = ImGui.Checkbox('Clouds', clouds)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles","VolumetricClouds", clouds)
					SaveSettings()
				end
				ui.tooltip("Toggle volumetric clouds.")

				ImGui.Dummy(0, 10)
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
					GameOptions.SetBool("Developer/FeatureToggles","Bloom", bloom)
					SaveSettings()

					if bloom then
						GameOptions.SetBool("Developer/FeatureToggles","ImageBasedFlares", true)
						lensFlares = true
						SaveSettings()
					else
						GameOptions.SetBool("Developer/FeatureToggles","ImageBasedFlares", false)
						lensFlares = false
						SaveSettings()
					end
				end
				ui.tooltip("Toggles bloom (also removes lens flare).")
				ImGui.SameLine(130)
				lensFlares, changed = ImGui.Checkbox('Lens Flares', lensFlares)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles","ImageBasedFlares", lensFlares)
					SaveSettings()
				end
				ui.tooltip("Toggles lens flare effect.")

				rain, changed = ImGui.Checkbox('SS Rain', rain)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles","ScreenSpaceRain", rain)
					SaveSettings()

					if rain then
						GameOptions.SetBool("Developer/FeatureToggles","Weather", true)
						weatherFX = true
						SaveSettings()
					else
						GameOptions.SetBool("Developer/FeatureToggles","Weather", false)
						weatherFX = false
						SaveSettings()
					end
				end
				ui.tooltip("Toggles screenspace rain effects, removing wet surfaces.")
				ImGui.SameLine(130)
				rainMap, changed = ImGui.Checkbox('Weather', rainMap)
				if changed then
					GameOptions.SetBool("Developer/FeatureToggles","RainMap", rainMap)
					SaveSettings()
				end
				ui.tooltip("Toggles all weather effects such as rain particles and wet surfaces.")

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


				ImGui.Dummy(0, 10)
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

				ImGui.Dummy(0, 10)
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


				ImGui.EndTabItem()
			end

			if ImGui.BeginTabItem("Misc") then
				
			
				-- Add a new section for weather transition duration presets
				ImGui.Dummy(0, 2)
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

				-- Display the currently selected transition duration
				-- ImGui.Dummy(0, 2)
				-- ImGui.Text("Current Duration: " .. tostring(settings.Current.transitionDuration) .. "s")

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
				ImGui.Dummy(0, 50)
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
					-- Convert the total minutes back to hours and minutes
					local hours = math.floor(totalMinutes / 60)
					local mins = totalMinutes % 60

					-- Set the game time
					Game.GetTimeSystem():SetGameTimeByHMS(hours, mins, secs)
				end
				if ImGui.Button('Toggle Time Slider Window', 290, 30) then
					timeSliderWindowOpen = not timeSliderWindowOpen
				end

				ImGui.Dummy(0, 50)
				ImGui.Separator()
				ImGui.Dummy(0, 1)
				if ImGui.Button('Reset GUI', 290, 30) then
					resetWindow = true
				end
				ui.tooltip("Reset GUI to default position and size.")

			end
			ImGui.EndTabBar()
		end
		ImGui.End()
	end
end

function DrawWindowHider()
	if not cetopen then
		return
	end
	if ImGui.Begin("Window Hider Tool") then
		if ImGui.BeginMenu("TheCyanideX Mods") then
			if ImGui.Button("Toggle Nova Weather Mod") then
				if settings.Current.mywindowhidden == true then
					settings.Current.mywindowhidden = false
					SaveSettings()
				elseif settings.Current.mywindowhidden == false then
					settings.Current.mywindowhidden = true
					SaveSettings()
				end
			end
			ImGui.EndMenu()
		end
		ImGui.End()
	end
end

function DrawTimeSliderWindow()
    if not cetopen or not timeSliderWindowOpen then
        return
    end
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(320, 120, ImGuiCond.FirstUseEver)
    if ImGui.Begin('Time Slider') then
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
            local hours = math.floor(totalMinutes / 60)
            local mins = totalMinutes % 60
            Game.GetTimeSystem():SetGameTimeByHMS(hours, mins, secs)
        end
        ImGui.End()
    end
end

registerForEvent("onInit", function()
	LoadSettings()
end)

registerForEvent('onDraw', function()
    if timeSliderWindowOpen == true then
        DrawTimeSliderWindow()
    end
    DrawButtons()
    local WindowHiderTool = GetMod("WindowHiderTool")
    if WindowHiderTool and cetopen then
        DrawWindowHider()
    elseif not WindowHiderTool then
        settings.Current.mywindowhidden = false
        SaveSettings()
    end
end)

registerForEvent('onOverlayOpen', function()
	LoadSettings()
	cetopen = true
end)

registerForEvent('onOverlayClose', function()
	cetopen = false
	SaveSettings()
end)
