#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <builtinvotes>
#include <sdkhooks>
#include <left4dhooks>
#include <colors>

#define MENU_DISPLAY_TIME		15

#define TEAM_SPECTATORS         1
#define TEAM_SURVIVORS          2
#define TEAM_INFECTED           3

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_SPITTER              4
#define ZC_JOCKEY               5
#define ZC_CHARGER              6
#define ZC_WITCH                7
#define ZC_TANK                 8

#define M2_WEAPON_SMG           1 << 0     // 1
#define M2_WEAPON_SHOTGUN       1 << 1     // 2
#define M2_WEAPON_SNIPER        1 << 2     // 4

#define WEAPON_SMG              "weapon_smg,weapon_smg_silenced"
#define WEAPON_SG               "weapon_pumpshotgun,weapon_shotgun_chrome"
#define WEAPON_SNIPER           "weapon_sniper_scout,weapon_sniper_awp"

char SI_Names[][] =
{
	"Unknown",
	"Smoker",
	"Boomer",
	"Hunter",
	"Spitter",
	"Jockey",
	"Charger",
	"Witch",
	"Tank",
	"Not SI"
};

int tempTankDmg = -1;
int tempSITimer = -1;
int tempTankBhop = -1;
int tempTankRock = -1;
int tempPlayerInfected = -1;
int tempPlayerTank = -1;
int tempM2HunterFlag = -1;
int tempMorePills = -1;
int tempKillMapPills = -1;
int tempWaveSpawnEnabled = -1;
float tempSITimerNew = -1.0;
int tempSILimitNew = -1;

bool bIsUsingAbility[MAXPLAYERS + 1];
float fDmgPrint = 0.0;
int iKillSI[MAXPLAYERS + 1];
int iKillCI[MAXPLAYERS + 1];

ConVar hRehealth;
ConVar hReammo;
ConVar hReammoSI;
ConVar hReammoCI;
ConVar hReammoSG;
ConVar hReammoSMG;
ConVar hReammoSniper;

ConVar hSITimer;
ConVar hSITimerNew;
ConVar hSILimitNew;
Handle g_hVote;

ConVar hDmgModifyEnable;
ConVar hDmgThreshold;
ConVar hRatioDamage;
ConVar hFastGetup;
ConVar hFastUseAction;
ConVar hWaveSpawnEnabled;

