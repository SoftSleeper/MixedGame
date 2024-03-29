untyped

global function MpTitanweaponVortexShield_Init

global function OnWeaponActivate_titanweapon_vortex_shield
global function OnWeaponDeactivate_titanweapon_vortex_shield
global function OnWeaponCustomActivityStart_titanweapon_vortex_shield
global function OnWeaponVortexHitBullet_titanweapon_vortex_shield
global function OnWeaponVortexHitProjectile_titanweapon_vortex_shield
global function OnWeaponPrimaryAttack_titanweapon_vortex_shield
global function OnWeaponChargeBegin_titanweapon_vortex_shield
global function OnWeaponChargeEnd_titanweapon_vortex_shield
global function OnWeaponAttemptOffhandSwitch_titanweapon_vortex_shield
global function OnWeaponOwnerChanged_titanweapon_vortex_shield

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_vortex_shield
#endif // #if SERVER

#if CLIENT
global function OnClientAnimEvent_titanweapon_vortex_shield
#endif // #if CLIENT


const ACTIVATION_COST_FRAC = 0.05 //0.2 //R1 was 0.1

function MpTitanweaponVortexShield_Init()
{
	VortexShieldPrecache()

	// to fix bad vortex refiring, this is removed
	//RegisterSignal( "DisableAmpedVortex" )
	//RegisterSignal( "FireAmpedVortexBullet" )
}

function VortexShieldPrecache()
{
	PrecacheParticleSystem( $"wpn_vortex_chargingCP_titan_FP" )
	PrecacheParticleSystem( $"wpn_vortex_chargingCP_titan_FP_replay" )
	PrecacheParticleSystem( $"wpn_vortex_chargingCP_titan" )
	PrecacheParticleSystem( $"wpn_vortex_shield_impact_titan" )
	PrecacheParticleSystem( $"wpn_muzzleflash_vortex_titan_CP_FP" )

	PrecacheParticleSystem( $"wpn_vortex_chargingCP_mod_FP" )
	PrecacheParticleSystem( $"wpn_vortex_chargingCP_mod_FP_replay" )
	PrecacheParticleSystem( $"wpn_vortex_chargingCP_mod" )
	PrecacheParticleSystem( $"wpn_vortex_shield_impact_mod" )
	PrecacheParticleSystem( $"wpn_muzzleflash_vortex_mod_CP_FP" )

	PrecacheParticleSystem( $"P_impact_exp_emp_med_air" )
}

void function OnWeaponOwnerChanged_titanweapon_vortex_shield( entity weapon, WeaponOwnerChangedParams changeParams )
{
	// modded weapon
	if( weapon.HasMod( "archon_shock_shield" ) )
		return OnWeaponOwnerChanged_titanweapon_shock_shield( weapon, changeParams )
	if ( weapon.HasMod( "vortex_blocker" ) )
		return OnWeaponOwnerChanged_titanability_vortex_blocker( weapon, changeParams )

	// vanilla behavior
	if ( !( "initialized" in weapon.s ) )
	{
		weapon.s.fxChargingFPControlPoint <- $"wpn_vortex_chargingCP_titan_FP"
		weapon.s.fxChargingFPControlPointReplay <- $"wpn_vortex_chargingCP_titan_FP_replay"
		weapon.s.fxChargingControlPoint <- $"wpn_vortex_chargingCP_titan"
		weapon.s.fxBulletHit <- $"wpn_vortex_shield_impact_titan"

		weapon.s.fxChargingFPControlPointBurn <- $"wpn_vortex_chargingCP_mod_FP"
		weapon.s.fxChargingFPControlPointReplayBurn <- $"wpn_vortex_chargingCP_mod_FP_replay"
		weapon.s.fxChargingControlPointBurn <- $"wpn_vortex_chargingCP_mod"
		weapon.s.fxBulletHitBurn <- $"wpn_vortex_shield_impact_mod"

		weapon.s.fxElectricalExplosion <- $"P_impact_exp_emp_med_air"

		weapon.s.lastFireTime <- 0
		weapon.s.hadChargeWhenFired <- false


		#if CLIENT
			weapon.s.lastUseTime <- 0
		#endif

		weapon.s.initialized <- true
	}

	// respawn hardcode turns to settings: clear color update func might set by weapon mods
	Vortex_ClearWeaponVortexColorUpdateFunc( weapon )
}

