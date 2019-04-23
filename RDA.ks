RUNONCEPATH("delay.ks").

LOCK DateTime TO FLOOR(1 + TIME:SECONDS / (3600 * 6 * 426)) + "-" + FLOOR(1 + MOD(TIME:SECONDS, 3600 * 6 * 426) / (3600 * 6)) + " " + TIME:CLOCK.

FUNCTION Log2
{
	PARAMETER msg.
	
	IF (HOMECONNECTION:ISCONNECTED)
	{ LOG msg TO logFile. }
	ELSE
	{ SET logCache TO logCache + msg + Char(13) + Char(10). }
}

ON HOMECONNECTION:ISCONNECTED
{
	IF HOMECONNECTION:ISCONNECTED
	{
		Log2(logCache).
		Echo("Signal acquired.").
		SET logCache TO "".
	}
	ELSE
	{ 
		PRINT DateTime + ": Signal lost.".
		Echo("Signal lost.").
	}
	RETURN TRUE.
}

FUNCTION Echo
{
	PARAMETER msg.
	
	IF (HOMECONNECTION:ISCONNECTED)
	{ PRINT DateTime + ": " + msg. }
	Log2(TIME:SECONDS +";" + CHAR(34) + msg + CHAR(34) + ";;;;;;;;;;;").
}

FUNCTION Display
{
	PARAMETER msg.

	IF (HOMECONNECTION:ISCONNECTED)
	{ PRINT msg + "            " AT (0, line). }
	SET line TO line + 1.
}

SET logFile TO "0:/logs/" + SHIP:NAME:SPLIT(" ")[0] + " Docking Data.csv".
SET logCache TO "".
Log2("UT;Message;Distance;TAS;TRM;Facing/TRM;TV/TRM;DV;Throttle").
Echo("Rendezvous & Docking Active (RDA) Script for " + SHIP:NAME).

IF NOT (DEFINED TVN)
{
	WAIT UNTIL HASTARGET.
	SET TVN TO TARGET:NAME.
}
SET TV TO VESSEL(TVN).
Echo("Target Vessel (TV): " + TV:NAME).
IF NOT (DEFINED DSR) { SET DSR TO 0.01. }
Echo("Distance/Speed Ratio (DSR) is " + DSR).
IF NOT (DEFINED SAD) { SET SAD TO 10000. }
Echo("Script Activation Distance (SAD) is " + SAD + " m").

WAIT UNTIL TV:DISTANCE < SAD.
KUNIVERSE:TIMEWARP:CANCELWARP.

SAS OFF.

WHEN TV:UNPACKED AND NOT (DEFINED TP) THEN
{
	Echo("Choosing a docking port to target...").
	LIST DOCKINGPORTS IN dpList.
	FOR p1 IN dpList
	{
		IF p1:STATE = "READY"
		{
			FOR p2 IN TV:DOCKINGPORTS
			{
				IF p2:STATE = "READY" AND p2:NODETYPE = p1:NODETYPE
				{
					SET LP TO p1.
					SET TP TO p2.
					BREAK.
				}
			}
			IF DEFINED LP { BREAK. }
		}
	}
	IF NOT (DEFINED LP)
	{
		Echo("Error: Could not find a pair of matching docking ports on this vessel and the target. Executing approach instead.").
		//quit ON.
	}
	ELSE
	{
		SET LPH TO HIGHLIGHT(LP, GREEN).
		SET TPH TO HIGHLIGHT(TP, YELLOW).
		Echo("Local Port (LP) is " + LP:NAME).
		Echo("Target Port (TP) is " + TP:NAME).
	}
	RETURN TRUE.
}

SET oldDistance TO TV:DISTANCE.
SET TAS TO 0.  // Target Approach Speed (TAS) is how fast the target is moving toward (+) or away (-) form the vessel
SET oldPosition TO TV:POSITION.
SET TRM TO V(0, 0, 0).  // Target Relative Movement (TRM) is a vector showing movement of the target relative to the vessel; its magnitude is NOT the same as speed (because some movement is parallel)
LOCK TRM2 TO TV:DIRECTION:VECTOR * MIN(TV:DISTANCE * DSR, MAX(TV:DISTANCE * DSR * 0.5, TRM:MAG)).  // Sought TRM
LOCK DV TO (TRM2 - TRM):MAG.  // Delta V: how to change current speed to achieve TRM2
SET updateTime TO TIME:SECONDS.
SET logTime TO TIME:SECONDS.
finalApproach OFF.
acquired OFF.
quit OFF.

