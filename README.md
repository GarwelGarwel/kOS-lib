# Garwel's kOS Script Library

This is a collection of scripts I use in my (rather hardcore) KSP career game. I update and improve them frequently. Feel free to use or edit them according to MIT license.

## How to Use

Simply download the raw files to your computer, put into the `Ships/Scripts` folder in your KSP install and edit if necessary. Then, during the game, run a command `COPYPATH("0:/<filename>", "").` in the terminal and then `RUN <filename>.`

## Signal Delay

For realism purposes, I emulate a signal delay in most of the scripts. It works best alongside my [Signal Delay](https://github.com/GarwelGarwel/SignalDelay) mod that introduces similar delay for most other actions (unfortunately, it's impossible to do that within kOS itself). It is done by the `DELAY.ks` script located in the `sys` folder. You need to copy that file to your kOS CPU. For it to work, you need to manually set the delay (just take the value displayed by the Signal Delay mod). Use this command to set delay to 12 seconds: `SET SD TO 12.` Delay is automatically set to 0 in the SOI of Kerbin, Mun and Minmus.

## Logging

Some of the scripts log flight data to CSV files for analysis. KSC connection is required for the logging, but they can handly temporary loss of signal. The files are stored in the `Ships/Scripts/logs` folder in your KSP install and can be opened with Excel.

## Parameters

Many of the scripts have optional parameters that you can set *before* running the script. For a list of parameters and their default values, see the source code (they usually start with `IF NOT (DEFINED ...)`).

## Scripts List

- `DunaEDL`: Duna Entry, Descent and Landing for a chute- and engine-equipped lander
- `KerbinEDL`: Kerbin Entry, Descent and Landin for a chute- and heatshield-equipped reentry module
- `LAO`: Liftoff, Ascent and Orbit script to takeoff and go into orbit of a distant, non-atmospheric body (+logging)
- `LAUNCH`: Fully automatic launch into a Kerbin orbit (+logging)
- `NODE`: Creates an empty maneuver node in 2 minutes from now (used to address a KSP glitch)
- `RDA`: Rendezvous & Docking Active script for a powered approach and docking with the target vessel (+logging)
- `RDP`: Rendezvous & Docking Passive script for a vessel (e.g. a station) orientation towards the approaching vessel; run it simultaneously with RDA on the bigger vessel
- `SBLAND`: Suicide Burn Landing script for non-atmospheric bodies with an optional waypoint target (+logging)
- `SBLAND`: An experimental (hopefully improved) version of SBLAND (+logging)
- `XMN`: eXecute Maneuver Node script to do just that (based on the example provided in kOS Documentation)