void function OnWeaponActivate_titanweapon_vortex_shield( entity weapon )
{
	// modded weapon
	if( weapon.HasMod( "archon_shock_shield" ) )
		return OnWeaponActivate_titanweapon_shock_shield( weapon )

	// vanilla behavior
	entity weaponOwner = weapon.GetWeaponOwner()

	// just for NPCs (they don't do the deploy event)
	if ( !weaponOwner.IsPlayer() )
	{
		Assert( !( "isVortexing" in weaponOwner.s ), "NPC trying to vortex before cleaning up last vortex" )
		StartVortex( weapon )
	}

	#if SERVER
		// to fix bad vortex refiring, this is removed
		/*
		if ( weapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod ) )
			thread AmpedVortexRefireThink( weapon )
		*/
	#endif
}

void function OnWeaponDeactivate_titanweapon_vortex_shield( entity weapon )
{
	// modded weapon
	if( weapon.HasMod( "archon_shock_shield" ) )
		return OnWeaponDeactivate_titanweapon_shock_shield( weapon )

	// vanilla behavior
	EndVortex( weapon )

	// to fix bad vortex refiring, this is removed
	//if ( weapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod ) )
	//	weapon.Signal( "DisableAmpedVortex" )
}

void function OnWeaponCustomActivityStart_titanweapon_vortex_shield( entity weapon )
{
	// modded weapon
	if( weapon.HasMod( "archon_shock_shield" ) )
		return OnWeaponCustomActivityStart_titanweapon_shock_shield( weapon )

	// vanilla behavior
	EndVortex( weapon )
}

function StartVortex( entity weapon )
{
	entity weaponOwner = weapon.GetWeaponOwner()

#if CLIENT
	if ( weaponOwner != GetLocalViewPlayer() )
		return

	if ( IsFirstTimePredicted() )
		Rumble_Play( "rumble_titan_vortex_start", {} )
#endif

	Assert( IsAlive( weaponOwner ),  "ent trying to start vortexing after death: " + weaponOwner )

	if ( "shotgunPelletsToIgnore" in weapon.s )
		weapon.s.shotgunPelletsToIgnore = 0
	else
		weapon.s.shotgunPelletsToIgnore <- 0

	Vortex_SetBulletCollectionOffset( weapon, Vector( 110, -28, -22.0 ) )

	int sphereRadius = 150
	int bulletFOV = 120

	ApplyActivationCost( weapon, ACTIVATION_COST_FRAC )

	local hasBurnMod = weapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod )
	if ( weapon.GetWeaponChargeFraction() < 1 )
	{
		weapon.s.hadChargeWhenFired = true
		CreateVortexSphere( weapon, false, false, sphereRadius, bulletFOV )
		EnableVortexSphere( weapon )
		weapon.EmitWeaponSound_1p3p( "vortex_shield_loop_1P", "vortex_shield_loop_3P" )
	}
	else
	{
		weapon.s.hadChargeWhenFired = false
		weapon.EmitWeaponSound_1p3p( "vortex_shield_empty_1P", "vortex_shield_empty_3P" )
	}

	#if SERVER
		thread ForceReleaseOnPlayerEject( weapon )
	#endif

	#if CLIENT
		weapon.s.lastUseTime = Time()
	#endif
}

