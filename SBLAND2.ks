RUNONCEPATH("DELAY").

LOCK DateTime TO FLOOR(1 + TIME:SECONDS / (3600 * 6 * 426)) + "-" + FLOOR(1 + MOD(TIME:SECONDS, 3600 * 6 * 426) / (3600 * 6)) + " " + TIME:CLOCK.

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

	PRINT DateTime + ": " + msg.
	Log2(TIME:SECONDS +";" + CHAR(34) + msg + CHAR(34) + ";;;;;;;;;;;;;;").
}

FUNCTION Display
{
	PARAMETER msg.

	PRINT msg + "            " AT (0, line).
	SET line TO line + 1.
}

FUNCTION LogFuel
{
	Echo("Ship mass: " + ROUND(SHIP:MASS, 3) + " t").
	LIST RESOURCES IN ResList.
	FOR Res IN ResList
	{
		IF Res:NAME = "LiquidFuel" OR Res:NAME = "Oxidizer" OR Res:NAME = "LqdHydrogen" OR Res:NAME = "XenonGas" OR Res:NAME = "ArgonGas"
		{ Echo(Res:NAME + ": " + ROUND(Res:AMOUNT, 2) + " / " + ROUND(Res:CAPACITY, 2)). }
	}
}

CLEARSCREEN.
SET logFile TO "0:/logs/" + SHIP:NAME:SPLIT(" ")[0] + " Landing Data.csv".
SET logCache TO "".
Log2("UT;Message;Alt;Speed;VSpeed;HSpeed;Acc;GA;MAC;Throttle;SBD;TTI;SRP;DTLZ;TDIST;TBEAR").
Echo("Suicide Burn Landing Script (SBLAND) for " + SHIP:NAME).

IF NOT (DEFINED maxSpeed) { SET maxSpeed TO 6. }
Echo("Max Landing Speed: " + maxSpeed + " m/s").
IF NOT (DEFINED minSpeed) { SET minSpeed TO 2. }
Echo("Min Landing Speed: " + minSpeed + " m/s").
IF NOT (DEFINED hoverAlt) { SET hoverAlt TO 100. }
Echo("Hovering Altitude: " + hoverAlt + " m").
IF NOT (DEFINED uprightAlt) { SET uprightAlt TO 10. }
Echo("Upright Altitude: " + uprightAlt + " m").
IF DEFINED TWP
{
	SET WPList TO ALLWAYPOINTS().
	FOR WPItem IN WPList
	{
		IF WPItem:NAME = TWP
		{
			SET WP TO WPItem.
			SET TGEO TO WP:GEOPOSITION.
			//LOCK TPOS TO TGEO:POSITION.
			LOCK TDIST TO TGEO:DISTANCE.
			LOCK TBEAR TO TGEO:BEARING.  // Angle between Heading and Target direction
			LOCK THEAD TO HEADING(TGEO:HEADING, 0).  // Compass Heading towards Target in horizontal plane
			Echo("Target Waypoint (WP): " + WP:NAME + " @ " + TGEO + " (" + ROUND(TDIST) + " m away)").
			BREAK.
		}
		ELSE
		{
			SET TGEO TO 0.
			SET TDIST TO 0.
			SET TBEAR TO 0.
			SET THEAD TO 0.
		}
	}
}

UNTIL NOT HASNODE
{
	Echo("Running XMN routine for the upcoming maneuver node...").
	RUNPATH("XMN").
	Echo("Maneuver node executed. Back to SBLAND.").
}

Echo("Body: " + BODY:NAME).
LogFuel.

IF PERIAPSIS > 0
{
	Echo("WARNING: The vessel's Pe = " + ROUND(PERIAPSIS) + ". Cannot conduct a suicide burn unless Pe is negative.").
	//WAIT UNTIL PERIAPSIS < 0.
}

LOCK SRP TO 90 - VANG(SRFRETROGRADE:VECTOR, UP:VECTOR).  // Surface retrograde pitch
LOCK srfSpeed TO VELOCITY:SURFACE:MAG.  // Surface speed
LOCK HALFRAD TO BODY:RADIUS + ALTITUDE - ALT:RADAR / 2.  // Distance from body's center at half current altitude above ground
LOCK GA TO BODY:MU / (HALFRAD * HALFRAD) - GROUNDSPEED * GROUNDSPEED / HALFRAD.  // Gravitational acceleration at half the current altitude
Echo("Gravitational acceleration (GA): ~" + ROUND(GA, 2) + " m/s/s").
LOCK MAC TO AVAILABLETHRUST / MASS.  // Ship's max acceleration
IF MAC <= GA { Echo("ERROR: Cannot calculate a suicide burn with gravity acceleration of " + ROUND(GA, 1) + " m/s/s and ship's max acceleration of " + ROUND(MAC, 1) + " m/s/s!"). }

