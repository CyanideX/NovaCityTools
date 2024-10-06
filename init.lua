------------------------------------------------------
-- NovaCityTools
-- 2024 by CyanideX
-- https://next.nexusmods.com/profile/theCyanideX/mods
------------------------------------------------------

local Cron = require("Cron")
local GameUI = require("GameUI")
local GameSettings = require("GameSettings")

local modName = "Nova City"
local modVersion = "1.8.2"
local changelog = {}

local isNewVersion = false
local updateWindowDismissed = false
local showPastVersions = false

local cetOpen = false
local guiFlags
local showExportWindow = false
local issueDescription = ""

local toggleFog = true
local toggleFogClouds = true
local volumetricFog = true
local distantVolumetricFog = true
local distantFog = true
local clouds = true

local toggleDLSSDPT = true
local rain = true
local rainMap = true

local bloom = true
local lensFlares = false
local chromaticAberration = true
local filmGrain = true
local dof = true
local motionBlur = true
local motionBlurIndex = 2

local RIS = false
local toggleNRD = false

local vehicleCollisions = true
local stopVehicleSpawning = true
local vehicleSpawning = true
local crowdSpawning = true

local tonemapping = true
local graphics = true

local hasResetOrForced = false
local weatherReset = false
local resetWindow = false

local timeScale = 1.0
local searchText = ""
local userInteracted = false

local previousWeatherState = nil
local currentWeatherState = nil
local weatherStateHistory = {}
local weatherStates = {}
local weatherStateNames = {}
local weatherTypeKeywords = {}
local categories = {}
local collapsedCategories = {}

local settings =
{
	Current = {
		weatherState = "None",
		transitionDuration = 0,
		timeSliderWindowOpen = false,
		warningMessages = true,
		notificationMessages = true,
		autoApplyWeather = false,
		debugOutput = false,
		scrollbarEnabled = false,
		tooltipsEnabled = true,
		advancedToggles = false,
		motionBlurScale = 0.5,
	},
	Default = {
		weatherState = "None",
		transitionDuration = 0,
		timeSliderWindowOpen = false,
		warningMessages = true,
		notificationMessages = true,
		autoApplyWeather = false,
		debugOutput = false,
		scrollbarEnabled = false,
		tooltipsEnabled = true,
		advancedToggles = false,
		motionBlurScale = 0.5,
	}
}

local ui = {
	tooltip = function(text, alwaysShow)
		if (alwaysShow or settings.Current.tooltipsEnabled) and ImGui.IsItemHovered() and text ~= "" then
			ImGui.BeginTooltip()
			ImGui.SetTooltip(text)
			ImGui.EndTooltip()
		end
	end
}

local function loadWeatherStates()
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
				debugPrint("Successfully loaded "  .. filePath)
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

local function loadChangelog()
    local function processFile(filePath)
        local fileHandle = io.open(filePath, "r")
        if fileHandle then
            local content = fileHandle:read("*a")
            fileHandle:close()
            local success, data = pcall(json.decode, content)
            if success and data then
                changelog = data
                debugPrint("Successfully loaded " .. filePath)
            else
                print(IconGlyphs.CityVariant .. " Nova City Tools: Failed to decode JSON content from " .. filePath)
            end
        else
            print(IconGlyphs.CityVariant .. " Nova City Tools: No file found at " .. filePath)
        end
    end
    -- Load changelog from changelog.json
    processFile("changelog.json")
end

local function sortWeatherStates()
	table.sort(weatherStates, function(a, b)
		return a[2] < b[2]
	end)
end

local function sortCategories()
	table.sort(categories, function(a, b)
		return a.order < b.order
	end)
end

local function UpdateUserSettings()
	rayReconstruction = Game.GetSettingsSystem():GetVar("/graphics/presets", "DLSS_D"):GetValue()
	filmGrain = Game.GetSettingsSystem():GetVar("/graphics/basic", "FilmGrain"):GetValue()
	chromaticAberration = Game.GetSettingsSystem():GetVar("/graphics/basic", "ChromaticAberration"):GetValue()
	dof = Game.GetSettingsSystem():GetVar("/graphics/basic", "DepthOfField"):GetValue()
	lensFlares = Game.GetSettingsSystem():GetVar("/graphics/basic", "LensFlares"):GetValue()
	motionBlurIndex = Game.GetSettingsSystem():GetVar("/graphics/basic", "MotionBlur"):GetIndex()
	motionBlur = motionBlurIndex ~= 0
end

local function updateWeatherStateHistory(newState)
    table.insert(weatherStateHistory, 1, newState)
    if #weatherStateHistory > 10 then
        table.remove(weatherStateHistory)
    end
end

