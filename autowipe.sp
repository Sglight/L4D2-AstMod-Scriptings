#pragma semicolon 1
#pragma newdecls required

#define AS_DEBUG 0
#define GRACETIME 5.0
#define TEAM_SURVIVOR 2

#include <sourcemod>
#include <sdktools>

// This plugin was created because of a Hard12 bug where one ore more survivors were not taking damage while pinned
// by special infected. If the whole team is immobilised, they get a grace period before they are AutoWiped.
public Plugin myinfo =
{
	name = "AutoWipe",
	author = "Breezy, 海洋空氣",
	description = "Wipes the team if they are simultaneously incapped/pinned for a period of time",
	version = "1.1"
};

bool g_bCanAllowNewAutowipe = false; // start true to prevent autowipe being activated at round start
bool bIsWipping = false;
bool bIsPinned[MaxClients + 1] = { false };

public void OnPluginStart()
{
    HookEvent("tongue_grab", smoker_land);
    HookEvent("tongue_release", smoker_clear);
    HookEvent("jockey_ride", jockey_land);
    HookEvent("jockey_ride_end", jockey_clear);
    HookEvent("pounce_stopped", hunter_clear);
    HookEvent("charger_impact", multi_charge);
    HookEvent("charger_carry_end", charger_land_instant);
    HookEvent("charger_pummel_start", charger_land);
    HookEvent("charger_pummel_end", charger_clear);

	HookEvent("player_left_start_area", EnableAutoWipe, EventHookMode_PostNoCopy);
	// Disabling autowipe
	HookEvent("map_transition", DisableAutoWipe, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", DisableAutoWipe, EventHookMode_PostNoCopy);
	HookEvent("round_end", DisableAutoWipe, EventHookMode_PostNoCopy);
}

public Action DisableAutoWipe(Handle event, const char[] name, bool dontBroadcast)
{
	g_bCanAllowNewAutowipe = false; // prevents autowipe from being called until next map
	bIsWipping = false;
	return Plugin_Handled;
}

public Action EnableAutoWipe(Handle event, const char[] name, bool dontBroadcast)
{
	g_bCanAllowNewAutowipe = true;
	return Plugin_Handled;
}

public void OnGameFrame() {
	// activate AutoWipe if necessary
	if (bIsWipping || IsTeamDead()) return;
	if (g_bCanAllowNewAutowipe && GetConVarInt(FindConVar("survivor_max_incapacitated_count")) != 0) {
		if (IsTeamArePinned()) {
			CreateTimer(1.0, Timer_AutoWipe, _, TIMER_FLAG_NO_MAPCHANGE);
			bIsWipping = true;
		}
		else if (IsTeamImmobilised()) {
			CreateTimer(GRACETIME, Timer_AutoWipe, _, TIMER_FLAG_NO_MAPCHANGE);
			g_bCanAllowNewAutowipe = false;
			bIsWipping = true;
		}
	}
}

public Action Timer_AutoWipe(Handle timer) {
	if (IsTeamImmobilised() && !IsTeamInCapacitated()) {
		WipeSurvivors();
	} else {
		g_bCanAllowNewAutowipe = true;	
	}
	bIsWipping = false;
	return Plugin_Stop; 
}

void WipeSurvivors() { //incap everyone
	for (int client = 1; client <= MaxClients; client++) {
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			SetEntProp(client, Prop_Send, "m_isIncapacitated", true); // 倒地
			SetEntProp(client, Prop_Send, "m_iHealth", 1); // 设置实血为1
			SetEntProp(client, Prop_Send, "m_isIncapacitated", false); // 起身
			int ReviveCount = GetEntProp(client, Prop_Send, "m_currentReviveCount") + 1; // 获取倒地次数
			SetEntProp(client, Prop_Send, "m_currentReviveCount", ReviveCount); // 设置倒地次数+1
			if (ReviveCount == GetConVarInt(FindConVar("survivor_max_incapacitated_count"))) // 如果倒地次数满了
			{
				SetEntProp(client, Prop_Send, "m_isGoingToDie", 1); // 设置濒死状态
				SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 1); // 设置黑白状态
			}
			else if (ReviveCount > GetConVarInt(FindConVar("survivor_max_incapacitated_count")))
			{
				ForcePlayerSuicide(client);
			}
			SetTempHealth(client, GetConVarInt(FindConVar("survivor_revive_health"))); // 设置虚血
		}
		else if (IsInfected(client) && GetEntProp(client, Prop_Send, "m_zombieClass") != 8) { // 清除不是克的特感
			ForcePlayerSuicide(client);
		}
	}
	g_bCanAllowNewAutowipe = true;
	bIsWipping = false;
}