LOCK SBD TO srfSpeed / (MAC - GA * VERTICALSPEED / srfSpeed).  // Suicide Burn Duration
LOCK TTI TO (SQRT(MAX(VERTICALSPEED * VERTICALSPEED + 2 * ALT:RADAR * GA, 0)) + VERTICALSPEED) / GA.  // Time To Impact without thrust
LOCK TTT TO SQRT(VERTICALSPEED * VERTICALSPEED / ((MAC - GA) * (MAC - GA)) - 2 * ALT:RADAR / (MAC - GA)) - VERTICALSPEED / (MAC - GA).  // Time to Touchdown with Thrust
LOCK DTLZ TO GROUNDSPEED * SBD - MAC * COS(SRP) * SBD * SBD / 2.  // Estimated Distance To Landing Zone if suicide burn starts now

SET lastSpeed TO srfSpeed.
SET ac TO 0.
SET logTime TO TIME:SECONDS.
SET hovering TO FALSE.

GEAR ON.
SAS OFF.
LOCK STEERING TO SRFRETROGRADE.

// Suicide burn
WHEN ((TTI <= SBD) OR ((TDIST > 0) AND (TDIST <= DTLZ))) AND (srfSpeed > maxSpeed) AND (THROTTLE = 0) THEN
{
	KUNIVERSE:TIMEWARP:CANCELWARP.
	Echo("Activating engine for suicide burn.").
	SET THROTTLE TO 1.
	RETURN TRUE.
}

// Cut off engine if speed is below minSpeed or if going up
WHEN (((VELOCITY:SURFACE:MAG < minSpeed) AND NOT hovering) OR (VERTICALSPEED > 0)) AND (THROTTLE > 0) THEN
{
	Echo("Cutting off engine.").
	SET THROTTLE TO 0.
	SET hovering TO FALSE.
	RETURN TRUE.
}

// In hovering mode, the vessel slowly reduces its speed to minSpeed
WHEN (ALT:RADAR <= hoverAlt) AND (srfSpeed > minSpeed) AND (VERTICALSPEED < 0) AND (THROTTLE = 0) AND (NOT hovering) THEN
{
	Echo("Starting hovering mode.").
	SET hovering TO TRUE.
	LOCK THROTTLE TO ((srfSpeed - minSpeed) * (srfSpeed + minSpeed) / (ALT:RADAR - uprightAlt) / 2 + GA) / MAC.
	RETURN TRUE.
}

// Just before landing, reorient vessel to vertical (upright) position
WHEN (ALT:RADAR <= uprightAlt) AND (srfSpeed < maxSpeed) THEN
{
	Echo("Setting vessel upright for landing.").
	LOCK STEERING TO UP.
	LOCK THROTTLE TO GA / MAC.
	SET hovering TO TRUE.
}

exit OFF.
ON AG9 { exit ON. }

CLEARSCREEN.
PRINT " ".
PRINT " ".
PRINT " ".
PRINT " ".
PRINT " ".
PRINT " ".
PRINT " ".
PRINT " ".

UNTIL exit
{
	SET line TO 1.
	Display("Alt:   " + ROUND(ALT:RADAR) + " m").
	Display("DTLZ:  " + ROUND(DTLZ) + " m").
	IF DEFINED TGEO
	{
		Display("DTT:   " + ROUND(TDIST) + " m").
		Display("TBEAR: " + ROUND(TBEAR, 1)).
	}
	Display("Speed: " + ROUND(srfSpeed, 1) + " (" + ROUND(VERTICALSPEED, 1) + ", " + ROUND(GROUNDSPEED, 1) + ") m/s").
	Display("AC:    " + ROUND(ac, 3) + " / " + ROUND(MAC, 3) + " (" + ROUND(MAC * SIN(SRP), 3) + ", " + ROUND(MAC * COS(SRP), 3) + ") m/s^2").
	Display("SRP:   " + ROUND(SRP, 2) + " deg").
	Display("SBD:   " + ROUND(SBD) + " s").
	Display("TTI:   " + ROUND(TTI) + " s").
	
	IF (TIME:SECONDS >= logTime)
	{
		SET ac TO (srfSpeed - lastSpeed) / (TIME:SECONDS - logTime + 1).
		SET lastSpeed TO srfSpeed.
		Log2(TIME:SECONDS + ";;" + ROUND(ALT:RADAR) + ";" + ROUND(srfSpeed, 1) + ";" + ROUND(VERTICALSPEED, 1) + ";" + ROUND(GROUNDSPEED, 1) + ";" + ROUND(ac, 2) + ";" + ROUND(GA, 2) + ";" + ROUND(MAC, 3) + ";" + ROUND(THROTTLE * 100) + "%;" + ROUND(SBD, 1) + ";" + ROUND(TTI, 1) + ";" + ROUND(SRP, 1) + ";" + ROUND(DTLZ) + ";" + ROUND(TDIST) + ";" + ROUND(TBEAR, 1)).
		SET logTime TO TIME:SECONDS + 1.
	}
	
	IF SHIP:STATUS = "LANDED"
	{
		Echo("Touchdown. Stabilizing.").
		SET THROTTLE TO 0.
		UNLOCK STEERING.
		SAS ON.
		WAIT UNTIL srfSpeed < 0.01.
		Echo(SHIP:NAME + " has landed.").
		LogFuel.
		exit ON.
	}
}

SET THROTTLE TO 0.
UNLOCK THROTTLE.
UNLOCK STEERING.

WAIT UNTIL HOMECONNECTION:ISCONNECTED.
WAIT 1.