// to fix bad vortex refiring, this is removed
/*
// this needs to rework and should be fully handled by VortexReflectAttack()
function AmpedVortexRefireThink( entity weapon )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	weapon.EndSignal( "DisableAmpedVortex" )
	weapon.EndSignal( "OnDestroy" )
	weaponOwner.EndSignal( "OnDestroy" )

	for ( ;; )
	{
		weapon.WaitSignal( "FireAmpedVortexBullet" )

		if ( IsValid( weaponOwner )	)
		{
			// unpredicted refire...? how's client first person look like
			ShotgunBlast( weapon, weaponOwner.EyePosition(), weaponOwner.GetPlayerOrNPCViewVector(), expect int( weapon.s.ampedBulletCount ), damageTypes.shotgun | DF_VORTEX_REFIRE )
			weapon.s.ampedBulletCount = 0
		}
	}
}
*/

function ForceReleaseOnPlayerEject( entity weapon )
{
	weapon.EndSignal( "VortexFired" )
	weapon.EndSignal( "OnDestroy" )

	entity weaponOwner = weapon.GetWeaponOwner()
	if ( !IsAlive( weaponOwner ) )
		return

	weaponOwner.EndSignal( "OnDeath" )

	weaponOwner.WaitSignal( "TitanEjectionStarted" )

	weapon.ForceRelease()
}

function ApplyActivationCost( entity weapon, float frac )
{
	if ( weapon.HasMod( "vortex_extended_effect_and_no_use_penalty" ) )
		return

	float fracLeft = weapon.GetWeaponChargeFraction()

	if ( fracLeft + frac >= 1 )
	{
		weapon.ForceRelease()
		weapon.SetWeaponChargeFraction( 1.0 )
	}
	else
	{
		weapon.SetWeaponChargeFraction( fracLeft + frac )
	}
}

function EndVortex( entity weapon )
{
	#if CLIENT
		weapon.s.lastUseTime = Time()
	#endif
	weapon.StopWeaponSound( "vortex_shield_loop_1P" )
	weapon.StopWeaponSound( "vortex_shield_loop_3P" )
	DestroyVortexSphereFromVortexWeapon( weapon )
}

bool function OnWeaponVortexHitBullet_titanweapon_vortex_shield( entity weapon, entity vortexSphere, var damageInfo )
{
	// modded weapon
	if( weapon.HasMod( "archon_shock_shield" ) )
		return OnWeaponVortexHitBullet_titanweapon_shock_shield( weapon, vortexSphere, damageInfo )
	if ( weapon.HasMod( "vortex_blocker" ) )
		return OnWeaponVortexHitBullet_titanability_vortex_blocker( weapon, vortexSphere, damageInfo )

	// vanilla behavior
	if ( weapon.HasMod( "shield_only" ) )
		return true

	#if CLIENT
		return true
	#else
		if ( !ValidateVortexImpact( vortexSphere ) )
			return false

		entity attacker				= DamageInfo_GetAttacker( damageInfo )
		vector origin				= DamageInfo_GetDamagePosition( damageInfo )
		int damageSourceID			= DamageInfo_GetDamageSourceIdentifier( damageInfo )
		entity attackerWeapon		= DamageInfo_GetWeapon( damageInfo )
		if ( PROTO_ATTurretsEnabled() && !IsValid( attackerWeapon ) )
			return true
		string attackerWeaponName	= attackerWeapon.GetWeaponClassName()
		int damageType				= DamageInfo_GetCustomDamageType( damageInfo )

		// NOTE: after we add delayed refire for TryVortexAbsorb(), this tempfix should be removed!

		// tempfix ttf2 vanilla behavior: burn mod vortex shield
		// never try to catch a burn mod vortex's refiring bullets if we're using burn mod vortex shield
		// otherwise it may cause infinite refire and crash the server( indicates by SCRIPT ERROR Failed to Create Entity "info_particle_system", the failure is because we've created so much entities due to infinite refire )
		// tried to fully fix amped vortex, this fix is no longer needed
		/*
		if ( weapon.HasMod( "burn_mod_titan_vortex_shield" ) && attackerWeapon.HasMod( "burn_mod_titan_vortex_shield" ) )
		{
			// build impact data
			local impactData = Vortex_CreateImpactEventData( weapon, attacker, origin, damageSourceID, attackerWeaponName, "hitscan" )
			// do vortex drain
			VortexDrainedByImpact( weapon, attackerWeapon, null, null )
			// like heat shield and TryVortexAbsorb() behavior: if it's absorb behavior, we don't do FX
			if ( impactData.refireBehavior == VORTEX_REFIRE_ABSORB )
				return true
			// generic shield ping FX, modified to globalize this function in _vortex.nut
			Vortex_SpawnShieldPingFX( weapon, impactData )
			return true
		}
		*/
		//

		return TryVortexAbsorb( vortexSphere, attacker, origin, damageSourceID, attackerWeapon, attackerWeaponName, "hitscan", null, damageType, weapon.HasMod( "burn_mod_titan_vortex_shield" ) )
	#endif
}

