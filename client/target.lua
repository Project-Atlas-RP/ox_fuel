local config = require 'config'
local state  = require 'client.state'
local utils  = require 'client.utils'
local fuel   = require 'client.fuel'
local nozzle = require 'client.nozzle'

---Check if a fuel pump is destroyed/broken
---@param entity number
---@return boolean
local function isPumpDestroyed(entity)
	if not DoesEntityExist(entity) then return true end
	return IsEntityDead(entity) or GetEntityHealth(entity) <= 0
end

-- Gas pump targets - Take/Return nozzle and petrol can options
local pumpTargets = {
	{
		name = 'take_gas_nozzle',
		distance = 2.5,
		onSelect = function(data)
			nozzle.take(data.entity)
		end,
		icon = "fas fa-gas-pump",
		label = locale('take_nozzle') or 'Take Nozzle',
		canInteract = function(entity, distance, coords)
			if isPumpDestroyed(entity) then return false end
			if state.isFueling or cache.vehicle or lib.progressActive() then
				return false
			end
			return not state.hasGasNozzle
		end
	},
	{
		name = 'return_gas_nozzle',
		distance = 2.5,
		onSelect = function()
			nozzle.return_()
		end,
		icon = "fas fa-gas-pump",
		label = locale('return_nozzle') or 'Return Nozzle',
		canInteract = function(entity, distance, coords)
			if isPumpDestroyed(entity) then return false end
			if state.isFueling or cache.vehicle or lib.progressActive() then
				return false
			end
			return state.hasGasNozzle
		end
	},
}

-- Add petrol can options if enabled
if config.petrolCan.enabled then
	pumpTargets[#pumpTargets + 1] = {
		name = 'buy_petrolcan',
		distance = 2.5,
		onSelect = function(data)
			local petrolCan = GetSelectedPedWeapon(cache.ped) == `WEAPON_PETROLCAN`
			local moneyAmount = utils.getMoney()

			if petrolCan and moneyAmount >= config.petrolCan.refillPrice then
				return fuel.getPetrolCan(data.coords, true)
			elseif not petrolCan and moneyAmount >= config.petrolCan.price then
				return fuel.getPetrolCan(data.coords, false)
			else
				return lib.notify({ type = 'error', description = locale('petrolcan_cannot_afford') })
			end
		end,
		icon = "fas fa-faucet",
		label = locale('petrolcan_buy_or_refill'),
		canInteract = function(entity, distance, coords)
			if isPumpDestroyed(entity) then return false end
			return not state.isFueling and not cache.vehicle and not lib.progressActive()
		end
	}
end

exports.ox_target:addModel(config.pumpModels, pumpTargets)

-- Vehicle bones for targeting the fuel cap area
local fuelBones = {
	'petroltank',
	'petroltank_l',
	'petroltank_r',
	'petrolcap',
	'wheel_rf',
	'wheel_rr',
	'seat_dside_r',
	'boot',
	'engine',
	'chassis_Control',
}

-- Vehicle target - Refuel with nozzle (non-electric vehicles)
local vehicleTargets = {
	{
		name = 'refuel_with_nozzle',
		bones = fuelBones,
		distance = 2.5,
		onSelect = function(data)
			if not state.hasGasNozzle then
				return lib.notify({ type = 'error', description = locale('no_nozzle') or 'You need to take a nozzle from the pump first.' })
			end

			if utils.isElectricVehicle(data.entity) then
				return lib.notify({ type = 'error', description = locale('electric_vehicle_gas') or 'This is an electric vehicle. Use a charger instead.' })
			end

			if utils.getMoney() >= config.priceTick then
				fuel.startFueling(data.entity, true)
			else
				lib.notify({ type = 'error', description = locale('refuel_cannot_afford') })
			end
		end,
		icon = "fas fa-gas-pump",
		label = locale('refuel_vehicle') or 'Refuel Vehicle',
		canInteract = function(entity, distance, coords)
			if state.isFueling or cache.vehicle or lib.progressActive() then
				return false
			end

			-- Must have gas nozzle
			if not state.hasGasNozzle then
				return false
			end

			-- Not for electric vehicles
			if utils.isElectricVehicle(entity) then
				return false
			end

			-- Must be a vehicle that uses fuel
			if not DoesVehicleUseFuel(entity) then
				return false
			end

			return true
		end
	},
}

-- Add petrol can refueling option if enabled
if config.petrolCan.enabled then
	vehicleTargets[#vehicleTargets + 1] = {
		name = 'fuel_with_petrolcan',
		bones = fuelBones,
		distance = 2.5,
		onSelect = function(data)
			if not state.petrolCan then
				return lib.notify({ type = 'error', description = locale('petrolcan_not_equipped') })
			end

			if state.petrolCan.metadata.ammo <= config.durabilityTick then
				return lib.notify({
					type = 'error',
					description = locale('petrolcan_not_enough_fuel')
				})
			end

			fuel.startFueling(data.entity, false)
		end,
		icon = "fas fa-gas-pump",
		label = locale('refuel_with_can') or 'Refuel with Jerry Can',
		canInteract = function(entity, distance, coords)
			if state.isFueling or cache.vehicle or lib.progressActive() then
				return false
			end

			if not DoesVehicleUseFuel(entity) then
				return false
			end

			-- Don't show if player has gas nozzle (use nozzle instead)
			if state.hasGasNozzle then
				return false
			end

			return state.petrolCan and config.petrolCan.enabled
		end
	}
end

exports.ox_target:addGlobalVehicle(vehicleTargets)

