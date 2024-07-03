local Cron = require("Cron")
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

local settings =
{
	Current = {
		weatherState = 'None',
		mywindowhidden = false,
	},
	Default = {
		weatherState = 'None',
		mywindowhidden = false,
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

local stateSelections = {
	'None',
	'24h_weather_sunny',
    '24h_weather_light_clouds',
    '24h_weather_cloudy',
    '24h_weather_heavy_clouds',
    '24h_weather_fog',
    '24h_weather_rain',
    '24h_weather_toxic_rain',
    '24h_weather_pollution',
    '24h_weather_sandstorm',
    'q302_light_rain',
    '24h_weather_fog_dense',
    '24h_weather_dew',
    '24h_weather_haze',
    '24h_weather_haze_heavy',
    '24h_weather_haze_pollution',
    '24h_weather_smog',
    '24h_weather_clear',
    '24h_weather_drizzle',
    '24h_weather_windy',
    '24h_weather_sunny_windy',
    '24h_weather_storm',
    '24h_weather_overcast',
    '24h_weather_drought',
    '24h_weather_humid',
    '24h_weather_fog_wet',
    '24h_weather_fog_heavy',
    '24h_weather_sunny_sunset',
    '24h_weather_drizzle_light',
    '24h_weather_light_rain',
    '24h_weather_rain_alt_1',
    '24h_weather_rain_alt_2',
    '24h_weather_mist',
    '24h_weather_sky_softbox',
    '24h_weather_blackout',
    '24h_weather_downpour',
    '24h_weather_drizzle_heavy',
	'24h_weather_distant_rain',
	'24h_weather_courier_clouds',
	'24h_weather_showroom'
}

local weatherStateLocalization = {
    ['None'] = 'Default Cycles', 
    ['24h_weather_sunny'] = 'Sunny', 
    ['24h_weather_light_clouds'] = 'Light Clouds', 
    ['24h_weather_cloudy'] = 'Cloudy', 
    ['24h_weather_heavy_clouds'] = 'Heavy Clouds', 
    ['24h_weather_fog'] = 'Fog', 
    ['24h_weather_rain'] = 'Rain', 
    ['24h_weather_toxic_rain'] = 'Toxic Rain', 
    ['24h_weather_pollution'] = 'Pollution', 
    ['24h_weather_sandstorm'] = 'Sandstorm', 
    ['q302_light_rain'] = 'Light Rain', 
    ['24h_weather_fog_dense'] = 'Dense Fog', 
    ['24h_weather_dew'] = 'Dew', 
    ['24h_weather_haze'] = 'Haze', 
    ['24h_weather_haze_heavy'] = 'Heavy Haze', 
    ['24h_weather_haze_pollution'] = 'Haze Pollution', 
    ['24h_weather_smog'] = 'Smog', 
    ['24h_weather_clear'] = 'Clear', 
    ['24h_weather_drizzle'] = 'Drizzle', 
    ['24h_weather_windy'] = 'Windy', 
    ['24h_weather_sunny_windy'] = 'Sunny Windy', 
    ['24h_weather_storm'] = 'Storm', 
    ['24h_weather_overcast'] = 'Overcast', 
    ['24h_weather_drought'] = 'Drought', 
    ['24h_weather_humid'] = 'Humid', 
    ['24h_weather_fog_wet'] = 'Wet Fog', 
    ['24h_weather_fog_heavy'] = 'Heavy Fog', 
    ['24h_weather_sunny_sunset'] = 'Sunset', 
    ['24h_weather_drizzle_light'] = 'Light Drizzle', 
    ['24h_weather_light_rain'] = 'Light Rain', 
    ['24h_weather_rain_alt_1'] = 'Rain (Alt 1)', 
    ['24h_weather_rain_alt_2'] = 'Rain (Alt 2)', 
    ['24h_weather_mist'] = 'Mist', 
    ['24h_weather_sky_softbox'] = 'Sky Softbox', 
    ['24h_weather_blackout'] = 'Blackout', 
    ['24h_weather_downpour'] = 'Downpour', 
    ['24h_weather_drizzle_heavy'] = 'Heavy Drizzle', 
    ['24h_weather_distant_rain'] = 'Distant Storm',
    ['24h_weather_courier_clouds'] = 'Dense Clouds',
    ['24h_weather_showroom'] = 'Showroom'
}

local buttonLocalization = {
    ['24h_weather_sunny'] = 'Sunny', 
    ['24h_weather_light_clouds'] = 'Clouds (Light)', 
    ['24h_weather_cloudy'] = 'Clouds', 
    ['24h_weather_heavy_clouds'] = 'Clouds (Heavy)', 
    ['24h_weather_fog'] = 'Fog', 
    ['24h_weather_rain'] = 'Rain', 
    ['24h_weather_toxic_rain'] = 'Rain (Toxic)', 
    ['24h_weather_pollution'] = 'Pollution', 
    ['24h_weather_sandstorm'] = 'Sandstorm', 
    ['q302_light_rain'] = 'Rain (Quest)', 
    ['24h_weather_fog_dense'] = 'Fog (Dense)', 
    ['24h_weather_dew'] = 'Dew', 
    ['24h_weather_haze'] = 'Haze', 
    ['24h_weather_haze_heavy'] = 'Haze (Heavy)', 
    ['24h_weather_haze_pollution'] = 'Haze (Pollution)', 
    ['24h_weather_smog'] = 'Smog', 
    ['24h_weather_clear'] = 'Sunny (Clear)', 
    ['24h_weather_drizzle'] = 'Drizzle', 
    ['24h_weather_windy'] = 'Windy', 
    ['24h_weather_sunny_windy'] = 'Sunny (Windy)', 
    ['24h_weather_storm'] = 'Rain (Storm)', 
    ['24h_weather_overcast'] = 'Clouds (Overcast)', 
    ['24h_weather_drought'] = 'Drought', 
    ['24h_weather_humid'] = 'Drought (Humid)', 
    ['24h_weather_fog_wet'] = 'Fog (Wet)', 
    ['24h_weather_fog_heavy'] = 'Fog (Heav)', 
    ['24h_weather_sunny_sunset'] = 'Sunny (Sunset)', 
    ['24h_weather_drizzle_light'] = 'Drizzle (Light)', 
    ['24h_weather_light_rain'] = 'Rain (Light)', 
    ['24h_weather_rain_alt_1'] = 'Rain (Alt 1)', 
    ['24h_weather_rain_alt_2'] = 'Rain (Alt 2)', 
    ['24h_weather_mist'] = 'Fog (Mist)', 
    ['24h_weather_sky_softbox'] = 'Creative (Softbox)', 
    ['24h_weather_blackout'] = 'Creative (Blackout)', 
    ['24h_weather_downpour'] = 'Rain (Downpour)', 
    ['24h_weather_drizzle_heavy'] = 'Drizzle (Heavy)', 
    ['24h_weather_distant_rain'] = 'Rain (Distant)',
    ['24h_weather_courier_clouds'] = 'Clouds (Desnse)',
    ['24h_weather_showroom'] = 'Creative (Showroom)'
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

function DrawButtons()
	if not cetopen or settings.Current.mywindowhidden == true then
		return
	end
	ImGui.SetNextWindowPos(10, 250, ImGuiCond.FirstUseEver)
	ImGui.SetNextWindowSize(308, 898, ImGuiCond.FirstUseEver)
	if ImGui.Begin('Nova City Tools', true) then
		if ImGui.BeginTabBar("Nova Tabs") then
			if ImGui.BeginTabItem("Weather") then
				ImGui.Text('Vanilla States')
				if ImGui.Button('Sunny', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_sunny', 10, 0)
					settings.Current.weatherState = '24h_weather_sunny'
					Game.GetPlayer():SetWarningMessage('SUNNY!')
				end
				ImGui.SameLine()
				if ImGui.Button('Light Clouds', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_light_clouds', 10, 0)
					settings.Current.weatherState = '24h_weather_light_clouds'
				end
				if ImGui.Button('Cloudy', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_cloudy', 10, 0)
					settings.Current.weatherState = '24h_weather_cloudy'
				end
				ImGui.SameLine()
				if ImGui.Button('Heavy Clouds', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_heavy_clouds', 10, 0)
					settings.Current.weatherState = '24h_weather_heavy_clouds'
				end
				if ImGui.Button('Fog', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_fog', 10, 0)
					settings.Current.weatherState = '24h_weather_fog'
				end
				ImGui.SameLine()
				if ImGui.Button('Rain', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_rain', 10, 0)
					settings.Current.weatherState = '24h_weather_rain'
				end
				if ImGui.Button('Toxic Rain', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_toxic_rain', 10, 0)
					settings.Current.weatherState = '24h_weather_toxic_rain'
				end
				ImGui.SameLine()
				if ImGui.Button('Pollution', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_pollution', 10, 0)
					settings.Current.weatherState = '24h_weather_pollution'
				end
				if ImGui.Button('Sandstorm', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_sandstorm', 10, 0)
					settings.Current.weatherState = '24h_weather_sandstorm'
				end
				ImGui.SameLine()
				if ImGui.Button('Quest Rain', 140, 30) then
					Game.GetWeatherSystem():SetWeather('q302_light_rain', 10, 0)
					settings.Current.weatherState = 'q302_light_rain'
				end
				ImGui.Text('Nova Beta States')
				if ImGui.Button('Dense Fog', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_fog_dense', 10, 0)
					settings.Current.weatherState = '24h_weather_fog_dense'
				end
				ImGui.SameLine()
				if ImGui.Button('Dew', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_dew', 10, 0)
					settings.Current.weatherState = '24h_weather_dew'
				end
				if ImGui.Button('Haze', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_haze', 10, 0)
					settings.Current.weatherState = '24h_weather_haze'
				end
				ImGui.SameLine()
				if ImGui.Button('Heavy Haze', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_haze_heavy', 10, 0)
					settings.Current.weatherState = '24h_weather_haze_heavy'
				end
				if ImGui.Button('Haze Poll.', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_haze_pollution', 10, 0)
					settings.Current.weatherState = '24h_weather_haze_pollution'
				end
				ImGui.SameLine()
				if ImGui.Button('Smog', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_smog', 10, 0)
					settings.Current.weatherState = '24h_weather_smog'
				end
				if ImGui.Button('Clear', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_clear', 10, 0)
					settings.Current.weatherState = '24h_weather_clear'
				end
				ImGui.SameLine()
				if ImGui.Button('Drizzle', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_drizzle', 10, 0)
					settings.Current.weatherState = '24h_weather_drizzle'
				end
				if ImGui.Button('Windy', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_windy', 10, 0)
					settings.Current.weatherState = '24h_weather_windy'
				end
				ImGui.SameLine()
				if ImGui.Button('Sunny Windy', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_sunny_windy', 10, 0)
					settings.Current.weatherState = '24h_weather_sunny_windy'
				end
				if ImGui.Button('Storm', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_storm', 10, 0)
					settings.Current.weatherState = '24h_weather_storm'
				end
				ImGui.SameLine()
				if ImGui.Button('Overcast', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_overcast', 10, 0)
					settings.Current.weatherState = '24h_weather_overcast'
				end
				if ImGui.Button('Drought', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_drought', 10, 0)
					settings.Current.weatherState = '24h_weather_drought'
				end
				ImGui.SameLine()
				if ImGui.Button('Humid', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_humid', 10, 0)
					settings.Current.weatherState = '24h_weather_humid'
				end
				ImGui.Text('Nova Alpha States')
				if ImGui.Button('Fog Wet', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_fog_wet', 10, 0)
					settings.Current.weatherState = '24h_weather_fog_wet'
				end
				ImGui.SameLine()
				if ImGui.Button('Heavy Fog', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_fog_heavy', 10, 0)
					settings.Current.weatherState = '24h_weather_fog_heavy'
				end
				if ImGui.Button('Sunny Wind', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_sunny_windy', 10, 0)
					settings.Current.weatherState = '24h_weather_sunny_windy'
				end
				ImGui.SameLine()
				if ImGui.Button('Sunset', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_sunny_sunset', 10, 0)
					settings.Current.weatherState = '24h_weather_sunny_sunset'
				end
				if ImGui.Button('Drizzle Light', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_drizzle_light', 10, 0)
					settings.Current.weatherState = '24h_weather_drizzle_light'
				end
				ImGui.SameLine()
				if ImGui.Button('Light Rain', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_light_rain', 10, 0)
					settings.Current.weatherState = '24h_weather_light_rain'
				end
				if ImGui.Button('Rain Alt 1', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_rain_alt_1', 10, 0)
					settings.Current.weatherState = '24h_weather_rain_alt_1'
				end
				ImGui.SameLine()
				if ImGui.Button('Rain Alt 2', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_rain_alt_2', 10, 0)
					settings.Current.weatherState = '24h_weather_rain_alt_2'
				end
				if ImGui.Button('Mist', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_mist', 10, 0)
					settings.Current.weatherState = '24h_weather_mist'
				end
				ImGui.SameLine()
				if ImGui.Button('Dense Clouds', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_courier_clouds', 10, 0)
					settings.Current.weatherState = '24h_weather_courier_clouds'
				end
				ImGui.Text('Nova Concept States')
				if ImGui.Button('Distant Storm', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_distant_rain', 10, 0)
					settings.Current.weatherState = '24h_weather_distant_rain'
				end
				ImGui.SameLine()
				if ImGui.Button('Drizzle Heavy', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_drizzle_heavy', 10, 0)
					settings.Current.weatherState = '24h_weather_drizzle_heavy'
				end
				if ImGui.Button('Downpour', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_downpour', 10, 0)
					settings.Current.weatherState = '24h_weather_downpour'
				end
				ImGui.Text('Creative')
				if ImGui.Button('Sky Softbox', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_sky_softbox', 10, 0)
					settings.Current.weatherState = '24h_weather_sky_softbox'
				end
				ImGui.SameLine()
				if ImGui.Button('Blackout', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_blackout', 10, 0)
					settings.Current.weatherState = '24h_weather_blackout'
				end

				if ImGui.Button('Showroom', 140, 30) then
					Game.GetWeatherSystem():SetWeather('24h_weather_showroom', 10, 0)
					settings.Current.weatherState = '24h_weather_showroom'
				end

				ImGui.Dummy(0, 10)
				ImGui.Separator()
				ImGui.Text("Weather Control:")				

				if ImGui.Button('Reset Weather', 290, 30) then
					Game.GetWeatherSystem():ResetWeather(true)
					settings.Current.weatherState = 'None'
					settings.Current.nativeWeather = 1
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
				local localizedCurrentWeatherState = weatherStateLocalization[currentWeatherState] or currentWeatherState
				ImGui.Text(localizedCurrentWeatherState)

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
				ui.tooltip("DLSSD Separate Particle Color - Disabling will reduce \n distant shimmering but also makes other paricles invisible \n like rain and debris particles. Disabling is not recommended.")

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

registerForEvent("onInit", function()
	LoadSettings()
end)

registerForEvent('onDraw', function()
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
