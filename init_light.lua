------------------------------------------------------
-- NovaCityTools v1.7.8b
-- 2024 by CyanideX
-- https://next.nexusmods.com/profile/theCyanideX/mods
------------------------------------------------------

local Cron = require("Cron")
local GameUI = require("GameUI")
local GameSettings = require("GameSettings")
local modName = "Nova City"
local modVersion = "1.7.8b"
local cetOpen = false
local hasResetOrForced = false
local weatherReset = false
local resetWindow = false
local currentWeatherState = nil
local timeScale = 1.0
local searchText = ""
local collapsedCategories = {}
local weatherStates = {}
local weatherStateNames = {}
local weatherTypeKeywords = {}
local categories = {}

local settings =
{
	Current = {
		weatherState = "None",
		transitionDuration = 0,
		timeSliderWindowOpen = false,
		warningMessages = true,
		notificationMessages = true,
		debugOutput = false,
	},
	Default = {
		weatherState = "None",
		transitionDuration = 0,
		timeSliderWindowOpen = false,
		warningMessages = true,
		notificationMessages = true,
		debugOutput = false,
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

function LoadWeatherStates()
    local function processFile(filePath)
        local fileHandle = io.open(filePath, "r")
        if fileHandle then
            local content = fileHandle:read("*a")
            fileHandle:close()
            local success, data = pcall(json.decode, content)
            if success and data then
                for category, info in pairs(data) do
                    table.insert(categories, { name = category, order = info.order })
                    for _, state in ipairs(info.states) do
                        table.insert(weatherStates, { state.location, state.name, category, state.DLSSDSeparateParticleColor, state.weatherType })
                        weatherStateNames[state.location] = state.name
                        if state.weatherType then
                            weatherTypeKeywords[state.location] = state.weatherType
                        end
                    end
                end
				DebugPrint("Successfully loaded "  .. filePath)
            else
                print(IconGlyphs.CityVariant .. " Nova City Tools: Failed to decode JSON content from " .. filePath)
            end
        else
            print(IconGlyphs.CityVariant .. " Nova City Tools: No file found at " .. filePath)
        end
    end
    -- Load weather states from weatherStates.json
    processFile("weatherStates.json")
end

function SortWeatherStates()
	table.sort(weatherStates, function(a, b)
		return a[2] < b[2]
	end)
end

function SortCategories()
	table.sort(categories, function(a, b)
		return a.order < b.order
	end)
end

function DebugPrint(message)
	if settings.Current.debugOutput then
		print(IconGlyphs.CityVariant .. " Nova City Tools: " .. message)
	end
end

----------------------------------------
------------- RES PRESETS --------------
----------------------------------------

function SetResolutionPresets(width, height)
	local presets = {
	 -- { 1,    2,    3, 4, 5, 6, 7, 8, 9, 10, 11,   12,  13, 14, 15,   16, 17, 18,  19, 20, 21, 22,  23,  24,  25,  26, 27, 28, 29, 30, 31, 32,  33, 34 },
		{ 3840, 2160, 8, 6, 5, 5, 6, 7, 1, 1,  0.7,  140, 34, 36, 0.62, 1,  6,  320, 33, 34, 6,  650, 250, 336, 7.5, 9,  8,  5,  34, 34, 30, 140, 36, 36 },
		{ 2560, 1440, 8, 6, 1, 3, 6, 7, 1, 1,  0.45, 122, 28, 28, 0.85, 1,  8,  272, 29, 34, 4,  500, 219, 298, 7.5, 8,  8,  3,  32, 32, 18, 125, 34, 36 },
		{ 1920, 1080, 5, 4, 1, 4, 6, 6, 1, 1,  0.5,  100, 24, 24, 0.85, 1,  0,  221, 21, 30, 4,  400, 169, 230, 4.8, 9,  8,  6,  27, 27, 16, 100, 30, 22 },
		{ 0,    0,    5, 4, 1, 4, 6, 6, 1, 1,  0.5,  100, 24, 24, 0.85, 1,  0,  221, 21, 30, 4,  400, 169, 230, 4.8, 9,  8,  6,  27, 27, 16, 100, 30, 22 }
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
			invisibleButtonWidth = preset[33]
            invisibleButtonHeight = preset[34]
			break
		end
	end
end

----------------------------------------
------------- CET HOTKEYS --------------
----------------------------------------

-- Register a CET hotkey to reset weather
registerHotkey("NCTResetWeather", "Reset Weather", function()
	Game.GetWeatherSystem():ResetWeather(true)
	settings.Current.weatherState = "None"
	-- settings.Current.nativeWeather = 1
	Game.GetPlayer():SetWarningMessage("Weather reset to default cycles! \nWeather states will progress automatically.")
	GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", true)
	toggleDLSSDPT = true
	DebugPrint("DLSSD set to " .. tostring(toggleDLSSDPT))
	SaveSettings()
	weatherReset = true
end)

-- Register a CET hotkey to toggle freeze time
registerHotkey("NCTFreezeToggle", "Freeze Time Toggle", function()
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
registerHotkey("NCTIncreaseTime", "Increase Time Scale", function()
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
registerHotkey("NCTDecreaseTime", "Decrease Time Scale", function()
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
registerHotkey("NCTResetTime", "Reset Time Scale", function()
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
registerHotkey("NCTHDRToggle", "Toggle HDR Mode", function()
	local options, current = GameSettings.Options("/video/display/HDRModes")
	local hdrMode = (current % 2) + 1

	-- Change labels
	local displayOptions = { "SDR", "HDR" }

	GameSettings.Set("/video/display/HDRModes", options[hdrMode])
	GameSettings.Save()

	if GameSettings.NeedsConfirmation() then
		GameSettings.Confirm()
	end

	if settings.Current.warningMessages then
		ShowWarningMessage(("Switched display mode from %s to %s"):format(displayOptions[current],
			displayOptions[hdrMode]))
	end
	if settings.Current.notificationMessages then
		ShowNotificationMessage(("Switched display mode from %s to %s"):format(displayOptions[current],
			displayOptions[hdrMode]))
	end
end)

----------------------------------------
---------------- MAIN ------------------
----------------------------------------

registerForEvent("onInit", function()
	print(IconGlyphs.CityVariant .. " Nova City Tools: Initialized")
	LoadSettings()
	LoadWeatherStates()
	SortWeatherStates()
	SortCategories()
end)

registerForEvent("onDraw", function()
	if timeSliderWindowOpen == true then
		DrawTimeSliderWindow()
	end
	DrawGUI()
end)

registerForEvent("onOverlayOpen", function()
	LoadSettings()
	cetOpen = true
	width, height = GetDisplayResolution()
	SetResolutionPresets(width, height)
end)

registerForEvent("onOverlayClose", function()
	cetOpen = false
	SaveSettings()
end)

registerForEvent("onUpdate", function()
	Cron.Update(delta)
	if hasResetOrForced then
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
			DebugPrint("Weather changed to " .. (tostring(currentWeatherState)))
		end
		-- Reset the weather reset flag after the weather change notification has been skipped
		weatherReset = false
	end
end)

function KeywordMatches(keywords, searchText)
	for _, keyword in ipairs(keywords) do
		if string.find(keyword:lower(), searchText:lower()) then
			return true
		end
	end
	return false
end

----------------------------------------
----------- WEATHER CONTROL-------------
----------------------------------------

function DrawWeatherControl()
	ImGui.Text("Weather Control:")

	-- Make the reset button fit the width of the GUI
	local resetButtonWidth = ImGui.GetWindowContentRegionWidth()

	-- Change button color, hover color, and text color
	ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(1, 0.3, 0.3, 1))       -- Custom button color
	ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(1, 0.45, 0.45, 1)) -- Custom hover color
	ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0, 0, 0, 1))             -- Custom text color
	if ImGui.Button("Reset Weather", resetButtonWidth, buttonHeight) then
		Game.GetWeatherSystem():ResetWeather(true)
		settings.Current.weatherState = "None"
		Game.GetPlayer():SetWarningMessage("Weather reset to default cycles! \nWeather states will progress automatically.")
		GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", true)
		toggleDLSSDPT = true
		DebugPrint("DLSSD set to " .. tostring(toggleDLSSDPT))
		DebugPrint("Weather reset")
		SaveSettings()
		weatherReset = true
	end
	-- Revert to original color
	ImGui.PopStyleColor(3)

	ui.tooltip("Reset any manually selected states and returns the weather to \nits default weather cycles, starting with the sunny weather state. \nWeather will continue to advance naturally.")

	local selectedWeatherState = settings.Current.weatherState
	if selectedWeatherState == "None" then
		selectedWeatherState = "Default Cycles"
	else
		selectedWeatherState = "Locked State"
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

----------------------------------------
------------ DRAW BUTTONS --------------
----------------------------------------

function DrawGUI()
	-- Check if the CET window is open
	if not cetOpen then
		return
	end

	-- Set window size constraints
	ImGui.SetNextWindowSizeConstraints(uiMinWidth, 10, width / 100 * 50, height / 100 * 90)
	if resetWindow then
		ImGui.SetNextWindowPos(6, 160, ImGuiCond.Always)
		ImGui.SetNextWindowSize(312, 1168, ImGuiCond.Always)
		ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 5)
		ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 5)
		resetWindow = false
	end
	if ImGui.Begin("Nova City Tools - v" .. modVersion, true, ImGuiWindowFlags.NoScrollbar) then
		-- Reset padding
		ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, frameTabPaddingXValue, frameTabPaddingYValue)
		ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, itemTabSpacingYValue)

		-- Set the font scale for the window
		ImGui.SetWindowFontScale(customFontScale)

		if ImGui.BeginTabBar("Nova Tabs") then
			ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize("XXX"))

			-- TIME SLIDER TOGGLE ------------------------
			-- Set button text alignment and frame padding
			ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
			ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, glyphFramePaddingXValue, glyphFramePaddingYValue)

			-- Create the button and toggle the time slider window
			if timeSliderWindowOpen then
				ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0.0, 1, 0.7, 1))
				ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0, 0.8, 0.56, 1))
				ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0.1, 0.8, 0.6, 1))
				ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0, 0, 0, 1))
				if ImGui.Button(IconGlyphs.ClockOutline, glyphButtonWidth, glyphButtonHeight) then
					DebugPrint("Closing time slider window.")
					timeSliderWindowOpen = false
					settings.Current.timeSliderWindowOpen = timeSliderWindowOpen
					SaveSettings()
				end
				ImGui.PopStyleColor(4)
			else
				ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0.4, 1, 0.8, 1))
				ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0.3, 0.3, 0.3, 1))
				if ImGui.Button(IconGlyphs.ClockOutline, glyphButtonWidth, glyphButtonHeight) then
					DebugPrint("Opening time slider window.")
					timeSliderWindowOpen = true
					settings.Current.timeSliderWindowOpen = timeSliderWindowOpen
					SaveSettings()
				end
				-- Reset style variables
				ImGui.PopStyleColor(2)
			end

			ui.tooltip("Toggles the time slider window.")

			ImGui.PopStyleVar(2)

			--if ImGui.BeginTabItem(IconGlyphs.WeatherPartlyCloudy) then
			if ImGui.BeginTabItem("Weather") then
				local availableWidth = ImGui.GetContentRegionAvail() - searchPaddingXValue

				ImGui.Dummy(0, dummySpacingYValue)
				ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, framePaddingXValue, framePaddingYValue)

				if searchIcon == IconGlyphs.MagnifyClose then
					ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1) -- Set color to red
				end
				InvisibleButton(searchIcon)
				if ImGui.IsItemClicked() and searchIcon == IconGlyphs.MagnifyClose then
					searchText = ""
					searchIcon = IconGlyphs.Magnify
				end
				if ImGui.IsItemHovered() then
					ImGui.PopStyleColor()
					ui.tooltip("Click to clear search.")
				end
				if searchIcon == IconGlyphs.MagnifyClose then
					ImGui.PopStyleColor()
				end
				ImGui.SameLine()
				ImGui.SetNextItemWidth(availableWidth)

				-- Push text within the search bar
				ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 10, searchPaddingYValue)
				searchText = ImGui.InputText(" ", searchText, 100)
				if searchText ~= "" then
					searchIcon = IconGlyphs.MagnifyClose
				else
					searchIcon = IconGlyphs.Magnify
					ui.tooltip("Search for a weather state by typing in this field.\nUse keywords like 'wet', 'hot', 'bright', to search by properties.")
				end
				ImGui.PopStyleVar()

				ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, framePaddingXValue, framePaddingYValue)
				ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, itemSpacingXValue, itemSpacingYValue)

				for _, category in ipairs(categories) do
					local isCollapsed = collapsedCategories[category.name] or false
					ImGui.PushStyleColor(ImGuiCol.Header, ImGui.GetColorU32(0, 0, 0, 0))
					ImGui.PushStyleColor(ImGuiCol.HeaderHovered, ImGui.GetColorU32(0, 0, 0, 0))
					ImGui.PushStyleColor(ImGuiCol.HeaderActive, ImGui.GetColorU32(0, 0, 0, 0))
					if ImGui.CollapsingHeader(category.name .. " ", isCollapsed and ImGuiTreeNodeFlags.None or ImGuiTreeNodeFlags.DefaultOpen) then
						if collapsedCategories[category.name] then
							collapsedCategories[category.name] = false
							SaveSettings()
						end
						ImGui.Dummy(0, dummySpacingYValue)
						local windowWidth = ImGui.GetWindowWidth()
						local buttonsPerRow = math.floor(windowWidth / buttonWidth)
						local buttonCount = 0
						for _, state in ipairs(weatherStates) do
							local weatherState = state[1]
							local localization = state[2]
							local stateCategory = state[3]
							local enableDLSSDPT = state[4]
							local weatherType = state[5]
							if stateCategory == category.name and (searchText == "" or string.find(localization:lower(), searchText:lower()) or (weatherType and KeywordMatches(weatherType, searchText))) then
								local isActive = settings.Current.weatherState == weatherState
								if isActive then
									ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0.0, 1, 0.7, 1))
									ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0, 0.8, 0.56, 1))
									ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0.1, 0.8, 0.6, 1))
									ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0, 0, 0, 1))
								else
									ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0.14, 0.27, 0.43, 1))
									ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0.26, 0.59, 0.98, 1))
									ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0.3, 0.3, 0.3, 1))
									ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(1, 1, 1, 1))
								end
								if ImGui.Button(localization, buttonWidth, buttonHeight) then
									if isActive then
										Game.GetWeatherSystem():ResetWeather(true)
										settings.Current.weatherState = "None"
										Game.GetPlayer():SetWarningMessage("Weather reset to default cycles! \nWeather states will progress automatically.")
										GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", true)
										toggleDLSSDPT = true
										DebugPrint("DLSSD set to " .. tostring(toggleDLSSDPT))
										weatherReset = true
										DebugPrint("Weather reset to default cycles.")
									else
										Game.GetWeatherSystem():SetWeather(weatherState, settings.transitionTime, 10)
										settings.Current.weatherState = weatherState
										Game.GetPlayer():SetWarningMessage("Locked weather state to " .. localization:lower() .. "!")
										GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", enableDLSSDPT)
										toggleDLSSDPT = enableDLSSDPT
										DebugPrint("DLSSD set to " .. tostring(toggleDLSSDPT))
										DebugPrint("Weather locked to selected state.")
									end
									SaveSettings()
								end

								if isActive then
									ImGui.PopStyleColor(4)
								end

								buttonCount = buttonCount + 1
								if buttonCount % buttonsPerRow ~= 0 then
									ImGui.SameLine()
								end
							end
						end
						if buttonCount % buttonsPerRow ~= 0 then
							ImGui.NewLine()
						end
						ImGui.Dummy(0, dummySpacingYValue) -- Added here
					else
						if not collapsedCategories[category.name] then
							collapsedCategories[category.name] = true
							SaveSettings()
						end
					end
					ImGui.PopStyleColor(3)
					ImGui.Separator()
				end
				DrawWeatherControl()
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
				local amPm = math.floor(totalMinutes / 60) < 12 and "AM" or "PM"
				local timeLabel = string.format("%02d:%02d %s", hours12, mins, amPm)

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
				totalMinutes, changed = ImGui.SliderInt("##", totalMinutes, 0, 24 * 60 - 1)
				if changed then
					local hours = math.floor(totalMinutes / 60)
					local mins = totalMinutes % 60
					Game.GetTimeSystem():SetGameTimeByHMS(hours, mins, secs)
				end

				ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, framePaddingXValue, framePaddingYValue) -- Reset padding

				-- Add a new section for weather transition duration presets
				ImGui.Dummy(0, dummySpacingYValue + 10)
				ImGui.Text("Weather Transition Duration:")

				ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - 10)
				ImGui.Text(tostring(settings.Current.transitionDuration) .. "s")
				ImGui.Separator()
				ImGui.Dummy(0, dummySpacingYValue)

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
					if ImGui.Button(tostring(duration) .. "s", buttonWidth, buttonHeight) then
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

				ImGui.Dummy(0, dummySpacingYValue + 10)
				ImGui.Text("Weather state notifications:")
				ImGui.Separator()
				ImGui.Dummy(0, dummySpacingYValue)

				settings.Current.warningMessages, changed = ImGui.Checkbox("Warning Message",
					settings.Current.warningMessages)
				if changed then
					DebugPrint("Toggled warning message to " .. tostring(settings.Current.warningMessages))
					SaveSettings()
				end
				ui.tooltip("Show warning message when naturally progressing to a new weather state. \nNotifications only occur with default cycles during natural transitions. \nManually selected states will always show a warning notification.")
				settings.Current.notificationMessages, changed = ImGui.Checkbox("Notification",
					settings.Current.notificationMessages)
				if changed then
					DebugPrint("Toggled notifications to " .. tostring(settings.Current.notificationMessages))
					SaveSettings()
				end
				ui.tooltip("Show side notification when naturally progressing to a new weather state. \nNotifications only occur with default cycles during natural transitions. \nManually selected states will always show a warning notification.")

				ImGui.Dummy(0, dummySpacingYValue + 10)
				ImGui.Text("Debug:")
				ImGui.Separator()
				ImGui.Dummy(0, dummySpacingYValue)

				settings.Current.debugOutput, changed = ImGui.Checkbox("Debug Output", settings.Current.debugOutput)
				if changed then
					print(IconGlyphs.CityVariant .. " Nova City Tools: Toggled debug output to " .. tostring(settings.Current.debugOutput))
					SaveSettings()
				end

				ImGui.Dummy(0, dummySpacingYValue)

				local resetButtonWidth = ImGui.GetWindowContentRegionWidth()

				if not Game.GetSystemRequestsHandler():IsPreGame() and not Game.GetSystemRequestsHandler():IsGamePaused() then
					ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0.1, 0.8, 0.6, 1))
					if ImGui.Button("Export Debug File", resetButtonWidth, buttonHeight) then
						ExportDebugFile()
						print(IconGlyphs.CityVariant .. " Nova City Tools: Exported debug file ")
					end
					ImGui.PopStyleColor()
					ui.tooltip("Export debug information to novaCityDebug.json file in the NovaCityTools CET mod folder.\nShare this file with the author when submitting a bug report.")
				else
					ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0.3, 0.3, 0.3, 1))
					ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0.35, 0.35, 0.35, 1))
					ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0.35, 0.35, 0.35, 1))
					ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0.6, 0.6, 0.6, 1))
					if ImGui.Button("Export Debug File", resetButtonWidth, buttonHeight) then
						print(IconGlyphs.CityVariant .. " Nova City Tools: Cannot export debug file while in menu")
					end
					ImGui.PopStyleColor(4)
					ui.tooltip("Cannot export debug file while in menu")
				end

				ImGui.Dummy(0, dummySpacingYValue)
				ImGui.Separator()
				ImGui.Dummy(0, dummySpacingYValue)

				if ImGui.Button("Reset GUI", resetButtonWidth, buttonHeight) then
					resetWindow = true
					DebugPrint(IconGlyphs.CityVariant .. " Nova City Tools: Reset GUI size and position.")
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

