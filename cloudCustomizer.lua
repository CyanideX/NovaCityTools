-- cloudCustomizer.lua
local M = {}

local transitioning = false
local elapsedTime = 0.0
local previousSettings = { coverage = 0.0, noise = 0.0, detail = 0.0 }
local settings = {
    Current = {
        coverage = 2.250000,
        noise = 1.400000,
        detail = 2.200000,
        transitionDuration = 300.0
    },
    Default = {
        coverage = 2.250000,
        noise = 1.400000,
        detail = 2.200000,
        transitionDuration = 300.0
    }
}

local function randomFloat(min, max)
    return min + math.random() * (max - min)
end

local function startTransition(newCoverage, newNoise, newDetail)
    transitioning = true
    elapsedTime = 0.0
    previousSettings.coverage = settings.Current.coverage
    previousSettings.noise = settings.Current.noise
    previousSettings.detail = settings.Current.detail
    settings.Current.coverage = newCoverage
    settings.Current.noise = newNoise
    settings.Current.detail = newDetail
    debugPrint("StartTransition called with: coverage=" .. tostring(newCoverage) .. ", noise=" .. tostring(newNoise) .. ", detail=" .. tostring(newDetail) .. ", transitionTime=" .. tostring(settings.Current.transitionDuration))
end

function M.UpdateTransition(deltaTime)
    if not transitioning then return end
    elapsedTime = elapsedTime + deltaTime
    local t = math.min(elapsedTime / settings.Current.transitionDuration, 1.0)
    local currentCoverage = previousSettings.coverage + t * (settings.Current.coverage - previousSettings.coverage)
    local currentNoise = previousSettings.noise + t * (settings.Current.noise - previousSettings.noise)
    local currentDetail = previousSettings.detail + t * (settings.Current.detail - previousSettings.detail)
    GameOptions.SetFloat("Editor/VolumetricClouds", "CoverageScale", currentCoverage)
    GameOptions.SetFloat("Editor/VolumetricClouds", "NoiseScale", currentNoise)
    GameOptions.SetFloat("Editor/VolumetricClouds", "DetailNoiseScale", currentDetail)
    if t >= 1.0 then
        transitioning = false
        M.SaveSettings()
    end
end

function M.RandomizeClouds(duration)
    transitioning = false
    elapsedTime = 0.0
    local coverageMin, coverageMax = 1.0, 10.0
    local noiseMin, noiseMax = 0.4, 10.0
    local detailMin, detailMax = 0.4, 10.0
    local coverage = randomFloat(coverageMin, coverageMax)
    local noise = randomFloat(noiseMin, noiseMax)
    local detail = randomFloat(detailMin, detailMax)
    debugPrint("RandomizeClouds called with duration: " .. tostring(duration))
    if duration ~= nil then
        settings.Current.transitionDuration = duration
    end
    debugPrint("Transition Time set to: " .. tostring(settings.Current.transitionDuration))
    startTransition(coverage, noise, detail)
end

function M.DefaultClouds()
    transitioning = false
    elapsedTime = 0.0
    GameOptions.SetFloat("Editor/VolumetricClouds", "CoverageScale", settings.Default.coverage)
    GameOptions.SetFloat("Editor/VolumetricClouds", "NoiseScale", settings.Default.noise)
    GameOptions.SetFloat("Editor/VolumetricClouds", "DetailNoiseScale", settings.Default.detail)
    settings.Current.coverage = settings.Default.coverage
    settings.Current.noise = settings.Default.noise
    settings.Current.detail = settings.Default.detail
    M.SaveSettings()
end

function M.ApplySettings()
    GameOptions.SetFloat("Editor/VolumetricClouds", "CoverageScale", settings.Current.coverage)
    GameOptions.SetFloat("Editor/VolumetricClouds", "NoiseScale", settings.Current.noise)
    GameOptions.SetFloat("Editor/VolumetricClouds", "DetailNoiseScale", settings.Current.detail)
end

function M.ApplyCloudSettingsWithTransition(newCoverage, newNoise, newDetail, duration)
    if duration ~= nil then
        settings.Current.transitionDuration = duration
    end
    debugPrint("Transition Duration set to: " .. tostring(settings.Current.transitionDuration))
    startTransition(newCoverage, newNoise, newDetail)
end

function M.DrawCloudCustomizer(cetOpen)
    if not cetOpen then
        return
    end
    ImGui.SetNextWindowSizeConstraints(292, 300, width / 100 * 47, 300)
    if ImGui.Begin("Cloud Customizer", ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.AlwaysUseWindowPadding) then
        ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(0.65, 0.7, 1, 0.045))
        -- Set inner padding for the child window
        ImGui.PushStyleVar(ImGuiStyleVar.ChildRounding, 5.0)
        ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 10, 0)
        ImGui.SetWindowFontScale(0.85)
        if ImGui.BeginChild("CloudCustomizer", ImGui.GetContentRegionAvail()) then
            ImGui.PushItemWidth(-1) -- Makes the item width span the entire child window
            ImGui.Text("Coverage Scale")
            settings.Current.coverage, changed = ImGui.SliderFloat("##Coverage Scale", settings.Current.coverage, 1.0, 10.0)
            if changed then
                GameOptions.SetFloat("Editor/VolumetricClouds", "CoverageScale", settings.Current.coverage)
                M.SaveSettings()
            end
            ImGui.Text("Noise Scale")
            settings.Current.noise, changed = ImGui.SliderFloat("##Noise Scale", settings.Current.noise, 0.4, 10.0)
            if changed then
                GameOptions.SetFloat("Editor/VolumetricClouds", "NoiseScale", settings.Current.noise)
                M.SaveSettings()
            end
            ImGui.Text("Detail Scale")
            settings.Current.detail, changed = ImGui.SliderFloat("##Detail Scale", settings.Current.detail, 0.4, 10.0)
            if changed then
                GameOptions.SetFloat("Editor/VolumetricClouds", "DetailNoiseScale", settings.Current.detail)
                M.SaveSettings()
            end
            ImGui.Text("Transition Duration")
            settings.Current.transitionDuration, changed = ImGui.SliderInt("##Transition Duration", settings.Current.transitionDuration, 0, 10000)
            if changed then
                M.SaveSettings()
            end
            ImGui.Dummy(0, 10)
            ImGui.PopStyleVar()
            local buttonWidth = (ImGui.GetContentRegionAvail() - ImGui.GetStyle().ItemSpacing.x) / 2
            ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 10, 6)
            if ImGui.Button("Randomize", buttonWidth, 0) then
                M.RandomizeClouds()
            end
            ImGui.SameLine()
            if ImGui.Button("Default", buttonWidth, 0) then
                M.DefaultClouds()
            end
            ImGui.PopItemWidth()
            ImGui.EndChild()
        end
        ImGui.SetWindowFontScale(1)
        ImGui.PopStyleVar(2)
        ImGui.PopStyleColor()
    end
end

function M.SaveSettings()
    local file = io.open("cloudSettings.json", "w")
    if file then
        file:write(json.encode(settings.Current))
        file:close()
    end
end

function M.LoadSettings()
    local file = io.open("cloudSettings.json", "r")
    if file then
        settings.Current = json.decode(file:read("*all"))
        file:close()
        M.ApplySettings()
    end
end

return M