local function getRandomWeatherState()
    return weatherStates[math.random(#weatherStates)][1]
end

local function getRandomTime()
    return math.random(0, 1440) -- Random minute in a 24-hour period
end

----------------------------------------
----------------- MAIN -----------------
----------------------------------------

registerForEvent("onInit", function()
	print(IconGlyphs.CityVariant .. " Nova City Tools: Initialized")

	LoadSettings()

	loadWeatherStates()
	sortWeatherStates()
	sortCategories()
	loadChangelog()
	
	ObserveAfter("inkISystemRequestsHandler", "RequestSaveUserSettings", function(this)
		if changedAnySetting then
			local timer = Cron.After(0.1, function()
				Game.GetSystemRequestsHandler():UnpauseGame()
				changedAnySetting = false
			end)
		end
	end)

	ObserveAfter("UserSettings", "NeedsConfirmation", function(this, wrappedMethod)
        if not changedAnySetting or Game.GetSettingsSystem():NeedsRestartToApply() then return end
        Game.GetSettingsSystem():ConfirmChanges()
        Game.GetSystemRequestsHandler():RequestSaveUserSettings()
    end)

	GameUI.OnSessionStart(function()
		Cron.After(0.25, function()
			if settings.Current.autoApplyWeather and settings.Current.weatherState ~= "None" then
				Game.GetWeatherSystem():SetWeather(settings.Current.weatherState, settings.Current.transitionDuration, 0)
				Game.GetPlayer():SetWarningMessage("Auto-applied " .. weatherStateNames[settings.Current.weatherState]:lower() .. "!")
				debugPrint("Auto-applied weather state: " .. settings.Current.weatherState)
			else
				local currentWeatherState = Game.GetWeatherSystem():GetWeatherState().name.value
				if currentWeatherState ~= settings.Current.weatherState then
					settings.Current.weatherState = "None"
					-- Assuming there's a function to set the active state button
					SetActiveStateButton("None")
					GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", true)
					debugPrint("Auto-apply weather is disabled. Weather state set to None.")
				end
			end
		end)
	end)

    --[[ GameUI.OnSessionEnd(function()
        -- Handle end
    end) ]]
end)

registerForEvent("onDraw", function()
	if timeSliderWindowOpen == true then
		DrawTimeSliderWindow()
	end
	UpdateUserSettings()
	DrawButtons()
	DrawUpdateWindow()
end)

registerForEvent("onOverlayOpen", function()
	cetOpen = true
	LoadSettings()

	width, height = GetDisplayResolution()
	SetResolutionPresets(width, height)

	local currentWeatherState = Game.GetWeatherSystem():GetWeatherState().name.value
	if currentWeatherState ~= settings.Current.weatherState then
		settings.Current.weatherState = "None"
		-- Assuming there's a function to set the active state button
		SetActiveStateButton("None")
		GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", true)
		debugPrint("Auto-apply weather is disabled. Weather state set to None.")
	end

	changedAnySetting = false
end)

registerForEvent("onOverlayClose", function()
	cetOpen = false
	SaveSettings()
	--Game.GetSystemRequestsHandler():UnpauseGame()
end)

registerForEvent("onUpdate", function(delta)
    Cron.Update(delta)
    if hasResetOrForced == true then
        local resetorforcedtimer = Cron.After(0.5, function()
            hasResetOrForced = false
        end)
    end
    if not Game.GetPlayer() or Game.GetSystemRequestsHandler():IsGamePaused() then return end
    local newWeatherState = tostring(Game.GetWeatherSystem():GetWeatherState().name.value)
    if newWeatherState ~= currentWeatherState then
        previousWeatherState = currentWeatherState
        currentWeatherState = newWeatherState
        updateWeatherStateHistory(currentWeatherState)
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
            debugPrint("Weather changed to " .. (tostring(currentWeatherState)))
        end
        -- Reset the weather reset flag after the weather change notification has been skipped
        weatherReset = false
    end
end)

function debugPrint(message)
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
		{ 2560, 1440, 8, 6, 1, 3, 6, 7, 1, 1,  0.45, 122, 28, 28, 0.85, 1,  8,  292, 29, 34, 4,  500, 222, 298, 7.5, 8,  8,  3,  32, 32, 18, 130, 34, 36 },
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
---
-- Register a CET hotkey to reset weather
registerHotkey("NCTResetWeather", "Reset Weather", function()
	Game.GetWeatherSystem():ResetWeather(true)
	settings.Current.weatherState = "None"
	-- settings.Current.nativeWeather = 1
	Game.GetPlayer():SetWarningMessage("Weather reset to default cycles! \nWeather states will progress automatically.")
	GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", true)
	toggleDLSSDPT = true
	SaveSettings()
	weatherReset = true
	settings.Current.autoApplyWeather = false
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

-- Register hotkey to randomize weather
registerHotkey("NCTRandomizeWeather", "Randomize Weather", function()
	local randomWeather = getRandomWeatherState()
	Game.GetWeatherSystem():SetWeather(randomWeather, 0, 0)
	debugPrint("Random weather state applied: " .. randomWeather)

	local timer = Cron.After(0.1, function()
		local localizedState = weatherStateNames[currentWeatherState]
		
		if settings.Current.warningMessages then
			ShowWarningMessage("Randomization:\nWeather set to " .. localizedState )
		end
		if settings.Current.notificationMessages then
			ShowNotificationMessage("Randomization:\nWeather set to " .. localizedState)
		end
	end)
end)

-- Register hotkey to randomize weather
registerHotkey("NCTRandomizeTime", "Randomize Time", function()
	local randomTime = getRandomTime()
	local hours = math.floor(randomTime / 60)
	local mins = randomTime % 60
	Game.GetTimeSystem():SetGameTimeByHMS(hours, mins, 0)
	debugPrint("Random time set: " .. string.format("%02d:%02d", hours, mins))


	if settings.Current.warningMessages then
		ShowWarningMessage("Randomization:\nTime set to " .. string.format("%02d:%02d", hours, mins))
	end
	if settings.Current.notificationMessages then
		ShowNotificationMessage("Randomization:\nTime set to " .. string.format("%02d:%02d", hours, mins))
	end
end)

-- Register hotkey to randomize weather
registerHotkey("NCTRandomizeWeatherTime", "Randomize Weather & Time", function()
	local randomWeather = getRandomWeatherState()
	Game.GetWeatherSystem():SetWeather(randomWeather, 0, 0)
	debugPrint("Random weather state applied: " .. randomWeather)

	local randomTime = getRandomTime()
	local hours = math.floor(randomTime / 60)
	local mins = randomTime % 60
	Game.GetTimeSystem():SetGameTimeByHMS(hours, mins, 0)
	debugPrint("Random time set: " .. string.format("%02d:%02d", hours, mins))

	local timer = Cron.After(0.1, function()
		local localizedState = weatherStateNames[currentWeatherState]
		
		if settings.Current.warningMessages then
			ShowWarningMessage("Randomization:\nWeather set to " .. localizedState .. "\nTime set to " .. string.format("%02d:%02d", hours, mins))
		end
		if settings.Current.notificationMessages then
			ShowNotificationMessage("Randomization:\nWeather set to " .. localizedState .. "\nTime set to " .. string.format("%02d:%02d", hours, mins))
		end
	end)
	
end)

----------------------------------------
------------- UPDATE MODAL -------------
----------------------------------------

local function GetCenteredPosition(width, height)
	local displayWidth, displayHeight = GetDisplayResolution()
	local posX = (displayWidth - width) / 2
	local posY = (displayHeight - height) / 2
	return posX, posY
end

-- Function to sort versions in descending order
local function sortVersionsDescending(versions)
    table.sort(versions, function(a, b) return a > b end)
end

-- Add function to draw the update GUI window
function DrawUpdateWindow()
    if isNewVersion and cetOpen and not updateWindowDismissed then

        local windowWidth, windowHeight = GetDisplayResolution()
        local posX, posY = GetCenteredPosition(windowWidth / 2.5, windowHeight / 2)
        ImGui.SetNextWindowPos(posX, posY, ImGuiCond.Always)
        ImGui.SetNextWindowSize(windowWidth / 2.5, windowHeight / 2, ImGuiCond.Always)
        
        ImGui.Begin("Nova City Changelog", ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.AlwaysUseWindowPadding)
        ImGui.Dummy(0, dummySpacingYValue)

        ImGui.Text("Nova City has been updated to version " .. modVersion .. ".")
        ImGui.Dummy(0, dummySpacingYValue)


		-- Child window for important notices
        
		-- Set background for notice window
		ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(0.65, 0.7, 1, 0.045))

		-- Set scrollbar styling if enabled
        if settings.Current.scrollbarEnabled then
            ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 2)
            ImGui.PushStyleColor(ImGuiCol.ScrollbarBg, ImGui.GetColorU32(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ScrollbarGrab, ImGui.GetColorU32(0.8, 0.8, 1, 0.1))
        end

        -- Begin child window
        if ImGui.BeginChild("Important Notices", ImGui.GetContentRegionAvail(), windowHeight / 30, false, guiFlags) then
			ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(1, 0.1, 0.1, 1))
            ImGui.Text("IMPORTANT: Please use the new 'Export Debug File' button found at the bottom of the GUI when reporting issues!")
			ImGui.PopStyleColor()
        end
        ImGui.EndChild() -- End child window

		-- Pop scrollbar styling if enabled
        if settings.Current.scrollbarEnabled then
            ImGui.PopStyleVar()
            ImGui.PopStyleColor(2)
        end

		-- Pop background for notice window
        ImGui.PopStyleColor()


        ImGui.Dummy(0, dummySpacingYValue)
		ImGui.Text("Changelogs:")
        ImGui.Dummy(0, dummySpacingYValue)

		ImGui.SetWindowFontScale(customFontScale)

		-- Set background for changelog window
		ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(0.65, 0.7, 1, 0.045))

        if ImGui.BeginChild("Changelog", ImGui.GetContentRegionAvail(), - 65, false, guiFlags) then

            local versions = {}
            for version, _ in pairs(changelog) do
                table.insert(versions, version)
            end
            sortVersionsDescending(versions)

            local latestVersion = versions[1]
            local changes = changelog[latestVersion]
            ImGui.Dummy(0, 6)
            ImGui.Text(latestVersion)
            ImGui.Dummy(0, 6)
            local sortedCategories = {}
            for id, categoryData in pairs(changes) do
                table.insert(sortedCategories, {id = id, data = categoryData})
            end
            table.sort(sortedCategories, function(a, b) return tonumber(a.id) < tonumber(b.id) end)
            for _, category in ipairs(sortedCategories) do
                ImGui.Text(category.data.category .. ":")
                for _, item in ipairs(category.data.items) do
                    ImGui.BulletText(item)
                end
                ImGui.Dummy(0, 8)
            end
            --ImGui.Separator()

            if showPastVersions then
                for i = 2, #versions do
                    ImGui.Separator()
                    local version = versions[i]
                    local changes = changelog[version]
                    ImGui.Dummy(0, 6)
                    ImGui.Text(version)
                    ImGui.Dummy(0, 6)
                    local sortedCategories = {}
                    for id, categoryData in pairs(changes) do
                        table.insert(sortedCategories, {id = id, data = categoryData})
                    end
                    table.sort(sortedCategories, function(a, b) return tonumber(a.id) < tonumber(b.id) end)
                    for _, category in ipairs(sortedCategories) do
                        ImGui.Text(category.data.category .. ":")
                        for _, item in ipairs(category.data.items) do
                            ImGui.BulletText(item)
                        end
                        ImGui.Dummy(0, 8)
                    end
                    --ImGui.Separator()
                end
            end
        end
        ImGui.EndChild()

		-- Pop background for notice window
		ImGui.PopStyleColor()

        ImGui.Dummy(0, 50)
        
        local buttonPosX = (windowWidth / 2.5 - buttonWidth * 2) / 2
        local buttonPosY = windowHeight / 2 - 55
        ImGui.SetCursorPos(buttonPosX, buttonPosY)
        showPastVersions, changed = ImGui.Checkbox("Show All", showPastVersions)
        ImGui.SameLine()
        if ImGui.Button("Dismiss", buttonWidth, buttonHeight) then
            updateWindowDismissed = true
        end
        ui.tooltip("After dismissing, changelogs will not be shown again until the next update.\n\nYou can always view changelogs later in the Misc tab.", true)

        ImGui.SetWindowFontScale(defaultFontScale)

        ImGui.End()
    end