public Plugin myinfo =
{
	name = "Amethyst Challenge",
	author = "海洋空氣",
	description = "Difficulty Controller for Amethyst Mod.",
	version = "2.4",
	url = "https://github.com/Sglight/L4D2-AstMod-Scriptings/"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_tz", challengeRequest, "打开难度控制系统菜单");
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	HookEvent("infected_death", OnInfectedDeath, EventHookMode_Post);
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
	HookEvent("player_team", OnChangeTeam, EventHookMode_Post);
	HookEvent("tongue_grab", OnTongueGrab);
	HookEvent("tongue_release", OnTongueRelease);
	HookEvent("tongue_broke_bent", OnTongueRelease);
	HookEvent("tongue_pull_stopped", OnTonguePullStopped);
	HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);

	// 牛起身无敌修复
	HookEvent("charger_carry_start", Event_ChargerCarryStart, EventHookMode_Post);
	HookEvent("charger_pummel_start", Event_ChargerPummelStart, EventHookMode_Post);

	hRehealth = CreateConVar("ast_rehealth",					"0", "击杀特感回血开关", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hReammo = CreateConVar("ast_reammo",						"0", "击杀回复备弹开关", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hReammoSI = CreateConVar("ast_reammo_SI",					"10", "回复备弹所需的特感击杀数", FCVAR_NOTIFY, true, 1.0);
	hReammoCI = CreateConVar("ast_reammo_CI",					"25", "回复备弹所需的小僵尸击杀数", FCVAR_NOTIFY, true, 1.0);
	hReammoSG = CreateConVar("ast_reammo_count_SG",				"8", "霰弹枪回复备弹数量", FCVAR_NOTIFY, true, 1.0);
	hReammoSMG = CreateConVar("ast_reammo_count_SMG",			"100", "冲锋枪回复备弹数量", FCVAR_NOTIFY, true, 1.0);
	hReammoSniper = CreateConVar("ast_reammo_count_Sniper",		"15", "狙击枪回复备弹数量", FCVAR_NOTIFY, true, 1.0);

	hSITimer = CreateConVar("ast_sitimer",						"1", "特感刷新速率（旧版）", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hWaveSpawnEnabled = CreateConVar("ast_wave_spawn",			"1", "新版特感生成机制开关", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hSITimerNew = CreateConVar("ast_sitimer_new",				"8", "特感刷新时间（新版，直接刷新控制时间）", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	hSILimitNew = CreateConVar("ast_silimit_new",				"3", "特感刷新数量（新版，一波特感数量）", FCVAR_NOTIFY, true, 0.0, true, 32.0);
	
	hDmgModifyEnable = CreateConVar("ast_dmgmodify",			"1", "伤害修改总开关", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hDmgThreshold = CreateConVar("ast_dma_dmg",					"12.0", "被控扣血数值", FCVAR_NOTIFY, true, 1.0, true, 100.0);
	hRatioDamage = CreateConVar("ast_ratio_damage",				"0", "按比例扣血开关", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hFastGetup = CreateConVar("ast_fast_getup",					"1", "快速起身开关", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hFastUseAction = CreateConVar("ast_fast_use_action",		"1", "快速机关读条", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	RegConsoleCmd("sm_laser", laserCommand, "激光瞄准器开关");
	RegConsoleCmd("sm_si", NewSITimerCommand, "新版特感刷新速率调节，无极调节");

	HookConVarChange(hSITimer, ReloadVScript);
	HookConVarChange(hSITimerNew, ReloadVScript);
	HookConVarChange(hSILimitNew, ReloadVScript);
	HookConVarChange(hWaveSpawnEnabled, ReloadVScript);
}

public Action OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i <= MaxClients; i++) {
		iKillSI[i] = 0;
		iKillCI[i] = 0;
	}
	return Plugin_Handled;
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	// 出门输出特感刷新参数
	float fTimerCurrent = GetConVarFloat(hSITimerNew);
	int iLimitCurrent = GetConVarInt(hSILimitNew);
	PrintToChatAll("\x04[AstMod] \x01当前刷新速率：\x03%.1f秒%i特\x01.", fTimerCurrent, iLimitCurrent);
	return Plugin_Continue;
}

public Action challengeRequest(int client, int args)
{
	if (client) {
		drawPanel(client, 0);
	}
	return Plugin_Handled;
}

public Action drawPanel(int client, int first_item)
{
	// 创建面板
	char buffer[64];
	Menu menu = CreateMenu(MenuHandler);
	SetMenuTitle(menu, "难度控制 Difficulty Controller");
	SetMenuExitButton(menu, true);

	// 1  0
	// FormatEx(buffer, sizeof(buffer), "按特感血量扣血%s", GetConVarBool(hRatioDamage) ? " [已启用]" : "");
	// AddMenuItem(menu, "hp", buffer);
	AddToggleMenuItem(menu, "按特感血量扣血", GetConVarBool(hRatioDamage));

	// 2  1
	Format(buffer, sizeof(buffer), "修改 Tank 伤害 [%i]", GetConVarInt(FindConVar("vs_tank_damage")));
	AddMenuItem(menu, "td", buffer);

	// 3  2
	AddMenuItem(menu, "st", "修改特感刷新速率");

	// 4  3
	Format(buffer, sizeof(buffer), "修改特感基础伤害 [%i]", GetConVarInt(hDmgThreshold));
	AddMenuItem(menu, "sd", buffer);

	// 5  4
	AddToggleMenuItem(menu, "击杀特感回血", GetConVarBool(hRehealth));

	// 6  5
	AddToggleMenuItem(menu, "击杀回复备弹", GetConVarBool(hReammo));

	// 7  6
	AddMenuItem(menu, "rs", "恢复默认设置");

	// 翻页
	// 1  7
	AddMenuItem(menu, "", "额外发药设定");

	// 2  8
	AddMenuItem(menu, "wc", "天气控制");

	// 3  9
	AddMenuItem(menu, "", "Tank 设定");

	// 4  10
	AddMenuItem(menu, "", "推 Hunter 设定");

	// 5  11
	AddMenuItem(menu, "", "玩家特感设定");

	// 6  12
	AddMenuItem(menu, "", "激光瞄准器设定");

	// 7  13
	AddMenuItem(menu, "rs", "恢复默认设置");


	DisplayMenuAtItem(menu, client, first_item, MENU_DISPLAY_TIME);

	// 清除已选未投票状态
	if (FindConVar("weapon_allow_m2_hunter") == null) {
		PrintToChat(client, "\x04[AstMod] \x05l4d2_hunter_no_deadstops.smx \x01插件未安装，请联系管理员.");
		return Plugin_Handled;
	}
	ConVar hM2HunterWeapon = FindConVar("weapon_allow_m2_hunter");
	char sM2HunterWeapon[256];
	GetConVarString(hM2HunterWeapon, sM2HunterWeapon, sizeof(sM2HunterWeapon));

	// 0 完全禁止，1 允许机枪，2 允许喷子，4 允许狙击
	tempM2HunterFlag = 0;
	if (StrContains(sM2HunterWeapon, WEAPON_SMG) >= 0) {
		tempM2HunterFlag ^= M2_WEAPON_SMG;
	}
	if ((StrContains(sM2HunterWeapon, WEAPON_SG) >= 0)) {
		tempM2HunterFlag ^= M2_WEAPON_SHOTGUN;
	}
	if ((StrContains(sM2HunterWeapon, WEAPON_SNIPER) >= 0)) {
		tempM2HunterFlag ^= M2_WEAPON_SNIPER;
	}
	return Plugin_Handled;
}

public int MenuHandler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		switch (param) {
			case 0: {
				if ( !IsClientSurvivor(client, true) || GetDifficulty() != 1) {
					drawPanel(client, 0);
					return 1;
				}
				SetConVarBool(hRatioDamage, !GetConVarBool(hRatioDamage));
				drawPanel(client, 0);
			}
			case 1: {
				Menu_TankDmg(client, false);
			}
			case 2: {
				Menu_SITimer(client, false);
			}
			case 3: {
				if (GetDifficulty() == 1)
					Menu_SIDamage(client, false);
				else {
					PrintToChat(client, "\x04[AstMod] \x01当前模式不支持调整特感伤害.");
					drawPanel(client, 0);
				}
			}
			case 4: {
				if ( !IsClientSurvivor(client, true) ) {
					drawPanel(client, 0);
					return 1;
				}

				bool enabled = GetConVarBool(hRehealth);
				SetConVarBool(hRehealth, !enabled);
				PrintToChatAll("\x04[AstMod] \x01有人\x03%s\x01了击杀回血.", enabled ? "关闭" : "打开");

				drawPanel(client, 0);
			} case 5: { // 击杀回备弹
				if ( !IsClientSurvivor(client, true) ) {
					drawPanel(client, 0);
					return 1;
				}

				bool enabled = GetConVarBool(hReammo);
				SetConVarBool(hReammo, !enabled);
				PrintToChatAll("\x04[AstMod] \x01有人\x03%s\x01了击杀回复备弹.", enabled ? "关闭" : "打开");

				drawPanel(client, 0);
			}
			case 6: { // 恢复默认
				if ( IsClientSurvivor(client, true) ) {
					ResetSettings();
				}
				drawPanel(client, 0);
			}
			case 7: { // 自动发药
				Menu_MorePills(client, false);
			}
			case 8: { // 天气
				FakeClientCommand(client, "sm_weather");
			}
			case 9: { // Tank
				Menu_Tank(client, false);
			}
			case 10: { // 推 ht
				Menu_HunterM2(client, false);
			}
			case 11: { // 玩家特感
				Menu_PlayerInfected(client, false);
			}
			case 12: { // 激光瞄准器
				// 开、关
				if ( !IsClientSurvivor(client, true) ) {
					drawPanel(client, 7);
					return 1;
				}
				Menu_Laser(client, false);
			}
			case 13: { // 恢复默认
				if ( IsClientSurvivor(client, true) ) {
					ResetSettings();
				}
				drawPanel(client, 0);
			}
		}
	} else if (action == MenuAction_End) {
		delete menu;
	}
	return 1;
}

int g_tankDamages[] = {24, 36, 48, 100};

public Action Menu_TankDmg(int client, int args)
{
	Handle menu = CreateMenu(Menu_TankDmgHandler);
	SetMenuTitle(menu, "修改 tank 伤害");
	SetMenuExitBackButton(menu, true);

	int currentDmg = GetConVarInt(FindConVar("vs_tank_damage"));

	for (int i = 0; i < sizeof(g_tankDamages); i++)
	{
		char label[16];
		Format(label, sizeof(label), "%s%d", (currentDmg == g_tankDamages[i]) ? "✔" : "", g_tankDamages[i]);
		
		char info[4];
		IntToString(i, info, sizeof(info));  // 用索引作为 info

		AddMenuItem(menu, info, label);
	}

	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_TankDmgHandler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		if (0 <= param < sizeof(g_tankDamages))
		{
			TZ_CallVote(client, 1, g_tankDamages[param]);
		}
		drawPanel(client, 0);
	}
	else if (action == MenuAction_Cancel)
	{
		drawPanel(client, 0);
	}
	return 1;
}


public void TZ_CallVote(int client, int target, int value)
{
	if ( !IsClientSurvivor(client, true) ) return;
	
	if ( IsNewBuiltinVoteAllowed() ) {
		int iNumPlayers;
		int iPlayers[MAXPLAYERS];
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) != TEAM_SURVIVORS)) {
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}

		char sBuffer[64];
		g_hVote = CreateBuiltinVote(VoteHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

		switch (target) {
			case 1: { // Tank 伤害
				Format(sBuffer, sizeof(sBuffer), "修改 Tank 伤害为 [%i]", value);
				tempTankDmg = value;
				SetBuiltinVoteResultCallback(g_hVote, TankDmgVoteResultHandler);
			}
			case 2: { // Tank 连跳
				value ? Format(sBuffer, sizeof(sBuffer), "开启 Tank 连跳") : Format(sBuffer, sizeof(sBuffer), "关闭 Tank 连跳");
				tempTankBhop = value;
				SetBuiltinVoteResultCallback(g_hVote, TankBhopVoteResultHandler);
			}
			case 3: { // Tank 石头
				value ? Format(sBuffer, sizeof(sBuffer), "开启 Tank 丢石头") : Format(sBuffer, sizeof(sBuffer), "关闭 Tank 丢石头");
				tempTankRock = value;
				SetBuiltinVoteResultCallback(g_hVote, TankRockVoteResultHandler);
			}
			case 4: { // 玩家特感
				if (value == 0) {
					Format(sBuffer, sizeof(sBuffer), "禁止玩家加入特感");
				} else {
					Format(sBuffer, sizeof(sBuffer), "允许 %d 名玩家加入特感", value);
				}
				tempPlayerInfected = value;
				SetBuiltinVoteResultCallback(g_hVote, PlayerInfectedVoteResultHandler);
			}
			case 5: { // 玩家 Tank
				value ? Format(sBuffer, sizeof(sBuffer), "允许玩家扮演 Tank") : Format(sBuffer, sizeof(sBuffer), "禁止玩家扮演 Tank");
				tempPlayerTank = value;
				SetBuiltinVoteResultCallback(g_hVote, PlayerTankVoteResultHandler);
			}
			case 6: { // 推 Hunter
				if (tempM2HunterFlag == 0) {
					Format(sBuffer, sizeof(sBuffer), "禁止所有武器推 Hunter");
				} else {
					Format(sBuffer, sizeof(sBuffer), "允许");
					if (tempM2HunterFlag & 1) {
						Format(sBuffer, sizeof(sBuffer), "%s 机枪", sBuffer);
					}
					if (tempM2HunterFlag & 2) {
						Format(sBuffer, sizeof(sBuffer), "%s 喷子", sBuffer);
					}
					if (tempM2HunterFlag & 4) {
						Format(sBuffer, sizeof(sBuffer), "%s 狙击", sBuffer);
					}
					Format(sBuffer, sizeof(sBuffer), "%s 推 Hunter", sBuffer);
				}
				SetBuiltinVoteResultCallback(g_hVote, M2HunterVoteResultHandler);
			}
			case 7: { // 额外发药
				value ? Format(sBuffer, sizeof(sBuffer), "开启额外发药") : Format(sBuffer, sizeof(sBuffer), "关闭额外发药");
				tempMorePills = value;
				SetBuiltinVoteResultCallback(g_hVote, MorePillsVoteResultHandler);
			}
			case 8: { // 删除地图药
				value ? Format(sBuffer, sizeof(sBuffer), "删除地图药（下回合生效）") : Format(sBuffer, sizeof(sBuffer), "保留地图药（下回合生效）");
				tempKillMapPills = value;
				SetBuiltinVoteResultCallback(g_hVote, KillMapPillsVoteResultHandler);
			}
			case 9: { // 新版特感速率
				Format(sBuffer, sizeof(sBuffer), "修改特感刷新速度为 [%.1f秒%i特]", tempSITimerNew, tempSILimitNew);
				SetBuiltinVoteResultCallback(g_hVote, SITimerNewVoteResultHandler);
			}
		}

		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, client);
		DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, MENU_DISPLAY_TIME);
		FakeClientCommand(client, "Vote Yes");
	}
}

