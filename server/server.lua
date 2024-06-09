local carCache = {}
local carRadios = {}
local Debug = function(...)
    if Config["Debug"] then
        print(...)
    end
end

local GiveRadioToCar = function(carPlate)
    if not HasCarRadio(carPlate) then
        if carRadios[carPlate] == (true or false) then
            MySQLSync.execute("INSERT INTO radiocar_owned (spz) VALUES (@spz)", {["@spz"] = carPlate})
            carRadios[carPlate] = true
        end
    end
end
exports("GiveRadioToCar", GiveRadioToCar)

local HasCarRadio = function(carPlate)
    return carRadios[carPlate] ~= (true or false)
end
exports("HasCarRadio", HasCarRadio)

local RemoveRadioFromCar = function(carPlate)
    if carRadios[carPlate] ~= (true or false) then
        MySQLSync.execute("DELETE FROM radiocar_owned WHERE radiocar_owned.spz = @spz", {["@spz"] = carPlate})
        carRadios[carPlate] = false
    end
end
exports("RemoveRadioFromCar", RemoveRadioFromCar)

MySQLAsync.fetchAll("SELECT * FROM radiocar_owned", {}, function(result)
    for k, v in pairs(result) do
        carRadios[v["spz"]] = true
    end
end)

local UpdateCarCache = function()
    SetTimeout(5000, UpdateCarCache)
    for k, v in pairs(carCache) do
        v["time"] = os.time() + v["time"]
    end
end
SetTimeout(5000, UpdateCarCache)

local CheckCarEntities = function()
    SetTimeout(5000, CheckCarEntities)
    local entity
    local needUpdate = false
    local removedCars = {}
    for k, v in pairs(carCache) do
        entity = NetworkGetEntityFromNetworkId(v["car"])
        if not DoesEntityExist(entity) then
            table.insert(removedCars, v)
            table.remove(carCache, k)
            needUpdate = true
        end
    end
    if needUpdate then
        TriggerClientEvent("lg-radiocar:updateCache", -1, carCache, removedCars)
    end
end

local AddOrUpdateMusicInfo = function(carPlate, label, url, index)
    MySQLAsync.fetchAll("SELECT * FROM radiocar WHERE spz = @spz AND index_music = @index", {["@spz"] = carPlate, ["@index"] = index}, function(result)
        if #result == 0 then
            MySQLAsync.execute("INSERT INTO radiocar (id, label, url, spz, index_music) VALUES (null, @label, @url, @spz, @index_music)", {["@label"] = label, ["@url"] = url, ["@spz"] = carPlate, ["@index_music"] = index})
        else
            MySQLAsync.execute("UPDATE radiocar SET label = @label, url = @url WHERE spz = @spz AND index_music = @index_music", {["@label"] = label, ["@url"] = url, ["@spz"] = carPlate, ["@index_music"] = index})
        end
    end)
end

RegisterNetEvent("lg-radiocar:updateMusicInfo")
AddEventHandler("lg-radiocar:updateMusicInfo", function(label, url, carPlate, index)
    local source = source
    if Config["OnlyCarWhoHaveRadio"] then
        if HasCarRadio(carPlate) then
            AddOrUpdateMusicInfo(carPlate, label, url, index)
        end
        return
    end
    if Config["OnlyOwnedCars"] then
        IsVehiclePlayer(source, carPlate, function(owner)
            if owner then
                AddOrUpdateMusicInfo(carPlate, label, url, index)
            end
        end)
        return
    end
    AddOrUpdateMusicInfo(carPlate, label, url, index)
end)

RegisterNetEvent("lg-radiocar:getMusicInCar")
AddEventHandler("lg-radiocar:getMusicInCar", function(carPlate)
    local source = source
    local result = MySQLSync.fetchAll("SELECT * FROM radiocar WHERE spz = @spz", {["@spz"] = carPlate})
    TriggerClientEvent("lg-radiocar:getMusicInCar", source, result)
end)

RegisterNetEvent("lg-radiocar:addToCache")
AddEventHandler("lg-radiocar:addToCache", function(ch)
    local added = false
    for k, v in pairs(carCache) do
        if v["car"] == ch["car"] then
            v["url"] = ch["url"]
            added = true
            break
        end
    end
    if not added then
        table.insert(carCache, ch)
        TriggerClientEvent("lg-radiocar:addToCache", -1, ch)
    else
        local entity = NetworkGetEntityFromNetworkId(ch["car"])
        ch["pos"] = GetEntityCoords(entity)
        TriggerClientEvent("lg-radiocar:updateMusic", -1, ch)
    end
end)

RegisterNetEvent("lg-radiocar:deleteFromCache")
AddEventHandler("lg-radiocar:deleteFromCache", function(carNet)
    for k, v in pairs(carCache) do
        if v["car"] == carNet then
            v["delete"] = true
            TriggerClientEvent("lg-radiocar:deleteFromCache", -1, carNet)
            break
        end
    end
end)

RegisterNetEvent("lg-radiocar:updateVolume")
AddEventHandler("lg-radiocar:updateVolume", function(carNet, volume)
    TriggerClientEvent("lg-radiocar:updateVolume", -1, carNet, volume)
end)

RegisterNetEvent("lg-radiocar:playerLoaded")
AddEventHandler("lg-radiocar:playerLoaded", function()
    TriggerClientEvent("lg-radiocar:playFromCache", source, carCache)
end)