----------------------------------------
------------- EXPORT DEBUG -------------
----------------------------------------

function ExportDebugFile()
	-- Check if the player is in menu or game is paused
	if Game.GetSystemRequestsHandler():IsPreGame() or Game.GetSystemRequestsHandler():IsGamePaused() then
		return
	end

	local pos = ToVector4(Game.GetPlayer():GetWorldPosition())
	local inVehicle = false
	local file = io.open("novaCityDebug.json", "r")
	local debugData = {}
	local selectedWeatherState = settings.Current.weatherState
	if selectedWeatherState == "None" then
		selectedWeatherState = "Default Cycles"
	else
		selectedWeatherState = "Locked State"
	end

	if not Game.GetPlayer().mountedVehicle then
		if inVehicle then
			inVehicle = false
		end
	else
		if not inVehicle then
			inVehicle = true
		end
	end

	-- Collect data with error handling
	local data = {
		modName = tostring(modName),
		modVersion = tostring(modVersion) or nil,
		gameVersion = Game.GetSystemRequestsHandler():GetGameVersion() or nil,
		dateTime = os.date("%m/%d/%Y - %H:%M:%S", os.time()) or nil,
		weatherCycleMode = tostring(selectedWeatherState),
		localizedState = tostring(weatherStateNames[currentWeatherState]),
		weatherState = (Game.GetWeatherSystem():GetWeatherState() and Game.GetWeatherSystem():GetWeatherState().name.value) or
		nil,
		gameTime = tostring(Game.GetTimeSystem():GetGameTime():ToString()),
		inVehicle = inVehicle,
		playerDirection = (function()
			local dir = Game.GetPlayer():GetWorldOrientation():ToEulerAngles()
			if dir then
				return { roll = dir.roll, pitch = dir.pitch, yaw = dir.yaw }
			else
				return { roll = 0, pitch = 0, yaw = -180 }
			end
		end)(),
		playerPosition = (function()
			if pos then
				return { x = pos.x, y = pos.y, z = pos.z, w = 1.0 }
			else
				return { x = 0.0, y = 0.0, z = 0.0, w = 1.0 }
			end
		end)()
	}

	-- Read existing data from Debug.json
	if file then
		local content = file:read("*a")
		debugData = json.decode(content)
		file:close()
	end

	-- Insert new data in the same order as defined in 'data'
	table.insert(debugData, {
		modName = data.modName,
		modVersion = data.modVersion,
		gameVersion = data.gameVersion,
		dateTime = data.dateTime,
		weatherCycleMode = data.weatherCycleMode,
		localizedState = data.localizedState,
		weatherState = data.weatherState,
		gameTime = data.gameTime,
		inVehicle = data.inVehicle,
		playerDirection = data.playerDirection,
		playerPosition = data.playerPosition
	})

	-- Write updated data to Debug.json
	file = io.open("novaCityDebug.json", "w")
	if file then
		file:write(json.encode(debugData))
		file:close()
	else
		print(IconGlyphs.CityVariant .. " Nova City Tools: Error - Could not open Debug.json for writing")
	end