end

----------------------------------------
----------- WEATHER CONTROL-------------
----------------------------------------

function DrawWeatherControl()
	ImGui.Text("Weather Control:")

	-- Make the reset button fit the width of the GUI
	local resetButtonWidth = ImGui.GetWindowContentRegionWidth()

	-- REST BUTTON PUSH: Change button color, hover color, and text color
	ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(1, 0.3, 0.3, 1))          -- Custom button color
	ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(1, 0.45, 0.45, 1)) -- Custom hover color
	ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0, 0, 0, 1))                -- Custom text color
	if ImGui.Button("Reset Weather", resetButtonWidth, buttonHeight) then
		Game.GetWeatherSystem():ResetWeather(true)
		settings.Current.weatherState = "None"
		Game.GetPlayer():SetWarningMessage("Weather reset to default cycles! \nWeather states will progress automatically.")
		GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", true)
		toggleDLSSDPT = true
		debugPrint("Weather reset")
		SaveSettings()
		weatherReset = true
		settings.Current.autoApplyWeather = false
	end
	-- RESET BUTTON POP: Revert to original color
	ImGui.PopStyleColor(3)

	ui.tooltip("Reset any manually selected states and returns the weather to \nits default weather cycles, starting with the sunny weather state. \nWeather will continue to advance naturally.", true)

	-- Auto Apply button
	local isActive = settings.Current.autoApplyWeather
	-- APPLY BUTTON PUSH: Set active color to teal
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
	if ImGui.Button("Auto Apply", resetButtonWidth, buttonHeight) then
		settings.Current.autoApplyWeather = not settings.Current.autoApplyWeather
		debugPrint("Auto Apply Weather: " .. tostring(settings.Current.autoApplyWeather))
	end
	-- APPLY BUTTON POP
	ImGui.PopStyleColor(4)
	ui.tooltip("Auto apply selected weather when loading game or save files.\nWeather states will be locked when applying your selected weather.\nThis will override quest weather when loading a save file from a mission.")

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

	if not Game.GetSystemRequestsHandler():IsPreGame() and not Game.GetSystemRequestsHandler():IsGamePaused() then
		-- DEBUG EXPORT BUTTON PUSH
		ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0.1, 0.8, 0.6, 1))
		if ImGui.Button("Export Debug File", resetButtonWidth, buttonHeight) then
			showExportWindow = true
		end
		-- DEBUG EXPORT BUTTON POP
		ImGui.PopStyleColor()
		ui.tooltip("Export debug information to novaCityDebug.json file in the NovaCityTools CET mod folder.\nShare this file with the author when submitting a bug report.", true)
	else
		-- DEBUG EXPORT BUTTON DISABLED PUSH
		ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0.3, 0.3, 0.3, 1))
		ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0.35, 0.35, 0.35, 1))
		ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0.35, 0.35, 0.35, 1))
		ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0.6, 0.6, 0.6, 1))
		if ImGui.Button("Export Debug File", resetButtonWidth, buttonHeight) then
			print(IconGlyphs.CityVariant .. " Nova City Tools: Cannot export debug file while in menu")
		end
		-- DEBUG EXPORT BUTTON DISABLED POP
		ImGui.PopStyleColor(4)
		ui.tooltip("DISABLED: Cannot export debug file while in menu!\n\nExport debug information to novaCityDebug.json file in the NovaCityTools CET mod folder.\nShare this file with the author when submitting a bug report.", true)
	end

	ExportDescriptionWindow()
end

function ExportDescriptionWindow()
	if showExportWindow then
		local windowWidth, windowHeight = GetDisplayResolution()
		local posX, posY = GetCenteredPosition(windowWidth / 3, windowHeight / 8)
		local buttonPosX = (windowWidth / 3 - buttonWidth * 2) / 2
        local buttonPosY = windowHeight / 8 - 45

		ImGui.SetNextWindowPos(posX, posY, ImGuiCond.Always)
		ImGui.SetNextWindowSize(windowWidth / 3, windowHeight / 8, ImGuiCond.Always)

		ImGui.Begin("Export Debug File", true, ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.AlwaysUseWindowPadding)

		ImGui.SetWindowFontScale(0.95)

		ImGui.Text("Enter issue description:")
		ImGui.Dummy(0, 0)
		ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, framePaddingXValue * 10, framePaddingYValue * 3.5)
		ImGui.PushStyleColor(ImGuiCol.FrameBg, ImGui.GetColorU32(0.65, 0.7, 1, 0.045)) -- Change text box background color
		issueDescription = ImGui.InputTextMultiline("##issueDescription", issueDescription or "", 500, ImGui.GetWindowContentRegionWidth(), windowHeight / 32)
		ImGui.PopStyleColor()
		ImGui.PopStyleVar()

		ImGui.SetWindowFontScale(customFontScale)

		ImGui.SetCursorPos(buttonPosX, buttonPosY)
		if ImGui.Button("Save", buttonWidth, buttonHeight) then
			ExportDebugFile(issueDescription)
			showExportWindow = false
			issueDescription = nil
		end
		ImGui.SameLine()
		if ImGui.Button("Cancel", buttonWidth, buttonHeight) then
			showExportWindow = false
			issueDescription = nil
		end

		ImGui.SetWindowFontScale(defaultFontScale)

		ImGui.End()
	end
end

----------------------------------------
----------------- GUI ------------------
----------------------------------------

function AnyKeywordMatches(keywords, searchText)
	for _, keyword in ipairs(keywords) do
		if string.find(keyword:lower(), searchText:lower()) then
			return true
		end
	end
	return false
end

