# Garwel's kOS Script Library

This is a collection of scripts I use in my (rather hardcore) KSP career game. I update and improve them frequently. Feel free to use or edit them according to MIT license.

## How to Use

Simply download the raw files to your computer, put into the `Ships/Scripts` folder in your KSP install and edit if necessary. Then, during the game, run a command `COPYPATH("0:/<filename>", "").` in the terminal and then `RUN <filename>.`

## Signal Delay

For realism purposes, I emulate a signal delay in most of the scripts. It works best alongside my [Signal Delay](https://github.com/GarwelGarwel/SignalDelay) mod that introduces similar delay for most other actions (unfortunately, it's currently impossible to do that within kOS itself). It is done by the `DELAY.ks` script located in the `sys` folder. You need to copy that file to your kOS CPU. For it to work, you need to manually set the delay (just take the value displayed by the Signal Delay mod). Use this command to set delay to 12 seconds: `SET SD TO 12.` Delay is automatically set to 0 in the SOI of Kerbin, Mun and Minmus.

## Logging

Some of the scripts log flight data to CSV files for analysis. KSC connection is required for the logging, but they can handly temporary loss of signal. The files are stored in the `Ships/Scripts/logs` folder in your KSP install and can be opened with Excel. Log files usually include the first word in the vessel's name.

## Parameters

Many of the scripts have optional parameters that you can set *before* running the script. For a list of parameters and their default values, see the source code (they usually start with `IF NOT (DEFINED ...)`).

## Scripts

### DunaEDL

Duna Entry, Descent and Landing for a chute- and engine-equipped lander

Duna's atmosphere height is considered 75 km according to Realistic Atmospheres mod.

Realtime Data & Logging: Yes

Action Groups:
- 1: Safe situation actions (e.g. deploy antennas and solar panels, executed after successful landing or leaving atmosphere)
- 2: Pre-entry actions (e.g. retract antennas and solar panels)
- 3: Science experiments (executed at 72 km, then at 16 km altitudes)
- 4: Clear science (executed at 16 km altitude before the second call of AG3)

### KerbinEDL

Kerbin Entry, Descent and Landin for a chute- and heatshield-equipped reentry module

Ensure that chutes deployment is the next stage and heatshield decoupling (if present) is the one after it. Otherwise, use `MANSTAGE` parameter.

Parameters:
- `MANSTAGE`: Manual staging of chutes and heathshield decoupler to override automatics. Just define this variable by assigning any value to it and then follow on-screen tips for when to stage.

### LAO

Liftoff, Ascent and Orbit script to takeoff and go into orbit of a non-atmospheric body

Realtime Data & Logging: Yes

Parameters:
- `TA`: Target Altitude of the circular orbit, default = 30,000 m
- `HFA`: Horizontal Flight Altitude (above "sea level"), when the vessel ends its gravity turn and starts burning horizontally, default = 5,000 m above takeoff altitude
- `TOI`: Target Orbital Inclination in degrees, may be very inaccurate for takeoffs from high latitudes, deault = 0
- `CBP`: Circularization Burn Precession, how many seconds before apoapsis to start circularization burn, increase for lower TWR vessels, default = 20 s
- `CFO`: Check Flame-Out of engines, useful for strap-on boosters, but disable if you have multiple engines on one stage that flameout separately (e.g. an LFO engine and an SRB), default = True

### LAUNCH

Automatic launch into a Kerbin orbit

Realtime Data & Logging: Yes

Action Groups:
- 1: In-space actions, run twice at 65 km and at 70 km altitutde (e.g. to eject fairing and deploy solar panels)

Parameters:
- `TA`: Target Apoapsis, default = 100,000 m
- `TP`: Target Periapsis, default = TA (i.e. circular orbit)
- `GTS`: Gravity Turn Start Altitude above sea level, default = 3000 m
- `TOI`: Target Orbital Inclination in degrees, may be very inaccurate for takeoffs from high latitudes, deault = 0
- `acProfile` & `altProfile`: kOS lists that define target accelerations at altitude ranges, only change them if you know what you are doing
- `CBP`: Circularization Burn Precession, how many seconds before apoapsis to start circularization burn, increase for lower TWR vessels, default = 40 s
- `CFO`: Check Flame-Out of engines, useful for strap-on boosters, but disable if you have multiple engines on one stage that flameout separately (e.g. an LFO engine and an SRB), default = True

### NODE

Creates an empty maneuver node in 2 minutes from now (used to address a KSP glitch)

### RDA

Rendezvous & Docking Active script for a powered approach and docking with the target vessel

Run this script on the approaching vessel. It uses main engine to correct trajectory, slowly approach, automatically select the target port and dock with the another vessel. Press '9' to abort the script.

Realtime Data & Logging: Yes

Parameters:
- `TVN`: Target Vessel Name to manually define which vessel to approach, default is the current target
- `DSR`: Distance/Speed Ratio, the lower, the slower will be the approach, default = 0.01 (i.e. approach speed will be 10 m/s at 1000 m distance etc.)
- `SAD`: Script Activation Distance, how far from the target vessel to start maneuvering, default = 10,000 m

### RDP

Rendezvous & Docking Passive script for a vessel orientation towards the approaching vessel

Run this script on the bigger vessel (e.g. a station) simultaneously with RDA. It won't use any engines and will instead maintain the correct orientation of the docking port.

Parameters:
- `TVN`: Target Vessel Name to manually define which vessel to approach, default is the current target

### SBLAND

Suicide Burn Landing script for non-atmospheric bodies

This script is used to auto-land a vessel in suborbital traectory over a non-atmospheric body. It initiates the "suicide burn" (often a series of burns) and then very slowly descends on the surface. Optionally, it can try to target a waypoint, but you need to be flying over it. Press '9' to abort the script.

Realtime Data & Logging: Yes

Parameters:
- `maxSpeed`: Maximum allowed landing speed, set it according to your vessel's sturdiness, default = 6 m/s
- `minSpeed`: Minimum landing speed, too low value will make descent slow and fuel-consuming, default = 2 m/s
- `hoverAlt`: Hovering Altitude above ground, when the vessel starts a gentle descent, default = 100 m
- `uprightAlt`: Upright Altitude above ground, when the vessel is positioned vertically just before touchdown, change according to the vessel's height, default = 10 m
- `TWP`: Target Waypoint name, set it if you want the vessel to start suicide burn in time to land close to the waypoint

### SBLAND2

An experimental (hopefully a bit more accurate) version of SBLAND, uses the same parameters as.

### XMN

Execute Maneuver Node script to do just what it says on the tin (based on the example provided in kOS Documentation)

It is rather precise, but it doesn't take into account TWR changes due to fuel depletion and staging, so you can set burn time manually.

Parameters:
- `BD`: Burn Duration to override automatic calculation
