#include <sourcemod>
#include <left4dhooks>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util_weapons>

#pragma newdecls required

#define TICK_TIME 0.199951

ConVar cvarSpitCanHarmGascan;

int g_iTickCount = 0;

public Plugin myinfo =
{
  name = "[L4D2] Allow Bot Spitter Ignite Gascan",
  author = "海洋空氣",
  description = "",
  version = "1.1",
  url = "https://github.com/Sglight/L4D2-AstMod-Scriptings"
};

public void OnPluginStart()
{
  cvarSpitCanHarmGascan = CreateConVar("coop_spit_can_harm_gascan", "1", "");
}

public void L4D2_CInsectSwarm_CanHarm_Post(int acid, int spitter, int entity)
{
  int weaponId = IdentifyWeapon(entity);
  if (weaponId == WEPID_GASCAN) {
    if (GetConVarBool(cvarSpitCanHarmGascan)) {
      float time = GetConVarFloat(FindConVar("gascan_spit_time"));

      if (g_iTickCount == 0) {
        CreateTimer(time, Timer_GascanIgnite, entity);
      }
      g_iTickCount++;
    }
  }
}

public Action Timer_GascanIgnite(Handle timer, int entity)
{
  float time = GetConVarFloat(FindConVar("gascan_spit_time"));
  float igniteTick = time / TICK_TIME;
  if (g_iTickCount >= igniteTick) {
    // Ignite
    SetEntProp(entity, Prop_Data, "m_iHealth", 0);
  }
  // CloseHandle(hGascanIgnite);
  // hGascanIgnite = INVALID_HANDLE;
  g_iTickCount = 0;
  return Plugin_Continue;
}