bool function OnWeaponVortexHitProjectile_titanweapon_vortex_shield( entity weapon, entity vortexSphere, entity attacker, entity projectile, vector contactPos )
{
	// modded weapon
	if( weapon.HasMod( "archon_shock_shield" ) )
		return OnWeaponVortexHitProjectile_titanweapon_shock_shield( weapon, vortexSphere, attacker, projectile, contactPos )
	if ( weapon.HasMod( "vortex_blocker" ) )
		return OnWeaponVortexHitProjectile_titanability_vortex_blocker( weapon, vortexSphere, attacker, projectile, contactPos )

	// vanilla behavior
	if ( weapon.HasMod( "shield_only" ) )
		return true

	#if CLIENT
		return true
	#else
		if ( !ValidateVortexImpact( vortexSphere, projectile ) )
			return false

		int damageSourceID = projectile.ProjectileGetDamageSourceID()
		string weaponName = projectile.ProjectileGetWeaponClassName()

		// NOTE: after we add delayed refire for TryVortexAbsorb(), this tempfix should be removed!

		// tempfix ttf2 vanilla behavior: burn mod vortex shield
		// never try to catch a burn mod vortex's refiring bullets if we're using burn mod vortex shield
		// otherwise it may cause infinite refire and crash the server( indicates by SCRIPT ERROR Failed to Create Entity "info_particle_system", the failure is because we've created so much entities due to infinite refire )
		// if a projectile is fired by amped vortex, can get it in projectile.ProjectileGetMods()
		// tried to fully fix amped vortex, this fix is no longer needed
		/*
		if ( weapon.HasMod( "burn_mod_titan_vortex_shield" ) && projectile.ProjectileGetMods().contains( "burn_mod_titan_vortex_shield" ) )
		{
			// build impact data
			local impactData = Vortex_CreateImpactEventData( weapon, attacker, contactPos, damageSourceID, weaponName, "projectile" )
			// do vortex drain
			VortexDrainedByImpact( weapon, projectile, projectile, null )
			// like heat shield and TryVortexAbsorb() behavior: if it's absorb behavior, we don't do FX
			if ( impactData.refireBehavior == VORTEX_REFIRE_ABSORB )
				return true
			// generic shield ping FX, modified to globalize this function in _vortex.nut
			Vortex_SpawnShieldPingFX( weapon, impactData )
			return true
		}
		*/
		//

		return TryVortexAbsorb( vortexSphere, attacker, contactPos, damageSourceID, projectile, weaponName, "projectile", projectile, null, weapon.HasMod( "burn_mod_titan_vortex_shield" ) )
	#endif
}

