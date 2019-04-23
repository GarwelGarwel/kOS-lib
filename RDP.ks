RUNONCEPATH("delay.ks").

LOCK DateTime TO FLOOR(1 + TIME:SECONDS / (3600 * 6 * 426)) + "-" + FLOOR(1 + MOD(TIME:SECONDS, 3600 * 6 * 426) / (3600 * 6)) + " " + TIME:CLOCK.

FUNCTION Echo
{
	PARAMETER msg.

	PRINT DateTime + ": " + msg.
}

IF NOT (DEFINED TVN)
{
	WAIT UNTIL HASTARGET.
	SET TVN TO TARGET:NAME.
}
SET TV TO VESSEL(TVN).
Echo("Target Vessel (TV): " + TV:NAME).

WAIT UNTIL TV:UNPACKED.

Echo("Choosing a docking port to target...").
LIST DOCKINGPORTS IN dpList.
FOR p1 IN dpList
{
	IF p1:STATE = "READY"
	{
		FOR p2 IN TV:DOCKINGPORTS
		{
			IF p2:TARGETABLE AND p2:NODETYPE = p1:NODETYPE
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
	Echo("Error: Could not find a pair of matching docking ports on this vessel and the target. Docking will fail.").
	quit ON.
}
ELSE
{
	Echo("Local Port (LP) is " + LP:NAME).
	Echo("Target Port (TP) is " + TP:NAME).
}

acquired OFF.
quit OFF.
SAS OFF.

LOCK STEERING TO TP:POSITION - LP:POSITION.

// Quit script when 9 is pressed
ON AG9 { quit ON. }

ON SAS { SAS OFF. }

UNTIL quit OR SHIP:STATUS = "DOCKED"
{
	IF LP:STATE = "PREATTACHED" AND NOT acquired
	{
		Echo("Docking port acquired.").
		UNLOCK STEERING.
		acquired ON.
	}
	
	IF LP:STATE = "READY" AND acquired
	{
		Echo("Acquisition lost.").
		LOCK STEERING TO TP:POSITION - LP:POSITION.
		acquired OFF.
	}
	
	IF LP:STATE:CONTAINS("DOCKED")
	{
		Echo(SHIP:NAME + " and " + TV:NAME + " have docked.").
		UNLOCK STEERING.
		quit ON.
	}
}

UNLOCK STEERING.
