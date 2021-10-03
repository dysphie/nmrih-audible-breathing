/* TODO:
 * - Read sounds from config instead of hardcoding values
 * - Clean up code, it's all over the place atm
 */

#include <sdktools>
#include <sdkhooks>

public Plugin myinfo = {
    name        = "Audible Breathing",
    author      = "Dysphie",
    description = "Makes breathing sounds audible to others",
    version     = "0.2.1",
    url         = ""
};

#define MAXPLAYERS_NMRIH 9
#define OBS_MODE_IN_EYE 4

#define SNDLEVEL_FIRSTPERSON SNDLEVEL_NORMAL 
#define SNDLEVEL_THIRDPERSON SNDLEVEL_CONVO   

#define SND_LIGHT_BREATH "player/stamina/female/light_breath.wav"

#define LB_FEMALE "player/stamina/female/light_breath.wav"
#define LB_PUGMAN "player/stamina/pugman/light_breath.wav"
#define LB_MALE "player/stamina/light_breath.wav"
#define MB_MALE "player/stamina/medium_breath1.wav"
			
char MB_FEMALE[][] = {
	"player/stamina/female/medium_breath1.wav",
	"player/stamina/female/medium_breath2.wav"
}
char HB_FEMALE[][] = {
	"player/stamina/female/heavy_breath1.wav",
	"player/stamina/female/heavy_breath2.wav",
	"player/stamina/female/heavy_breath3.wav"
}

char MB_PUGMAN[][] = {
	"player/stamina/pugman/medium_breath1.wav",
	"player/stamina/pugman/medium_breath2.wav"
}
char HB_PUGMAN[][] = {
	"player/stamina/pugman/heavy_breath1.wav",
	"player/stamina/pugman/heavy_breath2.wav",
	"player/stamina/pugman/heavy_breath3.wav"
}			

char HB_MALE[][] = {
	"player/stamina/heavy_breath1.wav",
	"player/stamina/heavy_breath2.wav",
	"player/stamina/heavy_breath3.wav"
}

enum eVoiceID 
{
	Voice_Male,
	Voice_Female,
	Voice_Pugman,
	Voice_MAX
}

enum eBreathing
{
	Breathing_Light,
	Breathing_Medium,
	Breathing_Heavy,
	Breathing_MAX
}

char breathSfx[MAXPLAYERS_NMRIH+1][Breathing_MAX][PLATFORM_MAX_PATH];

ConVar hb_heavy_threshold;
ConVar hb_medium_threshold;
ConVar hb_light_threshold;
ConVar hb_breath_looptime;
ConVar sm_audible_breath_firstperson;
ConVar sm_audible_breath_thirdperson;

bool initedSounds[MAXPLAYERS_NMRIH+1] = {false, ...};
int voiceID[MAXPLAYERS_NMRIH+1] = {Voice_Male, ...};
float nextBreathTime[MAXPLAYERS_NMRIH+1] = {-1.0, ...};
float nextBeatSound[MAXPLAYERS+1] = {-1.0, ...};
int beatOut[MAXPLAYERS+1] = {false, ...};

ConVar hb_beat_endlooptime, hb_beat_baselooptime, hb_beat_endpulsetime, hb_beat_basepulsetime;
ConVar sm_audible_hb_firstperson;


#define BEAT_IN 0
#define BEAT_OUT 1

char HB_SND[][] = {
	"player/stamina/heartbeat_in.wav",
	"player/stamina/heartbeat_out.wav"
} 