var function OnWeaponPrimaryAttack_titanweapon_vortex_shield( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapon
	if( weapon.HasMod( "archon_shock_shield" ) )
		return OnWeaponPrimaryAttack_titanweapon_shock_shield( weapon, attackParams )

	// vanilla behavior
	local hasBurnMod = weapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod )
	int bulletsFired
	// modified here: burn mod has been reworked to fire back each impact data after 1 frame
	// still needs to fire back remaining data manually on release
	// but keep return value to be 1, so that we can play it's firing animation
	if ( hasBurnMod )
	{
		VortexPrimaryAttack( weapon, attackParams )
		bulletsFired = 1
	}
	else
		bulletsFired = VortexPrimaryAttack( weapon, attackParams )
	// only play the release/refire endcap sounds if we started with charge remaining
	if ( weapon.s.hadChargeWhenFired )
	{
		string attackSound1p = "vortex_shield_end_1P"
		string attackSound3p = "vortex_shield_end_3P"
		if ( bulletsFired )
		{
			weapon.s.lastFireTime = Time()
			if ( hasBurnMod )
			{
				// removing burnmod specific sounds -- they're not implemented good enough in tf2
				// though.. this can't impact clients those are not installed the script
				// let's play it on server-side
				attackSound1p = "Vortex_Shield_Deflect_Amped"
				attackSound3p = "Vortex_Shield_Deflect_Amped"
			}
			else
			{
				attackSound1p = "vortex_shield_throw_1P"
				attackSound3p = "vortex_shield_throw_3P"
			}
		}

		//printt( "SFX attack sound:", attackSound )
		weapon.EmitWeaponSound_1p3p( attackSound1p, attackSound3p )

		// server-side sound fix
		#if SERVER
			if ( hasBurnMod )
			{
				entity owner = weapon.GetWeaponOwner()
				if ( IsValid( owner ) && owner.IsPlayer() )
				{
					EmitSoundOnEntityOnlyToPlayer( weapon, owner, "vortex_shield_throw_1P" )
					EmitSoundOnEntityExceptToPlayer( weapon, owner, "vortex_shield_throw_3P" )
				}
				else
					EmitSoundOnEntity( weapon, "vortex_shield_throw_3P" )
			}
		#endif
	}

	DestroyVortexSphereFromVortexWeapon( weapon )  // sphere ent holds networked ammo count, destroy it after predicted firing is done

	if ( hasBurnMod )
	{
		// removing burnmod specific sounds -- they're not used in tf2
		//FadeOutSoundOnEntity( weapon, "vortex_shield_start_amped_1P", 0.15 )
		//FadeOutSoundOnEntity( weapon, "vortex_shield_start_amped_3P", 0.15 )
		FadeOutSoundOnEntity( weapon, "vortex_shield_start_1P", 0.15 )
		FadeOutSoundOnEntity( weapon, "vortex_shield_start_3P", 0.15 )
	}
	else
	{
		FadeOutSoundOnEntity( weapon, "vortex_shield_start_1P", 0.15 )
		FadeOutSoundOnEntity( weapon, "vortex_shield_start_3P", 0.15 )
	}

	return bulletsFired
}


#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_vortex_shield( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapon
	if( weapon.HasMod( "archon_shock_shield" ) )
		return OnWeaponNpcPrimaryAttack_titanweapon_shock_shield( weapon, attackParams )
	
	// vanilla behavior
	int bulletsFired = VortexPrimaryAttack( weapon, attackParams )

	DestroyVortexSphereFromVortexWeapon( weapon )  // sphere ent holds networked ammo count, destroy it after predicted firing is done

	return bulletsFired
}
#endif // #if SERVER

#if CLIENT
void function OnClientAnimEvent_titanweapon_vortex_shield( entity weapon, string name )
{
	// modded weapon
	if( weapon.HasMod( "archon_shock_shield" ) )
		return OnClientAnimEvent_titanweapon_shock_shield( weapon, name )

	// vanilla behavior
	if ( name == "muzzle_flash" )
	{
		asset fpEffect
		if ( weapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod ) )
			fpEffect = $"wpn_muzzleflash_vortex_mod_CP_FP"
		else
			fpEffect = $"wpn_muzzleflash_vortex_titan_CP_FP"

		int handle
		if ( GetLocalViewPlayer() == weapon.GetWeaponOwner() )
		{
			handle = weapon.PlayWeaponEffectReturnViewEffectHandle( fpEffect, $"", "vortex_center" )
		}
		else
		{
			handle = StartParticleEffectOnEntity( weapon, GetParticleSystemIndex( fpEffect ), FX_PATTACH_POINT_FOLLOW, weapon.LookupAttachment( "vortex_center" ) )
		}

		Assert( handle )
		// This Assert isn't valid because Effect might have been culled
		// Assert( EffectDoesExist( handle ), "vortex shield OnClientAnimEvent: Couldn't find viewmodel effect handle for vortex muzzle flash effect on client " + GetLocalViewPlayer() )

		vector colorVec = GetVortexSphereCurrentColor( weapon.GetWeaponChargeFraction() )
		EffectSetControlPointVector( handle, 1, colorVec )
	}
}
#endif