public void TankDmgVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				DisplayBuiltinVotePass(vote, "正在更改 Tank 伤害...");
				SetConVarInt(FindConVar("vs_tank_damage"), tempTankDmg);
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}

public void TankBhopVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				DisplayBuiltinVotePass(vote, "正在更改 Tank 连跳...");
				SetConVarInt(FindConVar("ai_tank_bhop"), tempTankBhop);
				return;
			}
		}
	}
	tempTankBhop = GetConVarInt(FindConVar("ai_tank_bhop"));
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}

public void TankRockVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				DisplayBuiltinVotePass(vote, "正在更改 Tank 丢石头...");
				SetConVarInt(FindConVar("ai_tank_rock"), tempTankRock);
				return;
			}
		}
	}
	tempTankRock = GetConVarInt(FindConVar("ai_tank_rock"));
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}

public void PlayerInfectedVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				char sBuffer[64];
				Format(sBuffer, sizeof(sBuffer), "正在更改特感玩家数量为 %d ...", tempPlayerInfected);
				DisplayBuiltinVotePass(vote, sBuffer);
				SetConVarInt(FindConVar("ast_maxinfected"), tempPlayerInfected);
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}

public void PlayerTankVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				char sBuffer[64];
				tempPlayerTank == 0 ? Format(sBuffer, sizeof(sBuffer), "禁止") : Format(sBuffer, sizeof(sBuffer), "允许");
				Format(sBuffer, sizeof(sBuffer), "%s玩家扮演 Tank", sBuffer);
				DisplayBuiltinVotePass(vote, sBuffer);
				SetConVarInt(FindConVar("ast_allowhumantank"), tempPlayerTank);
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}

public void M2HunterVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				DisplayBuiltinVotePass(vote, "正在修改推 Hunter 设定 ...");

				char sBuffer[256];
				sBuffer[0] = '\0'; // 初始化为空字符串

				if (tempM2HunterFlag & M2_WEAPON_SMG) {
					StrCat(sBuffer, sizeof(sBuffer), WEAPON_SMG);
					StrCat(sBuffer, sizeof(sBuffer), ",");
				}
				if (tempM2HunterFlag & M2_WEAPON_SHOTGUN) {
					StrCat(sBuffer, sizeof(sBuffer), WEAPON_SG);
					StrCat(sBuffer, sizeof(sBuffer), ",");
				}
				if (tempM2HunterFlag & M2_WEAPON_SNIPER) {
					StrCat(sBuffer, sizeof(sBuffer), WEAPON_SNIPER);
					StrCat(sBuffer, sizeof(sBuffer), ",");
				}

				// 去掉最后一个逗号（如果存在）
				int len = strlen(sBuffer);
				if (len > 0 && sBuffer[len - 1] == ',') {
					sBuffer[len - 1] = '\0';
				}

				SetConVarString(FindConVar("weapon_allow_m2_hunter"), sBuffer);
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}

