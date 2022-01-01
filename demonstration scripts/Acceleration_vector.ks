
LOCAL deltaVel IS vec_delta_init(SHIP:VELOCITY:ORBIT).
LOCAL vdAcc IS VECDRAW(v(0,0,0),v(0,0,0),YELLOW,"Accel",1,TRUE,1,TRUE).
LOCAL vdGrav IS VECDRAW(v(0,0,0),v(0,0,0),BLUE,"Grav",1,TRUE,1,TRUE).
LOCAL vdNet IS VECDRAW(v(0,0,0),v(0,0,0),GREEN,"Net",1,TRUE,1,TRUE).

RCS OFF.
WAIT 0.
LOCAL dtTest IS 0.
LOCAL staticUPvector IS v(0,1,0).
UNTIL RCS {
	WAIT 0.
	LOCAL bodyPos IS BODY:POSITION.
	LOCAL shipPos IS SHIP:POSITION.
	LOCAL velVec IS SHIP:VELOCITY:ORBIT.
	LOCAL staticFrame IS LOOKDIRUP(SOLARPRIMEVECTOR,staticUPvector).
	LOCAL currentTime IS TIME:SECONDS.
	
	LOCAL radVec IS (bodyPos - shipPos).
	LOCAL gravVec IS radVec:NORMALIZED * BODY:MU / radVec:SQRMAGNITUDE.
	SET accVec TO deltaVel(velVec,staticFrame,currentTime).
	CLEARSCREEN.
	LOCAL netVector IS (accVec - gravVec).
	SET vdAcc:VECTOR TO accVec.
	SET vdGrav:VECTOR TO gravVec.
	SET vdNet:START TO gravVec.
	SET vdNet:VECTOR TO netVector.
	PRINT "acc: " + accVec:MAG.
	PRINT "grav: " + gravVec:MAG.
	PRINT "net: " + netVector:MAG.
}

CLEARVECDRAWS().

FUNCTION vec_delta_init {
	LOCAL staticUPvector IS v(0,1,0).
    PARAMETER initalVal, staticFrame IS LOOKDIRUP(SOLARPRIMEVECTOR,staticUPvector).
    LOCAL oldTime IS TIME:SECONDS.
    LOCAL oldVal IS initalVal * staticFrame.
	LOCAL oldDelta IS oldVal - oldVal.
    RETURN {
        PARAMETER newVal, staticFrame IS LOOKDIRUP(SOLARPRIMEVECTOR,staticUPvector), newTime IS TIME:SECONDS.
        LOCAL deltaT IS newTime - oldTime.
        IF deltaT = 0 {
            RETURN oldDelta.
        } ELSE {
			SET newVal TO newVal * staticFrame.
            LOCAL deltaVal IS newVal - oldVal.
            SET oldTime TO newTime.
            SET oldVal TO newVal.
            SET oldDelta TO deltaVal / deltaT.
            RETURN oldDelta * staticFrame:INVERSE.
            // RETURN oldDelta.
        }
    }.
}