//Used to set temp health, written by TheDanner.
void SetTempHealth(int client, int hp)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	float newOverheal = hp * 1.0; //prevent tag mismatch
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", newOverheal);
}

/***********************************************************************************************************************************************************************************

																				UTILITY

***********************************************************************************************************************************************************************************/

bool IsTeamImmobilised() {
	//Check if there is still an upright survivor
	bool bIsTeamImmobilised = true;
	for (int client = 1; client < MaxClients; client++) {
		// If a survivor is found to be alive and neither pinned nor incapacitated
		// team is not immobilised.
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			if ( !IsPinned(client) && !IsIncapacitated(client) ) {		
				bIsTeamImmobilised = false;				
						#if AS_DEBUG
							decl String:ClientName[32];
							GetClientName(client, ClientName, sizeof(ClientName));
							LogMessage("IsTeamImmobilised() -> %s is mobile, team not immobilised: \x05", ClientName);
						#endif
				break;
			} 
		} 
	}
	return bIsTeamImmobilised;
}

bool IsTeamDead() {
	bool bIsTeamDead = true;
	for (int client = 1; client < MaxClients; client++) {
		// If a survivor is found to be alive and neither pinned nor incapacitated
		// team is not immobilised.
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			bIsTeamDead = false;
			break;
		}
	}
	return bIsTeamDead;
}

bool IsTeamInCapacitated() {
	//Check if there is still an upright survivor
	bool bIsTeamInCapacitated = true;
	for (int client = 1; client < MaxClients; client++) {
		// If a survivor is found to be alive and neither pinned nor incapacitated
		// team is not immobilised.
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			if ( !IsIncapacitated(client) ) {		
				bIsTeamInCapacitated = false;
				break;
			}
		}
	}
	return bIsTeamInCapacitated;
}


bool IsTeamArePinned() {
	//Check if there is still an upright survivor
	bool bIsTeamArePinned = true;
	for (int client = 1; client < MaxClients; client++) {
		// If a survivor is found to be alive and neither pinned nor incapacitated
		// team is not immobilised.
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			if ( !IsPinned(client) ) {		
				bIsTeamArePinned = false;
				break;
			}
		}
	}
	return bIsTeamArePinned;
}

bool IsPinned(int client) {
	bool bIsPinned = false;
	if (IsSurvivor(client)) {
		// check if held by:
		if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) bIsPinned = true; // smoker
		if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) bIsPinned = true; // hunter
		if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) bIsPinned = true; // charger
		if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0) bIsPinned = true; // jockey
	}		
	return bIsPinned;
}

bool IsIncapacitated(int client) {
	bool bIsIncapped = false;
	if ( IsSurvivor(client) ) {
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0) bIsIncapped = true;
		if (!IsPlayerAlive(client)) bIsIncapped = true;
	}
	return bIsIncapped;
}
bool IsSurvivor(int client) {
	return IsValidClient(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

bool IsInfected(int client) {
	return IsValidClient(client) && GetClientTeam(client) == 3;
}

bool IsValidClient(int client) { 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client)) return false; 
    return IsClientInGame(client); 
}  
