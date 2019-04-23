RUNONCEPATH("DELAY").

LOCK DateTime TO FLOOR(1 + TIME:SECONDS / (3600 * 6 * 426)) + "-" + FLOOR(1 + MOD(TIME:SECONDS, 3600 * 6 * 426) / (3600 * 6)) + " " + TIME:CLOCK.

FUNCTION TTime
{
	PARAMETER t.
	
	IF t >= 0
	{ SET res TO "+". }
	ELSE
	{ SET res TO "-". }
	SET t TO ABS(FLOOR(t)).
	SET h TO FLOOR(t / 3600).
	IF h > 0
	{
		SET res TO res + h + ":".
		SET t TO t - h * 3600.
	}
	SET m TO FLOOR(t / 60).
	IF m > 0
	{
		IF (m < 10) AND (h > 0)
		{ SET res TO res + "0". }
		SET res TO res + m + ":".
		SET t TO t - m * 60.
	}
	IF (t < 10) AND ((m > 0) OR (h > 0))
	{ SET res TO res + "0". }
	SET res TO res + t.
	RETURN res.
}

FUNCTION Log2
{
	PARAMETER msg.
	
	IF (HOMECONNECTION:ISCONNECTED)
	{ LOG msg TO logFile. }
	ELSE
	{ SET logCache TO logCache + msg + Char(13). }
}

ON HOMECONNECTION:ISCONNECTED
{
	IF HOMECONNECTION:ISCONNECTED
	{
		Echo("Signal acquired.").
		Log2(logCache).
		SET logCache TO "".
	}
	ELSE
	{ Echo("Signal lost."). }
	RETURN TRUE.
}

FUNCTION Echo
{
	PARAMETER msg.

	PRINT "T" + TTime(TIME:SECONDS - StartTime) + ": " + msg.
	Log2(TTime(TIME:SECONDS - StartTime) + ";" + CHAR(34) + msg + CHAR(34) + ";;;;;;;;;;;").
}

FUNCTION Display
{
	PARAMETER msg.

	PRINT msg + "            " AT (0, line).
	SET line TO line + 1.
}

SET StartTime TO TIME:SECONDS + 10.

SET logFile TO "0:/logs/" + SHIP:NAME:SPLIT(" ")[0] + " LAO Data.csv".
SET logCache TO "".
Log2("MET;Message;Stage;Alt;Alt Radar;Airspeed;Ac;Throttle;Ap;Pe").

Echo("Liftoff / Ascent to Orbit (LAO) Script for " + SHIP:NAME).

IF NOT (DEFINED TA) { SET TA TO 30000. }
Echo ("Target Altitude (TA): " + TA + " m").
SET LSA TO ALTITUDE.
Echo ("Launch Site Altitude (LSA) @ " + ROUND(LSA) + " m").
IF NOT (DEFINED HFA) OR (HFA <= LSA) { SET HFA TO LSA + 5000. }
SET HFA TO MIN(HFA, TA).
Echo ("Horizontal Flight Altitude (HFA) @ " + ROUND(HFA) + " m").
IF NOT (DEFINED TOI) { SET TOI TO 0. }
Echo ("Target orbital inclination (TOI) is " + TOI + " deg").
IF NOT (DEFINED CBP) { SET CBP TO 20. }
Echo ("Circularization burn precession (CBP) is " + CBP + " s").
// Set checkFlameout to false if there are engines on the same stage that don't flame out simultaneously
IF NOT (DEFINED CFO) { SET cfo TO TRUE. }
Echo("Flameout check (CFO) is " + CFO).

LOCK maxAc TO AVAILABLETHRUST / MASS.  // Max acceleration
LOCK ac TO AVAILABLETHRUST * THROTTLE / MASS.  // Current thrust to mass ratio
SET reachedAp TO FALSE.
SET circularization TO FALSE.
SET isFlameout TO FALSE.

IF SHIP:STATUS = "LANDED"
{
	SET THROTTLE TO 0.
	// Countdown
	FROM { SET t TO 10. } UNTIL t = 0 STEP { SET t TO t - 1. } DO
	{
		PRINT "Launch in " + t + " s".
		WAIT 1.
	}
	KUNIVERSE:TIMEWARP:CANCELWARP.
}

CLEARSCREEN.
PRINT " ".
PRINT " ".
PRINT " ".

