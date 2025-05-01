/*

This version of Boss Percents was designed to work with my custom Ready Up plugin.
It's designed so when boss percentages are changed, it will edit the already existing
Ready Up footer, rather then endlessly stacking them ontop of one another.

It was also created so that my Witch Toggler plugin can properly display if the witch is disabled
or not on both the ready up menu aswell as when using the !boss commands.

I tried my best to comment everything so it can be very easy to understand what's going on. Just in case you want to
do some personalization for your server or config. It will also come in handy if somebody finds a bug and I need to figure
out what's going on :D Kinda makes my other plugins look bad huh :/

*/

#pragma semicolon 1
#pragma newdecls required

#include <colors>
#include <left4dhooks>
#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <confogl>
#include <witch_and_tankifier>

#define PLUGIN_VERSION "3.2.5"

public Plugin myinfo =
{
	name        = "[L4D2] Boss Percents/Vote Boss Hybrid",
	author      = "Spoon, Forgetest",
	version     = PLUGIN_VERSION,
	description = "Displays Boss Flows on Ready-Up and via command. Remade for NextMod. 删除 readyup 和 rounds 相关",
	url         = "https://github.com/spoon-l4d2"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("SetTankDisabled", Native_SetTankDisabled);                // Other plugins can use this to set the tank as "disabled" on the ready up, and when the !boss command is used - YOU NEED TO SET THIS EVERY MAP
	CreateNative("SetWitchDisabled", Native_SetWitchDisabled);              // Other plugins can use this to set the witch as "disabled" on the ready up, and when the !boss command is used - YOU NEED TO SET THIS EVERY MAP
	CreateNative("UpdateBossPercents", Native_UpdateBossPercents);          // Used for other plugins to update the boss percentages
	CreateNative("GetStoredTankPercent", Native_GetStoredTankPercent);      // Used for other plugins to get the stored tank percent
	CreateNative("GetStoredWitchPercent", Native_GetStoredWitchPercent);    // Used for other plugins to get the stored witch percent
	CreateNative("IsDarkCarniRemix", Native_IsDarkCarniRemix);              // Used for other plugins to check if the current map is Dark Carnival: Remix (It tends to break things when it comes to bosses)

	RegPluginLibrary("l4d_boss_percent");
	return APLRes_Success;
}

// Variables
char g_sCurrentMap[64];        // Stores the current map name
bool g_bWitchDisabled;         // Stores if another plugin has disabled the witch
bool g_bTankDisabled;          // Stores if another plugin has disabled the tank

// Dark Carnival: Remix Work Around Variables
bool g_bIsRemix;    // Stores if the current map is Dark Carnival: Remix. So we don't have to keep checking via IsDKR()
// int g_idkrwaAmount; 													// Stores the amount of times the DKRWorkaround method has been executed. We only want to execute it twice, one to get the tank percentage, and a second time to get the witch percentage.
int  g_fDKRFirstRoundTankPercent;     // Stores the Tank percent from the first half of a DKR map. Used so we can set the 2nd half to the same percent
int  g_fDKRFirstRoundWitchPercent;    // Stores the Witch percent from the first half of a DKR map. Used so we can set the 2nd half to the same percent
// bool g_bDKRFirstRoundBossesSet; 										// Stores if the first round of DKR boss percentages have been set

// Percent Variables
int  g_fWitchPercent;    // Stores current Witch Percent
int  g_fTankPercent;     // Stores current Tank Percent
char g_sWitchString[80];
char g_sTankString[80];

// Current
ConVar g_hVsBossBuffer;