public void MorePillsVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				char sBuffer[64];
				tempMorePills == 0 ? Format(sBuffer, sizeof(sBuffer), "关闭") : Format(sBuffer, sizeof(sBuffer), "开启");
				Format(sBuffer, sizeof(sBuffer), "正在 %s 额外发药...", sBuffer);
				DisplayBuiltinVotePass(vote, sBuffer);
				SetConVarInt(FindConVar("ast_pills_enabled"), tempMorePills);
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}

public void KillMapPillsVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				char sBuffer[64];
				tempKillMapPills == 0 ? Format(sBuffer, sizeof(sBuffer), "保留") : Format(sBuffer, sizeof(sBuffer), "删除");
				Format(sBuffer, sizeof(sBuffer), "已设置为 %s 地图药，下回合生效", sBuffer);
				DisplayBuiltinVotePass(vote, sBuffer);
				SetConVarInt(FindConVar("ast_pills_map_kill"), tempKillMapPills);
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}

public void SITimerNewVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				char sBuffer[64];
				Format(sBuffer, sizeof(sBuffer), "修改特感刷新速度为 [%.1f秒%i特]", tempSITimerNew, tempSILimitNew);
				DisplayBuiltinVotePass(vote, sBuffer);
				SetConVarFloat(hSITimerNew, tempSITimerNew);
				SetConVarInt(hSILimitNew, tempSILimitNew);
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}

public void VoteHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action) {
		case BuiltinVoteAction_End: {
			g_hVote = INVALID_HANDLE;
			CloseHandle(vote);
			return;
		}
		case BuiltinVoteAction_Cancel: {
			DisplayBuiltinVoteFail( vote, view_as<BuiltinVoteFailReason>(param1) );
			return;
		}
	}
	return;
}


static const char timerOptions[4][] = {
	"较慢", "默认", "较快", "特感速递！"
};

public Action Menu_SITimer(int client, int args)
{
	Handle menu = CreateMenu(Menu_SITimerHandler);
	bool bWaveSpawnEnabled = GetConVarBool(hWaveSpawnEnabled);
	
	if (bWaveSpawnEnabled) {
		float fTimerCurrent = GetConVarFloat(hSITimerNew);
		int iLimitCurrent = GetConVarInt(hSILimitNew);
		SetMenuTitle(menu, "当前刷新速率：%.1f秒%i特", fTimerCurrent, iLimitCurrent);
	} else {
		SetMenuTitle(menu, "修改特感刷新速度");
	}
	SetMenuExitBackButton(menu, true);

	for (int i = 0; i < sizeof(timerOptions); i++)
	{
		char sBuffer[64];
		int SITimer = GetConVarInt(hSITimer);
		if (i == SITimer && !bWaveSpawnEnabled) {
			Format(sBuffer, sizeof(sBuffer), "✔%s", timerOptions[i]);
		} else {
			strcopy(sBuffer, sizeof(sBuffer), timerOptions[i]);
		}
		AddMenuItem(menu, "", sBuffer);
	}

	AddToggleMenuItem(menu, "新版刷特", bWaveSpawnEnabled);
	AddToggleMenuItem(menu, "旧版刷特", !bWaveSpawnEnabled);

	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_SITimerHandler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		char buffer[64];

		// 处理刷新速度选项（仅在旧版刷特下可选）
		if (param < sizeof(timerOptions)) {
			if (!GetConVarBool(hWaveSpawnEnabled)) {
				tempSITimer = param;
				Format(buffer, sizeof(buffer), "%s", timerOptions[param]);
				TZ_CallVoteStr(client, 1, buffer);
			} else {
				PrintToChat(client, "\x04[AstMod] \x01此选项仅支持旧版刷特机制！请使用 !si 指令.");
			}
		}
		// 处理模式切换（新版 / 旧版 刷特）
		else if (param > sizeof(timerOptions) - 1) {
			tempWaveSpawnEnabled = (param == sizeof(timerOptions)) ? 1 : 0;
			Format(buffer, sizeof(buffer), "%s版刷特", tempWaveSpawnEnabled ? "新" : "旧");
			TZ_CallVoteStr(client, 2, buffer);
		}

		drawPanel(client, 0);
	}
	else if (action == MenuAction_Cancel) {
		drawPanel(client, 0);
	}

	return 1;
}

public void TZ_CallVoteStr(int client, int target, char[] param1)
{
	if (!IsClientSurvivor(client, true)) return;

	if ( IsNewBuiltinVoteAllowed() ) {
		int iNumPlayers;
		int iPlayers[MAXPLAYERS];
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) != TEAM_SURVIVORS))
			{
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}

		char sBuffer[64];
		g_hVote = CreateBuiltinVote(VoteHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		switch (target) {
			case 1: {
				Format(sBuffer, sizeof(sBuffer), "修改特感刷新速度为 [%s]", param1);
				SetBuiltinVoteResultCallback(g_hVote, SITimerVoteResultHandler);
			}
			case 2: {
				Format(sBuffer, sizeof(sBuffer), "修改为 [%s]", param1);
				SetBuiltinVoteResultCallback(g_hVote, WaveSpawnVoteResultHandler);
			}
		}

		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, client);
		DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, MENU_DISPLAY_TIME);
		FakeClientCommand(client, "Vote Yes");
	}
}

public int SITimerVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				DisplayBuiltinVotePass(vote, "正在更改特感刷新速率...");
				SetConVarInt(hSITimer, tempSITimer);
				return 1;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return 0;
}

public int WaveSpawnVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				DisplayBuiltinVotePass(vote, "正在更改刷特机制...");
				SetConVarInt(hWaveSpawnEnabled, tempWaveSpawnEnabled);
				return 1;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return 0;
}

