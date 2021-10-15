#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

Handle hStartMoney;
Handle hSinglePistolGain;
Handle hDualPistolGain;
Handle hMagnumGain;
Handle hScoutGain;
Handle hAWPGain;
Handle hAutoSniperGain;
Handle hMeleeGain;
Handle hTankGain;
Handle hFFLose;
Handle hOtherGain;

Handle hDoublePills;
Handle hKillAmmoPack;

Handle hZeusX27Enabled;
Handle hZeusX27Weapon;
Handle hZeusX27Range;
Handle hZeusX27Damage;
Handle hZeusX27Frequency;

bool grenade[MAXPLAYERS] = false;
int money[MAXPLAYERS];
bool gavePills[MAXPLAYERS] = false;

int zx27[MAXPLAYERS];
bool isUsingZX27[MAXPLAYERS];

//bool GameStarted = false;

// 　　单手枪 - $300
// 　　双手枪 - $200
// 　　沙鹰 - $200
//　　 鸟狙 - $200
//　　 大狙 - $150
//　　 连狙 - $100
//	 近战 - $250
//	 击杀 Tank - $1400
// 　　黑枪 - $-100
// 　　其他击杀 - $100

public Plugin myinfo =
{
	name = "[L4D2] Shop and Economic System",
	author = "海洋空氣",
	description = "",
	version = "1.2",
	url = "https://steamcommunity.com/id/larkspur2017/"
};

public void OnPluginStart() {
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	//HookEvent("mission_lost", Event_MissionLost);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("weapon_drop", Event_WeaponDrop, EventHookMode_Post);
	HookEvent("weapon_given", Event_WeaponGive, EventHookMode_Post);
	
	RegConsoleCmd("sm_buy", BuyWeapons, "Open shop menu");
	RegConsoleCmd("sm_b", BuyWeapons, "Open shop menu");
	RegAdminCmd("sm_ineedmoney", GiveMoney, ADMFLAG_ROOT, "白给");
	
	hStartMoney = CreateConVar("gp_startmoney", "500", "起始现金.", FCVAR_PROTECTED, true, 0.0, false);
	hSinglePistolGain = CreateConVar("gp_spgain", "300", "单手枪击杀获得的现金.", FCVAR_PROTECTED, true, 0.0, false);
	hDualPistolGain = CreateConVar("gp_dpgain", "200", "双手枪击杀获得的现金.", FCVAR_PROTECTED, true, 0.0, false);
	hMagnumGain = CreateConVar("gp_dggain", "200", "沙鹰击杀获得的现金.", FCVAR_PROTECTED, true, 0.0, false);
	hScoutGain = CreateConVar("gp_scgain", "200", "鸟狙击杀获得的现金.", FCVAR_PROTECTED, true, 0.0, false);
	hAWPGain = CreateConVar("gp_awpgain", "150", "大狙击杀获得的现金.", FCVAR_PROTECTED, true, 0.0, false);
	hAutoSniperGain = CreateConVar("gp_asgain", "100", "连狙击杀获得的现金.", FCVAR_PROTECTED, true, 0.0, false);
	hMeleeGain = CreateConVar("gp_meleegain", "250", "近战击杀获得的现金.", FCVAR_PROTECTED, true, 0.0, false);
	hTankGain = CreateConVar("gp_tankgain", "1400", "击杀 Tank 获得的现金.", FCVAR_PROTECTED, true, 0.0, false);
	hFFLose = CreateConVar("gp_fflose", "100", "攻击队友时扣除的现金.", FCVAR_PROTECTED, true, 0.0, false);
	hOtherGain = CreateConVar("gp_othergain", "100", "其他击杀获得的现金.", FCVAR_PROTECTED, true, 0.0, false);
	
	hDoublePills = CreateConVar("gp_doublepills", "1", "第一个药用了再发一个.", FCVAR_PROTECTED, true, 0.0, false);
	hKillAmmoPack = CreateConVar("gp_killammopack", "1", "删除子弹堆.", FCVAR_PROTECTED, true, 0.0, false);
	
	hZeusX27Enabled = CreateConVar("gp_zx27nabled", "1", "电击枪开关", FCVAR_PROTECTED, true, 0.0, false, 0.0);
	hZeusX27Weapon = CreateConVar("gp_zx27weapon", "weapon_melee, weapon_pistol_magnum, weapon_pistol, weapon_dual_pistols", "附加电击枪的武器，支持多武器，逗号分隔", FCVAR_PROTECTED, true, 0.0, false, 0.0);
	hZeusX27Range = CreateConVar("gp_zx27range", "300", "电击枪的最大距离", FCVAR_PROTECTED, true, 0.0, false, 0.0);
	hZeusX27Damage = CreateConVar("gp_zx27damage", "600", "电击枪的伤害", FCVAR_PROTECTED, true, 0.0, false, 0.0);
	hZeusX27Frequency = CreateConVar("gp_zx27freq", "1", "可使用电击枪次数", FCVAR_PROTECTED, true, 0.0, false, 0.0);
}

