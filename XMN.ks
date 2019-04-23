RUNONCEPATH("delay.ks").

PRINT "Execute Maneuver Node (XMN) Script".

SET nd TO NEXTNODE.

UNTIL MAXTHRUST > 0
{
	PRINT "No active engine. Staging.".
	STAGE.
	WAIT 3.
}

PRINT "Node in " + ROUND(NEXTNODE:ETA) + " s. Delta V: " + ROUND(NEXTNODE:DELTAV:MAG) + " m/s.".

LOCK max_acc TO AVAILABLETHRUST / SHIP:MASS.
IF NOT (DEFINED BD)
{
	SET BD TO NEXTNODE:DELTAV:MAG / max_acc.
}
PRINT "Estimated burn duration: " + ROUND(BD) + " s".

WAIT UNTIL NEXTNODE:ETA <= BD / 2 + 60.
KUNIVERSE:TIMEWARP:CANCELWARP.

PRINT "Orienting the vessel toward maneuver node...".

SAS OFF.
LOCK STEERING TO nd:DELTAV:DIRECTION.

WAIT UNTIL nd:ETA <= BD / 2.
KUNIVERSE:TIMEWARP:CANCELWARP.

PRINT "Starting burn.".

SET tset TO 0.
LOCK THROTTLE TO tset.
SET dv0 TO nd:DELTAV.
SET stagedTime TO 0.

WHEN MAXTHRUST = 0 AND MISSIONTIME >= stagedTime + 3 THEN
{
	PRINT "Staging.".
	STAGE.
	SET stagedTime TO MISSIONTIME.
	RETURN TRUE.
}

UNTIL FALSE
{
    SET tset TO MIN(nd:DELTAV:MAG / max_acc, 1).

    IF VDOT(dv0, nd:DELTAV) < 0 { BREAK. }

    IF nd:DELTAV:MAG < 0.1
    {
        PRINT "Finalizing burn, remaining dv " + ROUND(nd:DELTAV:MAG, 1) + " m/s, vDot: " + ROUND(VDOT(dv0, nd:DELTAV), 1).
        WAIT UNTIL VDOT(dv0, nd:DELTAV) < 0.5.
		BREAK.
    }
}

PRINT "Remaining dv " + ROUND(nd:DELTAV:MAG, 1) + " m/s. vDot: " + ROUND(VDOT(dv0, nd:DELTAV), 1).
PRINT "Maneuver node executed.".

SET THROTTLE TO 0.
UNLOCK THROTTLE.
UNLOCK STEERING.
REMOVE nd.
REMOVE BD.