#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <builtinvotes>

#define FILE_PATH		"configs/cfgs.txt"

Handle g_hVote = INVALID_HANDLE;
Handle g_hVoteKick = INVALID_HANDLE;
Handle g_hCfgsKV = INVALID_HANDLE;
char g_sCfg[64];
char g_sType[64];
char kickplayername[MAX_NAME_LENGTH];

public Plugin myinfo = 
{
	name = "投票读取cfg文件",
	author = "HazukiYuro, 海洋空氣",
	description = "!vote投票",
	version = "1.2",
	url = ""
}

public void OnPluginStart()
{
	char sBuffer[128];
	GetGameFolderName(sBuffer, sizeof(sBuffer));
	if (!StrEqual(sBuffer, "left4dead2", false))
	{
		SetFailState("该插件只支持 求生之路2!");
	}
	g_hCfgsKV = CreateKeyValues("Cfgs");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), FILE_PATH);
	if (!FileToKeyValues(g_hCfgsKV, sBuffer))
	{
		SetFailState("无法加载cfgs.txt文件!");
	}

	RegConsoleCmd("sm_vote", CommondVote);
	RegConsoleCmd("sm_votekick", Command_Voteskick);
}

stock void CheatCommand(int client, const char[] command, const char[] arguments)
{
	int admindata = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, admindata);
}

public Action CommondVote(int client, int args)
{
	if (!client) return Plugin_Handled;
	if (args > 0)
	{
		char sCfg[64], sBuffer[256];
		GetCmdArg(1, sCfg, sizeof(sCfg));
		BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "../../cfg/%s", sCfg);
		if (DirExists(sBuffer))
		{
			FindConfigName(sCfg, sBuffer, sizeof(sBuffer));
			if (StartVote(client, sBuffer))
			{
				strcopy(g_sCfg, sizeof(g_sCfg), sCfg);
				FakeClientCommand(client, "Vote Yes");
			}
			return Plugin_Handled;
		}
	}
	
	ShowVoteMenu(client);
	
	return Plugin_Handled;
}

bool FindConfigName(const char[] cfg, char[] message, int maxlength)
{
	KvRewind(g_hCfgsKV);
	if (KvGotoFirstSubKey(g_hCfgsKV))
	{
		do
		{
			if (KvJumpToKey(g_hCfgsKV, cfg))
			{
				KvGetString(g_hCfgsKV, "message", message, maxlength);
				return true;
			}
		} while (KvGotoNextKey(g_hCfgsKV));
	}
	return false;
}

void ShowVoteMenu(int client)
{
	Handle hMenu = CreateMenu(VoteMenuHandler);
	SetMenuTitle(hMenu, "选择:");
	char sSectionName[64];
	KvRewind(g_hCfgsKV);
	if (KvGotoFirstSubKey(g_hCfgsKV))
	{
		do
		{
			KvGetSectionName(g_hCfgsKV, sSectionName, sizeof(sSectionName));
			AddMenuItem(hMenu, sSectionName, sSectionName);
		} while (KvGotoNextKey(g_hCfgsKV));
	}
	DisplayMenu(hMenu, client, 20);
}

