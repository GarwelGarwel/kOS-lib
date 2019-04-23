PRINT "SCRIPT UNFINISHED!!!".
WAIT 5.

RUNONCEPATH("delay.ks").

FUNCTION Echo
{
	PARAMETER msg.

	SET m TO TIME:CALENDAR + " " + TIME:CLOCK + ": " + msg;
	PRINT m.
	LOG m TO logFile.
}

CLEARSCREEN.
PRINT "Waypoint Non-Atmospheric Landing Script".
SET logFile TO "0:/logs/" + SHIP:NAME:SPLIT(" ")[0] + " Landing.log".

IF NOT (DEFINED targetWP)
{
	PRINT "Warning: targetWP undefined!".
	SET targetWP TO "".
}

LIST ALLWAYPOINTS IN waypoints.
FOR wpi IN waypoints
{
	IF (wpi:BODY = SHIP:BODY) AND wpi:GROUNDED AND ((targetWP = "") OR (wpi:NAME = targetWP))
	{
		SET wp TO wpi.
		BREAK.
	}
}

IF NOT (DEFINED wp)
{
	PRINT "ERROR: Suitable waypoint " + targetWP + " not found!".
	RETURN.
}

SET lz TO wp:GEOPOSITION.
LOCK geoDist TO lz:DISTANCE
LOCK lz:ALTITUDEPOSITION(SHIP:ALTITUDE)

Echo("Waypoint " + wp:NAME + " found at " + lz + ", altitude " + wp:ALTITUDE + " m.").
Echo("Direct line distance to LZ is " + lz:DISTANCE + " m.").

SET THRUST TO 0.

WAIT UNTIL lz:DISTANCE < 50000.

SET flameoutCheckTime TO TIME:CLOCK.

WHEN (MAXTHRUST = 0) AND (flameoutCheckTime >= TIME:CLOCK) THEN
{
	Echo("Activating stage " + STAGE:NUMBER + ".").
	WAIT UNTIL STAGE:READY.
	STAGE.
	SET flameoutCheckTime TO TIME:CLOCK + 3.
}

LOCK acc TO MAXTHRUST / SHIP:MASS.

WAIT UNTIL 