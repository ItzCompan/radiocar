local xsound = exports["xsound"]
local cache = {}
local vehicles = {}
local carEntityPrefix = "car_entity_"
local uiActive = false

local function debugPrint(...)
    if Config["Debug"] then
        print(...)
    end
end

local function setUIVisibility(visible, focus)
    uiActive = visible
    if focus ~= (true or false) then
        SetNuiFocus(focus, focus)
    end
    SendNUIMessage({ type = "ui", status = visible })
    SendNUIMessage({ type = "timeWorld", timeWorld = string.format("%.2d:%.2d", GetClockHours(), GetClockMinutes()) })
end

local function isVehicleBlacklisted()
    local playerPed = PlayerPedId()
    local blacklistedCategories = Config["blackListedCategories"]
    local vehicleModel = GetEntityModel(GetVehiclePedIsIn(playerPed))

    for _, v in pairs(Config["whitelistedCars"]) do
        if v == vehicleModel then return false end
    end

    for _, v in pairs(Config["blacklistedCars"]) do
        if v == vehicleModel then return true end
    end

    if not blacklistedCategories["anyBoat"] and IsPedInAnyBoat(playerPed) then return true end
    if not blacklistedCategories["anyHeli"] and IsPedInAnyHeli(playerPed) then return true end
    if not blacklistedCategories["anyPlane"] and IsPedInAnyPlane(playerPed) then return true end
    if not blacklistedCategories["anyCopCar"] and IsPedInAnyPoliceVehicle(playerPed) then return true end
    if not blacklistedCategories["anySub"] and IsPedInAnySub(playerPed) then return true end
    if not blacklistedCategories["anyTaxi"] and IsPedInAnyTaxi(playerPed) then return true end
    if not blacklistedCategories["anyTrain"] and IsPedInAnyTrain(playerPed) then return true end
    if not blacklistedCategories["anyVehicle"] and IsPedInAnyVehicle(playerPed, true) then return true end

    return false
end

local function isVehicleEngineRunning(vehicle)
    if not Config["DisableMusicAfterEngineIsOFF"] then return true end
    return GetIsVehicleEngineRunning(vehicle)
end

local function clearUI()
    local plateText = GetVehicleNumberPlateText(GetVehiclePedIsIn(PlayerPedId()))
    SendNUIMessage({ type = "clear" })

    for _, v in pairs(Config["defaultList"]) do
        SendNUIMessage({ type = "add", url = v["url"], label = v["label"] })
    end

    TriggerServerEvent("lg-radiocar:getMusicInCar", plateText)
    Wait(100)
    setUIVisibility(true, true)

    local vehicleNetId = carEntityPrefix .. VehToNet(GetVehiclePedIsIn(PlayerPedId(), false))

    if xsound:soundExists(xsound, vehicleNetId) then
        if xsound:isPlaying(xsound, vehicleNetId) then
            SendNUIMessage({ type = "update", url = xsound:getLink(xsound, vehicleNetId) })
        else
            SendNUIMessage({ type = "reset" })
        end
        SendNUIMessage({ type = "volume", volume = xsound:getVolume(xsound, vehicleNetId) })
    else
        SendNUIMessage({ type = "reset" })
    end
end

local function getVehicleSeat(vehicle)
    for i = -1, GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) - 2 do
        if GetPedInVehicleSeat(vehicle, i) == PlayerPedId() then
            return i
        end
    end
    return nil
end

local function updateMusicCache(vehicle, musicUrl)
    if not NetworkGetEntityIsNetworked(vehicle) then
        NetworkRegisterEntityAsNetworked(vehicle)
    end

    local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
    local musicData = {
        idMusic = carEntityPrefix .. vehicleNetId,
        time = 0,
        car = vehicleNetId,
        url = musicUrl,
        pos = GetEntityCoords(vehicle)
    }

    TriggerServerEvent("lg-radiocar:addToCache", musicData)
    debugPrint("Triggering event for updating cache")
end

RegisterNUICallback("volumeup", function()
    local vehicleNetId = carEntityPrefix .. VehToNet(GetVehiclePedIsIn(PlayerPedId(), false))
    if IsPedInAnyVehicle(PlayerPedId(), false) and xsound:soundExists(xsound, vehicleNetId) then
        local volume = xsound:getVolume(xsound, vehicleNetId)
        volume = math.min(volume + 0.1, 1.0)
        SendNUIMessage({ type = "volume", volume = volume })
        TriggerServerEvent("lg-radiocar:updateVolume", vehicleNetId, volume)
    end
end)

RegisterNUICallback("volumedown", function()
    local vehicleNetId = carEntityPrefix .. VehToNet(GetVehiclePedIsIn(PlayerPedId(), false))
    if IsPedInAnyVehicle(PlayerPedId(), false) and xsound:soundExists(xsound, vehicleNetId) then
        local volume = xsound:getVolume(xsound, vehicleNetId)
        volume = math.max(volume - 0.1, 0)
        SendNUIMessage({ type = "volume", volume = volume })
        TriggerServerEvent("lg-radiocar:updateVolume", vehicleNetId, volume)
    end
end)

RegisterNUICallback("editSong", function(data)
    if isVehicleBlacklisted() then return end
    local plateText = GetVehicleNumberPlateText(GetVehiclePedIsIn(PlayerPedId()))
    TriggerServerEvent("lg-radiocar:updateMusicInfo", data["label"], data["url"], plateText, data["index"])
end)

RegisterNetEvent("lg-radiocar:getMusicInCar")
AddEventHandler("lg-radiocar:getMusicInCar", function(data)
    for _, v in pairs(data) do
        SendNUIMessage({ type = "edit", url = v["url"], label = v["label"], index = v["index_music"] })
    end
end)

