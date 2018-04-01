#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\math_shared;

#using scripts\zm\gametypes\_zm_gametype;

#using scripts\zm\_zm_stats;

// T7ScriptSuite
#using scripts\m_shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#define VALID_GRIEF_TEAM(__team) (isdefined(level.grief_team[__team])&&level.grief_team[__team].size>0)
function main()
{
	zm_gametype::main();	// Generic zombie mode setup - must be called first.

	// Mode specific over-rides.

	level.onPrecacheGameType =&onPrecacheGameType;
	level.onStartGameType =&onStartGameType;
	level._game_module_custom_spawn_init_func = &zm_gametype::custom_spawn_init_func;
	level._game_module_stat_update_func = &zm_stats::survival_classic_custom_stat_update;

	// clientfield registration
	for ( i = 4; i < 8; i++ )
	{
		// Hardcoded clientfields per-player, each require a bitlen of 3.
		clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_damage", VERSION_SHIP, GetMinBitCountForNum( 7 ), "counter" );
		clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_death_normal", VERSION_SHIP, GetMinBitCountForNum( 3 ), "counter" );
		clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_death_torso", VERSION_SHIP, GetMinBitCountForNum( 3 ), "counter" );
		clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_death_neck", VERSION_SHIP, GetMinBitCountForNum( 3 ), "counter" );
		clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_death_head", VERSION_SHIP, GetMinBitCountForNum( 3 ), "counter" );
		clientfield::register( "clientuimodel", "PlayerList.client" + i + ".score_cf_death_melee", VERSION_SHIP, GetMinBitCountForNum( 3 ), "counter" );
	}

	callback::on_connect( &on_player_connect );
	callback::on_disconnect( &on_player_disconnect );
	callback::on_spawned( &on_player_spawned );
}

function onPrecacheGameType()
{
	level.playerSuicideAllowed = true;
	level.canPlayerSuicide = &zm_gametype::canPlayerSuicide;
}

function onStartGameType()
{
	level.no_end_game_check = true; // disable end-game check (_zm_utility)
	level._game_module_game_end_check = &grief_game_end_check_func; // override damage check (_zm)

	MAKE_ARRAY( level.grief_team );

	level.spawnMins = ( 0, 0, 0 );
	level.spawnMaxs = ( 0, 0, 0 );
	structs = struct::get_array("player_respawn_point", "targetname");
	foreach ( struct in structs )
	{
		level.spawnMins = math::expand_mins( level.spawnMins, struct.origin );
		level.spawnMaxs = math::expand_maxs( level.spawnMaxs, struct.origin );
	}

	level.mapCenter = math::find_box_center( level.spawnMins, level.spawnMaxs );
	SetMapCenter( level.mapCenter );

	level thread grief();
}

function grief_game_end_check_func()
{
	return false;
}


function on_player_connect()
{
	a_index = Array( "A", "B" );

	// always updating
	// not sure if I'll reuse
	//foreach ( index, player in level.players )
	//	player.team_grief = a_index[ Int( index % 2 ) ];

	self.team_grief = a_index[ Int( self GetEntityNumber() % 2 ) ];

	ARRAY_ADD( level.grief_team[ self.team_grief ], self );
}

function on_player_disconnect()
{
	ArrayRemoveValue( level.grief_team[ self.team_grief ], self );
}

function on_player_spawned()
{
	self endon( "death" );
	self endon( "disconnect" );

	self thread m_util::spawn_bot_button();
	self thread m_util::button_pressed( &ActionSlotOneButtonPressed, &debug_stuff );

	IPrintLnBold( "Name: " + self.name + " Team: " + self.team_grief );
	// bots do my bidding and FREEZE
	if ( self IsTestClient() )
		self FreezeControlsAllowLook( true );
}

function grief()
{
	level flag::wait_till( "initial_blackscreen_passed" );

	DEFAULT( level.grief_team_dead, false );
	DEFAULT( level.grief_teams_dead, false );

	level thread grief_round_logic();
}

function debug_stuff()
{
	self IPrintLnBold( "Team: " + self.team_grief );
}

function grief_round_logic()
{
	level endon( "end_game" );

	do
	{
		IPrintLnBold( "----- LOOP START" );
		grief_in_round_logic();
		grief_end_round_logic();
		IPrintLnBold( "----- LOOP END" );
	} while( true );
}

function grief_in_round_logic()
{
	level endon( "end_game" );
	level endon( "end_of_round" );

	level waittill( "start_of_round" );
	IPrintLn( "Start Round" );

	level thread grief_check_teams();
}

function grief_check_teams()
{
	level endon( "end_game" );
	level endon( "end_of_round" );

	a_dead_players = [];

	while ( true )
	{
		WAIT_SERVER_FRAME;

		a_dead_players["A"] = [];
		a_dead_players["B"] = [];

		if ( VALID_GRIEF_TEAM("A") )
		{
			IPrintLn("Team A: " + level.grief_team["A"].size );
			foreach( player in level.grief_team["A"] )
			{
				if ( !IsAlive( player ) )
					ARRAY_ADD( a_dead_players["A"], player );
			}
			if ( a_dead_players["A"].size == level.grief_team["A"].size ) // all players are dead
			{
				// if no team dead set value to true
				if ( !IsString( level.grief_team_dead ) )
				{
					level.grief_team_dead = "A";
					IPrintLnBold( "DEAD " + a_dead_players["A"].size + " TEAM " + level.grief_team["A"].size );
					IPrintLnBold( "All Players in A are Dead! Win The Round Team B" );
				}
				else // a team was dead, but now we're dead
					level.grief_teams_dead = true;
			}
		}

		if ( VALID_GRIEF_TEAM("B") )
		{
			IPrintLn("Team B: " + level.grief_team["B"].size );
			foreach( player in level.grief_team["B"] )
			{
				if ( !IsAlive( player ) )
					ARRAY_ADD( a_dead_players["B"], player );
			}

			if ( a_dead_players["B"].size == level.grief_team["B"].size ) // all players are dead
			{
				// if no team dead set value to true
				if ( !IsString( level.grief_team_dead ) )
				{
					level.grief_team_dead = "B";
					IPrintLnBold( "DEAD " + a_dead_players["B"].size + " TEAM " + level.grief_team["B"].size );
					IPrintLnBold( "All Players in B are Dead! Win The Round Team A" );
				}
				else // a team was dead, but now we're dead
					level.grief_teams_dead = true;
			}
		}
	}
}

function grief_end_round_logic()
{
	level endon( "end_game" );
	level endon( "start_of_round" );

	level waittill( "end_of_round" );
	IPrintLn( "End Round" );

	// check teams alive here for end-game OR round restart
	// reset values
	if ( isdefined( level.grief_team_dead ) && IsString( level.grief_team_dead ) )
	{
		IPrintLnBold( "A team has died, the winner is " + ( level.grief_team_dead === "A" ? "B" : "A" ) + "!" );
	}
	else if ( IS_TRUE( level.grief_teams_dead ) )
	{
		IPrintLnBold( "BOTH TEAMS HAVE DIED -- RESTARTING ROUND" );
	}
	else
	{
		level.grief_team_dead = false;
		level.grief_teams_dead = false;
	}
}