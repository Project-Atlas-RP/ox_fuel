local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local stations = lib.load 'data.stations'
local nozzle = require 'client.nozzle'

local pumpModels = {
    `prop_gas_pump_1a`,
    `prop_gas_pump_1b`,
    `prop_gas_pump_1c`,
    `prop_gas_pump_1d`,
    `prop_gas_pump_old1`,
    `prop_gas_pump_old2`,
    `prop_gas_pump_old3`,
    `prop_vintage_pump`,
    `prop_gas_pump_1d_short`,
}

local protectedPumps = {}

if config.showBlips == 2 then
	for station in pairs(stations) do utils.createBlip(station) end
end

local function protectPumps(pumps)
	for i = 1, #pumps do
		local pump = pumps[i]
		for j = 1, #pumpModels do
			local obj = GetClosestObjectOfType(pump.x, pump.y, pump.z, 2.0, pumpModels[j], false, false, false)
			if obj ~= 0 and not protectedPumps[obj] then
				SetEntityInvincible(obj, true)
				SetEntityProofs(obj, true, true, true, true, true, true, true, true)
				SetDisableFragDamage(obj, true)
				protectedPumps[obj] = true
			end
		end
	end
end

---@param point CPoint
local function onEnterStation(point)
	if config.showBlips == 1 and not point.blip then
		point.blip = utils.createBlip(point.coords)
	end

	protectPumps(point.pumps)
end

---@param point CPoint
local function nearbyStation(point)
	if point.currentDistance > 15 then return end

	local pumps = point.pumps
	local pumpDistance

	for i = 1, #pumps do
		local pump = pumps[i]
		pumpDistance = #(cache.coords - pump)

		if pumpDistance <= 3 then
			state.nearestPump = pump

			repeat
				local playerCoords = GetEntityCoords(cache.ped)
				pumpDistance = #(GetEntityCoords(cache.ped) - pump)

				if cache.vehicle then
					DisplayHelpTextThisFrame('fuelLeaveVehicleText', false)
				elseif not state.isFueling then
					local vehicleInRange = state.lastVehicle ~= 0 and
						#(GetEntityCoords(state.lastVehicle) - playerCoords) <= 3

					if vehicleInRange then
						DisplayHelpTextThisFrame('fuelHelpText', false)
					elseif config.petrolCan.enabled then
						DisplayHelpTextThisFrame('petrolcanHelpText', false)
					end
				end

				Wait(0)
			until pumpDistance > 3

			state.nearestPump = nil

			return
		end
	end
end

---@param point CPoint
local function onExitStation(point)
	if point.blip then
		point.blip = RemoveBlip(point.blip)
	end

	-- Return nozzle if player leaves the station area
	if state.hasGasNozzle then
		nozzle.forceReturn()
		lib.notify({
			type = 'error',
			description = locale('nozzle_station_exit') or 'You left the gas station. Nozzle returned.'
		})
	end
end

---@param point CPoint
local function pumpProtectionNearby(point)
	-- Re-check every ~5 seconds (nearby runs every frame, use timer to throttle)
	local now = GetGameTimer()
	if not point._lastProtectCheck or now - point._lastProtectCheck > 5000 then
		point._lastProtectCheck = now
		protectPumps(point.pumps)
	end
end

for station, pumps in pairs(stations) do
	lib.points.new({
		coords = station,
		distance = 60,
		onEnter = onEnterStation,
		onExit = onExitStation,
		nearby = config.ox_target and pumpProtectionNearby or nearbyStation,
		pumps = pumps,
	})
end
