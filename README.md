# [NMRiH] Audible Breathing
Makes breathing sounds audible to nearby teammates and spectators

## Installation
- (Optional) Upgrade to Sourcemod 1.11.0.6506 or higher. This will enable some extra features.
- Grab the latest zip from the [releases](https://github.com/dysphie/nmrih-audible-breathing/releases) section.
- Extract the contents into `addons/sourcemod`
- Load the plugin (`sm plugins load nmrih-audible-breathing` in server console)

## ConVars

ConVars are stored in `cfg/sourcemod/plugin.audible-breathing.cfg`

- `sm_audible_breath_firstperson` (1/0, Default: 1)
  - Play breathing sounds when spectating someone in first person

- `sm_audible_hb_firstperson` (1/0, Default: 1)
  - Play heartbeat sounds when spectating someone in first person

- `sm_audible_breath_thirdperson` (1/0, Default: 1)
  - Play breathing sounds when near another person 