public void OnPluginStart()
{
	sm_audible_breath_firstperson = CreateConVar("sm_audible_breath_firstperson", "1",
		"Whether to play breathing sounds to first-person spectators");

	sm_audible_breath_thirdperson = CreateConVar("sm_audible_breath_thirdperson", "1",
		"Whether to play breathing sounds to nearby teammates and third-person spectators");

	sm_audible_hb_firstperson = CreateConVar("sm_audible_hb_firstperson", "1",
		"Whether to play heartbeat sounds to first-person spectators");

	hb_heavy_threshold = CreateConVar("sm_audible_heavy_threshold", "40", 
		"Threshold of stamina to play heavy breathing sound");

	hb_medium_threshold = CreateConVar("sm_audible_medium_threshold", "60", 
		"Threshold of stamina to play medium breathing sound.");

	hb_light_threshold = CreateConVar("sm_audible_light_threshold", "80", 
		"Threshold of stamina to play light breathing sound.");

	hb_breath_looptime = CreateConVar("sm_audible_breath_looptime", "2.5",
		"Time in seconds between breath start times");

	hb_beat_endlooptime = CreateConVar("sm_audible_beat_endlooptime", "0.5", 
		"Time in seconds between heartbeats (ending point)");

	hb_beat_baselooptime = CreateConVar("sm_audible_beat_baselooptime", "1.0",
		"Time in seconds between heartbeats (baseline)");

	hb_beat_endpulsetime = CreateConVar("sm_audible_beat_endpulsetime", "0.25",
		"Time in seconds between in and out pulses (ending point)");

	hb_beat_basepulsetime = CreateConVar("sm_audible_beat_basepulsetime", "0.6",
		"Time in seconds between in and out pulses (baseline)");

	AutoExecConfig(true, "plugin.audible-breathing");

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

public void OnMapStart()
{
	PrecacheSounds();
}

public void OnClientPutInServer(int client)
{
	initedSounds[client] = false;
	voiceID[client] = Voice_Male;
	nextBeatSound[client] = -1.0;
	nextBreathTime[client] = -1.0;
	beatOut[client] = false;

	QueryClientConVar(client, "cl_voice_set", OnClVoiceSetReceived);

	SDKHook(client, SDKHook_PreThink, OnPlayerPreThink);
}

void OnClVoiceSetReceived(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	if (cookie == QUERYCOOKIE_FAILED || result != ConVarQuery_Okay)
		return;

	if (StrEqual(cvarValue, "FemaleDefault", false))
		voiceID[client] = Voice_Female;
	else if (StrEqual(cvarValue, "Alt7", false))
		voiceID[client] = Voice_Pugman;

	InitBreathingSounds(client);
}

void OnPlayerPreThink(int client)
{
	if (IsPlayerAlive(client))
	{
		UpdateBreathSound(client);
		UpdateBeatSound(client);
	}
}

void UpdateBreathSound(int client)
{
	float curTime = GetTickedTime();
	if (nextBreathTime[client] > curTime)
		return;

	float stamina = GetEntPropFloat(client, Prop_Send, "m_flStamina");

	if (stamina <= hb_light_threshold.FloatValue)
	{
		if (stamina <= hb_medium_threshold.FloatValue)
		{
			if (stamina <= hb_heavy_threshold.FloatValue)
			{
				EmitBreathSound(client, Breathing_Heavy);
			}
			else 
			{
				EmitBreathSound(client, Breathing_Medium);	
			}
		}
		else
		{
			EmitBreathSound(client, Breathing_Light);
		}

		nextBreathTime[client] = GetTickedTime() + hb_breath_looptime.FloatValue;
	}	
}

void UpdateBeatSound(int client)
{
	float stamina = GetEntPropFloat(client, Prop_Send, "m_flStamina");
	if (stamina > hb_light_threshold.FloatValue)
		return;

	if ( GetTickedTime() >= nextBeatSound[client] )
	{
		float end, base;

		float v6 = min(max(stamina / hb_light_threshold.FloatValue, 0.0), 1.0);
		if (!beatOut[client])
		{
			beatOut[client] = true;
			end = hb_beat_endlooptime.FloatValue;
			base = hb_beat_baselooptime.FloatValue;
		}
		else
		{
			beatOut[client] = false;
			end = hb_beat_endpulsetime.FloatValue;
			base = hb_beat_basepulsetime.FloatValue;
		}

		float vol = 1.0 - (v6 * v6);
		nextBeatSound[client] = GetTickedTime() + (((base - end) * v6) + end);
		EmitBeatSound(client, beatOut[client], vol);
	}
}

void EmitBeatSound(int client, int beatType, float vol)
{	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsClientInGame(i))
		{
			if (IsFirstPersonSpectating(i, client) && sm_audible_hb_firstperson.BoolValue)
			{
				EmitSoundToClient(i, HB_SND[beatType], 
					.volume=vol, 
					.entity=client, 
					.level=SNDLEVEL_NORMAL);
			}
		}
	}
}