function DrawButtons()
	-- Check if the CET window is open
	if not cetOpen then
		return
	end

	if settings.Current.scrollbarEnabled then
		-- SCROLLBAR STYLE PUSH: Change scrollbar color and size
		ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 2)
		ImGui.PushStyleColor(ImGuiCol.ScrollbarBg, ImGui.GetColorU32(0, 0, 0, 0))
		ImGui.PushStyleColor(ImGuiCol.ScrollbarGrab, ImGui.GetColorU32(0.8, 0.8, 1, 0.1))
	
		guiFlags = ImGuiWindowFlags.AlwaysUseWindowPadding
	else
		guiFlags = ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.AlwaysUseWindowPadding
	end

	-- Set window size constraints
	--ImGui.SetNextWindowSizeConstraints(uiMinWidth, 896, width / 100 * 50, 896) -- Locked vertical height to accommodate weather control
	ImGui.SetNextWindowSizeConstraints(uiMinWidth, 324, width / 100 * 47, height / 100 * 94)
	if resetWindow then
		ImGui.SetNextWindowPos(6, 160, ImGuiCond.Always)
		ImGui.SetNextWindowSize(312, 1168, ImGuiCond.Always)
		ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 5)
		ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 5)
		resetWindow = false
	end
	
	-- Begin main window
	if ImGui.Begin("Nova City Tools - v" .. modVersion, true, ImGuiWindowFlags.NoScrollbar) then
		-- FRAME PADDING PUSH
		ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, frameTabPaddingXValue, frameTabPaddingYValue)
		ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, itemTabSpacingYValue)

		-- Set the font scale for the window
		ImGui.SetWindowFontScale(customFontScale)

		if ImGui.BeginTabBar("Nova Tabs") then
			ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize("XXX"))

			-- TIME SLIDER TOGGLE ------------------------
			-- TIME SLIDER STYLE PUSH: Set button text alignment and frame padding
			ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
			ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, glyphFramePaddingXValue, glyphFramePaddingYValue)

			-- Create the button and toggle the time slider window
			if timeSliderWindowOpen then
				ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0.0, 1, 0.7, 1))
				ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0, 0.8, 0.56, 1))
				ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0.1, 0.8, 0.6, 1))
				ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0, 0, 0, 1))
				if ImGui.Button(IconGlyphs.ClockOutline, glyphButtonWidth, glyphButtonHeight) then
					debugPrint("Closing time slider window.")
					timeSliderWindowOpen = false
					settings.Current.timeSliderWindowOpen = timeSliderWindowOpen
					SaveSettings()
				end
				ImGui.PopStyleColor(4)
			else
				ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0.4, 1, 0.8, 1))
				ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0.3, 0.3, 0.3, 1))
				if ImGui.Button(IconGlyphs.ClockOutline, glyphButtonWidth, glyphButtonHeight) then
					debugPrint("Opening time slider window.")
					timeSliderWindowOpen = true
					settings.Current.timeSliderWindowOpen = timeSliderWindowOpen
					SaveSettings()
				end
				-- Reset style variables
				ImGui.PopStyleColor(2)
			end
			ui.tooltip("Toggles the time slider window.")

			-- TIME SLIDER STYLE POP
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
					if searchIcon == IconGlyphs.MagnifyClose then
						ImGui.PopStyleColor()
					end
					ui.tooltip("Click to clear search.")
				end
				if searchIcon == IconGlyphs.MagnifyClose then
					ImGui.PopStyleColor()
				end
				ImGui.SameLine()
				ImGui.SetNextItemWidth(availableWidth)
				
				ImGui.PopStyleVar()
				
				-- Push text within the search bar
				ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 10, searchPaddingYValue)
				searchText = ImGui.InputText(" ", searchText, 100)
				if searchText ~= "" then
					searchIcon = IconGlyphs.MagnifyClose
				else
					searchIcon = IconGlyphs.Magnify
					ui.tooltip("Search for a weather state by typing in this field.\nUse keywords like 'wet', 'hot', 'bright', to search by properties.", true)
				end
				ImGui.PopStyleVar()




				
				ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, framePaddingXValue, framePaddingYValue)
				ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, itemSpacingXValue, itemSpacingYValue)

				----------------------------------------
				------------- CHILD GUI ----------------
				----------------------------------------

				ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(0.65, 0.7, 1, 0.045)) -- Set your desired color here

				if settings.Current.scrollbarEnabled then
					-- Change scrollbar color and size
					ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 2)
					ImGui.PushStyleColor(ImGuiCol.ScrollbarBg, ImGui.GetColorU32(0, 0, 0, 0))
					ImGui.PushStyleColor(ImGuiCol.ScrollbarGrab, ImGui.GetColorU32(0.8, 0.8, 1, 0.1))
				end

				if ImGui.BeginChild("Weather", ImGui.GetContentRegionAvail(), -185, false, guiFlags) then
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
								if stateCategory == category.name and (searchText == "" or string.find(localization:lower(), searchText:lower()) or (weatherType and AnyKeywordMatches(weatherType, searchText))) then
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
											weatherReset = true
											debugPrint("Weather reset to default cycles.")
										else
											Game.GetWeatherSystem():SetWeather(weatherState, settings.transitionTime, 0)
											settings.Current.weatherState = weatherState
											Game.GetPlayer():SetWarningMessage("Locked weather state to " .. localization:lower() .. "!")
											GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", enableDLSSDPT)
											toggleDLSSDPT = enableDLSSDPT
											debugPrint("Weather locked to selected state.")
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
				end
				ImGui.EndChild()


				--Floating weather control panel
				ImGui.SetCursorPosY(ImGui.GetWindowHeight() - 185)
				DrawWeatherControl()

				ImGui.PopStyleColor()
				ImGui.PopStyleVar(2)
				ImGui.EndTabItem()
			end

			ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, frameTabPaddingXValue, frameTabPaddingYValue)
			ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, itemTabSpacingYValue)

			if ImGui.BeginTabItem("Toggles") then
				-- Push style variables for frame padding and item spacing INSIDE the tabs
				ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, framePaddingXValue, framePaddingYValue + 2)
				ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, itemSpacingXValue, itemSpacingYValue)

				----------------------------------------
				------------- CHILD GUI ----------------
				----------------------------------------
				
				ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(0.65, 0.7, 1, 0.045)) -- Set your desired color here
				ImGui.Dummy(0, dummySpacingYValue)
				--if ImGui.BeginChild("Weather", ImGui.GetContentRegionAvail(), - 150, false, ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.AlwaysUseWindowPadding) then
				if ImGui.BeginChild("Toggles", ImGui.GetContentRegionAvail(), - 185, false, guiFlags) then

					ImGui.Text("Grouped Toggles:")
					ImGui.Separator()

					toggleFogClouds, changed = ImGui.Checkbox("ALL: Volumetrics and Clouds", toggleFogClouds)
					if changed then
						userInteracted = true
						debugPrint("Volumetrics and Clouds toggled!")
						GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", toggleFogClouds)
						GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", toggleFogClouds)
						GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", toggleFogClouds)
						GameOptions.SetBool("Developer/FeatureToggles", "VolumetricClouds", toggleFogClouds)
						distantVolumetricFog = toggleFogClouds
						volumetricFog = toggleFogClouds
						distantFog = toggleFogClouds
						clouds = toggleFogClouds

						-- Ensure ALL: Fog is also enabled/disabled
						toggleFog = toggleFogClouds
						GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", toggleFog)
						GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", toggleFog)
						GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", toggleFog)
						volumetricFog = toggleFog
						distantVolumetricFog = toggleFog
						distantFog = toggleFog
					end
					ui.tooltip("Toggles all fog and clouds: volumetric, distant volumetric, distant fog planes, and volumetric clouds.")

					toggleFog, changed = ImGui.Checkbox("ALL: Fog", toggleFog)
					if changed then
						userInteracted = true
						debugPrint("Fog toggled!")
						GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", toggleFog)
						GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", toggleFog)
						GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", toggleFog)
						volumetricFog = toggleFog
						distantVolumetricFog = toggleFog
						distantFog = toggleFog


						if toggleFog and not toggleFogClouds then
							GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", true)
							GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", true)
							GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", true)
							volumetricFog = true
							distantVolumetricFog = true
							distantFog = true
						end
					end
					ui.tooltip("Toggles all fog types: volumetric, distant volumetric, and distant fog plane.")

					----------------------------------------
					----------- WEATHER TOGGLES ------------
					----------------------------------------
					
					ImGui.Dummy(0, dummySpacingYValue)
					ImGui.Text("Weather:")
					ImGui.Separator()

					volumetricFog, changed = ImGui.Checkbox("VFog", volumetricFog)
					if changed then
						userInteracted = true
						debugPrint("VFog toggled!")
						GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", volumetricFog)

						if volumetricFog then
							GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", true)
							distantVolumetricFog = true
						else
							GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", false)
							distantVolumetricFog = false
						end
					end
					ui.tooltip("Toggle volumetric fog. Also disables Distant VFog.")

					ImGui.SameLine(toggleSpacingXValue)
					distantVolumetricFog, changed = ImGui.Checkbox("Distant VFog", distantVolumetricFog)
					if changed then
						userInteracted = true
						debugPrint("Distant Fog toggled!")
						GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", distantVolumetricFog)

						if distantVolumetricFog and not volumetricFog then
							GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", true)
							volumetricFog = true
						end
					end
					ui.tooltip("Toggle distant volumetric fog. Also enables VFog if it's disabled.")

					distantFog, changed = ImGui.Checkbox("Fog", distantFog)
					if changed then
						userInteracted = true
						debugPrint("Fog changed!")
						GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", distantFog)
					end
					ui.tooltip("Toggle distant fog plane.")
					ImGui.SameLine(toggleSpacingXValue)
					clouds, changed = ImGui.Checkbox("Clouds", clouds)
					if changed then
						userInteracted = true
						debugPrint("Clouds changed!")
						GameOptions.SetBool("Developer/FeatureToggles", "VolumetricClouds", clouds)
					end
					ui.tooltip("Toggle volumetric clouds.")

					----------------------------------------
					---------- REQUIRED TOGGLES ------------
					----------------------------------------
					
					ImGui.Dummy(0, dummySpacingYValue)
					ImGui.Text("Required:")
					ImGui.Separator()

					toggleDLSSDPT, changed = ImGui.Checkbox("Separate Particle Color", toggleDLSSDPT)
					if changed then
						GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", toggleDLSSDPT)
						SaveSettings()
					end
					ui.tooltip("DLSSD Separate Particle Color - Disabling will reduce \ndistant shimmering but also makes other paricles invisible \nlike rain and debris particles. Disabling is not recommended. \nManually selecting a weather state will enable or disable \nthis as needed.")

					rainMap, changed = ImGui.Checkbox("Weather", rainMap)
					if changed then
						GameOptions.SetBool("Developer/FeatureToggles", "RainMap", rainMap)
						GameOptions.SetBool("Developer/FeatureToggles", "ScreenSpaceRain", rainMap)
						rain = rainMap
						SaveSettings()
					end
					ui.tooltip("Toggles all weather effects such as rain particles and wet surfaces.")
					ImGui.SameLine(toggleSpacingXValue)
					rain, changed = ImGui.Checkbox("SS Rain", rain)
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

					bloom, changed = ImGui.Checkbox("Bloom", bloom)
					if changed then
						GameOptions.SetBool("Developer/FeatureToggles", "Bloom", bloom)
						GameOptions.SetBool("Developer/FeatureToggles", "ImageBasedFlares", bloom and lensFlares)
						Game.GetSettingsSystem():GetVar("/graphics/basic", "LensFlares"):SetValue(bloom and lensFlares)
						Game.GetSettingsSystem():ConfirmChanges()
						SaveSettings()
					end
					ui.tooltip("Toggles bloom (also disables lens flare).")

					----------------------------------------
					---------- OPTIONAL TOGGLES ------------
					----------------------------------------
					
					ImGui.Dummy(0, dummySpacingYValue)
					ImGui.Text("Optional:")
					ui.tooltip("Optional toggles will load your in-game settings and adjust and save them when toggled.")
					ImGui.Separator()
					
				
					--ImGui.SameLine(toggleSpacingXValue)
					lensFlares, changed = ImGui.Checkbox("Lens Flare", lensFlares)
					if changed then
						GameOptions.SetBool("Developer/FeatureToggles", "ImageBasedFlares", lensFlares)
						Game.GetSettingsSystem():GetVar("/graphics/basic", "LensFlares"):SetValue(lensFlares)
						Game.GetSettingsSystem():ConfirmChanges()
						SaveSettings()

						Game.GetSettingsSystem():ConfirmChanges()
						local timer = Cron.After(0.1, function()
							Game.GetSystemRequestsHandler():RequestSaveUserSettings()
							changedAnySetting = true
						end)
						
						if lensFlares and not bloom then
							GameOptions.SetBool("Developer/FeatureToggles", "Bloom", true)
							bloom = true
							Game.GetSettingsSystem():GetVar("/graphics/basic", "LensFlares"):SetValue(bloom)
							Game.GetSettingsSystem():ConfirmChanges()
							SaveSettings()
						end
					end
					ui.tooltip("Toggles lens flare effect.")
					ImGui.SameLine(toggleSpacingXValue)
					-- RIS Checkbox
					RIS, changed = ImGui.Checkbox("RIS", RIS)
					if changed then
						GameOptions.SetBool("RayTracing/Reference", "EnableRIS", RIS)
						SaveSettings()
					end
					ui.tooltip("Toggles Resampled Importance Sampling.")
					
					chromaticAberration, changed = ImGui.Checkbox("CA", chromaticAberration)
					if changed then
						GameOptions.SetBool("Developer/FeatureToggles", "ChromaticAberration", chromaticAberration)
						Game.GetSettingsSystem():GetVar("/graphics/basic", "ChromaticAberration"):SetValue(chromaticAberration)
						Game.GetSettingsSystem():ConfirmChanges()
						SaveSettings()
						changedAnySetting = true
					end
					ui.tooltip("Toggles chromatic aberration.")
					ImGui.SameLine(toggleSpacingXValue)
					filmGrain, changed = ImGui.Checkbox("Film Grain", filmGrain)
					if changed then
						GameOptions.SetBool("Developer/FeatureToggles", "FilmGrain", filmGrain)
						Game.GetSettingsSystem():GetVar("/graphics/basic", "FilmGrain"):SetValue(filmGrain)
						Game.GetSettingsSystem():ConfirmChanges()
						SaveSettings()
						changedAnySetting = true
					end
					ui.tooltip("Toggles film grain.")

					dof, changed = ImGui.Checkbox("DOF", dof)
					if changed then
						GameOptions.SetBool("Developer/FeatureToggles", "DepthOfField", dof)
						Game.GetSettingsSystem():GetVar("/graphics/basic", "DepthOfField"):SetValue(dof)
						Game.GetSettingsSystem():ConfirmChanges()
						SaveSettings()
						changedAnySetting = true
					end
					ui.tooltip("Toggles depth of field.")
					ImGui.SameLine(toggleSpacingXValue)
					motionBlur, changed = ImGui.Checkbox("Motion Blur", motionBlur)
					if changed then
						GameOptions.SetBool("Developer/FeatureToggles", "MotionBlur", motionBlur)
						motionBlurIndex = motionBlur and 2 or 0
						Game.GetSettingsSystem():GetVar("/graphics/basic", "MotionBlur"):SetIndex(motionBlurIndex)
						Game.GetSettingsSystem():ConfirmChanges()
						SaveSettings()
						changedAnySetting = true
						-- Update user settings after changes
						UpdateUserSettings()
					end
					ui.tooltip("Toggles motion blur.")

					if motionBlurIndex ~= 0 then
						ImGui.Dummy(0, dummySpacingYValue)
						ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(1, 1, 1, 0.7))
						ImGui.Text("Motion Blur Scale:")
						ImGui.PopStyleColor()

						-- Set the width of the slider to the width of the window minus the padding
						local windowWidth = ImGui.GetWindowWidth()
						ImGui.PushItemWidth(windowWidth - timeSliderPadding - 2)
						ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 10, 10)
						settings.Current.motionBlurScale, changed = ImGui.SliderFloat("Blur Scale", settings.Current.motionBlurScale, 0.05, 10.0, "%.2f")
						if changed then
							GameOptions.SetFloat("Visuals", "MotionBlurScale", settings.Current.motionBlurScale)
							SaveSettings()
						end
						ImGui.PopStyleVar()
					end

					if settings.Current.advancedToggles and tostring(GameOptions.GetBool("Developer/FeatureToggles", "PathTracing")) == "true" then
						ImGui.Dummy(0, dummySpacingYValue)
						ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(1, 1, 1, 0.7))
						ImGui.Text("Advanced:")
						ImGui.PopStyleColor()
						ui.tooltip("May cause CTDs on lower end systems.")

						-- RR Checkbox
						rayReconstruction, changed = ImGui.Checkbox("RR", rayReconstruction)
						if changed then
							if toggleNRD then
								toggleNRD = false
								GameOptions.SetBool("RayTracing", "EnableNRD", false)
							else
								Cron.After(2.5, function()
									toggleNRD = false
									GameOptions.SetBool("RayTracing", "EnableNRD", false)
								end)
							end

							Game.GetSettingsSystem():GetVar("/graphics/presets", "DLSS_D"):SetValue(rayReconstruction)
							Game.GetSettingsSystem():ConfirmChanges()
							SaveSettings()

							Cron.After(2.0, function()
								Game.GetSystemRequestsHandler():RequestSaveUserSettings()
								changedAnySetting = true
							end)
						end
						ui.tooltip("Toggles ray reconstruction.\nMAY CAUSE CRASH TO DESKTOP.", true)
						ImGui.SameLine(toggleSpacingXValue)

						-- NRD Checkbox
						toggleNRD, changed = ImGui.Checkbox("NRD", toggleNRD)
						if changed then
							GameOptions.SetBool("RayTracing", "EnableNRD", toggleNRD)
							SaveSettings()
							UpdateUserSettings()

							if rayReconstruction then
								Cron.After(2.0, function()
									rayReconstruction = false
									Game.GetSettingsSystem():GetVar("/graphics/presets", "DLSS_D"):SetValue(
									rayReconstruction)
									Game.GetSystemRequestsHandler():RequestSaveUserSettings()
									changedAnySetting = true
									SaveSettings()
								end)
							end
						end
						ui.tooltip("Toggles Nvidia Realtime Denoiser.\nMAY CAUSE CRASH TO DESKTOP.", true)
					else
						if tostring(GameOptions.GetBool("Developer/FeatureToggles", "PathTracing")) ~= "true" then
							ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(1, 1, 1, 0.2))
							ImGui.Text("Enable PT to see other toggles.")
							ImGui.PopStyleColor()
						end
					end

					----------------------------------------
					----------- UTILITY TOGGLES ------------
					----------------------------------------

					ImGui.Dummy(0, dummySpacingYValue)
					ImGui.Text("Utility:")
					ImGui.Separator()
					vehicleCollisions, changed = ImGui.Checkbox("Vehicle Collisions", vehicleCollisions)
					if changed then
						GameOptions.SetBool("Vehicle", "vehicleVsVehicleCollisions", vehicleCollisions)
						SaveSettings()
					end
					ui.tooltip("Toggles vehicle collisions. Great for driving through \n Night City with Nova City Population density!")
					crowdSpawning, changed = ImGui.Checkbox("Crowd Spawning", crowdSpawning)
					if changed then
						GameOptions.SetBool("Crowd", "Enabled", crowdSpawning)
						SaveSettings()
					end
					ui.tooltip("Toggles crowd spawning.")
					stopVehicleSpawning, changed = ImGui.Checkbox("Vehicle Spawning", stopVehicleSpawning)
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

					----------------------------------------
					------------ OTHER TOGGLES -------------
					----------------------------------------

					ImGui.Dummy(0, dummySpacingYValue)
					ImGui.Text("Other:")
					ImGui.Separator()

					graphics, changed = ImGui.Checkbox("Global", graphics)
					if changed then
						-- Toggle all volumetrics and clouds
						toggleFogClouds = graphics
						GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", graphics)
						GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", graphics)
						GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", graphics)
						GameOptions.SetBool("Developer/FeatureToggles", "VolumetricClouds", graphics)
						volumetricFog = graphics
						distantVolumetricFog = graphics
						distantFog = graphics
						clouds = graphics

						-- Toggle DLSSDPT
						toggleDLSSDPT = graphics
						GameOptions.SetBool("Rendering", "DLSSDSeparateParticleColor", graphics)

						-- Toggle bloom
						bloom = graphics
						GameOptions.SetBool("Developer/FeatureToggles", "Bloom", graphics)

						-- Toggle weather and screen space rain
						rainMap = graphics
						rain = graphics
						GameOptions.SetBool("Developer/FeatureToggles", "RainMap", graphics)
						GameOptions.SetBool("Developer/FeatureToggles", "ScreenSpaceRain", graphics)

						SaveSettings()
					end
					ui.tooltip("Toggles all volumetrics, clouds, DLSSDPT, bloom, weather, screen space rain.")

					if userInteracted then
						-- Update ALL: Fog and ALL: Volumetrics and Clouds based on individual toggles
						if not volumetricFog and not distantVolumetricFog and not distantFog then
							toggleFog = false
							GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", false)
							GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", false)
							GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", false)
						end

						if not volumetricFog and not distantVolumetricFog and not distantFog and not clouds then
							toggleFogClouds = false
							GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", false)
							GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", false)
							GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", false)
							GameOptions.SetBool("Developer/FeatureToggles", "VolumetricClouds", false)
						end

						-- Enable ALL: Fog if all individual fog toggles are enabled
						if volumetricFog and distantVolumetricFog and distantFog then
							toggleFog = true
							GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", true)
							GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", true)
							GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", true)
						end

						-- Enable ALL: Volumetrics and Clouds if all individual toggles are enabled
						if volumetricFog and distantVolumetricFog and distantFog and clouds then
							toggleFogClouds = true
							GameOptions.SetBool("Developer/FeatureToggles", "VolumetricFog", true)
							GameOptions.SetBool("Developer/FeatureToggles", "DistantVolFog", true)
							GameOptions.SetBool("Developer/FeatureToggles", "DistantFog", true)
							GameOptions.SetBool("Developer/FeatureToggles", "VolumetricClouds", true)
						end
						SaveSettings()
						userInteracted = false
					end

				end
				ImGui.EndChild()

				ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, framePaddingXValue, framePaddingYValue)

				--Floating weather control panel
				ImGui.SetCursorPosY(ImGui.GetWindowHeight() - 185)
				DrawWeatherControl()

				ImGui.EndTabItem()

				ImGui.PopStyleColor()
				ImGui.PopStyleVar(3)
			end
			
			--Maybe not needed!
			ImGui.PopStyleVar(2)

			-- Reset padding
			ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, frameTabPaddingXValue, frameTabPaddingYValue)
			ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, itemTabSpacingYValue)

			if ImGui.BeginTabItem("Misc") then
				-- Push style variables for frame padding and item spacing INSIDE the tabs
				ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, framePaddingXValue, framePaddingYValue)
				ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, itemSpacingXValue, itemSpacingYValue)

				----------------------------------------
				------------- CHILD GUI ----------------
				----------------------------------------
				
				ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(0.65, 0.7, 1, 0.045)) -- Set your desired color here
				ImGui.Dummy(0, dummySpacingYValue)

				--if ImGui.BeginChild("Weather", ImGui.GetContentRegionAvail(), - 150, false, ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.AlwaysUseWindowPadding) then
				if ImGui.BeginChild("Misc", ImGui.GetContentRegionAvail(), - 185, false, guiFlags) then

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
					ImGui.Text("Adjust Game Time:")
					ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 10, 4) -- Slider height
					ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize(timeLabel) + 5)
					ImGui.Text(timeLabel)

					ImGui.PopStyleVar()

					ImGui.Separator()
					ImGui.Dummy(0, 1)

					-- Set the width of the slider to the width of the window minus the padding
					local windowWidth = ImGui.GetWindowWidth()
					ImGui.PushItemWidth(windowWidth - timeSliderPadding - 2)

					ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 10, 10)

					-- Create a slider for the total minutes
					totalMinutes, changed = ImGui.SliderInt("##", totalMinutes, 0, 24 * 60 - 1)
					if changed then
						local hours = math.floor(totalMinutes / 60)
						local mins = totalMinutes % 60
						Game.GetTimeSystem():SetGameTimeByHMS(hours, mins, secs)
					end

					ImGui.PopStyleVar()

					ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, framePaddingXValue, framePaddingYValue) -- Reset padding

					-- Add a new section for weather transition duration presets
					ImGui.Dummy(0, dummySpacingYValue + 10)
					ImGui.Text("Weather Transition Duration:")

					ImGui.PopStyleVar()

					ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - 10)
					ImGui.Text(tostring(settings.Current.transitionDuration) .. "s")
					ImGui.Separator()
					ImGui.Dummy(0, dummySpacingYValue/4)

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

					ImGui.Dummy(0, dummySpacingYValue)
					ImGui.Text("Weather state notifications:")
					ImGui.Separator()
					ImGui.Dummy(0, dummySpacingYValue/4)

					settings.Current.warningMessages, changed = ImGui.Checkbox("Warning Message", settings.Current.warningMessages)
					if changed then
						debugPrint("Toggled warning message to " .. tostring(settings.Current.warningMessages))
						SaveSettings()
					end
					ui.tooltip("Show warning message when naturally progressing to a new weather state. \nNotifications only occur with default cycles during natural transitions. \nManually selected states will always show a warning notification.")
					settings.Current.notificationMessages, changed = ImGui.Checkbox("Notification", settings.Current.notificationMessages)
					if changed then
						debugPrint("Toggled notifications to " .. tostring(settings.Current.notificationMessages))
						SaveSettings()
					end
					ui.tooltip("Show side notification when naturally progressing to a new weather state. \nNotifications only occur with default cycles during natural transitions. \nManually selected states will always show a warning notification.")

					ImGui.Dummy(0, dummySpacingYValue)
					ImGui.Text("Features:")
					ImGui.Separator()
					ImGui.Dummy(0, dummySpacingYValue/4)

					settings.Current.autoApplyWeather, changed = ImGui.Checkbox("Auto-Apply Weather", settings.Current.autoApplyWeather)
					if changed then
						debugPrint("Weather auto-apply on start set to " .. tostring(settings.Current.autoApplyWeather))
						SaveSettings()
					end
					ui.tooltip("Auto apply selected weather when loading game or save files.\nWeather states will be locked when applying your selected weather.\nThis will override quest weather when loading a save file from a mission.")

					----------------------------------------
					-------------- GUI TOGGLES -------------
					----------------------------------------
					
					ImGui.Dummy(0, dummySpacingYValue)
					ImGui.Text("GUI:")
					ImGui.Separator()
					ImGui.Dummy(0, dummySpacingYValue/4)

					settings.Current.scrollbarEnabled, changed = ImGui.Checkbox("Scrollbar", settings.Current.scrollbarEnabled)
					if changed then
						print(IconGlyphs.CityVariant .. " Nova City Tools: Toggled scrollbar to " .. tostring(settings.Current.scrollbarEnabled))
						SaveSettings()
					end

					settings.Current.tooltipsEnabled, changed = ImGui.Checkbox("Tooltips", settings.Current.tooltipsEnabled)
					if changed then
						print(IconGlyphs.CityVariant .. " Nova City Tools: Toggled tooltips to " .. tostring(settings.Current.tooltipsEnabled))
						SaveSettings()
					end

					----------------------------------------
					------------- DEBUG TOGGLES ------------
					----------------------------------------
					
					ImGui.Dummy(0, dummySpacingYValue)
					ImGui.Text("Debug:")
					ImGui.Separator()
					ImGui.Dummy(0, dummySpacingYValue/4)

					settings.Current.debugOutput, changed = ImGui.Checkbox("Debug Console Output", settings.Current.debugOutput)
					if changed then
						print(IconGlyphs.CityVariant .. " Nova City Tools: Toggled debug output to " .. tostring(settings.Current.debugOutput))
						SaveSettings()
					end
					ImGui.Dummy(0, dummySpacingYValue/4)
					local resetButtonWidth = ImGui.GetWindowContentRegionWidth()

					if not Game.GetSystemRequestsHandler():IsPreGame() and not Game.GetSystemRequestsHandler():IsGamePaused() then
						ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0.1, 0.8, 0.6, 1))
						if ImGui.Button("Export Debug File", resetButtonWidth, buttonHeight) then
							ExportDebugFile()
							print(IconGlyphs.CityVariant .. " Nova City Tools: Exported debug file ")
						end
						ImGui.PopStyleColor()
						ui.tooltip("Export debug information to novaCityDebug.json file in the NovaCityTools CET mod folder.\nShare this file with the author when submitting a bug report.", true)
					else
						ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0.3, 0.3, 0.3, 1))
						ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0.35, 0.35, 0.35, 1))
						ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0.35, 0.35, 0.35, 1))
						ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0.6, 0.6, 0.6, 1))
						if ImGui.Button("Export Debug File", resetButtonWidth, buttonHeight) then
							print(IconGlyphs.CityVariant .. " Nova City Tools: Cannot export debug file while in menu")
						end
						ImGui.PopStyleColor(4)
						ui.tooltip("DISABLED: Cannot export debug file while in menu!\n\nExport debug information to novaCityDebug.json file in the NovaCityTools CET mod folder.\nShare this file with the author when submitting a bug report.", true)
					end

					----------------------------------------
					--------- EXPERIMENTAL TOGGLES ---------
					----------------------------------------
					
					ImGui.Dummy(0, dummySpacingYValue)
					ImGui.Text("Experimental:")
					ImGui.Separator()
					ImGui.Dummy(0, dummySpacingYValue / 4)

					settings.Current.advancedToggles, changed = ImGui.Checkbox("Advanced Toggles", settings.Current.advancedToggles)
					if changed then
						print(IconGlyphs.CityVariant .. " Nova City Tools: Toggled advanced settings to " .. tostring(settings.Current.advancedToggles))
						SaveSettings()
					end
					ui.tooltip("Enables toggles for RR, NRD, and adds a rest GUI button.", true)

					----------------------------------------
					------------- RANDOMIZATION ------------
					----------------------------------------

					ImGui.Dummy(0, dummySpacingYValue)
					ImGui.Text("Randomization:")
					ImGui.Separator()
					ImGui.Dummy(0, dummySpacingYValue)

					-- RANDOMIZATION STYLE PUSH
					ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, glyphFramePaddingXValue, glyphFramePaddingYValue)
					ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 12, glyphItemSpacingYValue)
					ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 0, 0)
					ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.55, glyphAlignYValue)

					if ImGui.Button(IconGlyphs.WeatherPartlyCloudy, resetButtonWidth / 4 - 7, buttonHeight + 5) then
						local randomWeather = getRandomWeatherState()
						Game.GetWeatherSystem():SetWeather(randomWeather, 0, 0)
						debugPrint("Random weather state applied: " .. randomWeather)
					end
					ui.tooltip("Set random weather state")
					ImGui.SameLine()
					if ImGui.Button(IconGlyphs.Clock, resetButtonWidth / 4 - 7, buttonHeight + 5) then
						local randomTime = getRandomTime()
						local hours = math.floor(randomTime / 60)
						local mins = randomTime % 60
						Game.GetTimeSystem():SetGameTimeByHMS(hours, mins, 0)
						debugPrint("Random time set: " .. string.format("%02d:%02d", hours, mins))
					end
					ui.tooltip("Set random time")
					ImGui.SameLine()
					if ImGui.Button(IconGlyphs.WeatherPartlyCloudy .. " / " .. IconGlyphs.Clock, resetButtonWidth / 2 - 10, buttonHeight + 5) then
						local randomWeather = getRandomWeatherState()
						Game.GetWeatherSystem():SetWeather(randomWeather, 0, 0)
						debugPrint("Random weather state applied: " .. randomWeather)

						local randomTime = getRandomTime()
						local hours = math.floor(randomTime / 60)
						local mins = randomTime % 60
						Game.GetTimeSystem():SetGameTimeByHMS(hours, mins, 0)
						debugPrint("Random time set: " .. string.format("%02d:%02d", hours, mins))
					end
					ui.tooltip("Randomize both weather and time!")

					-- RANDOMIZATION STYLE POP
					ImGui.PopStyleVar(4)

					----------------------------------------
					--------------- RESET GUI --------------
					----------------------------------------

					if settings.Current.advancedToggles then
						ImGui.Dummy(0, dummySpacingYValue)
						ImGui.Separator()
						ImGui.Dummy(0, dummySpacingYValue)

						if ImGui.Button("Reset GUI", resetButtonWidth, buttonHeight) then
							resetWindow = true
							debugPrint("Reset GUI size and position.")
						end
						ui.tooltip("Reset GUI to default position and size.")
					end

					----------------------------------------
					--------------- CHANGELOG --------------
					----------------------------------------

					ImGui.Dummy(0, dummySpacingYValue)
					ImGui.Separator()
					ImGui.Dummy(0, dummySpacingYValue)

					if ImGui.Button("View Changelogs", resetButtonWidth, buttonHeight) then
						isNewVersion = true
						updateWindowDismissed = false
						DrawUpdateWindow()
					end
					ui.tooltip("Open changelog window")
					ImGui.Dummy(0, dummySpacingYValue)

				end
				ImGui.EndChild()
				

				--Floating weather control panel
				ImGui.SetCursorPosY(ImGui.GetWindowHeight() - 185)
				DrawWeatherControl()

				ImGui.PopStyleColor()
				ImGui.PopStyleVar(2)
				
				ImGui.EndTabItem()
			end

			ImGui.PopStyleVar(2)

		ImGui.EndTabBar()
		end

		-- Reset font scale
		ImGui.SetWindowFontScale(defaultFontScale)

		-- FRAME PADDING POP
		ImGui.PopStyleVar(2)

		ImGui.End()
	end

	-- SCROLLBAR STYLE POP: Revert scrollbar color and size
	if settings.Current.scrollbarEnabled then
		ImGui.PopStyleVar()
		ImGui.PopStyleColor(2)
	end
