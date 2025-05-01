#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public void OnPluginStart()
{
	RegConsoleCmd("sm_reloadscript", Cmd_Reload, "Reload Script");
}

// From vscript_replacer by SilverShot
public Action Cmd_Reload(int client, int args)
{
	if( args != 1 )
	{
		ReplyToCommand(client, "[SM] Usage: sm_reloadscript <filename>");
		return Plugin_Handled;
	}

	// Games inbuilt method to execute VScripts. In L4D2 "script_execute" causes a memory leak, so using an entity instead.
	// Using an entity would probably prevent the script executing during hibernation, not sure if command would work then either though.

	int entity = CreateEntityByName("logic_script");
	if( entity != -1 )
	{
		char sFile[PLATFORM_MAX_PATH];
		GetCmdArg(1, sFile, sizeof(sFile));
		DispatchSpawn(entity);
		SetVariantString(sFile);
		AcceptEntityInput(entity, "RunScriptFile");
		RemoveEdict(entity);
	}

	return Plugin_Handled;
}