public Action NewSITimerCommand(int client, int args)
{
	if ( !GetConVarBool(hWaveSpawnEnabled) ) {
		ReplyToCommand(client, "\x04[AstMod] \x01此指令仅支持新版刷特机制！");
		return Plugin_Handled;
	}

	if( args != 2 )
	{
		// 获取当前设定值
		float fTimerCurrent = GetConVarFloat(hSITimerNew);
		int iLimitCurrent = GetConVarInt(hSILimitNew);
		ReplyToCommand(client, "\x04[AstMod] \x01当前刷新速率：\x03%.1f秒%i特", fTimerCurrent, iLimitCurrent);
		ReplyToCommand(client, "\x04[AstMod] \x01使用方法: \x3sm_si <刷新时间> <特感数量>\x01，如：\x03!si 7.5 3");
		return Plugin_Handled;
	}

	// 发起投票修改
	char sSITimerNew[8];
	char sSILimitNew[8];
	GetCmdArg(1, sSITimerNew, sizeof(sSITimerNew));
	GetCmdArg(2, sSILimitNew, sizeof(sSILimitNew));
	tempSITimerNew = StringToFloat(sSITimerNew);
	tempSILimitNew = StringToInt(sSILimitNew);
	TZ_CallVote(client, 9, 0);

	return Plugin_Handled;
}

int SIDamageOptions[] = {8, 12, 24};

public Action Menu_SIDamage(int client, int args)
{
	Handle menu = CreateMenu(Menu_SIDamageHandler);
	int dmg = GetConVarInt(hDmgThreshold);
	SetMenuTitle(menu, "修改特感基础伤害");
	SetMenuExitBackButton(menu, true);

	char sBuffer[16];
	for (int i = 0; i < sizeof(SIDamageOptions); i++) {
		bool selected = (SIDamageOptions[i] == dmg);
		Format(sBuffer, sizeof(sBuffer), "%i", SIDamageOptions[i]);
		AddToggleMenuItem(menu, sBuffer, selected);
	}

	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_SIDamageHandler(Handle menu, MenuAction action, int client, int param)
{
	if (!IsClientSurvivor(client, true)) {
		drawPanel(client, 0);
		return 1;
	}

	if (action == MenuAction_Select) {
		if ( param > sizeof(SIDamageOptions) ) return 1;
		SIDamage(float(SIDamageOptions[param]));
		drawPanel(client, 0);
	} else if (action == MenuAction_Cancel) {
		drawPanel(client, 0);
	}
	return 1;
}


public void ResetSettings()
{
	SetConVarBool(hRatioDamage, false);
	SIDamage(12.0);
	SetConVarInt(FindConVar("vs_tank_damage"), 24);
	SetConVarInt(hSITimer, 1);
	SetConVarBool(hWaveSpawnEnabled, true);
	SetConVarBool(hRehealth, false);
	SetConVarBool(hReammo, false);

	if (FindConVar("ast_pills_map_kill") != null) {
		SetConVarBool(FindConVar("ast_pills_enabled"), true);
		SetConVarBool(FindConVar("ast_pills_map_kill"), true);
	}
	if (FindConVar("weapon_allow_m2_hunter") != null) {
		SetConVarString(FindConVar("weapon_allow_m2_hunter"), WEAPON_SMG);
	}
	if (FindConVar("ast_maxinfected") != null) {
		SetConVarInt(FindConVar("ast_maxinfected"), 0);
		SetConVarBool(FindConVar("ast_allowhumantank"), false);
	}

	ConVar hDifficulty = FindConVar("das_fakedifficulty");
	if (hDifficulty != null) {
		int iDifficulty = GetConVarInt(hDifficulty);
		SetConVarInt(hDifficulty, 0);
		SetConVarInt(hDifficulty, iDifficulty);
	}
	ReloadVScript(null, "", "");
}

public Action Menu_MorePills(int client, int args)
{
	if (FindConVar("ast_pills_map_kill") == null) {
		PrintToChat(client, "\x04[AstMod] \x05pills_giver.smx \x01插件未安装，请联系管理员.");
		drawPanel(client, 0);
		return Plugin_Handled;
	}

	// 开关，删除地图药
	Handle menu = CreateMenu(Menu_MorePillsHandler);
	SetMenuTitle(menu, "额外发药设定");
	SetMenuExitBackButton(menu, true);

	AddToggleMenuItem(menu, "自动发药", GetConVarBool(FindConVar("ast_pills_enabled")));
	AddToggleMenuItem(menu, "删除地图药", GetConVarBool(FindConVar("ast_pills_map_kill")));

	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_MorePillsHandler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 0: {
				bool bPillsEnabled = GetConVarBool(FindConVar("ast_pills_enabled"));
				TZ_CallVote(client, 7, !bPillsEnabled);
			}
			case 1: {
				bool bPillsMapKill = GetConVarBool(FindConVar("ast_pills_map_kill"));
				TZ_CallVote(client, 8, !bPillsMapKill);
			}
		}
		drawPanel(client, 7);
	}
	else if (action == MenuAction_Cancel) drawPanel(client, 7);
	return 1;
}

public Action Menu_Tank(int client, int args)
{
	if (FindConVar("ai_tank_bhop") == null) {
		PrintToChat(client, "\x04[AstMod] \x05AI_HardSI.smx \x01插件未安装，请联系管理员.");
		drawPanel(client, 0);
		return Plugin_Handled;
	}
	// 连跳，石头
	Handle menu = CreateMenu(Menu_TankHandler);
	SetMenuTitle(menu, "Tank 设定");
	SetMenuExitBackButton(menu, true);

	AddToggleMenuItem(menu, "连跳", GetConVarBool(FindConVar("ai_tank_bhop")));
	AddToggleMenuItem(menu, "石头", GetConVarBool(FindConVar("ai_tank_rock")));

	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_TankHandler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 0: {
				bool bAITankBhop = GetConVarBool(FindConVar("ai_tank_bhop"));
				TZ_CallVote(client, 2, !bAITankBhop);
			}
			case 1: {
				bool bAITankRock = GetConVarBool(FindConVar("ai_tank_rock"));
				TZ_CallVote(client, 3, !bAITankRock);
			}
		}
		drawPanel(client, 7);
	}
	else if (action == MenuAction_Cancel) drawPanel(client, 7);
	return 1;
}

public Action Menu_HunterM2(int client, int args)
{
	// 完全禁，允许机枪推，允许喷子推，允许狙击推
	Handle menu = CreateMenu(Menu_HunterM2Handler);
	SetMenuTitle(menu, "推 Hunter 设定");
	SetMenuExitBackButton(menu, true);

	AddToggleMenuItem(menu, "允许机枪推", view_as<bool>(tempM2HunterFlag & M2_WEAPON_SMG));
	AddToggleMenuItem(menu, "允许喷子推", view_as<bool>(tempM2HunterFlag & M2_WEAPON_SHOTGUN));
	AddToggleMenuItem(menu, "允许狙击推", view_as<bool>(tempM2HunterFlag & M2_WEAPON_SNIPER));

	AddMenuItem(menu, "", "发起投票");
	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_HunterM2Handler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 0: {
				tempM2HunterFlag ^= M2_WEAPON_SMG;
			}
			case 1: {
				tempM2HunterFlag ^= M2_WEAPON_SHOTGUN;
			}
			case 2: {
				tempM2HunterFlag ^= M2_WEAPON_SNIPER;
			}
			case 3: {
				TZ_CallVote(client, 6, 0);
			}
		}
		Menu_HunterM2(client, false);
	}
	else if (action == MenuAction_Cancel) drawPanel(client, 7);
	return 1;
}