end

----------------------------------------
------------- EXPORT DEBUG -------------
----------------------------------------

function ExportDebugFile(description)
    -- Check if the player is in menu or game is paused
    if Game.GetSystemRequestsHandler():IsPreGame() or Game.GetSystemRequestsHandler():IsGamePaused() then
        return
    end

    local pos = ToVector4(Game.GetPlayer():GetWorldPosition())
    local inVehicle = false
    local fileName = "debug/novaCityDebug_" .. modVersion .. ".json"
    local file = io.open(fileName, "r")
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
        weatherState = (Game.GetWeatherSystem():GetWeatherState() and Game.GetWeatherSystem():GetWeatherState().name.value) or nil,
        previousWeatherState = previousWeatherState,
        weatherStateHistory = weatherStateHistory,
        gameTime = tostring(Game.GetTimeSystem():GetGameTime():ToString()),
        inVehicle = tostring(inVehicle),
        playerDirection = (function()
            local dir = Game.GetPlayer():GetWorldOrientation():ToEulerAngles()
            if dir then
                return {roll = dir.roll, pitch = dir.pitch, yaw = dir.yaw}
            else
                return {roll = 0, pitch = 0, yaw = -180}
            end
        end)(),
        playerPosition = (function()
            if pos then
                return {x = pos.x, y = pos.y, z = pos.z, w = 1.0}
            else
                return {x = 0.0, y = 0.0, z = 0.0, w = 1.0}
            end
        end)(),
        issueDescription = description or "No description provided"
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
        previousWeatherState = data.previousWeatherState,
        weatherStateHistory = data.weatherStateHistory,
        gameTime = data.gameTime,
        inVehicle = data.inVehicle,
        playerDirection = data.playerDirection,
        playerPosition = data.playerPosition,
        issueDescription = data.issueDescription
    })

    -- Write updated data to Debug.json
    file = io.open(fileName, "w")
    if file then
        file:write(json.encode(debugData))
        file:close()
        print(IconGlyphs.CityVariant .. " Nova City Tools: Successfully exported debug file: " .. fileName )
    else
        print(IconGlyphs.CityVariant .. " Nova City Tools: Error - Could not open " .. fileName .. " for writing")
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
		ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 10, 10)
		ImGui.SameLine(ImGui.GetWindowContentRegionWidth() - ImGui.CalcTextSize(timeLabel))
		ImGui.Text(timeLabel)
		ImGui.SetNextItemWidth(-1)
		totalMinutes, changed = ImGui.SliderInt("##", totalMinutes, 0, 24 * 60 - 1)
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
		ImGui.PopStyleVar(1)

		-- Add hour buttons
		ImGui.Dummy(0, 0)
		ImGui.Separator()
		ImGui.Text("Set Hour:")

		local hourButtonWidth = ImGui.GetWindowContentRegionWidth() / 12 - uiTimeHourRightPadding
		for i = 1, 24 do
			local buttonHour = i % 24
			if totalMinutes >= buttonHour * 60 and totalMinutes < (buttonHour + 1) * 60 then
				ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0.0, 1, 0.7, 1))
				ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0, 0, 0, 1))
			end
			if ImGui.Button(tostring(i), hourButtonWidth, buttonHeight) then
				Game.GetTimeSystem():SetGameTimeByHMS(i, 0, secs)
			end
			if totalMinutes >= buttonHour * 60 and totalMinutes < (buttonHour + 1) * 60 then
				ImGui.PopStyleColor(2)
			end
			if i % 12 ~= 0 then
				ImGui.SameLine()
			end
		end

		ImGui.Dummy(0, 0)
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

		ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 10, 6)

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

		ImGui.PopStyleVar(3)

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
		ImGui.SetWindowFontScale(defaultFontScale)

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
		modVersion = modVersion,
		transitionDuration = settings.Current.transitionDuration,
		timeSliderWindowOpen = settings.Current.timeSliderWindowOpen,
		weatherState = settings.Current.weatherState,
		warningMessages = settings.Current.warningMessages,
		notificationMessages = settings.Current.notificationMessages,
		autoApplyWeather = settings.Current.autoApplyWeather,
		debugOutput = settings.Current.debugOutput,
		scrollbarEnabled = settings.Current.scrollbarEnabled,
		tooltipsEnabled = settings.Current.tooltipsEnabled,
		advancedToggles = settings.Current.advancedToggles,
		motionBlurScale = settings.Current.motionBlurScale,
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
		debugPrint("Settings saved successfully")
	else
		print(IconGlyphs.CityVariant .. " Nova City Tools: ERROR - Unable to open file for writing")
	end