public int VoteMenuHandler(Handle menu, MenuAction action, int client, int itemPos)
{
	if (action == MenuAction_Select)
	{
		char sSectionName[64], sBuffer[64];
		GetMenuItem(menu, itemPos, sSectionName, sizeof(sSectionName));
		KvRewind(g_hCfgsKV);
		if (KvJumpToKey(g_hCfgsKV, sSectionName) && KvGotoFirstSubKey(g_hCfgsKV))
		{
			Handle hMenu = CreateMenu(ConfigsMenuHandler);
			Format(sBuffer, sizeof(sBuffer), "选择 %s :", sSectionName);
			SetMenuTitle(hMenu, sBuffer);
			do
			{
				KvGetSectionName(g_hCfgsKV, sSectionName, sizeof(sSectionName));
				KvGetString(g_hCfgsKV, "type", g_sType, sizeof(g_sType));
				KvGetString(g_hCfgsKV, "message", sBuffer, sizeof(sBuffer));
				AddMenuItem(hMenu, sSectionName, sBuffer);
			} while (KvGotoNextKey(g_hCfgsKV));
			DisplayMenu(hMenu, client, 20);
		}
		else
		{
			PrintToChat(client, "没有相关的文件存在1.");
			ShowVoteMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 1;
}

public int ConfigsMenuHandler(Handle menu, MenuAction action, int client, int itemPos)
{
	if (action == MenuAction_Select)
	{
		char sSectionName[64], sMessage[64];
		GetMenuItem(menu, itemPos, sSectionName, sizeof(sSectionName), _, sMessage, sizeof(sMessage));
		
		if (StrEqual(g_sType, "command"))
		{
			if (StartVote(client, sMessage))
			{
				strcopy(g_sCfg, sizeof(g_sCfg), sSectionName);
				FakeClientCommand(client, "Vote Yes");
			}
			else
			{
				ShowVoteMenu(client);
			}
		}
		else if (StrEqual(g_sType, "map"))
		{
			Format(sSectionName, sizeof(sSectionName), "changelevel %s", sSectionName);
			if (StartVote(client, sMessage))
			{
				strcopy(g_sCfg, sizeof(g_sCfg), sSectionName);
				FakeClientCommand(client, "Vote Yes");
			}
			else
			{
				ShowVoteMenu(client);
			}
		}
		else if (StrEqual(g_sType, "panel"))
		{
			FakeClientCommand(client, sSectionName);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		ShowVoteMenu(client);
	}

	return 1;
}

bool StartVote(int client, const char[] cfgname)
{
	if (!IsBuiltinVoteInProgress())
	{
		int iNumPlayers;
		int[] iPlayers = new int[MaxClients];
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
			{
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}
		char sBuffer[64];
		g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		Format(sBuffer, sizeof(sBuffer), "执行 '%s' ?", cfgname);
		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, client);
		SetBuiltinVoteResultCallback(g_hVote, VoteResultHandler);
		DisplayBuiltinVoteToAll(g_hVote, 20);
		PrintToChatAll("\x04%N \x03发起了一个投票", client);
		return true;
	}
	PrintToChat(client, "已经有一个投票正在进行.");
	return false;
}

public void VoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			CloseHandle(vote);
			g_hVote = INVALID_HANDLE;
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Generic);
		}
	}
}

public void VoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] >= (num_clients * 0.6))
			{
				if (vote == g_hVote)
				{
					DisplayBuiltinVotePass(vote, "cfg文件正在加载...");
					ServerCommand("%s", g_sCfg);
					return;
				}
				else if(vote == g_hVoteKick)
				{
					ServerCommand("sm_kick %s 投票踢出", kickplayername);
					return;
				}
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action Command_Voteskick(int client, int args)
{
	if(client != 0 && client <= MaxClients) 
	{
		CreateVotekickMenu(client);
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

void CreateVotekickMenu(int client)
{	
	Handle menu = CreateMenu(Menu_Voteskick);		
	char name[MAX_NAME_LENGTH];
	char info[MAX_NAME_LENGTH + 6];
	char playerid[32];
	SetMenuTitle(menu, "选择踢出玩家");
	for(int i = 1;i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			Format(playerid,sizeof(playerid),"%i",GetClientUserId(i));
			if(GetClientName(i,name,sizeof(name)))
			{
				Format(info, sizeof(info), "%s",  name);
				AddMenuItem(menu, playerid, info);
			}
		}		
	}
	DisplayMenu(menu, client, 30);
}
public int Menu_Voteskick(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Select)
	{
		char info[32], name[32];
		GetMenuItem(menu, param2, info, sizeof(info), _, name, sizeof(name));
		kickplayername = name;
		PrintToChatAll("\x04%N 发起投票踢出 \x05 %s", param1, kickplayername);
		if(DisplayVoteKickMenu(param1)) FakeClientCommand(param1, "Vote Yes");
	}
	return 1;
}

public bool DisplayVoteKickMenu(int client)
{
	if (!IsBuiltinVoteInProgress())
	{
		int iNumPlayers;
		int[] iPlayers = new int[MaxClients];
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
			{
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}
		char sBuffer[64];
		g_hVoteKick = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		Format(sBuffer, sizeof(sBuffer), "踢出 '%s' ?", kickplayername);
		SetBuiltinVoteArgument(g_hVoteKick, sBuffer);
		SetBuiltinVoteInitiator(g_hVoteKick, client);
		SetBuiltinVoteResultCallback(g_hVoteKick, VoteResultHandler);
		DisplayBuiltinVoteToAll(g_hVoteKick, 20);
		PrintToChatAll("\x04%N \x03发起了一个投票", client);
		return true;
	}
	PrintToChat(client, "已经有一个投票正在进行.");
	return false;
}