RUNONCEPATH("DELAY").

LOCK DateTime TO FLOOR(1 + TIME:SECONDS / (3600 * 6 * 426)) + "-" + FLOOR(1 + MOD(TIME:SECONDS, 3600 * 6 * 426) / (3600 * 6)) + " " + TIME:CLOCK.
LOCK connected TO HOMECONNECTION:ISCONNECTED.

FUNCTION Log2
{
	PARAMETER msg.

	IF (connected) { LOG msg TO logFile. }
	ELSE
	{ SET logCache TO logCache + msg + Char(13). }
}

ON connected
{
	IF connected
	{
		Log2(logCache).
		SET logCache TO "".
		Echo("Signal acquired.").
	}
	ELSE
	{
		PRINT "Signal lost.".
		Echo("Signal lost.").
	}
	RETURN TRUE.
}

FUNCTION Echo
{
	PARAMETER msg.

	IF connected
	{ PRINT DateTime + ": " + msg. }
	Log2(TIME:SECONDS +";" + CHAR(34) + msg + CHAR(34) + ";;;;;;;;;;").
}

FUNCTION Display
{
	PARAMETER msg.

	PRINT msg + "            " AT (0, line).
	SET line TO line + 1.
}

SET logFile TO "0:/logs/" + SHIP:NAME:SPLIT(" ")[0] + " DUNAEDL Data.csv".
SET logCache TO "".
Log2("UT;Message;Stage;Alt;Radar Alt;Speed;Ac;Max Ac;Throttle;TTT;Qx1000;Pe;Ap").

Echo("Duna Atmospheric Entry, Descent and Landing (DUNAEDL) for " + SHIP:NAME).

WAIT UNTIL ALTITUDE < 80000.
KUNIVERSE:TIMEWARP:CANCELWARP().

Echo("Preparing for atmospheric entry. Retracting fragile parts. May result in LOS.").
SAS OFF.
LOCK STEERING TO SRFRETROGRADE.
TOGGLE AG2.

WAIT UNTIL ALTITUDE < 72000.

Echo("Entered atmosphere. Conducting experiments.").
TOGGLE AG3.

LOCK maxAc TO AVAILABLETHRUST / SHIP:MASS.  // Max thrust Acceleration

LOCK TTT TO MAX((10000 - ALTITUDE) / VERTICALSPEED, 0).  // Time to Target Altitude

WHEN (TTT < 40) AND (AIRSPEED - 200 > TTT * maxAc) THEN
{
	Echo("Pre-chute powered braking.").
	SET THROTTLE TO 1.
}

WHEN AIRSPEED < 200 THEN
{
	Echo("Target speed achieved.").
	SET THROTTLE TO 0.
}

WHEN ALTITUDE < 16000 THEN
{
	Echo("Reached low atmosphere. Conducting experiments.").
	TOGGLE AG4.
	TOGGLE AG3.
}

WHEN (AIRSPEED < 400) OR (NOT CHUTESSAFE) THEN
{
	Echo("Deploying chutes and landing gear. Qx1000 = " + ROUND(SHIP:Q * 1000)).
	STAGE.
	CHUTES ON.
	GEAR ON.
}

WHEN (THROTTLE = 0) AND (AIRSPEED > 10) AND (AIRSPEED < 180) THEN
{
	Echo("Burning engine for landing assistance.").
	SET THROTTLE TO 1.
	RETURN TRUE.
}

WHEN (THROTTLE > 0) AND ((AIRSPEED < 2) OR (VERTICALSPEED > -2)) THEN
{
	Echo("Stop landing assistance burn.").
	SET THROTTLE TO 0.
	RETURN TRUE.
}

WHEN (ALT:RADAR <= 100) AND (AIRSPEED < 5) THEN
{
	Echo("Pre-touchdown hovering.").
	LOCK STEERING TO UP.
	LOCK THROTTLE TO BODY:MU / (BODY:RADIUS * BODY:RADIUS) / MAX(maxAc, 0.01).  // Set thrust to be equal to weight
}

SET curSpeed TO AIRSPEED.
SET ac TO 0.
SET logTime TO TIME:SECONDS.

CLEARSCREEN.
PRINT "".
PRINT "".
PRINT "".
PRINT "".

UNTIL ((SHIP:STATUS = "LANDED") AND (AIRSPEED < 0.1)) OR (ALTITUDE > 80000)
{
	SET line TO 1.
	IF connected
	{
		Display("Alt:   " + ROUND(ALT:RADAR) + " m").
		Display("Speed: " + ROUND(AIRSPEED, 1) + " m/s").
		Display("Acc:   " + ROUND(ac, 1) + " / " + ROUND(maxAc, 1) + " m/s^2").
		Display("Q:     " + ROUND(SHIP:Q * 1000) + " mAtm").
	}

	IF TIME:SECONDS >= logTime
	{
		SET ac TO (AIRSPEED - curSpeed) / (TIME:SECONDS - logTime + 1).
		SET curSpeed TO AIRSPEED.
		Log2(TIME:SECONDS + ";;" + STAGE:NUMBER + ";" + ROUND(ALTITUDE) + ";" + ROUND(ALT:RADAR) + ";" + ROUND(AIRSPEED, 1) + ";" + ROUND(ac, 2) + ";" + ROUND(maxAc, 1) + ";" + ROUND(THROTTLE * 100) + "%;" + ROUND(TTT) + ";" + ROUND(SHIP:Q * 1000) + ";" + ROUND(SHIP:PERIAPSIS) + ";" + ROUND(SHIP:APOAPSIS)).
		SET logTime TO TIME:SECONDS + 1.
	}
}

UNLOCK THROTTLE.
SET THROTTLE TO 0.
UNLOCK STEERING.
SAS ON.
TOGGLE AG1.
IF (SHIP:STATUS = "LANDED") { Echo("Landing successful!"). }