public Action Menu_PlayerInfected(int client, int args)
{
	ConVar hMaxInfected = FindConVar("ast_maxinfected");
	ConVar hAllowHumanTank = FindConVar("ast_allowhumantank");

	if (hMaxInfected == null) {
		PrintToChat(client, "\x04[AstMod] \x05jointeam.smx \x01插件未安装，请联系管理员.");
		drawPanel(client, 0);
		return Plugin_Handled;
	}

	Handle menu = CreateMenu(Menu_PlayerInfectedHandler);
	SetMenuTitle(menu, "玩家特感设定");
	SetMenuExitBackButton(menu, true);

	int iMaxInfected = GetConVarInt(hMaxInfected);

	for (int i = 0; i <= 4; i++) {
		if (i == 0)
			AddToggleMenuItem(menu, "禁止玩家加入特感", !iMaxInfected);
		else {
			char buffer[32];
			Format(buffer, sizeof(buffer), "允许 %d 位特感", i);
			AddToggleMenuItem(menu, buffer, iMaxInfected == i);
		}
	}

	bool bAllowHumanTank = GetConVarBool(hAllowHumanTank);
	AddToggleMenuItem(menu, "禁止玩家扮演 Tank", !bAllowHumanTank);
	AddToggleMenuItem(menu, "允许玩家扮演 Tank", bAllowHumanTank);

	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;

}

public int Menu_PlayerInfectedHandler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		if (param >= 0 && param <= 4) {
			TZ_CallVote(client, 4, param);
		} else if (param == 5 || param == 6) {
			TZ_CallVote(client, 5, param - 5);
		}
		// DisplayMenu(menu, client, MENU_DISPLAY_TIME);
		drawPanel(client, 7);
	}
	else if (action == MenuAction_Cancel) drawPanel(client, 7);
	return 1;
}

public Action laserCommand(int client, int args) {
	if (!IsClientAndInGame(client) || GetClientTeam(client) != TEAM_SURVIVORS) return Plugin_Handled;
	ToggleLaser(client, true);
	return Plugin_Handled;
}

public void ToggleLaser(int client, bool on) {
	if (on){
		BypassAndExecuteCommand(client, "upgrade_add", "LASER_SIGHT");
	} else {
		BypassAndExecuteCommand(client, "upgrade_remove", "LASER_SIGHT");
	}
}

public Action Menu_Laser(int client, int args)
{
	Handle menu = CreateMenu(Menu_LaserHandler);
	SetMenuTitle(menu, "激光瞄准器");
	SetMenuExitBackButton(menu, true);
	AddMenuItem(menu, "", "为当前武器安装激光瞄准器");
	AddMenuItem(menu, "", "为当前武器卸载激光瞄准器");
	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_LaserHandler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 0: {
				ToggleLaser(client, true);
			}
			case 1: {
				ToggleLaser(client, false);
			}
		}
		drawPanel(client, 7);
	}
	else if (action == MenuAction_Cancel) drawPanel(client, 7);
	return 1;
}

///////////////////////////
//           Event           //
//////////////////////////
public bool isGrounded(int client)
{
	return (GetEntProp(client,Prop_Data,"m_fFlags") & FL_ONGROUND) > 0;
}

public Action Timer_ResetTongue(Handle timer, int client)
{
	bIsUsingAbility[client] = false;
	return Plugin_Continue;
}

public Action OnTongueGrab(Handle event, const char[] name, bool dontBroadcast)
{
	int smoker = GetClientOfUserId(GetEventInt(event, "userid"));
	if (isInfected(smoker) && GetZombieClass(smoker) == ZC_SMOKER) {
		bIsUsingAbility[smoker] = true;
	}
	return Plugin_Continue;
}

public Action OnTongueRelease(Handle event, const char[] name, bool dontBroadcast)
{
	int smoker = GetClientOfUserId(GetEventInt(event, "userid"));
	if (isInfected(smoker) && GetZombieClass(smoker) == ZC_SMOKER)
		bIsUsingAbility[smoker] = false;
	return Plugin_Continue;
}

// smoker tongue cutting & self clears
// Called when a smoker tongue is cleared on a dragging player. Includes cuts.
public Action OnTonguePullStopped(Handle event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	int victim	 = GetClientOfUserId(GetEventInt(event, "victim"));
	int smoker	 = GetClientOfUserId(GetEventInt(event, "smoker"));
	int reason	 = GetEventInt(event, "release_type");
	// 1: smoker got shoved
	// 2: survivor got shoved
	// 3: smoker got killed
	// 4: tongue cut

	if (!IsClientSurvivor(attacker, false) || !isInfected(smoker) || attacker != victim)
		return Plugin_Continue;
	
	if ( reason == 4 && GetConVarBool(hDmgModifyEnable) ) {
		ForcePlayerSuicide(smoker);

		char weapon[32];
		GetClientWeapon(attacker, weapon, sizeof(weapon));
		ReplaceString(weapon, sizeof(weapon), "weapon_", "", false);
		SendDeathMessage(attacker, smoker, weapon, true);
	}
	
	bIsUsingAbility[smoker] = false;
	return Plugin_Continue;
}

void SendDeathMessage(int attacker, int victim, const char[] weapon, bool headshot)
{
    Event event = CreateEvent("player_death");
    if (event == null)
    {
        return;
    }

    event.SetInt("userid", GetClientUserId(victim));
    event.SetInt("attacker", GetClientUserId(attacker));
    event.SetString("weapon", weapon);
    event.SetBool("headshot", headshot);
    event.Fire();
}