end

----------------------------------------
--------- TIME SLIDER WINDOW -----------
----------------------------------------

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

	if ImGui.Begin("Time Slider", ImGuiWindowFlags.NoScrollbar) then
		-- Set the custom font scale
		ImGui.SetWindowFontScale(customFontScale)

		-- Get current game time
		local currentTime = Game.GetTimeSystem():GetGameTime()
		local totalMinutes = currentTime:Hours() * 60 + currentTime:Minutes()
		local hours12 = math.floor(totalMinutes / 60) % 12
		if hours12 == 0 then hours12 = 12 end
		local mins = totalMinutes % 60
		local amPm = math.floor(totalMinutes / 60) < 12 and "AM" or "PM"
		local timeLabel = string.format("%02d:%02d %s", hours12, mins, amPm)

		ImGui.Text("Adjust Game Time:")
		ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 10, 6) -- Slider height
		ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize(timeLabel))
		ImGui.Text(timeLabel)
		ImGui.SetNextItemWidth(-1)
		totalMinutes, changed = ImGui.SliderInt("##", totalMinutes, 0, 24 * 60 - 1)
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
		local availableWidth = ImGui.GetWindowContentRegionWidth() - 2 * glyphButtonWidth -
			2 * ImGui.GetStyle().ItemSpacing.x - 4
		ImGui.SetNextItemWidth(availableWidth)
		timeScale, changed = ImGui.SliderFloat("##TimeScale", timeScale, 0.001, 10.0, "%.003f")
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
			end
			ImGui.PopStyleColor(2)
		else
			if ImGui.Button(IconGlyphs.Snowflake, glyphButtonWidth, glyphButtonHeight) then
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
			end
		end

		ui.tooltip("Freeze time (toggle)")

		ImGui.PopStyleVar(3)

		ImGui.End()
	end
