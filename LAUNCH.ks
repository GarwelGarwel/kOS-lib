FUNCTION Echo
{
	PARAMETER msg.

	PRINT msg.
	LOG ROUND(MISSIONTIME, 1) + ";" + CHAR(34) + msg + CHAR(34) + ";;;;;;;;;" TO logFile.
}

FUNCTION EchoTime
{
	PARAMETER msg.
	
	SET m TO FLOOR(MISSIONTIME / 60).
	SET s TO FLOOR(MISSIONTIME - m * 60).
	IF s < 10 { SET sString TO "0" + s. }
	ELSE { SET sString TO "" + s. }
	PRINT m + ":" + sString + ": " + msg.
	LOG ROUND(MISSIONTIME, 1) + ";" + CHAR(34) + msg + CHAR(34) + ";;;;;;;;;" TO logFile.
}

LOCK DateTime TO FLOOR(1 + TIME:SECONDS / 3600 / 6 / 426) + "-" + FLOOR(1 + MOD(TIME:SECONDS, 3600 * 6 * 426) / (3600 * 6)) + " " + TIME:CLOCK.

SET logFile TO "0:/logs/" + SHIP:NAME:SPLIT(" ")[0] + " Launch Data.csv".
LOG "MET;Message;Stage;Alt;Airspeed;SAC;TAC;Throttle;Ap;Pe;Qx1000" TO logFile.

Echo("Launching " + SHIP:NAME).

IF NOT (DEFINED TA) OR (TA < 70000) { SET TA TO 100000. }
Echo ("Target Apoapsis (TA): " + TA + " m").
IF NOT (DEFINED TP) OR (TP < 70000) { SET TP TO TA. }
Echo ("Target Periapsis (TP): " + TP + " m").
IF NOT (DEFINED GTS) { SET GTS TO 3000. }
Echo ("Gravity turn starts (GTS) @ " + GTS + " m").
IF NOT (DEFINED TOI) { SET TOI TO 0. }
Echo ("Target orbital inclination (TOI) is " + TOI + " deg").
IF NOT (DEFINED acProfile) { SET acProfile TO LIST(15, 30, 30). }
IF NOT (DEFINED altProfile) { SET altProfile TO LIST(10000, 30000, 60000). }
Echo ("Acceleration profile has " + (acProfile:LENGTH - 1) + " nodes").
IF NOT (DEFINED CBP) { SET CBP TO 40. }
Echo ("Circularization burn precession (CBP) is " + CBP + " s").
// Set checkFlameout to false if there are engines on the same stage that don't finish simultaneously
IF NOT (DEFINED CFO) { SET cfo TO TRUE. }
Echo("Flameout check (CFO) is " + CFO).

LOCK maxAc TO AVAILABLETHRUST / MASS.  // Max acceleration
LOCK TAC TO AVAILABLETHRUST * THROTTLE / MASS.  // Thrust ACceleration (TAC)
SET lastSpeed TO 0.
SET SAC TO 0.  // Surface Speed ACceleration (SAC)
LOCK inSpace TO ALTITUDE > 70000.
reachedAp OFF.
circularization OFF.
isFlameout OFF.
SET phase TO 1.
LOCK targetAc TO acProfile[phase - 1].

IF SHIP:STATUS = "PRELAUNCH"
{
	SAS ON.
	SET THROTTLE TO 0.
	// Countdown
	FROM { SET t TO 10. } UNTIL t = 0 STEP { SET t TO t - 1. } DO
	{
		PRINT "Launch in " + t + " s".
		WAIT 1.
	}

	// Logging launch time
	WHEN SHIP:STATUS <> "PRELAUNCH" THEN
	{ EchoTime("Liftoff at " + DateTime). }
}

CLEARSCREEN.
PRINT " ".
PRINT " ".
PRINT " ".
PRINT " ".

LOCK THROTTLE TO targetAc / MAX(maxAc, targetAc).

// After clearing tower, disable SAS and switch to kOS "cooked control"
WHEN ALTITUDE > 300 THEN
{
	EchoTime("Launch tower cleared. Switching to kOS steering control. Initiating roll.").
	SAS OFF.
	LOCK STEERING TO HEADING(90 + TOI, 90).
}

// Gravity turn starts at specified altitude and ends at 70 km
WHEN ALTITUDE > GTS THEN
{
	EchoTime("Starting gravity turn.").
	LOCK STEERING TO HEADING(90 + TOI, 90 * (70000 - ALTITUDE) / (70000 - GTS)).
}

// Action Group 1: In-Space Procedure Run 1 (e.g. deploy fairing)
WHEN ALTITUDE > 65000 THEN
{
	EchoTime("Approaching space. AG1 Run 1.").
	TOGGLE AG1.
}

// End gravity turnm, fix steering to horizontal and toggle Action Group 1 (deploy solar panels, antennas, etc.)
WHEN inSpace THEN
{
	EchoTime("Reached space. Reorienting for horizontal flight. AG1 Run 2.").
	TOGGLE AG1.
	LOCK STEERING TO HEADING(90 + TOI, 0).
}