public Action OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (attacker == 0 || victim == 0 || GetClientTeam(attacker) == TEAM_SPECTATORS) return Plugin_Handled;
	int zombie = GetZombieClass(victim);
	// 击杀回血
	if (GetConVarBool(hRehealth)) {
		bool headshot = GetEventBool(event, "headshot");
		char weapon[64];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		int HP = GetEntProp(attacker, Prop_Data, "m_iHealth");
		int tHP = GetClientHealth(attacker);
		int addHP = 0;
		switch (zombie) {
			case 1: {
				addHP++;
			} 		// Smoker
			case 2: {} 		// Boomer
			case 3: { 		// Hunter
				if (StrEqual(weapon, "pistol_magnum", false) ||
				StrEqual(weapon, "pistol", false) ||
				StrEqual(weapon, "smg",false) ||
				StrEqual(weapon, "smg_silenced", false) ) {
					addHP += 2;
				}
				else if (StrEqual(weapon, "pumpshotgun", false) ||
				StrEqual(weapon, "shotgun_chrome", false) ||
				StrEqual(weapon, "sniper_scout", false) ) {
					addHP++;
				}
				if (!isGrounded(victim)) addHP++;
			}
			case 4: {}		// Spitter
			case 5: { 			// Jockey
				addHP++;
				if (!isGrounded(victim)) addHP++;
			}
			case 6: { 			// Charger
				addHP++;
			}
			case 7: {} 		// Witch
			case 8: {} 		// Tank
		} // switch
		// 额外加血，降低难度
		if (zombie > 0 && headshot) addHP++; // 爆头额外加血
		if (40 < HP < 70)
			addHP += 2;
		else if (HP > 20)
			addHP += 3;
		else if (HP <= 10 && tHP < 40)
			addHP += 7;
		SetEntProp(attacker, Prop_Data, "m_iHealth", HP + addHP);
		//PrintToChat(attacker, "击杀 %i, 获得 addHP 点血量.");

		if (HP + addHP > 100) // 血量上限 100
			SetEntProp(attacker, Prop_Data, "m_iHealth", 100);
	}

	// 击杀回复备弹，打开开关才开始计数
	if (GetConVarBool(hReammo)) {
		int iPrimaryWeaponId = GetPlayerWeaponSlot(attacker, 0);
		if (iPrimaryWeaponId == -1) return Plugin_Handled; // 无主武器
		char sPrimaryWeapon[32];
		GetEdictClassname(iPrimaryWeaponId, sPrimaryWeapon, sizeof(sPrimaryWeapon));

		int ammoOffset = FindSendPropInfo("CCSPlayer", "m_iAmmo");
		if (zombie < ZC_WITCH) {
			iKillSI[attacker]++;
		}
		if (zombie == ZC_WITCH || iKillSI[attacker] % GetConVarInt(hReammoSI) == 0) {
			giveAmmo(attacker, sPrimaryWeapon, ammoOffset);
		}
		if (zombie == ZC_TANK) {
			for (int client = 1; client <= MaxClients; ++client) {
				if (!IsClientInGame(client) || IsFakeClient(client) || (GetClientTeam(client) != TEAM_SURVIVORS))  continue;
				giveAmmo(client, sPrimaryWeapon, ammoOffset);
			}
		}
	}

	// Unhook OnTakeDamage
	if ( isInfected(victim) ) {
		bIsUsingAbility[victim] = false;
		SDKUnhook(victim, SDKHook_OnTakeDamage, OnTakeDamage);
	}
	return Plugin_Continue;
}

public Action OnInfectedDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "infected_id"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (attacker == 0 || victim == 0 || GetClientTeam(attacker) == TEAM_SPECTATORS) return Plugin_Handled;

	if (GetConVarBool(hReammo)) {
		int iPrimaryWeaponId = GetPlayerWeaponSlot(attacker, 0);
		if (iPrimaryWeaponId == -1) return Plugin_Handled; // 无主武器
		char sPrimaryWeapon[32];
		GetEdictClassname(iPrimaryWeaponId, sPrimaryWeapon, sizeof(sPrimaryWeapon));

		int ammoOffset = FindSendPropInfo("CCSPlayer", "m_iAmmo");
		if (iKillCI[attacker] % GetConVarInt(hReammoCI) == 0) {
			giveAmmo(attacker, sPrimaryWeapon, ammoOffset);
		}
	}
	return Plugin_Continue;
}

public void giveAmmo(int client, char[] sPrimaryWeapon, int ammoOffset) {
	int addAmmo = 0;
	int finalOffset = 0;

	if (StrContains(WEAPON_SMG, sPrimaryWeapon) >= 0) {
		finalOffset = ammoOffset+(5*4);
		addAmmo = GetConVarInt(hReammoSMG);
	} else if (StrContains(WEAPON_SG, sPrimaryWeapon) >= 0) {
		finalOffset = ammoOffset+(7*4);
		addAmmo = GetConVarInt(hReammoSG);
	} else if (StrContains(WEAPON_SNIPER, sPrimaryWeapon) >= 0) {
		finalOffset = ammoOffset+(10*4);
		addAmmo = GetConVarInt(hReammoSniper);
	} else return;
	int currentAmmo = GetEntData(client, finalOffset);
	SetEntData(client, finalOffset, currentAmmo + addAmmo);
}

// While a Charger is carrying a Survivor, undo any friendly fire done to them
// since they are effectively pinned and pinned survivors are normally immune to FF
public Action Event_ChargerCarryStart(Handle event, const char[] name, bool dontBroadcast)
{
	int charger = GetClientOfUserId(GetEventInt(event, "userid"));
	bIsUsingAbility[charger] = true;
	return Plugin_Continue;
}

// End immunity about one second after the carry ends
// (there is some time between carryend and pummelbegin,
// but pummelbegin does not always get called if the charger died first, so it is unreliable
public Action Event_ChargerPummelStart(Handle event, const char[] name, bool dontBroadcast)
{
	int charger = GetClientOfUserId(GetEventInt(event, "userid"));
	bIsUsingAbility[charger] = false;
	return Plugin_Continue;
}

// 延迟设置 Tank 连跳和饼状态，覆盖 cfg 设置
public Action OnChangeTeam(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int newteam = GetEventInt(event, "team");
	int oldteam = GetEventInt(event, "oldteam");
	if (client > 0 && IsClientInGame(client) && IsFakeClient(client) 
	&& (newteam == TEAM_SURVIVORS || oldteam == TEAM_SURVIVORS)) {
		ArrayList cvar = new ArrayList();
		cvar.Push(tempTankBhop);
		cvar.Push(tempTankRock);
		
		CreateTimer(1.0, Timer_SetTankConVar, cvar);
	}
	return Plugin_Continue;
}

public Action Timer_SetTankConVar(Handle timer, ArrayList cvar)
{
	if (cvar.Get(0) != -1) {
		SetConVarInt(FindConVar("ai_tank_bhop"), tempTankBhop);
	}
	if (cvar.Get(1) != -1) {
		SetConVarInt(FindConVar("ai_tank_rock"), tempTankRock);
	}
	return Plugin_Continue;
}