public void OnClientPutInServer(int client)
{
	if (client > 0 && IsClientInGame(client) && !IsFakeClient(client)) {
		if (!money[client]) {
			money[client] = GetConVarInt(hStartMoney);
		}
	}
}

public Action GiveMoney(int client, int args)
{
	if (!client) return;
	char givemoneyChar[5];
	GetCmdArg(1, givemoneyChar, sizeof(givemoneyChar));
	money[client] += StringToInt(givemoneyChar);
	Menu_CreateWeaponMenu(client, false);
}

public Action BuyWeapons(int client, int args)
{
	if (!client) return;
	Menu_CreateWeaponMenu(client, false);
}

public Action Event_PlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int newteam = GetEventInt(event, "team");
	if (client > 0 && IsClientInGame(client) && !IsFakeClient(client) && newteam == 2) {
		Menu_CreateWeaponMenu(client, false);
	}
}

public Action Event_WeaponDrop(Handle event, const char[] name, bool dontBroadcast)
{
	if (GetConVarInt(hDoublePills))
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (!gavePills[client])
		{
			char weapon[32];
			GetEventString(event, "item", weapon, sizeof(weapon));
			if (StrEqual(weapon, "pain_pills", false))
			{
				CreateTimer(1.0, Timer_GivePill, client);
				gavePills[client] = true;
			}
		}
	}
}

public Action Event_WeaponGive(Handle event, const char[] name, bool dontBroadcast)
{
	if (GetConVarInt(hDoublePills))
	{
		int client = GetClientOfUserId(GetEventInt(event, "giver"));
		if (!gavePills[client])
		{
			int weapon = GetEventInt(event, "weapon");
			if (weapon == 15)
			{
				CreateTimer(1.0, Timer_GivePill, client);
				gavePills[client] = true;
			}
		}
	}
}

public Action Timer_GivePill(Handle timer, int client)
{
	Do_SpawnItem(client, "pain_pills");
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++) {
		if (bIsSurvior(client)) {
			Menu_CreateWeaponMenu(client, false);
		}
		grenade[client] = false;
		gavePills[client] = false;
	}

	if ( GetConVarBool(hKillAmmoPack) ) {
		CreateTimer(1.0, Timer_KillAmmoPack, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	char victimname[64];
	char weapon[64];
	GetEventString(event, "victimname", victimname, sizeof(victimname));
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	int gain = 0;
	
	if (bIsInfected(victim) && bIsSurvior(attacker)) {
		if (StrEqual(weapon, "pistol", false)) { // 单手枪
			gain = GetConVarInt(hSinglePistolGain);
		} else if (StrEqual(weapon, "dual_pistols", false)) { // 双手枪
			gain = GetConVarInt(hDualPistolGain);
		} else if (StrEqual(weapon, "pistol_magnum", false)) { // 马格南
			gain = GetConVarInt(hMagnumGain);
		} else if (StrEqual(weapon, "sniper_scout", false)) { // 鸟狙
			gain = GetConVarInt(hScoutGain);
		} else if (StrEqual(weapon, "sniper_awp", false)) { // 大狙
			gain = GetConVarInt(hAWPGain);
		} else if (StrEqual(weapon, "hunting_rifle", false)) { // 木狙
			gain = GetConVarInt(hAutoSniperGain);
		} else if (StrEqual(weapon, "sniper_military", false)) { // 军用连狙
			gain = GetConVarInt(hAutoSniperGain);
		} else if (StrEqual(weapon, "melee", false)) { // 近战
			gain = GetConVarInt(hMeleeGain);
		} else gain = GetConVarInt(hOtherGain); // 其他
		
		int zombie = GetZombieClass(victim);
		switch (zombie) {
			case 1: {} 		// Smoker
			case 2: {} 		// Boomer
			case 3: {} 		// Hunter
			case 4: {}		// Spitter
			case 5: {} 		// Jockey
			case 6: {} 		// Charger
			case 7: {} 		// Witch
			case 8: { 		// Tank
				int tankgain = GetConVarInt(hTankGain);
				for (int i = 1; i <= MaxClients; ++i) {
					if (bIsSurvior(i)) {
						money[i] += tankgain;
						PrintCenterText(i, "击杀 Tank 获得 $%d", tankgain);
					}
				}
				return;
			}
		} // end switch
		char str[64];
		Format(str, sizeof(str), "使用 %s 击杀 %s 获得 $%d", weapon, victimname, gain);
		PrintCenterText(attacker, str);
		money[attacker] += gain;
	}
}

public Action Event_PlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int dmghealth = GetEventInt(event, "dmg_health");
	if (bIsSurvior(attacker) && bIsSurvior(victim) && dmghealth > 0) {
		char str[32];
		int close = GetConVarInt(hFFLose);
		int lose = dmghealth * close;
		Format(str, sizeof(str), "击中队友扣除 $%d", lose);
		PrintCenterText(attacker, str);
		money[attacker] -= lose;
	}
}

