#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\math_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
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

	// clientfield registration
	/*for ( i = 4; i < 8; i++ )
	{
        // Hardcoded clientfields per-player, each require a bitlen of 3.
		clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_damage", VERSION_SHIP, GetMinBitCountForNum( 7 ), "counter" );
        clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_death_normal", VERSION_SHIP, GetMinBitCountForNum( 3 ), "counter" );
        clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_death_torso", VERSION_SHIP, GetMinBitCountForNum( 3 ), "counter" );
        clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_death_neck", VERSION_SHIP, GetMinBitCountForNum( 3 ), "counter" );
        clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_death_head", VERSION_SHIP, GetMinBitCountForNum( 3 ), "counter" );
        clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_death_melee", VERSION_SHIP, GetMinBitCountForNum( 3 ), "counter" );
	}*/

	//callback::on_connect( &on_player_connect );
	//callback::on_disconnect( &on_player_disconnect );
	callback::on_spawned( &on_player_spawned );
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


function on_player_spawned()
{
	self endon( "death" );
	self endon( "disconnect" );
}