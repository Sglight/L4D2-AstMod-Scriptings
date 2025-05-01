#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util_weapons>

Handle hPillsEnabled;
Handle hPillsSurvivor;
Handle hPillsTeam;
Handle hPillsMapKill;
Handle hPillsDelay;

int gavePillsSurvivorCount[MAXPLAYERS];
char clientModel[MAXPLAYERS][64];

public Plugin myinfo =
{
	name = "Pills Giver",
	author = "海洋空氣",
	description = "give more pills to survivors",
	version = "1.1",
	url = "https://steamcommunity.com/id/larkspur2017/"
};

public void OnPluginStart()
{
	hPillsEnabled = CreateConVar("ast_pills_enabled", "0", "发药开关", FCVAR_PROTECTED, true, 0.0, false);
	hPillsSurvivor = CreateConVar("ast_pills_survivor", "1", "个人发药次数，-1 不限制，0 不发药", FCVAR_PROTECTED, true, 0.0, false);
	hPillsTeam = CreateConVar("ast_pills_team", "4", "团队发药次数，-1 不限制，0 不发药", FCVAR_PROTECTED, true, 0.0, false);
	hPillsMapKill = CreateConVar("ast_pills_map_kill", "0", "删除地图刷的药", FCVAR_PROTECTED, true, 0.0, false);
	hPillsDelay = CreateConVar("ast_pills_delay", "5.0", "发药延迟时间", FCVAR_PROTECTED, true, 0.0, false);

	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("weapon_drop", Event_WeaponDrop, EventHookMode_Post);
}

public Action Event_WeaponDrop(Handle event, const char[] name, bool dontBroadcast)
{
	if (GetConVarInt(hPillsEnabled))
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (!isSurvivor(client)) return Plugin_Handled;
		
		char weapon[32];
		GetEventString(event, "item", weapon, sizeof(weapon));
		GetClientModel(client, clientModel[client], sizeof(clientModel));

		if (StrEqual(weapon, "pain_pills", false))
		{
			CreateTimer(0.1, Timer_DoubleCheck, client);
		}
	}
	return Plugin_Handled;
}

public Action Timer_DoubleCheck(Handle timer, int client)
{
	if (!IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client)) return Plugin_Handled;
	float delay = GetConVarFloat(hPillsDelay) - 0.1; // 减去 double check 的延迟
	CreateTimer(delay, Timer_GivePill, client);
	return Plugin_Handled;
}

public Action Timer_GivePill(Handle timer, int client)
{
	// 检测模型
	char model[64];
	GetClientModel(client, model, sizeof(model));
	// 如果模型没变化，则直接进入发药流程，否则需要寻找模型当前使用者
	if (!StrEqual(clientModel[client], model)) { 
		for (int i = 1; i <= MaxClients; i++) {
			if (!isSurvivor(i)) continue;

			char iModel[64];
			GetClientModel(i, iModel, sizeof(iModel));
			if (StrEqual(clientModel[client], iModel)) {
				client = i;
				break;
			}
		}
	}

	int currentSlotItem = GetPlayerWeaponSlot(client, 4);
	if ( ( GetConVarInt(hPillsSurvivor) == -1 || gavePillsSurvivorCount[client] < GetConVarInt(hPillsSurvivor) ) && // 个人发药次数无限 或 个人发药次数未达上限
	( GetConVarInt(hPillsTeam) == -1 || GetGavePillsTeamCount() < GetConVarInt(hPillsTeam) ) && // 团队发药次数无限 或 团队发药次数未达上限
	currentSlotItem == -1 && IsPlayerAlive(client)) {
		int pill = CreateEntityByName("weapon_pain_pills");
		float clientOrigin[3];
		GetClientAbsOrigin(client, clientOrigin);
		clientOrigin[2] += 10.0;
		TeleportEntity(pill, clientOrigin, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(pill);
		EquipPlayerWeapon(client, pill);
		gavePillsSurvivorCount[client]++;

		// Call Event
		Handle hFakeEvent = CreateEvent("weapon_given");
		SetEventInt(hFakeEvent, "userid", GetClientUserId(client));
		SetEventInt(hFakeEvent, "giver", GetClientUserId(client));
		SetEventInt(hFakeEvent, "weapon", view_as<int>(15));
		SetEventInt(hFakeEvent, "weaponentid", pill);
		
		FireEvent(hFakeEvent);
	}
	return Plugin_Handled;
}

public int GetGavePillsTeamCount()
{
	int count = 0;
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client) && GetClientTeam(client) == 2) {
			count += gavePillsSurvivorCount[client];
		}
	}
	return count;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++) {
		gavePillsSurvivorCount[client] = 0;
	}

	if ( GetConVarBool(hPillsMapKill) ) {
		CreateTimer(5.0, Timer_KillMapPills, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Handled;
}

// 来自 weaponrules
Action Timer_KillMapPills(Handle timer)
{
	int entcnt = GetEntityCount();
	for (int ent = 1; ent <= entcnt; ent++) {
		int source = IdentifyWeapon(ent);
		if (source == WEPID_PAIN_PILLS) {
			AcceptEntityInput(ent, "kill");
		}
	}
	return Plugin_Handled;
}

bool isSurvivor(int client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientConnected(client)) return false;
	if (!IsClientInGame(client)) return false;
	return GetClientTeam(client) == 2;
}