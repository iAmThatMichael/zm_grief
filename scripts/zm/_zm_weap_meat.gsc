#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm;
#using scripts\zm\_zm_equipment;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_zonemgr;

#define GRIEF_MEAT_NAME "grief_meat"
#namespace zm_weap_meat;

// use zm_weapons::weapon_give to call the zm_weapons::register_zombie_weapon_callback!
// might opt to use a gameshared object instead
function autoexec init()
{
	// DEBUG - on spawned
	callback::on_spawned( &on_player_spawned );
	// include as an equipment for buy/give checks
	zm_equipment::register_for_level( GRIEF_MEAT_NAME );
	zm_equipment::include( GRIEF_MEAT_NAME );
	// store it
	level.weaponZMGriefMeat = GetWeapon( GRIEF_MEAT_NAME );
	// the global model + trigger
	level.zm_meat = undefined;
}

function on_player_spawned()
{
	self thread player_handle_grief_meat();
}

function player_handle_grief_meat()
{
	self endon( "death" );
	self endon( "disconnect" );
	// maybe switch to be able to pickup
	while ( true )
	{
		self waittill( "grenade_fire", grenade, weapon );

		if ( weapon === level.weaponZMGriefMeat )
			grenade thread wait_for_feedback( self );
	}
}

function wait_for_feedback( e_player )
{
	hit_ground = false;
	hit_player = undefined;

	timeOut = GetTime() + 5000;	// 5 second time out.

	// Min distance to attract positions
	// using cymbal_monkey code again
	SET_IF_DEFINED( attract_dist_diff, level.monkey_attract_dist_diff );
	SET_IF_DEFINED( num_attractors, level.num_monkey_attractors );
	SET_IF_DEFINED( max_attract_dist, level.monkey_attract_dist );

	while ( isdefined ( self ) && (GetTime() < timeOut) )
	{
		// wait until we hit the ground
		if ( self IsOnGround() )
		{
			hit_ground = true;
			break;
		}
		// while alive search through all players
		foreach ( player in level.players )
		{
			// make sure we're not using same player (since frame @ spawn is touching the player)
			if ( player != e_player && self IsTouching( player ) && !laststand::player_is_in_laststand() )
			{
				hit_player = player;
				break;
			}
		}
		//
		WAIT_SERVER_FRAME;
	}
	// determine the type ground (maybe add checks for walls?)
	if ( hit_ground && !isdefined( hit_player ) )
	{
		valid_poi = zm_utility::check_point_in_enabled_zone( self.origin, undefined, undefined );

		if ( IS_TRUE( level.move_valid_poi_to_navmesh ) )
		{
			valid_poi = self move_valid_poi_to_navmesh( valid_poi );
		}

		if ( isdefined( level.check_valid_poi ) )
		{
			valid_poi = self [[ level.check_valid_poi ]]( valid_poi );
		}
		// TODO make a distance check and set the effect on them.
		if ( valid_poi )
		{
			// good spawn, create at the grenade location
			level.zm_meat = create_meat_object( self.origin, self.angles );
		}
		else
		{
			IPrintLn( "RESET MEAT/BAD LOCATION" );
			self meat_stolen_by_sam();
			// respawn after some time ( we already wait 1 second in the func )
			IPrintLn( "RESPAWNED" );
			level.zm_meat = create_meat_object( e_player.origin, e_player.angles );
		}
	}
	else if ( isdefined( hit_player ) && IsPlayer( hit_player ) )
	{
		IPrintLn( "Hit player: " + hit_player.name );

		//hit_player zm_utility::create_zombie_point_of_interest( max_attract_dist, num_attractors, 10000 );
		//hit_player.attract_to_origin = true;
		//hit_player thread zm_utility::create_zombie_point_of_interest_attractor_positions( 4, attract_dist_diff );
		//hit_player thread zm_utility::wait_for_attractor_positions_complete();

		//hit_player give_meat();
	}
	else
	{
		// reset meat
		IPrintLn( "RESET MEAT/TIMED OUT" );
		level.zm_meat = create_meat_object( e_player.origin, e_player.angles );
	}
}

function create_meat_object( origin, angles )
{
	obj = undefined;
	visuals = [];
	// really don't need to spawn the model and such
	ARRAY_ADD( visuals, util::spawn_model( level.weaponZMGriefMeat.worldModel, origin, angles ) );
	ARRAY_ADD( visuals, self );

	trigger = Spawn( "trigger_radius_use", origin + (0,0,32), 0, 32, 32 );
	trigger SetHintString( "Press F to jerk your meat" );
	trigger SetCursorHint( "HINT_NOICON" );
	trigger TriggerIgnoreTeam();
	trigger UseTriggerRequireLookAt();

	obj = gameobjects::create_use_object( "neutral", trigger, visuals, (0,0,0) ); // need to add an istring eventually
	obj gameobjects::set_use_time( 0 );
	obj gameobjects::set_visible_team( "any" );

	obj gameobjects::allow_use( "any" );
	obj gameobjects::set_model_visibility( true );

	obj.onUse = &meat_trigger_think;
	return obj;
}

function meat_trigger_think( player )
{
	player give_meat();
	// handle this at the end
	self gameobjects::destroy_object( true );

}

function give_meat()
{
	// give the weapon
	self zm_weapons::weapon_give( level.weaponZMGriefMeat, false, false, true, true );
	self SwitchToWeapon( level.weaponZMGriefMeat ); // have to manually switch
}
// copied from _zm_weap_cymbal_monkey
function private move_valid_poi_to_navmesh( valid_poi )
{
	if ( !IS_TRUE( valid_poi ) )
	{
		return false;
	}

	if ( IsPointOnNavMesh( self.origin ) )
	{
		return true;
	}

	v_orig = self.origin;
	queryResult = PositionQuery_Source_Navigation(
					self.origin,		// origin
					0,					// min radius
					level.valid_poi_max_radius,				// max radius
					level.valid_poi_half_height,				// half height
					level.valid_poi_inner_spacing,					// inner spacing
					level.valid_poi_radius_from_edges					// radius from edges
				);

	if ( queryResult.data.size )
	{
		foreach ( point in queryResult.data )
		{
			height_offset = abs( self.origin[2] - point.origin[2] );
			if ( height_offset > level.valid_poi_height )
			{
				continue;
			}

			if ( BulletTracePassed( point.origin + ( 0, 0, 20 ), v_orig + ( 0, 0, 20 ), false, self, undefined, false, false ) )
			{
				self.origin = point.origin;
				return true;
			}
		}
	}

	return false;
}
// if the player throws it to an unplayable area samantha steals it
function meat_stolen_by_sam()
{
	self MakeGrenadeDud();

	direction = self.origin;
	direction = (direction[1], direction[0], 0);

	if ( direction[1] < 0 || (direction[0] > 0 && direction[1] > 0) )
	{
		direction = (direction[0], direction[1] * -1, 0);
	}
	else if ( direction[0] < 0 )
	{
		direction = (direction[0] * -1, direction[1], 0);
	}

	// Play laugh sound here, players should connect the laugh with the movement which will tell the story of who is moving it
	players = GetPlayers();
	foreach ( player in level.players )
	{
		if ( IsAlive( player ) )
			player PlayLocalSound( level.zmb_laugh_alias );
	}

	// play the fx on the model
	PlayFXOnTag( level._effect[ "grenade_samantha_steal" ], self, "tag_origin" );

	wait( 1 );

	self Delete();
}
