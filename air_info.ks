RCS OFF.
UNTIL RCS {
	CLEARSCREEN.
	PRINT "Angle Of Attack: " + ROUND(angle_of_attack(),1).
	PRINT "Side slip:       " + ROUND(sideslip(),1).
	PRINT "Radar Altitude:  " + ROUND(ALT:RADAR).
	PRINT "Air	Speed:      " + ROUND(SHIP:AIRSPEED,1).
	PRINT "Vert Speed:      " + ROUND(VERTICALSPEED,1).
	WAIT 0.01.
}

FUNCTION angle_of_attack {
	LOCAL srfVel IS VXCL(SHIP:FACING:STARVECTOR,SHIP:VELOCITY:SURFACE).//surface velocity excluding any yaw component
	LOCAL shipFacingFor IS SHIP:FACING:FOREVECTOR.
	IF VDOT(SHIP:FACING:TOPVECTOR,(srfVel-shipFacingFor)) < 0 {
		RETURN VANG(shipFacingFor,srfVel).
	} ELSE {
		RETURN -VANG(shipFacingFor,srfVel).
	}
}

FUNCTION sideslip {
	LOCAL srfVel IS VXCL(SHIP:FACING:TOPVECTOR,SHIP:VELOCITY:SURFACE).//surface velocity excluding any pitch component
	LOCAL shipFacingFor IS SHIP:FACING:FOREVECTOR.
	IF VDOT(SHIP:FACING:STARVECTOR,(srfVel-shipFacingFor)) < 0 {
		RETURN VANG(shipFacingFor,srfVel).
	} ELSE {
		RETURN -VANG(shipFacingFor,srfVel).
	}
}