end

----------------------------------------
------------ NOTIFICATIONS -------------
----------------------------------------

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

----------------------------------------
-------------- SAVE/LOAD ---------------
----------------------------------------

function SaveSettings()
	local saveData = {
		transitionDuration = settings.Current.transitionDuration,
		timeSliderWindowOpen = settings.Current.timeSliderWindowOpen,
		weatherState = settings.Current.weatherState,
		warningMessages = settings.Current.warningMessages,
		notificationMessages = settings.Current.notificationMessages,
		debugOutput = settings.Current.debugOutput, -- Added debugOutput
		collapsedCategories = {}
	}

	for k, v in pairs(collapsedCategories) do
		if v then
			saveData.collapsedCategories[k] = v
		end
	end

	local function formatTable(t, indent)
		local formatted = "{\n"
		local indentStr = string.rep("    ", indent)
		local count = 0
		local total = 0
		for _ in pairs(t) do total = total + 1 end
		for k, v in pairs(t) do
			count = count + 1
			formatted = formatted .. indentStr .. string.format('"%s": ', k)
			if type(v) == "table" then
				formatted = formatted .. formatTable(v, indent + 1)
			elseif type(v) == "string" then
				formatted = formatted .. string.format('"%s"', v)
			else
				formatted = formatted .. tostring(v)
			end
			if count < total then
				formatted = formatted .. ",\n"
			else
				formatted = formatted .. "\n"
			end
		end
		return formatted .. string.rep("    ", indent - 1) .. "}"
	end

	local file = io.open("settings.json", "w")
	if file then
		local formattedJsonString = formatTable(saveData, 1)
		file:write(formattedJsonString)
		file:close()
		DebugPrint("Settings saved")
	else
		print(IconGlyphs.CityVariant .. " Nova City Tools: ERROR - Unable to open file for writing")
	end