public Action Menu_CreateWeaponMenu(int client, int args) {
	char title[32];
	Handle menu = CreateMenu(Menu_SpawnWeaponHandler);
	Format(title, sizeof(title), "购买武器  现金: $%d", money[client]);
	SetMenuTitle(menu, "%s\n%s", title, GetOtherClientMoney(client));
	SetMenuExitButton(menu, true);
	AddMenuItem(menu, "dp", "P2000 ($200)");
	AddMenuItem(menu, "pm", "Desert Eagle ($700)");
	AddMenuItem(menu, "sc", "Schmidt Scout ($2750)");
	AddMenuItem(menu, "awp", "AWP  ($4750)");
	AddMenuItem(menu, "scar", "SCAR-20  ($5000)");
	AddMenuItem(menu, "gsg", "G3SG1  ($5000)");
	AddMenuItem(menu, "hg", "HE Grenade  ($300)");
	AddMenuItem(menu, "am", "Ammo ($240)");
	AddMenuItem(menu, "pi", "Pill ($5678)");
	AddMenuItem(menu, "fa", "First Aid Kit ($6789)");
	DisplayMenu(menu, client, 30);
	return Plugin_Handled;
}

public int Menu_SpawnWeaponHandler(Handle menu, MenuAction action, int client, int itempos) {
	if (action == MenuAction_Select) {
		if (GetClientTeam(client) == 2) {
			switch (itempos) {
				case 0: {
					GiveWeapons(client, "pistol", 200);
				} case 1: {
					GiveWeapons(client, "pistol_magnum", 700);
				} case 2: {
					GiveWeapons(client, "sniper_scout", 2750);
				} case 3: {
					GiveWeapons(client, "sniper_awp", 4750);
				} case 4: {
					GiveWeapons(client, "sniper_military", 5000);
				} case 5: {
					GiveWeapons(client, "hunting_rifle", 5000);
				} case 6: {
					if (grenade[client]) {
						PrintHintText(client, "一回合仅能购买一颗雷~");
					} else {
						GiveWeapons(client, "pipe_bomb", 300);
						grenade[client] = true;
					}
				} case 7: {
					GiveWeapons(client, "ammo", 240);
				} case 8: {
					GiveWeapons(client, "pain_pills", 5678);
				} case 9: {
					GiveWeapons(client, "first_aid_kit", 6789);
				}
			}
		} else PrintHintText(client, "只有生还者才能买枪~");
		Menu_CreateWeaponMenu(client, false);
	} else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon)
{
	if (!GetConVarBool(hZeusX27Enabled) || isUsingZX27[client]) {
		return;
	}

	if (bIsSurvior(client) && zx27[client] < GetConVarInt(hZeusX27Frequency) && buttons & IN_ZOOM) {
		char clientWeapon[32];
		char zeusX27Weapon[256];
		GetClientWeapon(client, clientWeapon, sizeof(clientWeapon));
		GetConVarString(hZeusX27Weapon, zeusX27Weapon, sizeof(zeusX27Weapon));

		if (StrContains(zeusX27Weapon, clientWeapon, false)) {
			int target = GetClientAimTarget(client, true);
			if (bIsInfected(target))
			{
				float clientPos[3] = 0.0;
				GetClientEyePosition(client, clientPos);
				float targetPos[3] = 0.0;
				GetClientEyePosition(target, targetPos);
				float distance = GetVectorDistance(clientPos, targetPos, false);
				float zeusX27Range = GetConVarFloat(hZeusX27Range);

				if (distance <= zeusX27Range) { // 目标在射击范围内
					int hp = GetEntProp(target, Prop_Send, "m_iHealth", 4, 0);
					int damage = GetConVarInt(hZeusX27Damage);
					EmitSoundToAll("weapons/defibrillator/defibrillator_use.wav", client, 0, 75, 0, 1.0, 125, -1, clientPos, NULL_VECTOR, true, 0.0);
					ShowParticle(targetPos, NULL_VECTOR, "electrical_arc_01_system", 3.0);
					if (hp - damage <= 0) {
						ForcePlayerSuicide(target);
						SendDeathMessage(client, target, clientWeapon, true);
					} else {
						SetEntityHealth(target, hp - damage);
					}
					zx27[client]++;
					isUsingZX27[client] = true;
					CreateTimer(1.0, Timer_ResetUsingZX27, client, 0);
				}
			}
		}
	}
}

