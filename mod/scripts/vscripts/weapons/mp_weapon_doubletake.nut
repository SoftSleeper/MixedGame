untyped

global function OnWeaponPrimaryAttack_weapon_doubletake
global function OnProjectileCollision_weapon_doubletake
#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_doubletake
#endif // #if SERVER

struct {
	float[2][3] boltOffsets = [
		[0.0, -0.25],
		[0.0, 0.25],
		[0.0, 0.0],
	]
} file

var function OnWeaponPrimaryAttack_weapon_doubletake( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return FireWeaponPlayerAndNPC( attackParams, true, weapon )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_weapon_doubletake( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return FireWeaponPlayerAndNPC( attackParams, false, weapon )
}
#endif // #if SERVER

function FireWeaponPlayerAndNPC( WeaponPrimaryAttackParams attackParams, bool playerFired, entity weapon )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	entity owner = weapon.GetWeaponOwner()
	bool shouldCreateProjectile = false
	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true
	#if CLIENT
		if ( !playerFired )
			shouldCreateProjectile = false
	#endif

	vector attackAngles = VectorToAngles( attackParams.dir )
	vector baseUpVec = AnglesToUp( attackAngles )
	vector baseRightVec = AnglesToRight( attackAngles )

	bool hasArcNet = weapon.HasMod( "arc_net" )
	entity lastBolt = null
	bool isTripleTake = weapon.HasMod( "tripletake" )
	bool isNessieWeapon = weapon.HasMod( "nessie_balance" )
	asset fxAsset = weapon.GetWeaponSettingAsset( eWeaponVar.projectile_trail_effect_0 )

	float zoomFrac
	if ( playerFired )
		zoomFrac = owner.GetZoomFrac()
	else
		zoomFrac = 0.5

	float boltSpreadMax = expect float( weapon.GetWeaponInfoFileKeyField( "bolt_spread_max" ) )
	float boltSpreadMin = expect float( weapon.GetWeaponInfoFileKeyField( "bolt_spread_min" ) )

	float spreadFrac = Graph( zoomFrac, 0, 1, boltSpreadMax, boltSpreadMin ) * (hasArcNet ? 1.5 : 1.0)

	array<entity> projectiles

	if ( shouldCreateProjectile )
	{
		int numProjectiles = weapon.GetProjectilesPerShot()
		Assert( numProjectiles <= file.boltOffsets.len() )

		for ( int index = 0; index < numProjectiles; index++ )
		{
			vector upVec = baseUpVec * file.boltOffsets[index][0] * spreadFrac
			vector rightVec = baseRightVec * file.boltOffsets[index][1] * spreadFrac

			vector attackDir = attackParams.dir + upVec + rightVec

			int boltSpeed = expect int( weapon.GetWeaponInfoFileKeyField( "bolt_speed" ) )
			int damageFlags = weapon.GetWeaponDamageFlags()
			entity bolt = FireWeaponBolt_RecordData( weapon, attackParams.pos, attackDir, boltSpeed, damageFlags, damageFlags, playerFired, 0 )
			//entity bolt = FireWeaponBolt_RecordData( weapon, attackParams.pos, attackDir, 1.0, damageFlags, damageFlags, playerFired, 0 )
			if ( bolt != null )
			{
				if( index == 0 ) // always create linking with the first projectile
					lastBolt = bolt
				if( isNessieWeapon )
				{
					bolt.kv.gravity = 1.0
					if ( index == 2 )
						thread DelayedStartParticleSystem( bolt, fxAsset )
				}
				else
				{
					if ( index == 2 )
					{
						if( isTripleTake )
							thread DelayedStartParticleSystem( bolt, fxAsset )
						else
						{
							bolt.SetReducedEffects()
							bolt.SetRicochetMaxCount( 0 )
						}
					}
					bolt.kv.gravity = expect float( weapon.GetWeaponInfoFileKeyField( "bolt_gravity_amount" ) )
				}
				
				if( hasArcNet )
				{
					#if SERVER
					if( index != 1 ) // always create linking with the first projectile
						continue
					if ( lastBolt != null )
					{
						//printt( "Linking" )
						thread CreateArcNetBeam( lastBolt, bolt )
					}
					#endif
				}

				projectiles.append( bolt )
			}
		}
	}

	return 2
}

// fix trails
void function DelayedStartParticleSystem( entity bolt, asset trailEffect )
{
    WaitFrame()
    if( IsValid( bolt ) )
        StartParticleEffectOnEntity( bolt, GetParticleSystemIndex( trailEffect ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
}

void function OnProjectileCollision_weapon_doubletake( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	#if SERVER
		int bounceCount = projectile.GetProjectileWeaponSettingInt( eWeaponVar.projectile_ricochet_max_count )
		if ( projectile.proj.projectileBounceCount >= bounceCount )
			return

		if ( hitEnt == svGlobal.worldspawn )
			EmitSoundAtPosition( TEAM_UNASSIGNED, pos, "Bullets.DefaultNearmiss" )

		projectile.proj.projectileBounceCount++
	#endif
}