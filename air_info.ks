RCS OFF.
UNTIL RCS {
	CLEARSCREEN.
	PRINT "Angle Of Attack: " + ROUND(angle_of_attack(),1).
	PRINT "Side slip:       " + ROUND(side_slip(),1).
	PRINT "Radar Altitude:  " + ROUND(ALT:RADAR).
	PRINT "Air	Speed:      " + ROUND(SHIP:AIRSPEED,1).
	PRINT "Vert Speed:      " + ROUND(VERTICALSPEED,1).
	WAIT 0.01.
}

FUNCTION angle_of_attack {
	LOCAL shipF is SHIP:FACING.
	LOCAL srfVel IS VXCL(shipF:STARVECTOR,SHIP:VELOCITY:SURFACE:NORMALIZED):NORMALIZED.//surface velocity excluding any yaw component
	IF VDOT(shipF:TOPVECTOR,(srfVel)) < 0 {
		RETURN VANG(shipF:FOREVECTOR,srfVel).
	} ELSE {
		RETURN -VANG(shipF:FOREVECTOR,srfVel).
	}
}

FUNCTION side_slip {
	LOCAL shipF is SHIP:FACING.
	LOCAL srfVel IS VXCL(shipF:TOPVECTOR,SHIP:VELOCITY:SURFACE:NORMALIZED):NORMALIZED.//surface velocity excluding any pitch component
	IF VDOT(shipF:STARVECTOR,(srfVel)) < 0 {
		RETURN VANG(shipF:FOREVECTOR,srfVel).
	} ELSE {
		RETURN -VANG(shipF:FOREVECTOR,srfVel).
	}
}