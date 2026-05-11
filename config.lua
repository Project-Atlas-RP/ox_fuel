if not lib.checkDependency('ox_lib', '3.22.0', true) then return end
if not lib.checkDependency('ox_inventory', '2.30.0', true) then return end

return {
	-- Get notified when a new version releases
	versionCheck = true,

	-- Enable support for ox_target
	ox_target = true,

	/*
	* Show or hide gas stations blips
	* 0 - Hide all
	* 1 - Show nearest (5000ms interval check)
	* 2 - Show all
	*/
	showBlips = 0,

	-- Total duration (ex. 10% missing fuel): 10 / 0.25 * 250 = 10 seconds

	-- Fuel refill value (every 250msec add 0.25%)
	refillValue = 0.50,

	-- Fuel tick time (every 250 msec)
	refillTick = 250,

	-- Fuel cost (Added once every tick)
	priceTick = 0.5,

	-- Can durability loss per refillTick
	durabilityTick = 1.3,

	-- Enables fuel can
	petrolCan = {
		enabled = true,
		duration = 5000,
		price = 100,
		refillPrice = 50,
	},

	---Modifies the fuel consumption rate of all vehicles - see [`SET_FUEL_CONSUMPTION_RATE_MULTIPLIER`](https://docs.fivem.net/natives/?_0x845F3E5C).
	globalFuelConsumptionRate = 10.0,

	-- Default fuel levels for newly spawned vehicles
	defaultFuelLevel = 65.0, -- Default fuel level for regular vehicles (0-100)
	defaultElectricLevel = 85.0, -- Default charge level for electric vehicles (0-100)

	-- Electric vehicle consumption tuning
	-- Base consumption multiplier applied to electric vehicles (lower to make them last longer)
	electricConsumptionRate = 4.5, -- relative to gasoline globalFuelConsumptionRate
	-- Additional consumption influence from speed (kph / this value)
	electricSpeedFactor = 420.0,
	-- When charge hits this threshold engine will be forced off
	electricEngineCutoff = 0.5,

	-- Electric vehicles
	electricModels = {
		[`airtug`] = true,
		[`neon`] = true,
		[`raiden`] = true,
		[`caddy`] = true,
		[`caddy2`] = true,
		[`caddy3`] = true,
		[`cyclone`] = true,
		[`dilettante`] = true,
		[`dilettante2`] = true,
		[`surge`] = true,
		[`tezeract`] = true,
		[`imorgon`] = true,
		[`khamelion`] = true,
		[`voltic`] = true,
		[`voltic2`] = true,
		[`iwagen`] = true,
		[`omnisegt`] = true,
		[`rcbandito`] = true,
		[`khamel`] = true,
	},

	-- Vehicles that should never consume or display fuel (e.g. bicycles)
	nofuelModels = {
		[`bmx`] = true,
		[`tribike`] = true,
		[`tribike2`] = true,
		[`tribike3`] = true,
		[`fixter`] = true,
		[`scorcher`] = true,
		[`cruiser`] = true,
	},

	-- Electric charger settings
	electricCharger = {
		model = "electric_charger",
		nozzleModel = "electric_nozzle",
		maxDistance = 5.0, -- Maximum distance from charger before nozzle is returned
	},

	-- Gas pump models
	pumpModels = {
		`prop_gas_pump_old2`,
		`prop_gas_pump_1a`,
		`prop_vintage_pump`,
		`prop_gas_pump_old3`,
		`prop_gas_pump_1c`,
		`prop_gas_pump_1b`,
		`prop_gas_pump_1d`,
	}
}
