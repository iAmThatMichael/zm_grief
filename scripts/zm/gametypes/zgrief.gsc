#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\math_shared;
#using scripts\shared\sound_shared;

#using scripts\zm\gametypes\_zm_gametype;

#using scripts\zm\_zm;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_utility;

// T7ScriptSuite
#using scripts\m_shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "string", "MOD_HOLD_TO_KILL" );
#precache( "string", "MOD_IS_KILLING_YOU" );

function main()
{
	zm_gametype::main();	// Generic zombie mode setup - must be called first.

	// Mode specific over-rides.
	level.onPrecacheGameType = &onPrecacheGameType;
	level.onStartGameType = &onStartGameType;
	level._game_module_custom_spawn_init_func = &zm_gametype::custom_spawn_init_func;
	level._game_module_stat_update_func = &zm_stats::survival_classic_custom_stat_update;

	// on connect
	callback::on_connect( &on_player_connect );
	// on spawned
	callback::on_spawned( &on_player_spawned );
	// friendly-fire damage
	zm::register_player_friendly_fire_callback( &on_friendly_fire_damage );
	// revive override
	zm_perks::register_revive_success_perk_func( &on_revive_success );
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
	self.grief_team = ( Int( self GetEntityNumber() % 2 ) == 0 ? "A" : "B" );
	// register a revive override
	self zm_laststand::register_revive_override( &on_revive_func, undefined, undefined );
}

function on_revive_func( e_revivee )
{
	// modify the hintstring
	if ( self.grief_team != e_revivee.grief_team && self IsTouching( e_revivee.revivetrigger ) )
	{
		e_revivee.grief_death_marked = true;
		if ( IS_TRUE( e_revivee.revivetrigger.beingRevived ) )
		{
			e_revivee.revivetrigger SetHintString( "" );
			e_revivee.revive_hud SetText( &"MOD_IS_KILLING_YOU", e_revivee.name );
		}
		else
			e_revivee.revivetrigger SetHintString( &"MOD_HOLD_TO_KILL", e_revivee.name );
	}
	else
		e_revivee.grief_death_marked = false;

	// use the same code from zm_laststand
	return( self UseButtonPressed() && self zm_laststand::can_revive( e_revivee, true, true ) && self IsTouching( e_revivee.revivetrigger ) );
}

function on_revive_success()
{
	if ( !IS_TRUE( self.grief_death_marked ) )
		return;

	self zm_laststand::bleed_out();
}

function on_player_spawned()
{
	self endon( "death" );
	self endon( "disconnect" );

	self thread m_util::spawn_bot_button();

	// bots do my bidding and FREEZE
	if ( self IsTestClient() )
		self FreezeControlsAllowLook( true );
}

function grief()
{
	level flag::wait_till( "initial_blackscreen_passed" );

	DEFAULT( level.grief_team_dead, false );

	sound::play_on_players( "vox_zmba_grief_intro" );

	level thread grief_round_logic();
}

function grief_round_logic()
{
	level endon( "end_game" );

	do
	{
		grief_in_round_logic();
		grief_end_round_logic();
	} while ( true );
}

function grief_in_round_logic()
{
	level endon( "end_game" );
	level endon( "end_of_round" );

	level waittill( "start_of_round" );

	level thread grief_check_teams();
}

function grief_check_teams()
{
	level endon( "end_game" );
	level endon( "end_of_round" );

	team_a_alive = 0;
	team_b_alive = 0;

	while ( true )
	{
		WAIT_SERVER_FRAME;

		team_a_alive = 0;
		team_b_alive = 0;

		foreach ( player in level.players )
		{
			if ( zm_utility::is_player_valid( player ) )
			{
				if ( player.grief_team == "A" )
					team_a_alive++;
				else
					team_b_alive++;
			}
		}
		// neither team is down
		if ( team_a_alive > 0 && team_b_alive > 0 )
		{
			level.grief_team_dead = false;
			continue;
		}
		// both teams are downed
		else if ( team_a_alive == 0 && team_b_alive == 0 )
		{
			level.grief_team_dead = false;

			zm_utility::zombie_goto_round( level.round_number );
		}
		// a team is downed
		else if ( !IsString( level.grief_team_dead ) )
		{
			level.grief_team_dead = ( team_a_alive == 0 ? "A" : "B" );
			IPrintLnBold( "Team " + level.grief_team_dead + " is downed!" );
		}
	}
}

function grief_end_round_logic()
{
	level endon( "end_game" );
	level endon( "start_of_round" );

	level waittill( "end_of_round" );

	// check teams alive here for end-game OR round restart
	// reset values
	if ( IsString( level.grief_team_dead ) )
	{
		IPrintLnBold( "A team has died, the winner is " + ( level.grief_team_dead != "A" ? "A" : "B" ) + "!" );
		level notify( "end_game" );
	}
	else
	{
		level.grief_team_dead = false;
	}
}

function on_friendly_fire_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime, boneIndex )
{
	if ( !isdefined( eAttacker ) )
		return;
	// don't allow damage from self
	if ( self == eAttacker )
		return;
	// don't allow damage from same grief team
	if ( self.grief_team == eAttacker.grief_team )
		return;
	// make sure it's a player
	if ( IsPlayer( eAttacker ) )
	{
		// for melee usage
		if ( sMeansOfDeath == "MOD_MELEE" )
			self ApplyKnockBack( iDamage, vDir );
		// TODO: other modifiers?
	}
}