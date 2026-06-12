local config = require 'config'

if not config then return end

SetFuelConsumptionState(true)
SetFuelConsumptionRateMultiplier(config.globalFuelConsumptionRate)

AddTextEntry('fuelHelpText', locale('fuel_help'))
AddTextEntry('petrolcanHelpText', locale('petrolcan_help'))
AddTextEntry('fuelLeaveVehicleText', locale('leave_vehicle'))
AddTextEntry('ox_fuel_station', locale('fuel_station_blip'))

local utils = require 'client.utils'
local state = require 'client.state'
local fuel  = require 'client.fuel'

require 'client.stations'

-- Load electric charging system
require 'client.electric'

local function startDrivingVehicle()
	local vehicle = cache.vehicle

	-- GTA V natives report many electric vehicles as not using fuel; we still need to
	-- initialize a 'fuel' (charge) state for them so Entity(vehicle).state.fuel isn't nil.
	-- Allow electric vehicles past this guard.
	if not DoesVehicleUseFuel(vehicle) and not utils.isElectricVehicle(vehicle) then return end

	local vehState = Entity(vehicle).state

	if not vehState.fuel then
		local currentFuel = GetVehicleFuelLevel(vehicle)
		local defaultLevel

		-- Check if this is an electric vehicle
		if utils.isElectricVehicle(vehicle) then
			-- For electric vehicles, use default electric level if fuel is very low (newly spawned)
			defaultLevel = currentFuel <= 5.0 and config.defaultElectricLevel or currentFuel
		else
			-- For regular vehicles, use default fuel level if fuel is very low (newly spawned)
			defaultLevel = currentFuel <= 5.0 and config.defaultFuelLevel or currentFuel
		end

		-- Atlas: route the initial level through the server event (strict statebags
		-- reject client-side vehState writes) but keep the local level immediate.
		TriggerServerEvent('ox_fuel:setFuel', defaultLevel)
		SetVehicleFuelLevel(vehicle, defaultLevel)
		while not vehState.fuel do Wait(0) end
	end

	SetVehicleFuelLevel(vehicle, vehState.fuel)

	local fuelTick = 0

	while cache.seat == -1 do
		if GetIsVehicleEngineRunning(vehicle) then
			if not DoesEntityExist(vehicle) then return end

			local isElectric = utils.isElectricVehicle(vehicle)
			if isElectric then
				-- Custom electric consumption logic (battery drain)
				-- We disable native consumption so we control it manually
				SetFuelConsumptionRateMultiplier(0.0)
				local charge = tonumber(vehState.fuel) or GetVehicleFuelLevel(vehicle)
				if charge > 0 then
					-- Base drain scaled by configured electric rate
					local speed = GetEntitySpeed(vehicle) * 3.6 -- kph
					local drain = (config.electricConsumptionRate / 600.0) -- base hourly-ish divisor
					-- Add speed influence
					drain += (speed / math.max(config.electricSpeedFactor, 1.0)) * 0.02
					-- Extra drain if vehicle health poor (simulate inefficiency)
					if GetVehicleEngineHealth(vehicle) < 800.0 then
						drain += 0.015
					end
					charge -= drain
					if charge < 0 then charge = 0 end
					-- Replicate every 15s; update natives each tick
					if fuelTick == 15 or charge == 0 then
						fuel.setFuel(vehState, vehicle, charge, true)
						fuelTick = 0
					else
						SetVehicleFuelLevel(vehicle, charge)
						vehState:set('fuel', charge, false)
						fuelTick += 1
					end
					-- Force engine off when depleted / below cutoff
					if charge <= (config.electricEngineCutoff or 0.5) then
						SetVehicleEngineOn(vehicle, false, true, true)
					end
				end
			else
				SetFuelConsumptionRateMultiplier(config.globalFuelConsumptionRate)

				local fuelAmount = tonumber(vehState.fuel)
				local newFuel = GetVehicleFuelLevel(vehicle)
				if fuelAmount > 0 then
					if GetVehiclePetrolTankHealth(vehicle) < 700 then
						newFuel -= math.random(10, 20) * 0.01
					end

					if fuelAmount ~= newFuel then
						if fuelTick == 15 then
							fuelTick = 0
						end

						fuel.setFuel(vehState, vehicle, newFuel, fuelTick == 0)
						fuelTick += 1
					end
				end
			end
		else
			if not DoesEntityExist(vehicle) then return end
			SetFuelConsumptionRateMultiplier(0.0)
		end
		Wait(1000)
	end

	fuel.setFuel(vehState, vehicle, vehState.fuel, true)
end

if cache.seat == -1 then CreateThread(startDrivingVehicle) end

lib.onCache('seat', function(seat)
	if cache.vehicle then
		state.lastVehicle = cache.vehicle
	end

	if seat == -1 then
		SetTimeout(0, startDrivingVehicle)
	end
end)

if config.ox_target then return require 'client.target' end

RegisterCommand('startfueling', function()
	if state.isFueling or cache.vehicle or lib.progressActive() then return end

	local petrolCan = config.petrolCan.enabled and GetSelectedPedWeapon(cache.ped) == `WEAPON_PETROLCAN`
	local playerCoords = GetEntityCoords(cache.ped)
	local nearestPump = state.nearestPump

	if nearestPump then
		local moneyAmount = utils.getMoney()

		if petrolCan and moneyAmount >= config.petrolCan.refillPrice then
			return fuel.getPetrolCan(nearestPump, true)
		end

		local vehicleInRange = state.lastVehicle and #(GetEntityCoords(state.lastVehicle) - playerCoords) <= 3

		if not vehicleInRange then
			if not config.petrolCan.enabled then return end

			if moneyAmount >= config.petrolCan.price then
				return fuel.getPetrolCan(nearestPump)
			end

			return lib.notify({ type = 'error', description = locale('petrolcan_cannot_afford') })
		elseif moneyAmount >= config.priceTick then
			return fuel.startFueling(state.lastVehicle, true)
		else
			return lib.notify({ type = 'error', description = locale('refuel_cannot_afford') })
		end

		return lib.notify({ type = 'error', description = locale('vehicle_far') })
	elseif petrolCan then
		local vehicle = utils.getVehicleInFront()

		if vehicle and DoesVehicleUseFuel(vehicle) then

			local boneIndex = utils.getVehiclePetrolCapBoneIndex(vehicle)
			local fuelcapPosition = boneIndex and GetWorldPositionOfEntityBone(vehicle, boneIndex)

			if fuelcapPosition and #(playerCoords - fuelcapPosition) < 1.8 then
				return fuel.startFueling(vehicle, false)
			end

			return lib.notify({ type = 'error', description = locale('vehicle_far') })
		end
	end
end)

RegisterKeyMapping('startfueling', 'Fuel vehicle', 'keyboard', 'e')
TriggerEvent('chat:removeSuggestion', '/startfueling')
