local config = require 'config'
local state = require 'client.state'

local nozzle = {}

-- Nozzle configuration
local NOZZLE_PROP = 'prop_cs_fuel_nozle'
local NOZZLE_ANIM_DICT = 'anim@am_hold_up@male'
local NOZZLE_ANIM_CLIP = 'shoplift_high'
local NOZZLE_ANIM_DURATION = 1000
local NOZZLE_RETURN_ACTION_DELAY = 450
local MAX_NOZZLE_DISTANCE = 8.0 -- Maximum distance from pump before nozzle auto-returns
local SOUND_DISTANCE = 15.0
local SOUND_VOLUME = 0.35

local function playSound(file)
    TriggerServerEvent('InteractSound_SV:PlayWithinDistance', SOUND_DISTANCE, file, SOUND_VOLUME)
end

local function playNozzleAnimation(ped)
    lib.requestAnimDict(NOZZLE_ANIM_DICT)
    TaskPlayAnim(ped, NOZZLE_ANIM_DICT, NOZZLE_ANIM_CLIP, 2.0, 8.0, NOZZLE_ANIM_DURATION, 50, 0, false, false, false)
end

---Take the nozzle from a gas pump
---@param pumpEntity number? The pump entity (optional, for sound effects)
function nozzle.take(pumpEntity)
    if state.hasGasNozzle then return end
    if state.isFueling then return end

    local ped = cache.ped

    playNozzleAnimation(ped)

    -- Load and create nozzle prop
    lib.requestModel(NOZZLE_PROP)
    local nozzleObj = CreateObject(NOZZLE_PROP, 1.0, 1.0, 1.0, true, true, false)

    if DoesEntityExist(nozzleObj) then
        state.hasGasNozzle = true
        state.gasNozzleObject = nozzleObj
        state.gasNozzleStartCoords = GetEntityCoords(ped)

        -- Attach nozzle to player's hand
        AttachEntityToEntity(
            nozzleObj,
            ped,
            GetPedBoneIndex(ped, 18905), -- Right hand bone
            0.13, 0.04, 0.01,
            -42.0, -115.0, -63.42,
            false, true, false, true, 0, true
        )

        playSound('pickupnozzle')

        lib.notify({
            type = 'success',
            description = locale('nozzle_taken') or 'Nozzle taken. Walk to your vehicle to refuel.'
        })

        -- Start distance check thread
        nozzle.startDistanceCheck()
    end
end

---Return the nozzle to the gas pump
function nozzle.return_()
    if not state.hasGasNozzle then return end
    if state.isFueling then
        lib.notify({
            type = 'error',
            description = locale('cannot_return_while_fueling') or 'Cannot return nozzle while fueling.'
        })
        return
    end

    playNozzleAnimation(cache.ped)
    Wait(NOZZLE_RETURN_ACTION_DELAY)

    state.hasGasNozzle = false
    state.gasNozzleStartCoords = nil

    if DoesEntityExist(state.gasNozzleObject) then
        DeleteObject(state.gasNozzleObject)
        state.gasNozzleObject = nil
    end

    playSound('putbacknozzle')

    Wait(NOZZLE_ANIM_DURATION - NOZZLE_RETURN_ACTION_DELAY)
end

---Force return the nozzle (used when player walks too far)
function nozzle.forceReturn()
    state.hasGasNozzle = false
    state.gasNozzleStartCoords = nil

    if DoesEntityExist(state.gasNozzleObject) then
        DeleteObject(state.gasNozzleObject)
        state.gasNozzleObject = nil
    end

    playSound('putbacknozzle')
end

---Start monitoring distance from pump
function nozzle.startDistanceCheck()
    CreateThread(function()
        local startCoords = state.gasNozzleStartCoords

        while state.hasGasNozzle do
            if startCoords then
                local currentCoords = GetEntityCoords(cache.ped)
                local distance = #(currentCoords - startCoords)

                if distance > MAX_NOZZLE_DISTANCE then
                    nozzle.forceReturn()
                    lib.notify({
                        type = 'error',
                        description = locale('nozzle_auto_return') or 'You walked too far from the pump. Nozzle returned.'
                    })
                    break
                end
            end

            Wait(500)
        end
    end)
end

---Check if player has the gas nozzle
---@return boolean
function nozzle.hasNozzle()
    return state.hasGasNozzle
end

-- Clean up nozzle on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if DoesEntityExist(state.gasNozzleObject) then
            DeleteObject(state.gasNozzleObject)
        end
    end
end)

-- Exports for other scripts
exports('takeGasNozzle', nozzle.take)
exports('returnGasNozzle', nozzle.return_)
exports('hasGasNozzle', nozzle.hasNozzle)

return nozzle
