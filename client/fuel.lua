local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local fuel = {}

local isFuelDisabled = utils.isFuelDisabled

local SOUND_DISTANCE = 10.0
local SOUND_VOLUME = 0.2

local function playSound(file, coords)
	if coords then
		return TriggerServerEvent('InteractSound_SV:PlayAtCoord', coords, SOUND_DISTANCE, file, SOUND_VOLUME)
	end

	TriggerServerEvent('InteractSound_SV:PlayWithinDistance', SOUND_DISTANCE, file, SOUND_VOLUME)
end

local function stopSound(coords)
	if coords then
		return TriggerServerEvent('InteractSound_SV:StopAtCoord', coords, SOUND_DISTANCE)
	end

	TriggerServerEvent('InteractSound_SV:StopWithinDistance', SOUND_DISTANCE)
end

---@param vehState StateBag
---@param vehicle integer
---@param amount number
---@param replicate? boolean
function fuel.setFuel(vehState, vehicle, amount, replicate)
	if DoesEntityExist(vehicle) and not isFuelDisabled(vehicle) then
		amount = math.clamp(amount, 0, 100)

		SetVehicleFuelLevel(vehicle, amount)
		vehState.fuel = amount

		if replicate and NetworkGetEntityIsNetworked(vehicle) then TriggerServerEvent('ox_fuel:setFuel', amount) end
	end
end

function fuel.getPetrolCan(coords, refuel)
	TaskTurnPedToFaceCoord(cache.ped, coords.x, coords.y, coords.z, config.petrolCan.duration)
	Wait(500)

	if lib.progressCircle({
			duration = config.petrolCan.duration,
			useWhileDead = false,
			canCancel = true,
			disable = {
				move = true,
				car = true,
				combat = true,
			},
			anim = {
				dict = 'timetable@gardener@filling_can',
				clip = 'gar_ig_5_filling_can',
				flags = 49,
			}
		}) then
		if refuel and exports.ox_inventory:GetItemCount('WEAPON_PETROLCAN') then
			return TriggerServerEvent('ox_fuel:fuelCan', true, config.petrolCan.refillPrice)
		end

		TriggerServerEvent('ox_fuel:fuelCan', false, config.petrolCan.price)
	end

	ClearPedTasks(cache.ped)
end

function fuel.startFueling(vehicle, isPump)
	if isFuelDisabled(vehicle) then
		return lib.notify({ type = 'error', description = locale('tank_full') or 'This vehicle does not require fuel' })
	end
	local vehState = Entity(vehicle).state
	local fuelAmount = vehState.fuel or GetVehicleFuelLevel(vehicle)
	local duration = math.ceil((100 - fuelAmount) / config.refillValue) * config.refillTick
	local price, moneyAmount
	local durability = 0

	if 100 - fuelAmount < config.refillValue then
		return lib.notify({ type = 'error', description = locale('tank_full') })
	end

	if isPump then
		price = 0
		moneyAmount = utils.getMoney()

		if config.priceTick > moneyAmount then
			return lib.notify({
				type = 'error',
				description = locale('not_enough_money', config.priceTick)
			})
		end
	elseif not state.petrolCan then
		return lib.notify({ type = 'error', description = locale('petrolcan_not_equipped') })
	elseif state.petrolCan.metadata.ammo <= config.durabilityTick then
		return lib.notify({
			type = 'error',
			description = locale('petrolcan_not_enough_fuel')
		})
	end

	state.isFueling = true

	TaskTurnPedToFaceEntity(cache.ped, vehicle, duration)
	Wait(500)

	local soundCoords = GetEntityCoords(cache.ped)
	playSound('fueling-sound', soundCoords)

	CreateThread(function()
		lib.progressCircle({
			duration = duration,
			useWhileDead = false,
			canCancel = true,
			disable = {
				move = true,
				car = true,
				combat = true,
			},
			anim = {
				dict = isPump and 'timetable@gardener@filling_can' or 'weapon@w_sp_jerrycan',
				clip = isPump and 'gar_ig_5_filling_can' or 'fire',
			},
			-- Only add prop for jerry can, not for pump (player already holds nozzle)
			prop = (not isPump) and nil or nil,
		})

		state.isFueling = false
	end)

	while state.isFueling do
		if isPump then
			price += config.priceTick

			if price + config.priceTick >= moneyAmount and lib.progressActive() then
				lib.cancelProgress()
			end
		elseif state.petrolCan then
			durability += config.durabilityTick

			if durability >= state.petrolCan.metadata.ammo then
				lib.cancelProgress()
				durability = state.petrolCan.metadata.ammo
				break
			end
		else
			break
		end

		fuelAmount += config.refillValue

		if fuelAmount >= 100 then
			state.isFueling = false
			fuelAmount = 100.0
		end

		Wait(config.refillTick)
	end

	ClearPedTasks(cache.ped)

	stopSound(soundCoords)
	playSound('fuelstop', soundCoords)

	if isPump then
		TriggerServerEvent('ox_fuel:pay', price, fuelAmount, NetworkGetNetworkIdFromEntity(vehicle))
	else
		TriggerServerEvent('ox_fuel:updateFuelCan', durability, NetworkGetNetworkIdFromEntity(vehicle), fuelAmount)
	end
