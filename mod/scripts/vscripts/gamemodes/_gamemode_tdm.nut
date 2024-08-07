global function GamemodeTdm_Init
global function RateSpawnpoints_Directional

// defined for PP_Gamemode_HarvesterPush.gnut
global function PP_HarvesterPush_init

struct
{
	bool isHarvesterPush = false
} file

void function PP_HarvesterPush_init()
{
    file.isHarvesterPush = true
}

void function GamemodeTdm_Init()
{
	if( file.isHarvesterPush ) 
        PP_GameMode_HarvesterPush_init()
    else
	{
		AddCallback_OnPlayerKilled( GiveScoreForPlayerKill )
		ScoreEvent_SetupEarnMeterValuesForMixedModes()
		SetTimeoutWinnerDecisionFunc( CheckScoreForDraw )

		// tempfix specifics
		SetShouldPlayDefaultMusic( true ) // play music when score or time reaches some point
		EarnMeterMP_SetPassiveGainProgessEnable( true ) // enable earnmeter gain progressing like vanilla
	
		// challenge fix
		SetupGenericTDMChallenge()
	}
}

void function GiveScoreForPlayerKill( entity victim, entity attacker, var damageInfo )
{
	if ( victim != attacker 
		 && victim.IsPlayer() 
		 && IsValid( attacker ) 
		 && attacker.IsPlayer() 
		 && GetGameState() == eGameState.Playing )
	{
		// Team filter -- don't want Friendly Fire able to influence score
		// make it a setting
		if ( victim.GetTeam() != attacker.GetTeam() || FriendlyFire_ShouldAddScoreOnFriendlyKill() )
			AddTeamScore( attacker.GetTeam(), 1 )
		
		if ( GetGameState() == eGameState.WinnerDetermined ) // win match with AddTeamScore()
			ScoreEvent_VictoryKill( attacker )
	}
}

void function RateSpawnpoints_Directional( int checkclass, array<entity> spawnpoints, int team, entity player )
{
	// temp
	RateSpawnpoints_Generic( checkclass, spawnpoints, team, player )
}

int function CheckScoreForDraw()
{
	if ( GameRules_GetTeamScore( TEAM_IMC ) > GameRules_GetTeamScore( TEAM_MILITIA ) )
		return TEAM_IMC
	else if ( GameRules_GetTeamScore( TEAM_MILITIA ) > GameRules_GetTeamScore( TEAM_IMC ) )
		return TEAM_MILITIA

	return TEAM_UNASSIGNED
}
