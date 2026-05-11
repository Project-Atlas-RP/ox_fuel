local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local fuel = require 'client.fuel'

local spawnedChargers = {}
local hasNozzle = false
local electricNozzle = nil
local refueling = false

-- State variables for electric charging
state.hasElectricNozzle = false
state.isElectricCharging = false

-- Spawn electric chargers
CreateThread(function()
    Wait(1000)
    local chargers = require 'data.chargers'

    for k, v in pairs(chargers.coords) do
        lib.requestModel(chargers.model)
        local prop = CreateObjectNoOffset(chargers.model, v.x, v.y, v.z, false, false, false)
        SetEntityHeading(prop, v.w + 180.0)
        FreezeEntityPosition(prop, true)
        SetEntityAsMissionEntity(prop, true, true)
        SetEntityInvincible(prop, true)
        SetCanClimbOnEntity(prop, false)
        spawnedChargers[prop] = prop

        if config.ox_target then
            exports.ox_target:addLocalEntity(prop, {
                {
                    name = 'take_charger',
                    icon = 'fas fa-bolt',
                    label = locale('take_charger') or 'Take Charger',
                    distance = 2.0,
                    onSelect = function()
                        takeCharger(prop)
                    end,
                    canInteract = function()
                        return not IsPedInAnyVehicle(cache.ped) and not hasNozzle
                    end,
                },
                {
                    name = 'return_charger',
                    icon = 'fas fa-bolt',
                    label = locale('return_charger') or 'Return Charger',
                    distance = 2.0,
                    onSelect = function()
                        returnCharger()
                    end,
                    canInteract = function()
                        return hasNozzle and not refueling
                    end,
                },
            })
        end
        Wait(100)
    end
end)

function takeCharger(prop)
    if hasNozzle then return end

    local ped = cache.ped
    local nozzleProp = config.electricCharger.nozzleModel

    RequestAnimDict("anim@am_hold_up@male")
    while not HasAnimDictLoaded('anim@am_hold_up@male') do
        Wait(100)
    end

    TaskPlayAnim(ped, "anim@am_hold_up@male", "shoplift_high", 2.0, 8.0, 1000, 50, 0, 0, 0, 0)

    lib.requestModel(nozzleProp)
    electricNozzle = CreateObject(nozzleProp, 1.0, 1.0, 1.0, 1, 1, 0)

    if DoesEntityExist(electricNozzle) then
        hasNozzle = true
        state.hasElectricNozzle = true
        AttachEntityToEntity(electricNozzle, ped, GetPedBoneIndex(ped, 18905), 0.15, 0.10, 0.04, -180.0, 100.0, -10.0, 0, 1, 0, 1, 0, 1)
    end

    -- Keep track of distance from charger
    local startCoords = GetEntityCoords(cache.ped)
    CreateThread(function()
        while hasNozzle do
            local coords = GetEntityCoords(cache.ped)
            if startCoords then
                local distance = #(coords - startCoords)
                if distance > config.electricCharger.maxDistance then
                    returnCharger()
                    lib.notify({
                        type = 'error',
                        description = locale('charger_too_far') or 'You left the charging station and the charger was returned.'
                    })
                end
            end
            Wait(1000)
        end
    end)
end

function returnCharger()
    if not hasNozzle then return end

    hasNozzle = false
    state.hasElectricNozzle = false

    if DoesEntityExist(electricNozzle) then
        DeleteObject(electricNozzle)
        electricNozzle = nil
    end
end

-- Add electric vehicle targets
if config.ox_target then
    exports.ox_target:addGlobalVehicle({
        {
            name = 'place_charger',
            icon = 'fas fa-bolt',
            label = locale('place_charger') or 'Place Charger',
            distance = 2.0,
            onSelect = function(data)
                if not utils.isElectricVehicle(data.entity) then
                    return lib.notify({
                        type = 'error',
                        description = locale('not_electric_vehicle') or 'This is not an electric vehicle.'
                    })
                end

                fuel.startElectricCharging(data.entity)
            end,
            canInteract = function(entity)
                if refueling or cache.vehicle or lib.progressActive() then
                    return false
                end
                return hasNozzle and utils.isElectricVehicle(entity)
            end
        },
        {
            name = 'remove_charger',
            icon = 'fas fa-bolt',
            label = locale('remove_charger') or 'Remove Charger',
            distance = 2.0,
            onSelect = function(data)
                fuel.stopElectricCharging(data.entity)
            end,
            canInteract = function(entity)
                if cache.vehicle or lib.progressActive() then
                    return false
                end
                local vehState = Entity(entity).state
                return vehState.isCharging and utils.isElectricVehicle(entity)
            end
        }
    })
end

-- Clean up on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for k, v in pairs(spawnedChargers) do
            if DoesEntityExist(k) then
                DeleteEntity(k)
            end
        end

        if DoesEntityExist(electricNozzle) then
            DeleteObject(electricNozzle)
        end
    end
end)

-- Export functions for other scripts
exports('takeCharger', takeCharger)
exports('returnCharger', returnCharger)
exports('hasElectricNozzle', function() return hasNozzle end)