public void OnPluginStart()
{
	LoadTranslations("l4d_boss_percent.phrases");

	g_hVsBossBuffer = FindConVar("versus_boss_buffer");

	// Commands
	RegConsoleCmd("sm_boss", BossCmd);     // Used to see percentages of both bosses
	RegConsoleCmd("sm_tank", BossCmd);     // Used to see percentages of both bosses
	RegConsoleCmd("sm_witch", BossCmd);    // Used to see percentages of both bosses
	RegConsoleCmd("sm_current", BossCmd);    // Used to see percentages of both bosses
	RegConsoleCmd("sm_cur", BossCmd);    // Used to see percentages of both bosses

	// Hooks/Events
	HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);                  // When a new round starts (2 rounds in 1 map -- this should be called twice a map)
	HookEvent("player_say", DKRWorkaround, EventHookMode_Post);                           // Called when a message is sent in chat. Used to grab the Dark Carnival: Remix boss percentages.
}

/* ========================================================
// ====================== Section #1 ======================
// ======================= Natives ========================
// ========================================================
 *
 * This section contains all the methods that other plugins
 * can use.
 *
 * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
*/

// Allows other plugins to update boss percentages
public int Native_UpdateBossPercents(Handle plugin, int numParams)
{
	CreateTimer(0.1, GetBossPercents);

	return 1;
}

// Used for other plugins to check if the current map is Dark Carnival: Remix (It tends to break things when it comes to bosses)
public int Native_IsDarkCarniRemix(Handle plugin, int numParams)
{
	return g_bIsRemix;
}

// Other plugins can use this to set the witch as "disabled" on the ready up, and when the !boss command is used
// YOU NEED TO SET THIS EVERY MAP
public int Native_SetWitchDisabled(Handle plugin, int numParams)
{
	g_bWitchDisabled = view_as<bool>(GetNativeCell(1));

	return 1;
}

// Other plugins can use this to set the tank as "disabled" on the ready up, and when the !boss command is used
// YOU NEED TO SET THIS EVERY MAP
public int Native_SetTankDisabled(Handle plugin, int numParams)
{
	g_bTankDisabled = view_as<bool>(GetNativeCell(1));

	return 1;
}

// Used for other plugins to get the stored witch percent
public int Native_GetStoredWitchPercent(Handle plugin, int numParams)
{
	return g_fWitchPercent;
}

// Used for other plugins to get the stored tank percent
public int Native_GetStoredTankPercent(Handle plugin, int numParams)
{
	return g_fTankPercent;
}

/* ========================================================
// ====================== Section #2 ======================
// ==================== Ready Up Check ====================
// ========================================================
 *
 * This section makes sure that the Ready Up plugin is loaded.
 *
 * It's needed to make sure we can actually add to the Ready
 * Up menu, or if we should just diplay percentages in chat.
 *
 * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
*/

/* ========================================================
// ====================== Section #3 ======================
// ======================== Events ========================
// ========================================================
 *
 * This section is where all of our events will be. Just to
 * make things easier to keep track of.
 *
 * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
*/

// Called when a new map is loaded
public void OnMapStart()
{
	// Get Current Map
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));

	// Check if the current map is part of the Dark Carnival: Remix Campaign -- and save it
	g_bIsRemix = IsDKR();
}

// Called when a map ends
public void OnMapEnd()
{
	// Reset Variables
	g_fDKRFirstRoundTankPercent  = -1;
	g_fDKRFirstRoundWitchPercent = -1;
	g_fWitchPercent              = -1;
	g_fTankPercent               = -1;
	// g_bDKRFirstRoundBossesSet = false;
	// g_idkrwaAmount = 0;
	g_bTankDisabled              = false;
	g_bWitchDisabled             = false;
}

/* Called when survivors leave the saferoom
 * If the Ready Up plugin is not available, we use this.
 * It will print boss percents upon survivors leaving the saferoom.
 */
public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client)
{
	PrintBossPercents(client);

	// If it's the first round of a Dark Carnival: Remix map, we want to save our boss percentages so we can set them next round
	if (g_bIsRemix)
	{
		g_fDKRFirstRoundTankPercent  = g_fTankPercent;
		g_fDKRFirstRoundWitchPercent = g_fWitchPercent;
	}
}

/* Called when a new round starts (twice each map)
 * Here we will need to refresh the boss percents.
 */
public void RoundStartEvent(Event event, const char[] name, bool dontBroadcast)
{
	// Find percentages and update readyup footer
	CreateTimer(5.0, GetBossPercents);
}

