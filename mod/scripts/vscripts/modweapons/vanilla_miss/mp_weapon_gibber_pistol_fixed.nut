// vanilla missing MpWeaponGibberPistol_Init
global function MpWeaponGibberPistol_Init

void function MpWeaponGibberPistol_Init()
{
#if SERVER
    // vortex refire override
	Vortex_AddImpactDataOverride_WeaponMod( 
		"mp_weapon_semipistol", // weapon name
		"gibber_pistol", // mod name
		GetWeaponInfoFileKeyFieldAsset_Global( "mp_weapon_softball", "vortex_absorb_effect" ), // absorb effect
		GetWeaponInfoFileKeyFieldAsset_Global( "mp_weapon_softball", "vortex_absorb_effect_third_person" ), // absorb effect 3p
		"grenade" // refire behavior
	)
    // grenade pistol
    Vortex_AddImpactDataOverride_WeaponMod( 
		"mp_weapon_semipistol", // weapon name
		"grenade_pistol", // mod name
		GetWeaponInfoFileKeyFieldAsset_Global( "mp_weapon_mgl", "vortex_absorb_effect" ), // absorb effect
		GetWeaponInfoFileKeyFieldAsset_Global( "mp_weapon_mgl", "vortex_absorb_effect_third_person" ), // absorb effect 3p
		"grenade" // refire behavior
	)
#endif
}