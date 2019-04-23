PRINT "AUTORUN script.".

UNTIL NOT HASNODE
{
	PRINT "Running XMN routine for the upcoming maneuver node...".
	RUNPATH("XMN").
	PRINT "Maneuver node executed. Back to AUTORUN.".
}

PRINT "AUTORUN script completed.".