/* ========================================================
// ====================== Section #4 ======================
// ============ Dark Carnival: Remix Workaround ===========
// ========================================================
 *
 * This section is where all of our DKR work around stuff
 * well be kept. DKR has it's own boss flow "randomizer"
 * and therefore needs to be set as a static map to avoid
 * having 2 tanks on the map. Because of this, we need to
 * do a few extra steps to determine the boss spawn percents.
 *
 * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
*/

// Check if the current map name is equal to and of the Dark Carnival: Remix map names
bool IsDKR()
{
	if (StrEqual(g_sCurrentMap, "dkr_m1_motel", true) || StrEqual(g_sCurrentMap, "dkr_m2_carnival", true) || StrEqual(g_sCurrentMap, "dkr_m3_tunneloflove", true) || StrEqual(g_sCurrentMap, "dkr_m4_ferris", true) || StrEqual(g_sCurrentMap, "dkr_m5_stadium", true))
	{
		return true;
	}
	return false;
}

// Finds a percentage from a string
int GetPercentageFromText(const char[] text)
{
	// Check to see if text contains '%' - Store the index if it does
	int index = StrContains(text, "%", false);

	// If the index isn't -1 (No '%' found) then find the percentage
	if (index > -1)
	{
		char sBuffer[12];    // Where our percentage will be kept.

		// If the 3rd character before the '%' symbol is a number it's 100%.
		if (IsCharNumeric(text[index - 3]))
		{
			return 100;
		}

		// Check to see if the characters that are 1 and 2 characters before our '%' symbol are numbers
		if (IsCharNumeric(text[index - 2]) && IsCharNumeric(text[index - 1]))
		{
			// If both characters are numbers combine them into 1 string
			Format(sBuffer, sizeof(sBuffer), "%c%c", text[index - 2], text[index - 1]);

			// Convert our string to an int
			return StringToInt(sBuffer);
		}
	}

	// Couldn't find a percentage
	return -1;
}

/*
 *
 * On Dark Carnival: Remix there is a script to display custom boss percentages to users via chat.
 * We can "intercept" this message and read the boss percentages from the message.
 * From there we can add them to our Ready Up menu and to our !boss commands
 *
 */
public void DKRWorkaround(Event event, const char[] name, bool dontBroadcast)
{
	// If the current map is not part of the Dark Carnival: Remix campaign, don't continue
	if (!g_bIsRemix) return;

	// Check if the function has already ran more than twice this map
	// if (g_bDKRFirstRoundBossesSet || InSecondHalfOfRound()) return;

	// Check if the message is not from a user (Which means its from the map script)
	int UserID = GetEventInt(event, "userid", 0);
	if (!UserID/* && !InSecondHalfOfRound()*/)
	{
		// Get the message text
		char sBuffer[128];
		GetEventString(event, "text", sBuffer, sizeof(sBuffer), "");

		// If the message contains "The Tank" we can try to grab the Tank Percent from it
		if (StrContains(sBuffer, "The Tank", false) > -1)
		{	
			// Create a new int and find the percentage
			int percentage;
			percentage = GetPercentageFromText(sBuffer);

			// If GetPercentageFromText didn't return -1 that means it returned our boss percentage.
			// So, if it did return -1, something weird happened, set our boss to 0 for now.
			if (percentage > -1) {
				g_fTankPercent = percentage;
			} else {
				g_fTankPercent = 0;
			}

			// 不用保存上第一回合刷新位置
			// g_fDKRFirstRoundTankPercent = g_fTankPercent;
		}

		// If the message contains "The Witch" we can try to grab the Witch Percent from it
		if (StrContains(sBuffer, "The Witch", false) > -1)
		{
			// Create a new int and find the percentage
			int percentage;
			percentage = GetPercentageFromText(sBuffer);

			// If GetPercentageFromText didn't return -1 that means it returned our boss percentage.
			// So, if it did return -1, something weird happened, set our boss to 0 for now.
			if (percentage > -1)
			{
				g_fWitchPercent = percentage;
			}
			else {
				g_fWitchPercent = 0;
			}

			// 不用保存上第一回合刷新位置
			// g_fDKRFirstRoundTankPercent = g_fTankPercent;
		}

		// Increase the amount of times we've done this function. We only want to do it twice. Once for each boss, for each map.
		// g_idkrwaAmount = g_idkrwaAmount + 1;

		// Check if both bosses have already been set
		// if (g_idkrwaAmount > 1)
		//{
		// This function has been executed two or more times, so we should be done here for this map.
		//	g_bDKRFirstRoundBossesSet = true;
		//}

		ProcessBossString();
	}
}