end

function LoadSettings()
	local file = io.open("settings.json", "r")
	local saveNeeded = false

	if file then
		local content = file:read("*all")
		file:close()
		local loadedSettings = json.decode(content)
		
		-- Check for missing parameters and set defaults if necessary
		for key, value in pairs(settings.Default) do
			if loadedSettings[key] == nil then
				loadedSettings[key] = value
				saveNeeded = true
			end
		end

		-- Save a backup if modVersion is different or settings are missing
		if loadedSettings.modVersion ~= modVersion or saveNeeded then
			local backupFileName = "settings_backup.json"
			if loadedSettings.modVersion then
				backupFileName = "settings_backup_" .. loadedSettings.modVersion .. ".json"
			end
			local backupFile = io.open(backupFileName, "w")
			if backupFile then
				backupFile:write(content)
				backupFile:close()
			end
			isNewVersion = true -- Set the flag for new version
		end

		settings.Current = loadedSettings
		timeSliderWindowOpen = settings.Current.timeSliderWindowOpen
		collapsedCategories = loadedSettings.collapsedCategories or {}

		if saveNeeded then
			-- Erase and rewrite settings.json with updated values
			SaveSettings()
			print(IconGlyphs.CityVariant .. " Nova City Tools: Settings loaded and updated successfully")
		else
			print(IconGlyphs.CityVariant .. " Nova City Tools: Settings loaded successfully")
		end
	else
		print(IconGlyphs.CityVariant .. " Nova City Tools: Settings file not found")
		print(IconGlyphs.CityVariant .. " Nova City Tools: Creating default settings file")
		SaveSettings()
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