LOCK STEERING TO TRM2 - TRM.

// Quit script when 9 is pressed
ON AG9 { quit ON. }

ON SAS { SAS OFF. }

CLEARSCREEN.
PRINT " ".
PRINT " ".
PRINT " ".
PRINT " ".
PRINT " ".
PRINT " ".
PRINT " ".
PRINT " ".

UNTIL quit
{
	SET line TO 0.
	Display("Distance:  " + ROUND(TV:DISTANCE) + " m").
	Display("TAS:       " + ROUND(TAS, 1) + " m/s").
	Display("TRM:       " + ROUND(TRM:MAG, 1) + " m/s").
	Display("Face/TVD: " + ROUND(VANG(FACING:VECTOR, TV:DIRECTION:VECTOR)) + " deg").
	Display("Face/TRM: " + ROUND(VANG(FACING:VECTOR, TRM)) + " deg").
	Display("TVD/TRM:   " + ROUND(VANG(TV:DIRECTION:VECTOR, TRM)) + " deg").
	Display("TRM/TRM2:  " + ROUND(VANG(TRM, TRM2)) + " deg").
	Display("DV:        " + ROUND(DV, 1) + " m/s").

	SET interval TO TIME:SECONDS - updateTime.
	IF interval > 0
	{
		SET TAS TO (oldDistance - TV:DISTANCE) / interval.
		SET oldDistance TO TV:DISTANCE.
		SET TRM TO (oldPosition - TV:POSITION) / interval.
		SET oldPosition TO TV:POSITION.
		IF TIME:SECONDS >= logTime + 1
		{
			Log2(ROUND(TIME:SECONDS) + ";;" + ROUND(TV:DISTANCE) + ";" + ROUND(TAS, 1) + ";" + ROUND(TRM:MAG, 1) + ";" + ROUND(VANG(FACING:VECTOR, TRM)) + ";" + ROUND(VANG(TV:DIRECTION:VECTOR, TRM), 1) + ";" + ROUND(DV, 1) + ";" + ROUND(THROTTLE * 100) + "%").
			SET logTime TO logTime + 1.
		}
		SET updateTime TO TIME:SECONDS.
	}
	
	IF THROTTLE = 0 AND DV > TRM2:MAG * 0.2 AND DV > 0.2 AND VANG(FACING:VECTOR, STEERING) < 5 AND NOT finalApproach
	{
		Echo("Activating engine.").
		SET THROTTLE TO MAX(DV * SHIP:MASS / AVAILABLETHRUST, 0.01).
	}
	
	IF THROTTLE > 0 AND (DV < TRM2:MAG * 0.1 OR DV < 0.1)
	{
		Echo("Cutting off engine.").
		SET THROTTLE TO 0.
	}
	
	IF TV:DISTANCE < 200 AND THROTTLE = 0 AND TAS < 1 AND TAS > 0 AND TV:DISTANCE * TAN(VANG(TV:DIRECTION:VECTOR, TRM)) < 2 AND NOT finalApproach
	{
		Echo("Beginning final approach.").
		finalApproach ON.
		LOCK STEERING TO TP:POSITION - LP:POSITION.
	}
	
	IF finalApproach AND (DEFINED LP) AND LP:STATE = "PREATTACHED" AND NOT acquired
	{
		Echo("Docking port acquired.").
		UNLOCK STEERING.
		acquired ON.
	}
	
	IF finalApproach AND (TAS < -1 OR TV:DISTANCE > 200)
	{
		Echo("Final approach failed. One more attempt.").
		finalApproach OFF.
		acquired OFF.
	}
	
	IF (DEFINED LP) AND LP:STATE:CONTAINS("DOCKED")
	{
		Echo(SHIP:NAME + " and " + TV:NAME + " have docked.").
		quit ON.
	}
}

IF DEFINED LPH
{
	LPH:ENABLED OFF.
	TPH:ENABLED OFF.
}

UNLOCK STEERING.
SET THROTTLE TO 0.

WAIT UNTIL HOMECONNECTION:ISCONNECTED.
WAIT 1.