RegisterNUICallback("exit", function()
    setUIVisibility(false, false)
end)

RegisterNUICallback("stop", function()
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        TriggerServerEvent("lg-radiocar:deleteFromCache", VehToNet(GetVehiclePedIsIn(PlayerPedId(), false)))
    end
end)

RegisterNUICallback("play", function(data)
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        updateMusicCache(GetVehiclePedIsIn(PlayerPedId(), false), data["url"])
    end
end)

RegisterNetEvent("lg-radiocar:deleteFromCache")
AddEventHandler("lg-radiocar:deleteFromCache", function(vehNet)
    debugPrint("trying to delete music:", vehNet)
    if xsound:soundExists(xsound, carEntityPrefix .. vehNet) then
        debugPrint("Music deleted")
        xsound:Destroy(xsound, carEntityPrefix .. vehNet)
    end
end)

RegisterNetEvent("lg-radiocar:openUI")
AddEventHandler("lg-radiocar:openUI", function()
    clearUI()
end)

RegisterNetEvent("lg-radiocar:updateVolume")
AddEventHandler("lg-radiocar:updateVolume", function(vehNet, volume)
    if xsound:soundExists(xsound, carEntityPrefix .. vehNet) then
        xsound:setVolumeMax(xsound, carEntityPrefix .. vehNet, volume)
    end
end)

RegisterNetEvent("lg-radiocar:updateCache")
AddEventHandler("lg-radiocar:updateCache", function(ch, destroy)
    vehicles = ch
    for _, v in pairs(destroy) do
        xsound:Destroy(xsound, v["idMusic"])
    end
end)

RegisterNetEvent("lg-radiocar:addToCache")
AddEventHandler("lg-radiocar:addToCache", function(ch)
    if not xsound:soundExists(xsound, ch["idMusic"]) then
        local exists = false
        for _, v in pairs(vehicles) do
            if v["car"] == ch["car"] then
                exists = true
                break
            end
        end
        if not exists then
            table.insert(vehicles, ch)
        end
    end
    debugPrint("Start playing music")
    xsound:PlayUrlPos(xsound, ch["idMusic"], ch["url"], Config["defaultVolume"], ch["pos"], false)
    xsound:onPlayStart(xsound, ch["idMusic"], function()
        xsound:Distance(xsound, ch["idMusic"], 0)
        debugPrint("The music successfully started playing, setting distance to 0")
    end)
    if GetVehiclePedIsIn(PlayerPedId(), false) == NetToVeh(ch["car"]) then
        SendNUIMessage({ type = "volume", volume = xsound:getVolume(xsound, ch["idMusic"]) })
    end
end)

RegisterNetEvent("lg-radiocar:updateMusic")
AddEventHandler("lg-radiocar:updateMusic", function(ch)
    xsound:Destroy(xsound, ch["idMusic"])
    Wait(1000)
    xsound:PlayUrlPos(xsound, ch["idMusic"], ch["url"], Config["defaultVolume"], ch["pos"], false)
    xsound:onPlayStart(xsound, ch["idMusic"], function()
        xsound:Distance(xsound, ch["idMusic"], 0)
    end)
end)

Citizen.CreateThread(function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    TriggerServerEvent("lg-radiocar:initializeCache", playerCoords)
    while true do
        Citizen.Wait(1000)
        playerPed = PlayerPedId()
        playerCoords = GetEntityCoords(playerPed)
        if #vehicles ~= 0 then
            for _, v in pairs(vehicles) do
                if #(playerCoords - v["pos"]) <= 40 and isVehicleEngineRunning(NetToVeh(v["car"])) then
                    if not xsound:soundExists(xsound, v["idMusic"]) then
                        xsound:PlayUrlPos(xsound, v["idMusic"], v["url"], Config["defaultVolume"], v["pos"], false)
                        xsound:onPlayStart(xsound, v["idMusic"], function()
                            xsound:Distance(xsound, v["idMusic"], 0)
                        end)
                    else
                        if not xsound:isPlaying(xsound, v["idMusic"]) then
                            xsound:Resume(xsound, v["idMusic"])
                        end
                    end
                else
                    if xsound:soundExists(xsound, v["idMusic"]) then
                        xsound:Destroy(xsound, v["idMusic"])
                    end
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    while true do
        Citizen.Wait(2000)
        playerPed = PlayerPedId()
        playerCoords = GetEntityCoords(playerPed)
        TriggerServerEvent("lg-radiocar:requestCache", playerCoords)
    end
end)

local function draw3DText(x, y, z, text)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextEntry("STRING")
    SetTextCentre(1)
    SetTextColour(255, 255, 255, 215)
    AddTextComponentString(text)
    DrawText(_x, _y)
    local factor = (string.len(text)) / 370
    DrawRect(_x, _y + 0.0150, 0.020 + factor, 0.03, 41, 11, 41, 100)
end

Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        if not IsPedInAnyVehicle(playerPed, false) then
            for _, v in pairs(vehicles) do
                local distance = #(GetEntityCoords(playerPed) - v["pos"])
                if distance < 10 then
                    draw3DText(v["pos"].x, v["pos"].y, v["pos"].z, "RadioCar")
                end
            end
        end
        Citizen.Wait(0)
    end
end)

Citizen.CreateThread(function()
    while true do
        Wait(1000)
        SendNUIMessage({ type = "timeWorld", timeWorld = string.format("%.2d:%.2d", GetClockHours(), GetClockMinutes()) })
    end
end)