public void L4D2_OnStartUseAction_Post(any action, int client, int entity) {
	if (GetConVarInt(hFastUseAction) < 1) return;

	if (action == L4D2UseAction_Button) {
		float durationOriginal;
		float durationNew;
		int difficulty = GetDifficulty();

		durationOriginal = GetEntPropFloat(client, Prop_Send, "m_flProgressBarDuration", 0);

		switch (difficulty)
		{
			case 1: {
				durationNew = 0.1;
			}
			case 2: {
				durationNew = durationOriginal * 0.25;
			}
			case 3: {
				durationNew = durationOriginal * 0.75;
			}
			case 4: {
				durationNew = durationOriginal;
			}
		}
		// PrintToChat(client, "m_flProgressBarDuration: %f -> %f", durationOriginal, durationNew);
		DispatchKeyValueFloat(entity, "use_time", durationNew); // 修改机关
		SetEntPropFloat(client, Prop_Send, "m_flProgressBarDuration", durationNew); // 更改进度条总时长
	}
	return;
}

public void SIDamage(float damage)
{
	SetConVarFloat(hDmgThreshold, damage);
}

stock int GetZombieClass(int client) {
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

stock bool IsClientAndInGame(int index) {
	return (index > 0 && index <= MaxClients && IsClientInGame(index));
}

public bool IsClientSurvivor(int client, bool isMenu) {
	if ( !IsClientAndInGame(client) ) return false;
	if (GetClientTeam(client) != TEAM_SURVIVORS) {
		if (isMenu) {
			PrintToChat(client, "\x04[AstMod] \x01仅限生还者选择!");
		}
		return false;
	}
	return true;
}

public int GetDifficulty() {
	ConVar cDifficulty = FindConVar("das_fakedifficulty");
	if (cDifficulty == null) {
		PrintToServer("\x04[ERROR!] \x05difficulty_adjustment_system.smx \x01插件未安装.");
		LogError("difficulty_adjustment_system.smx 插件未安装");
		return 4;
	}
	return GetConVarInt(cDifficulty);
}

public void BypassAndExecuteCommand(int client, char[] strCommand, char[] strParam1)
{
	int flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}

public void ReloadVScript(ConVar convar, const char[] oldvalue, const char[] newvalue)
{
	ServerCommand("sm_reloadscript");
}

void AddToggleMenuItem(Handle menu, const char[] label, bool enabled)
{
    char sBuffer[32];
    Format(sBuffer, sizeof(sBuffer), "%s%s", enabled ? "✔" : "", label);
    AddMenuItem(menu, "", sBuffer);
}

///////////////////////////////////////////////////
//                Damage Modifier                //
///////////////////////////////////////////////////

// 插件重读的时候也重新 Hook
public void OnMapStart() {
	for (int i = 1; i < MaxClients; i++) {
		if (!IsValidEntity(i)) return;
		SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public void OnClientPutInServer(int client)
{
	if ( client > 0 && client < MaxClients)
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	if (client > 0 && client < MaxClients)
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if ( !GetConVarBool(hDmgModifyEnable) ) return Plugin_Continue;

	if ( !IsClientAndInGame(victim) || !IsClientAndInGame(attacker) ) return Plugin_Continue;

	if (GetClientTeam(victim) == TEAM_INFECTED && GetZombieClass(victim) == ZC_SMOKER && bIsUsingAbility[victim]) { // 秒舌头
		damage = GetConVarFloat(FindConVar("z_gas_health"));
		return Plugin_Changed;
	}
	if ( GetClientTeam(attacker) == TEAM_INFECTED &&
		( GetZombieClass(attacker) == ZC_SMOKER ||
		GetZombieClass(attacker) == ZC_HUNTER ||
		GetZombieClass(attacker) == ZC_JOCKEY ||
		GetZombieClass(attacker) == ZC_CHARGER ) ) { // 舌ht猴牛
		float fdamage = GetConVarFloat(hDmgThreshold);
		if ( GetConVarBool(hRatioDamage) ) { // 按特感比例扣血
			int iHP = GetEntProp(attacker, Prop_Data, "m_iHealth"); // 获取特感血量
			int iHPmax = GetEntProp(attacker, Prop_Data, "m_iMaxHealth"); // 获取特感满血血量
			float fiHP = float(iHP); // 转成浮点型
			float fiHPmax = float(iHPmax);
			float ratio = fiHP / fiHPmax;
			fdamage = GetConVarFloat(hDmgThreshold) * ratio;
			if (fdamage < 1.0) { // 避免无伤害不处死特感
				fdamage = 1.0;
			}
		}
		fDmgPrint = fdamage;
		damage = fdamage;

		if (GetZombieClass(attacker) == ZC_HUNTER && GetEntityMoveType(victim) & MOVETYPE_LADDER) { // 在梯子上被扑
			damage = 0.0;
		}

		if (GetZombieClass(attacker) == ZC_CHARGER && bIsUsingAbility[attacker]) { // 牛撞停不造成伤害，防止过早处死导致pummel end事件不触发，进而导致起身没有无敌。
			damage = 0.0;
		}
		return Plugin_Changed;
	}
	else return Plugin_Continue;
}

public Action OnPlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	if ( !GetConVarBool(hDmgModifyEnable) ) return Plugin_Handled;

	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientAndInGame(attacker) || !IsClientAndInGame(victim)) return Plugin_Handled;

	int damage = GetEventInt(event, "dmg_health");
	int zombie_class = GetZombieClass(attacker);

	if (GetClientTeam(attacker) == TEAM_INFECTED && GetClientTeam(victim) == TEAM_SURVIVORS && zombie_class != ZC_TANK && damage > 0)
	{
		int remaining_health = GetClientHealth(attacker);
		ForcePlayerSuicide(attacker);
		CPrintToChatAll("[{olive}AstMod{default}] {red}%N{default}({green}%s{default}) 还剩下 {olive}%d{default} 血! 造成了 {olive}%2.1f{default} 点伤害!", attacker, SI_Names[zombie_class], remaining_health, fDmgPrint);
		if ( GetConVarBool(hFastGetup) && (GetZombieClass(attacker) == ZC_HUNTER || GetZombieClass(attacker) == ZC_CHARGER) ) {
            _CancelGetup(victim);
        }
	}
	return Plugin_Continue;
}

stock bool isInfected(int client) {
	return IsClientAndInGame(client) && GetClientTeam(client) == TEAM_INFECTED;
}

// Gets players out of pending animations, i.e. sets their current frame in the animation to 1000.
stock void _CancelGetup(int client) {
    CreateTimer(0.4, CancelGetup, client);
}

public Action CancelGetup(Handle timer, int client) {
    SetEntPropFloat(client, Prop_Send, "m_flCycle", 1000.0); // Jumps to frame 1000 in the animation, effectively skipping it.
    return Plugin_Continue;
}