void EmitBreathSound(int client, int breathType)
{
	if (!initedSounds[client])
		return;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsClientInGame(i))
		{
			if (IsFirstPersonSpectating(i, client) && sm_audible_breath_firstperson.BoolValue)
			{
				EmitSoundToClient(i, breathSfx[client][breathType],
					.entity=client, 
					.level=SNDLEVEL_FIRSTPERSON);
			}
			else if (sm_audible_breath_thirdperson.BoolValue)
			{
				EmitSoundToClient(i, breathSfx[client][breathType], 
					.entity=client, 
					.level=SNDLEVEL_THIRDPERSON);
			}
		}
	}
}

bool IsFirstPersonSpectating(int client, int target)
{
	return GetEntProp(client, Prop_Send, "m_iObserverMode") == OBS_MODE_IN_EYE &&
		GetEntPropEnt(client, Prop_Send, "m_hObserverTarget") == target;
}

void PrecacheSounds()
{
	for (int i; i < sizeof(MB_FEMALE); i++) 
		PrecacheSound(MB_FEMALE[i]);

	for (int i; i < sizeof(HB_FEMALE); i++) 
		PrecacheSound(HB_FEMALE[i]);

	for (int i; i < sizeof(MB_PUGMAN); i++) 
		PrecacheSound(MB_PUGMAN[i]);

	for (int i; i < sizeof(HB_PUGMAN); i++) 
		PrecacheSound(HB_PUGMAN[i]);

	for (int i; i < sizeof(HB_MALE); i++) 
		PrecacheSound(HB_MALE[i]);

	PrecacheSound(LB_FEMALE);
	PrecacheSound(LB_PUGMAN);
	PrecacheSound(LB_MALE);
	PrecacheSound(LB_PUGMAN);

	PrecacheSound(HB_SND[BEAT_IN]);
	PrecacheSound(HB_SND[BEAT_OUT]);
}

void InitBreathingSounds(int client)
{
	switch (voiceID[client])
	{
		case Voice_Female:
		{
			strcopy(breathSfx[client][Breathing_Light], sizeof(breathSfx[][]), LB_FEMALE);

			int rnd = GetRandomInt(0, sizeof(MB_FEMALE)-1);
			strcopy(breathSfx[client][Breathing_Medium], sizeof(breathSfx[][]), MB_FEMALE[rnd]);

			rnd = GetRandomInt(0, sizeof(HB_FEMALE)-1);
			strcopy(breathSfx[client][Breathing_Heavy], sizeof(breathSfx[][]), HB_FEMALE[rnd]);
		}

		case Voice_Pugman:
		{
			strcopy(breathSfx[client][Breathing_Light], sizeof(breathSfx[][]), LB_PUGMAN);

			int rnd = GetRandomInt(0, sizeof(MB_PUGMAN)-1);
			strcopy(breathSfx[client][Breathing_Medium], sizeof(breathSfx[][]), MB_PUGMAN[rnd]);

			rnd = GetRandomInt(0, sizeof(HB_PUGMAN)-1);
			strcopy(breathSfx[client][Breathing_Heavy], sizeof(breathSfx[][]), HB_PUGMAN[rnd]);
		}
		case Voice_Male:
		{
			strcopy(breathSfx[client][Breathing_Light], sizeof(breathSfx[][]), LB_MALE);
			strcopy(breathSfx[client][Breathing_Light], sizeof(breathSfx[][]), MB_MALE);
			int rnd = GetRandomInt(0, sizeof(HB_MALE)-1);
			strcopy(breathSfx[client][Breathing_Heavy], sizeof(breathSfx[][]), HB_MALE[rnd]);
		}
	}

	initedSounds[client] = true;
}

any min(any a, any b) { return (a < b) ? a : b; }
any max(any a, any b) { return (a > b) ? a : b; }