Action Timer_ResetUsingZX27(Handle timer, int client)
{
	isUsingZX27[client] = false;
}

void ShowParticle(float vPos[3], float vAng[3], char[] particlename, float time)
{
	int particle = CreateEntityByName("info_particle_system", -1);
	if (IsValidEdict(particle))
	{
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchSpawn(particle);
		ActivateEntity(particle);
		TeleportEntity(particle, vPos, vAng, NULL_VECTOR);
		AcceptEntityInput(particle, "start", -1, -1, 0);
		CreateTimer(time, DeleteParticles, particle, 2);
	}
}

Action DeleteParticles(Handle timer, int particle)
{
	if (IsValidEntity(particle))
	{
		char sClassname[64];
		GetEdictClassname(particle, sClassname, 64);
		if (StrEqual(sClassname, "info_particle_system", false))
		{
			AcceptEntityInput(particle, "kill", -1, -1, 0);
		}
	}
}

char[] GetOtherClientMoney(int self)
{
	char str[512];
	for (int i = 1; i <= MaxClients; ++i) {
		if (i != self && bIsSurvior(i)) {
			Format(str, sizeof(str), "%s\n%N: $%d", str, i, money[i]);
		}
	}
	return str;
}

void GiveWeapons(int client, char[] weapon, int price)
{
	if (money[client] >= price) {
		Do_SpawnItem(client, weapon);
		money[client] -= price;
	} else {
		PrintHintText(client, "您的现金不够嗷~");
	}
}

Action Timer_KillAmmoPack(Handle timer)
{
	char classname[128];
	int entityCount = GetEntityCount();

	for (int i = 1; i <= entityCount; i++)
	{
		if (!IsValidEntity(i)) { continue; }
		
		// check item type
		GetEdictClassname(i, classname, sizeof(classname));
		if ( StrEqual(classname, "weapon_ammo_spawn") ) {
			AcceptEntityInput(i, "Kill");
		}
	}
}

void SendDeathMessage(int attacker, int victim, const char[] weapon, bool headshot)
{
    Event event = CreateEvent("player_death");
    if (event == null) {
        return;
    }

    event.SetInt("userid", GetClientUserId(victim));
    event.SetInt("attacker", GetClientUserId(attacker));
    event.SetString("weapon", weapon);
    event.SetBool("headshot", headshot);
    event.Fire();
}

void Do_SpawnItem(int client, const char[] type) {
	if (client == 0) {
		ReplyToCommand(client, "Can not use this command from the console."); 
	} else {
		StripAndExecuteClientCommand(client, "give", type);
	}
}

void StripAndExecuteClientCommand(int client, const char[] command, const char[] arguments) {
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
}

bool bIsSurvior(int client) {
	return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2;
}

bool bIsInfected(int client) {
	return client > 0 && client <= MaxClients && GetClientTeam(client) == 3;
}

int GetZombieClass(int client) {
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

/**
 * 这个插件就是 Wingman 模式的主要插件了，看名字也看得出来，原本叫 give_pistol，是没有经济系统，只有手枪的，现在的 cvar 也依然保留着当年的命名。
 * 后来联系上之前“提高玩家玩狙的积极性”的想法，便加上了狙，同时加入了丢枪（记不清写插件的顺序了，先有鸡还是先有蛋的问题），持枪减速等。
 * Amethyst 是我做得最用心的一套插件（虽然一共就两个插件，一个 ht，一个 Amethyst），Wingman 也是我各种奇特想法的实现地。
 * 最早是跟 William 测试插件时，弄了个无限子弹 Magnum，都觉得挺有意思的，于是便单独做了这个模式。想贴个他的视频链接的，但是被他删了，行吧。
 * 原本还有一个电击枪的功能的，电一下1200血，秒单人 tank，一回合一次，带特效。但是 tmd 源码丢失了，后来渐渐发现丢失的源码不止这一个，服了。
 */