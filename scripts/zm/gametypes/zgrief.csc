#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;

#insert scripts\shared\shared.gsh;

function main()
{
	level._zombie_gameModePrecache = &onPrecacheGameType;
	level._zombie_gamemodeMain = &onStartGameType;

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

}

function onStartGameType()
{

}