end

function LoadSettings()
	local file = io.open("settings.json", "r")
	if file then
		local content = file:read("*all")
		file:close()
		local loadedSettings = json.decode(content)
		settings.Current = loadedSettings
		timeSliderWindowOpen = settings.Current.timeSliderWindowOpen
		collapsedCategories = loadedSettings.collapsedCategories or {}
		print(IconGlyphs.CityVariant .. " Nova City Tools: Settings loaded")
	elseif not file then
		print(IconGlyphs.CityVariant .. " Nova City Tools: Settings file not found")
		print(IconGlyphs.CityVariant .. " Nova City Tools: Creating default settings file")
		return
	end
end

----------------------------------------
------------- styling stuff ------------
----------------------------------------

function InvisibleButton(text, active)
	-- define 4 styles
	ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, glyphFramePaddingXValue, glyphFramePaddingYValue)
	ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, glyphItemSpacingXValue, glyphItemSpacingYValue)
	ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 0, 0)
	ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, glyphAlignYValue)

	-- define 3 colors (transparent)
	ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(1, 0, 0, 0))
	ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0, 0, 0, 0))
	ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0, 0, 0, 0))

	-- conditional text color
	if active then
		ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0, 1, 0.7, 1))
	end

	-- draw useless button
	ImGui.Button(text, invisibleButtonWidth, invisibleButtonHeight)

	-- drop active color
	if active then
		ImGui.PopStyleColor(1)
	end

	-- drop 3 colors
	ImGui.PopStyleColor(3)

	-- drop 4 styles
	ImGui.PopStyleVar(4)
end