/* ========================================================
// ====================== Section #5 ======================
// ================= Percent Updater/Saver ================
// ========================================================
 *
 * This section is where we will save our boss percents and
 * where we will call the methods to update our boss percents
 *
 * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
*/

// This method will return the Tank flow for a specified round
stock float GetTankFlow(int round)
{
	return L4D2Direct_GetVSTankFlowPercent(round);
}

stock float GetWitchFlow(int round)
{
	return L4D2Direct_GetVSWitchFlowPercent(round);
}

/*
 *
 * This method will find the current boss percents and will
 * save them to our boss percent variables.
 * This method will be called upon every new round
 *
 */
public Action GetBossPercents(Handle timer)
{
	// We need to do things a little differently if it's Dark Carnival: Remix
	if (g_bIsRemix)
	{
		// Bosses cannot be changed on Dark Carnival: Remix maps. Unless they are completely disabled. So, we need to check if that's the case here

		// if (g_bDKRFirstRoundBossesSet)
		//{
		//  If the Witch is not set to spawn this round, set it's percentage to 0
		if (!L4D2Direct_GetVSWitchToSpawnThisRound(0))
		{
			// Not quite enough yet. We also want to check if the flow is 0
			if ((GetWitchFlow(0) * 100.0) < 1)
			{
				// One last check
				if (g_bWitchDisabled)
					g_fWitchPercent = 0;
			}
		}
		else
		{
			// The boss must have been re-enabled :)
			g_fWitchPercent = g_fDKRFirstRoundWitchPercent;
		}

		// If the Tank is not set to spawn this round, set it's percentage to 0
		if (!L4D2Direct_GetVSTankToSpawnThisRound(0))
		{
			// Not quite enough yet. We also want to check if the flow is 0
			if ((GetTankFlow(0) * 100) < 1)
			{
				// One last check
				if (g_bTankDisabled)
					g_fTankPercent = 0;
			}
		}
		else
		{
			// The boss must have been re-enabled :)
			g_fTankPercent = g_fDKRFirstRoundTankPercent;
		}
		//}
	}
	else
	{
		// This will be any map besides Remix
		// We're in the first round.

		// Set our boss percents to 0 - If bosses are not set to spawn this round, they will remain 0
		g_fWitchPercent = 0;
		g_fTankPercent  = 0;

		// If the Witch is set to spawn this round. Find the witch flow and set it as our witch percent
		if (L4D2Direct_GetVSWitchToSpawnThisRound(0))
		{
			g_fWitchPercent = RoundToNearest(GetWitchFlow(0) * 100.0);
		}

		// If the Tank is set to spawn this round. Find the witch flow and set it as our witch percent
		if (L4D2Direct_GetVSTankToSpawnThisRound(0))
		{
			g_fTankPercent = RoundToNearest(GetTankFlow(0) * 100.0);
		}
	}

	// Finally build up our string for effiency, yea.
	ProcessBossString();
	return Plugin_Stop;
}

/* ========================================================
// ====================== Section #6 ======================
// ======================= Commands =======================
// ========================================================
 *
 * This is where all of our boss commands will go
 *
 * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
*/
public Action BossCmd(int client, int args)
{
	// Show our boss percents
	PrintBossPercents(client);

	return Plugin_Handled;
}