end

function fuel.startElectricCharging(vehicle)
	if isFuelDisabled(vehicle) then
		return lib.notify({ type = 'error', description = locale('tank_full') or 'This vehicle does not require charging' })
	end
	local vehState = Entity(vehicle).state
	local fuelAmount = vehState.fuel or GetVehicleFuelLevel(vehicle)
	local duration = math.ceil((100 - fuelAmount) / config.refillValue) * config.refillTick
	local price = 0
	local moneyAmount = utils.getMoney()

	if 100 - fuelAmount < config.refillValue then
		return lib.notify({ type = 'error', description = locale('tank_full') or 'Vehicle is already fully charged' })
	end

	if config.priceTick > moneyAmount then
		return lib.notify({
			type = 'error',
			description = locale('not_enough_money', config.priceTick) or 'Not enough money'
		})
	end

	-- Set vehicle charging state
	vehState:set('isCharging', true, true)
	state.isFueling = true
	state.isElectricCharging = true

	TaskTurnPedToFaceEntity(cache.ped, vehicle, duration)
	Wait(500)

	CreateThread(function()
		lib.progressCircle({
			duration = duration,
			useWhileDead = false,
			canCancel = true,
			disable = {
				move = true,
				car = true,
				combat = true,
			},
			anim = {
				dict = 'timetable@gardener@filling_can',
				clip = 'gar_ig_5_filling_can',
			},
		})

		state.isFueling = false
		state.isElectricCharging = false
		vehState:set('isCharging', false, true)
	end)

	lib.notify({
		type = 'info',
		description = locale('charging_started') or 'Charging started. Please wait until complete or remove the charger.',
	})

	while state.isFueling do
		price += config.priceTick

		if price + config.priceTick >= moneyAmount and lib.progressActive() then
			lib.cancelProgress()
		end

		fuelAmount += config.refillValue

		-- Update the vehicle's fuel state during charging
		fuel.setFuel(vehState, vehicle, fuelAmount, false)

		if fuelAmount >= 100 then
			state.isFueling = false
			state.isElectricCharging = false
			fuelAmount = 100.0
		end

		Wait(config.refillTick)
	end

	ClearPedTasks(cache.ped)
	vehState:set('isCharging', false, true)

	-- Ensure final fuel state is set
	fuel.setFuel(vehState, vehicle, fuelAmount, true)

	TriggerServerEvent('ox_fuel:payElectric', price, fuelAmount, NetworkGetNetworkIdFromEntity(vehicle))
end

function fuel.stopElectricCharging(vehicle)
	if isFuelDisabled(vehicle) then return end
	local vehState = Entity(vehicle).state
	vehState:set('isCharging', false, true)

	if state.isElectricCharging then
		lib.cancelProgress()
		state.isFueling = false
		state.isElectricCharging = false
	end

	lib.notify({
		type = 'info',
		description = locale('charging_stopped') or 'Charging stopped.'
	})
end

return fuel
