RUNONCEPATH("DELAY").

CLEARSCREEN.
PRINT "Kerbin Landing Script".

IF BODY:NAME <> "Kerbin"
{ PRINT "WARNING: The current body is not Kerbin. Press 0 or Ctrl-C to stop script execution.". }

PRINT "Stage #" + STAGE:NUMBER.

WAIT UNTIL ALTITUDE < 80000.

PRINT "Approaching atmosphere.".
SAS OFF.
LOCK STEERING TO SRFRETROGRADE.

WAIT UNTIL ALTITUDE < 70000.

PRINT "Entering atmosphere.".

WAIT UNTIL AIRSPEED < 500.

PRINT "Hot reentry complete. Releasing steering.".
UNLOCK STEERING.

WAIT UNTIL ((ALTITUDE < 5000 OR ALT:RADAR < 3000) AND (AIRSPEED < 300)) OR ALT:RADAR < 700.

IF NOT (DEFINED MANSTAGE)
{
	PRINT "Deploying chutes.".
	STAGE.
	WAIT UNTIL STAGE:READY.
	PRINT "Chutes deployed.".
}
ELSE
{
	PRINT "Deploy chutes now!".
}

WAIT UNTIL AIRSPEED < 10.

IF NOT (DEFINED MANSTAGE)
{
	PRINT "Decoupling the heat shield.".
	STAGE.
}
ELSE
{
	PRINT "Decouple heat shield now!".
}

WAIT UNTIL AIRSPEED < 1.

PRINT "Landing successful!".