void ProcessBossString()
{
	// Create some variables
	bool p_bStaticTank;     // Private Variable - Stores if current map contains static tank spawn
	bool p_bStaticWitch;    // Private Variable - Stores if current map contains static witch spawn

	// Check if the current map is from Dark Carnival: Remix
	if (!g_bIsRemix)
	{
		// Not part of the Dark Carnival: Remix Campaign -- Check to see if map contains static boss spawns - and store it to a bool variable
		p_bStaticTank  = IsStaticTankMap();
		p_bStaticWitch = IsStaticWitchMap();
	}

	// Format String For Tank
	if (g_fTankPercent > 0)    // If Tank percent is not equal to 0
	{
		Format(g_sTankString, sizeof(g_sTankString), "%t {red}%d%%", "TagTank", g_fTankPercent);
	}
	else if (g_bTankDisabled)    // If another plugin has disabled the tank
	{
		Format(g_sTankString, sizeof(g_sTankString), "%t {red}%t", "TagTank", "Disabled");
	}
	else if (p_bStaticTank)    // If current map has static Tank spawn
	{
		Format(g_sTankString, sizeof(g_sTankString), "%t {red}%t", "TagTank", "StaticSpawn");
	}
	else    // There is no Tank
	{
		Format(g_sTankString, sizeof(g_sTankString), "%t {red}%t", "TagTank", "None");
	}

	// Format String For Witch
	if (g_fWitchPercent > 0)    // If Witch percent is not equal to 0
	{
		Format(g_sWitchString, sizeof(g_sWitchString), "%t {red}%d%%", "TagWitch", g_fWitchPercent);
	}
	else if (g_bWitchDisabled)    // If another plugin has disabled the witch
	{
		Format(g_sWitchString, sizeof(g_sWitchString), "%t {red}%t", "TagWitch", "Disabled");
	}
	else if (p_bStaticWitch)    // If current map has static Witch spawn
	{
		Format(g_sWitchString, sizeof(g_sWitchString), "%t {red}%t", "TagWitch", "StaticSpawn");
	}
	else    // There is no Witch
	{
		Format(g_sWitchString, sizeof(g_sWitchString), "%t {red}%t", "TagWitch", "None");
	}
}

void PrintBossPercents(int client)
{
	int boss_proximity = RoundToNearest(GetBossProximity() * 100.0);
	char message[512];
	char buffer[256];
	Format(message, sizeof(message), "\x01<\x05Current\x01> \x04%d%%%%    ", boss_proximity);

	if (g_fTankPercent) {
		Format(buffer, sizeof(buffer), "\x01<\x05Tank\x01> \x04%d%%%%    ", g_fTankPercent);
	} else {
		Format(buffer, sizeof(buffer), "\x01<\x05Tank\x01> \x04Static Tank    ");
	}
	StrCat(message, sizeof(message), buffer);

	if (g_fWitchPercent) {
		Format(buffer, sizeof(buffer), "\x01<\x05Witch\x01> \x04%d%%%%", g_fWitchPercent);
	} else {
		Format(buffer, sizeof(buffer), "\x01<\x05Witch\x01> \x04Static Witch");
	}
	StrCat(message, sizeof(message), buffer);
	
	if (client) {
		PrintToChatAll(message);
	} else {
		PrintToServer(message);
	}
}

float GetBossProximity()
{
	float proximity = GetMaxSurvivorCompletion() + g_hVsBossBuffer.FloatValue / L4D2Direct_GetMapMaxFlowDistance();

	return (proximity > 1.0) ? 1.0 : proximity;
}

float GetMaxSurvivorCompletion()
{
	float flow = 0.0, tmp_flow = 0.0, origin[3];
	Address pNavArea;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2) {
			GetClientAbsOrigin(i, origin);
			pNavArea = L4D2Direct_GetTerrorNavArea(origin);
			if (pNavArea != Address_Null) {
				tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
				flow = (flow > tmp_flow) ? flow : tmp_flow;
			}
		}
	}

	return (flow / L4D2Direct_GetMapMaxFlowDistance());
}