ON AG9
{ exit ON. }

ON SAS
{ SAS OFF. }

// After take-off, disable SAS and switch to kOS "cooked control"
WHEN SHIP:STATUS <> "LANDED" THEN
{
	SET StartTime TO TIME:SECONDS.
	Echo("Liftoff at " + DateTime).
	SAS OFF.
	GEAR OFF.
	LOCK STEERING TO HEADING(90 + TOI, MAX(90 * (HFA - ALTITUDE) / (HFA - LSA), 0)).
}

// Cutting off engine after reaching 99% of TA
WHEN SHIP:OBT:APOAPSIS >= TA * 0.99 THEN
{
	Echo("Target Ap reached. Coasting.").
	SET THROTTLE TO 0.
	LOCK STEERING TO HEADING(90 + TOI, 0).
	reachedAp ON.
}

// Starting circularization burn before reaching Ap
WHEN reachedAp AND ETA:APOAPSIS < CBP THEN
{
	KUNIVERSE:TIMEWARP:CANCELWARP.
	Echo("Burning to circularize.").
	SET THROTTLE TO 1.
	circularization ON.
	SET minETA TO CBP.
}

// Switching to SBLAND script if moving downwards before reaching target Ap
WHEN NOT reachedAp AND VERTICALSPEED < -1 AND EXISTS("SBLAND") THEN
{
	Echo("CRITICAL FAILURE: Negative vertical speed detected before reaching target Ap. Attempting to land.").
	RUNPATH("SBLAND").
	exit ON.
}

SET logTime TO TIME:SECONDS.
SET flameoutCheckTime TO 0.
exit OFF.
SET THROTTLE TO 1.

// Main loop
UNTIL ((SHIP:PERIAPSIS + SHIP:APOAPSIS >= 2 * TA) AND (SHIP:STATUS = "ORBITING")) OR exit
{
	SET line TO 0.
	Display("Radar Alt:    " + ROUND(ALT:RADAR) + " m").
	Display("Throttle:     " + ROUND(THROTTLE * 100) + "%")..
	Display("Acceleration: " + ROUND(ac, 2) + " / " + ROUND(maxAc, 2) + " m/s^2").
	
	IF TIME:SECONDS >= logTime
	{
		Log2(ROUND(TIME:SECONDS) + ";;" + STAGE:NUMBER + ";" + ROUND(ALTITUDE) + ";" + ROUND(ALT:RADAR) + ";" + ROUND(AIRSPEED) + ";" + ROUND(ac, 2) + ";" + ROUND(THROTTLE * 100) + "%;" + ROUND(SHIP:APOAPSIS) + ";" + ROUND(SHIP:PERIAPSIS)).
		SET logTime TO TIME:SECONDS + 1.
	}
	
	IF TIME:SECONDS >= flameoutCheckTime
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
					Echo(eng:TITLE + " has flamed out.").
					SET isFlameout TO TRUE.
					BREAK.
				}
			}
		}
		
		// If any engine is out of fuel or max thrust is 0, stage
		IF isFlameout OR MAXTHRUST = 0
		{
			Echo("Activating stage " + STAGE:NUMBER + ".").
			WAIT UNTIL STAGE:READY.
			STAGE.
			// Do not check for flameout for the next 3 seconds
			SET flameoutCheckTime TO TIME:SECONDS + 3.
		}
	}
	
	IF circularization
	{
		IF THROTTLE > 0 AND ETA:APOAPSIS < ETA:PERIAPSIS
		{
			IF ETA:APOAPSIS > minETA + 1
			{
				Echo("Cutting off engines until Ap ETA is " + ROUND(minETA / 2, 1) + " s.").
				SET THROTTLE TO 0.
			}
			ELSE
			{ SET minETA TO MIN(ETA:APOAPSIS, minETA). }
		}
		
		IF (THROTTLE = 0) AND ((ETA:APOAPSIS < minETA / 2) OR (VERTICALSPEED < 0))
		{
			Echo("Restarting engines.").
			SET THROTTLE TO 1.
		}
	}
}

SET THROTTLE TO 0.
UNLOCK THROTTLE.

Echo("Target orbit achieved.").
Echo("Pe: " + ROUND(SHIP:PERIAPSIS / 1000, 1) + " km").
Echo("Ap: " + ROUND(SHIP:APOAPSIS / 1000, 1) + " km").