// Switching profile intervals upon reaching specified altitudes
WHEN NOT reachedAp AND ALTITUDE > altProfile[phase - 1] THEN
{
	IF phase >= altProfile:LENGTH - 1
	{
		EchoTime("Phase " + phase + " over. Full throttle.").
		LOCK THROTTLE TO 1.
		LOCK targetAc TO 100.
		SET phase TO phase + 1.
	}
	ELSE
	{
		SET phase TO phase + 1.
		EchoTime("Moving to phase " + phase + ".").
		RETURN TRUE.
	}
}

// Cutting off engine after reaching (99% of target Ap)
WHEN SHIP:OBT:APOAPSIS >= TA * 0.99 THEN
{
	EchoTime("Target Ap reached. Coasting.").
	LOCK THROTTLE TO 0.
	reachedAp ON.
}

// Starting circularization burn before reaching Ap
WHEN reachedAp AND ETA:APOAPSIS < CBP THEN
{
	EchoTime("Burning to circularize.").
	LOCK THROTTLE TO 1.
	circularization ON.
	SET minETA TO CBP.
}

// Aborting if moving downwards
WHEN (VERTICALSPEED < -1) AND NOT reachedAp THEN
{
	EchoTime("CRITICAL FAILURE: Negative vertical speed detected. Aborting.").
	ABORT ON.
	WAIT 1.
	IF (ALTITUDE < 30000) AND (AIRSPEED < 500)
	{ CHUTES ON. }
	LOCK STEERING TO SRFRETROGRADE.
	exit ON.
}

SET logTime TO 0.
SET flameoutCheckTime TO 0.
exit OFF.

// Main loop
UNTIL ((SHIP:PERIAPSIS * SHIP:APOAPSIS >= TP * TA) AND (SHIP:PERIAPSIS > 70000)) OR exit
{
	PRINT "Thrust phase: " + phase + " / " + acProfile:LENGTH + "    " AT (0, 0).
	PRINT "Throttle:     " + ROUND(THROTTLE * 100) + "%    " AT (0, 1).
	PRINT "Acceleration: " + ROUND(SAC, 2) + " m/s^2 (" + ROUND(SAC / 9.81, 2) + " g)    " AT (0, 2).
	PRINT "Qx1000:       " + ROUND(SHIP:Q * 1000) + "    " AT (0, 3).
	
	IF MISSIONTIME >= logTime
	{
		SET SAC TO (AIRSPEED - lastSpeed) / (MISSIONTIME - logTime + 1).
		SET lastSpeed TO AIRSPEED.
		LOG ROUND(MISSIONTIME) + ";;" + STAGE:NUMBER + ";" + ROUND(ALTITUDE) + ";" + ROUND(AIRSPEED) + ";" + ROUND(SAC, 2) + ";" + ROUND(TAC, 2) + ";" + ROUND(THROTTLE * 100) + "%;" + ROUND(SHIP:APOAPSIS) + ";" + ROUND(SHIP:PERIAPSIS) + ";" + ROUND(SHIP:Q * 1000) TO logFile.
		SET logTime TO MISSIONTIME + 1.
	}
	
	IF MISSIONTIME >= flameoutCheckTime
	{
		// Finding engines that are out of fuel
		IF CFO
		{
			LIST ENGINES IN allEngines.
			SET isFlameout TO FALSE.
			FOR eng IN allEngines
			{
				IF eng:FLAMEOUT
				{
					EchoTime(eng:TITLE + " has flamed out.").
					SET isFlameout TO TRUE.
					BREAK.
				}
			}
		}
		
		// If any engine is out of fuel or max thrust is 0, stage
		IF isFlameout OR MAXTHRUST = 0
		{
			EchoTime("Activating stage " + STAGE:NUMBER + ".").
			WAIT UNTIL STAGE:READY.
			STAGE.
			// Do not check for flameout for the next 3 seconds
			SET flameoutCheckTime TO MISSIONTIME + 3.
		}
	}
	
	IF circularization
	{
		IF THROTTLE > 0 AND ETA:APOAPSIS < ETA:PERIAPSIS
		{
			IF ETA:APOAPSIS > minETA + 1
			{
				EchoTime("Cutting off engines until Ap ETA is " + ROUND(minETA / 2, 1) + " s.").
				LOCK THROTTLE TO 0.
			}
			ELSE
			{ SET minETA TO MIN(ETA:APOAPSIS, minETA). }
		}
		
		IF THROTTLE = 0 AND (ETA:APOAPSIS < minETA / 2 OR VERTICALSPEED < 0)
		{
			EchoTime("Restarting engines.").
			LOCK THROTTLE TO 1.
		}
	}
}

SET THROTTLE TO 0.

EchoTime("Target orbit achieved.").
Echo("Pe: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km").
Echo("Ap: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km").

DELETEPATH("LAUNCH").
RUNPATH("COPY", "XMN").
