fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'

name 'ox_fuel'
author 'Overextended'
version '1.5.2'
repository 'https://github.com/communityox/ox_fuel'
description 'Fuel management system with ox_inventory support'

dependencies {
	'ox_lib',
	'ox_inventory',
	'ox_target',
}

shared_scripts {
	'@ox_lib/init.lua',
	'config.lua'
}

server_scripts {
	'server.lua'
}

client_script 'client/init.lua'

files {
	'locales/*.json',
	'data/stations.lua',
	'data/chargers.lua',
	'client/*.lua',
}

ox_libs {
	'math',
	'locale',
}



data_file 'DLC_ITYP_REQUEST' 'stream/[electric_nozzle]/electric_nozzle_typ.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/[electric_charger]/electric_charger_typ.ytyp'