bool function OnWeaponChargeBegin_titanweapon_vortex_shield( entity weapon )
{
	// modded weapon
	if( weapon.HasMod( "archon_shock_shield" ) )
		return OnWeaponChargeBegin_titanweapon_shock_shield( weapon )
	if ( weapon.HasMod( "vortex_blocker" ) )
		return OnWeaponChargeBegin_titanability_vortex_blocker( weapon ) // this one won't overwrite default vortex
	
	// vanilla behavior
	entity weaponOwner = weapon.GetWeaponOwner()

	// just for players
	if ( weaponOwner.IsPlayer() )
	{
		PlayerUsedOffhand( weaponOwner, weapon )
		StartVortex( weapon )
	}
	return true
}


void function OnWeaponChargeEnd_titanweapon_vortex_shield( entity weapon )
{
	// modded weapon
	if( weapon.HasMod( "archon_shock_shield" ) )
		return OnWeaponChargeEnd_titanweapon_shock_shield( weapon )
	
	// vanilla behavior
	// if ( weapon.HasMod( "slow_recovery_vortex" ) )
	// {
	// 	weapon.SetWeaponChargeFraction( 1.0 )
	// }
}

bool function OnWeaponAttemptOffhandSwitch_titanweapon_vortex_shield( entity weapon )
{
	// modded weapon
	if( weapon.HasMod( "archon_shock_shield" ) )
		return OnWeaponAttemptOffhandSwitch_titanweapon_shock_shield( weapon )

	// vanilla behavior
	bool allowSwitch
	entity weaponOwner = weapon.GetWeaponOwner()
	entity soul = weaponOwner.GetTitanSoul()
	Assert( IsValid( soul ) )
	entity activeWeapon = weaponOwner.GetActiveWeapon()
	int minEnergyCost = 100
	if ( IsValid( activeWeapon ) && activeWeapon.IsChargeWeapon() && activeWeapon.IsWeaponCharging() )
	{
		allowSwitch = false
	}
	else if ( weapon.GetWeaponClassName() == "mp_titanweapon_vortex_shield_ion" )
	{
		allowSwitch = weaponOwner.CanUseSharedEnergy( minEnergyCost )
	}
	else
	{
		//Assert( weapon.IsChargeWeapon(), weapon.GetWeaponClassName() + " should be a charge weapon." )
		// HACK: this is a temp fix for bug http://bugzilla.respawn.net/show_bug.cgi?id=131021
		// the bug happens when a non-ION titan gets a vortex shield in MP
		// should be fixed in a better way; possibly by giving ION a modded version of vortex?
		if ( GetConVarInt( "bug_reproNum" ) != 131242 && weapon.IsChargeWeapon() )
		{
			if ( weapon.HasMod( "slow_recovery_vortex" ) )
				allowSwitch = weapon.GetWeaponChargeFraction() == 0.0
			else
				allowSwitch = weapon.GetWeaponChargeFraction() < 0.9
		}
		else
		{
			allowSwitch = false
		}
	}


	if( !allowSwitch && IsFirstTimePredicted() )
	{
		// Play SFX and show some HUD feedback here...
		#if CLIENT
			FlashEnergyNeeded_Bar( minEnergyCost )
		#endif
	}
	// Return whether or not we can bring up the vortex
	// Only allow it if we have enough charge to do anything
	return allowSwitch
}

