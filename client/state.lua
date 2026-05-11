---@class State
---@field petrolCan SlotWithItem?
---@field isFueling boolean
---@field nearestPump vector3?
---@field lastVehicle number?
---@field hasGasNozzle boolean
---@field gasNozzleObject number?
---@field gasNozzleStartCoords vector3?
local state = {
	isFueling = false,
	lastVehicle = cache.vehicle or GetPlayersLastVehicle(),
	hasGasNozzle = false,
	gasNozzleObject = nil,
	gasNozzleStartCoords = nil,
}

if state.lastVehicle == 0 then state.lastVehicle = nil end

---@param data? SlotWithItem
local function setPetrolCan(data)
	state.petrolCan = data?.name == 'WEAPON_PETROLCAN' and data or nil
end

setPetrolCan(exports.ox_inventory:getCurrentWeapon())

AddEventHandler('ox_inventory:currentWeapon', setPetrolCan)

return state
