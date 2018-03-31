#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\math_shared;

#insert scripts\shared\shared.gsh;
#using scripts\zm\gametypes\_zm_gametype;

#using scripts\zm\_zm_stats;

function main()
{
	zm_gametype::main();	// Generic zombie mode setup - must be called first.
	
	// Mode specific over-rides.
	
	level.onPrecacheGameType =&onPrecacheGameType;
	level.onStartGameType =&onStartGameType;	
	level._game_module_custom_spawn_init_func = &zm_gametype::custom_spawn_init_func;	
	level._game_module_stat_update_func = &zm_stats::survival_classic_custom_stat_update;

	// _zm.gsc overrides
	level.player_too_many_players_check = false;
	level.func_get_zombie_spawn_delay = &get_zombie_spawn_delay;

	// clientfield registration
	for ( i = 4; i < 8; i++ )
	{
        // Hardcoded clientfields per-player, each require a bitlen of 3.
		clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_damage", VERSION_SHIP, GetMinBitCountForNum( 3 ), "counter" );
        clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_death_normal", VERSION_SHIP, GetMinBitCountForNum( 3 ), "counter" );
        clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_death_torso", VERSION_SHIP, GetMinBitCountForNum( 3 ), "counter" );
        clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_death_neck", VERSION_SHIP, GetMinBitCountForNum( 3 ), "counter" );
        clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_death_head", VERSION_SHIP, GetMinBitCountForNum( 3 ), "counter" );
        clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_death_melee", VERSION_SHIP, GetMinBitCountForNum( 3 ), "counter" );
	}
}

function onPrecacheGameType()
{
	level.playerSuicideAllowed = true;
	level.canPlayerSuicide =&zm_gametype::canPlayerSuicide;
}

function onStartGameType()
{
	level.spawnMins = ( 0, 0, 0 );
	level.spawnMaxs = ( 0, 0, 0 );
	structs = struct::get_array("player_respawn_point", "targetname");
	foreach(struct in structs)
	{
		level.spawnMins = math::expand_mins( level.spawnMins, struct.origin );
		level.spawnMaxs = math::expand_maxs( level.spawnMaxs, struct.origin );
	}

	level.mapCenter = math::find_box_center( level.spawnMins, level.spawnMaxs ); 
	setMapCenter( level.mapCenter );
}



// ******************
// Override Stock
// ******************
// Calculate the correct spawn delay for the round number
function get_zombie_spawn_delay( n_round )
{
	if ( n_round > 60 )	// Don't let this loop too many times
	{
		n_round = 60;
	}
	
	// Decay rate
	n_multiplier = 0.95;
	// Base delay
	switch( level.players.size )
	{
		case 1:
			n_delay = 2.0;		// 0.95 == 0.1 @ round 60
			break;
		case 2:
			n_delay = 1.5;		// 0.95 == 0.1 @ round 54
			break;
		case 3:
			n_delay = 0.89;		// 0.95 == 0.1 @ round 60
			break;
		default: // DUKIP - override case
			n_delay = 0.67;		// 0.95 == 0.1 @ round 60
			break;
	}

	for( i=1; i<n_round; i++ )
	{
		n_delay *= n_multiplier;
		
		if ( n_delay <= 0.1 )
		{
			n_delay = 0.1;
			break;			
		}
	}
	
	return n_delay;
}