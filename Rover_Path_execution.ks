PARAMETER maxSpeed,minSpeed,stopDist,waypointList,waypointRadius,destName.
FOR lib IN LIST("lib_geochordnate","lib_navball2","lib_formating") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
CLEARSCREEN.
PRINT "press V to show/hide vectors" AT(0,13).
ABORT OFF.
SAS OFF.
BRAKES OFF.
SET STEERINGMANAGER:ROLLCONTROLANGLERANGE TO 180.
//SET CONFIG:IPU TO 200.
//PID setup PIDLOOP(kP,kI,kD,min,max)
LOCAL throttlePID IS PIDLOOP(0.5,0.2,0.02,-1,1).
LOCAL steeringPID IS PIDLOOP(2,0.2,0.2,-1,1).

LOCAL waypointIndex IS 0.
LOCAL wayListLength IS waypointList:LENGTH - 1.
LOCAL distList IS generate_dist_list(waypointList).
LOCAL pathDist IS distList[waypointIndex].
LOCAL oldSlope IS 0.
LOCAL newSlope IS slope_calculation(waypointList[waypointIndex]).
LOCAL forSpeed IS 0.
LOCAL speedDif IS 0.
LOCAL speedLimit IS SHIP:BODY:MU / SHIP:BODY:RADIUS^2 * 10.
LOCAL percentTravled IS 0.
LOCAL pointMag IS 0.
LOCAL grade IS grade_claculation(SHIP:GEOPOSITION,waypointList[waypointIndex]).
LOCAL slope_grade_error IS COS(((oldSlope + newSlope) / 2 + grade) / 2).
LOCAL speedRange IS maxSpeed - minSpeed.
SET throttlePID:SETPOINT TO slope_grade_error * speedRange + minSpeed.
LOCAL showVectors IS TRUE.
LOCAL pathVecDraw IS VECDRAW(V(0,0,0),V(0,0,0),GREEN,"",1,showVectors,1).
LOCAL pointVecDraw IS VECDRAW(SHIP:POSITION,V(0,0,0),RED,"",1,showVectors,1).
average_eta(pathDist - stopDist,120,TRUE).

LOCAL srfNormal IS surface_normal(SHIP:GEOPOSITION).
LOCK steerDir TO LOOKDIRUP(VXCL(srfNormal,SHIP:SRFPROGRADE:FOREVECTOR),srfNormal).

LOCAL done IS FALSE.
LOCAL stopping IS FALSE.
LOCAL steerNotLocked IS TRUE.
UNTIL done {
	WAIT 0.
	LOCAL upVec IS SHIP:UP:VECTOR.
	LOCAL targetPos IS waypointList[waypointIndex]:POSITION.
	LOCAL origenPos IS SHIP:POSITION.
	LOCAL shipWayVec IS targetPos - SHIP:POSITION.
	LOCAL distToWay IS shipWayVec:MAG.

	//IF (distToWay < waypointRadius) AND (NOT stopping) {
	IF ((distToWay < waypointRadius) OR (pointMag = 1)) AND (NOT stopping) AND (waypointIndex < wayListLength) {
		SET waypointIndex TO MIN(waypointIndex + 1,wayListLength).
		IF waypointIndex > wayListLength { SET stopping TO TRUE. SET waypointIndex TO waypointIndex - 1. } ELSE {
			SET oldSlope TO newSlope.
			SET pathDist TO distList[waypointIndex].
			SET newSlope TO slope_calculation(waypointList[waypointIndex]).
			SET grade TO ABS(grade_claculation(waypointList[waypointIndex - 1],waypointList[waypointIndex])).
			SET slope_grade_error TO COS(((oldSlope + newSlope) / 2 + grade) / 2).

			SET targetPos TO waypointList[waypointIndex]:POSITION.
			SET shipWayVec TO targetPos - SHIP:POSITION.
			SET distToWay TO shipWayVec:MAG.
		}
	}
	IF waypointIndex <> 0 {
		SET origenPos TO waypointList[waypointIndex - 1]:POSITION.
	}
	LOCAL preNextVec IS targetPos - origenPos.
	LOCAL offPathVec IS VXCL(upVec,shipWayVec).
	LOCAL pathVec IS VXCL(upVec,preNextVec).
	//LOCAL offPathBy IS VANG(pathVec,offPathVec).
	LOCAL offPathBy IS VXCL(pathVec,offPathVec):MAG.//number of meters off the pathVector

	LOCAL percentTravled IS MAX(MIN(VDOT(pathVec - offPathVec,pathVec:NORMALIZED) / pathVec:MAG,1),-0.25).//distance of ship along pathVector in % 
	//LOCAL percentError IS (1 - percentTravled) * offPathBy / 180.
	//LOCAL percentError IS (1 - percentTravled) * COS(MIN(offPathBy*2,90)).
	//LOCAL percentError IS COS(MIN(offPathBy * 2,90)).
	LOCAL percentError IS MAX(1 - offPathBy / waypointRadius,0).//converting offPathBy into a % good

	//CLEARSCREEN.
	//PRINT "error: " + percentError.
	//PRINT "%remain: " + percentTravled.
	SET pointMag TO MAX(MIN(percentTravled + percentError * 0.25,1),0).
	LOCAL pointPos IS preNextVec * pointMag + origenPos.//calculating the target position along the path vec
	LOCAL shipPoinVec IS pointPos - SHIP:POSITION.

	LOCAL tarDist IS pathDist + distToWay.
	LOCAL tarGeoDist IS pathDist + dist_between_coordinates(waypointList[waypointIndex],SHIP:GEOPOSITION).
	LOCAL pointBearing IS bearing_between(SHIP:SRFPROGRADE:FOREVECTOR + SHIP:FACING:FOREVECTOR / 10,shipPoinVec).
	LOCAL steerError IS SIN(pointBearing / 2).
//	CLEARSCREEN.
//	PRINT "steerError: " + steerError.
	SET forSpeed TO signed_speed().
	IF stopping {
		SET throttlePID:SETPOINT TO 0.
		BRAKES ON.
		IF forSpeed < 0 OR ABORT { SET done TO TRUE. ABORT OFF. }
	} ELSE {
		IF (tarDist < stopDist) OR ABORT { SET stopping TO TRUE. ABORT OFF. }
		LOCAL accelLimit IS accel_dist_to_speed(0.05,tarGeoDist - stopDist,speedRange,0).
		SET throttlePID:SETPOINT TO MIN(MAX(MIN(1 - (slope_grade_error + ABS(steerError * 2) + (1 - percentError)),1),0) * speedRange,accelLimit) + minSpeed.
		//PRINT (slope_grade_error) AT(0,15).
		//PRINT ABS(steerError * 2) AT(0,16).
		//PRINT (1 - percentError) AT (0,17).
		SET speedDif TO throttlePID:SETPOINT - forSpeed.
		brake_check(speedDif,forSpeed).
	}

	IF showVectors {
		SET pathVecDraw:START TO origenPos.
		SET pathVecDraw:VEC TO preNextVec.
		//SET pointVecDraw:START TO SHIP:POSITION.
		SET pointVecDraw:VEC TO shipPoinVec.
	}

	IF was_v_pressed {
		SET showVectors TO NOT showVectors.
		SET pathVecDraw:SHOW TO showVectors.
		SET pointVecDraw:SHOW TO showVectors.
	}

	LOCAL steerPIDrange IS MIN(MAX(1 - (forSpeed / speedLimit),0.025),1).
	SET steeringPID:MAXOUTPUT TO steerPIDrange.
	SET steeringPID:MINOUTPUT TO -steerPIDrange.

	LOCAL timeStep IS TIME:SECONDS.
	SET SHIP:CONTROL:WHEELTHROTTLE TO throttlePID:UPDATE(timeStep,forSpeed).
	IF forSpeed > 0 {
		SET SHIP:CONTROL:WHEELSTEER TO steeringPID:UPDATE(timeStep,steerError).
	} ELSE {
		SET SHIP:CONTROL:WHEELSTEER TO 0 - steeringPID:UPDATE(timeStep,steerError).
	}
	screen_update(tarGeoDist,pointBearing,forSpeed,speedDif).
	SET srfNormal TO surface_normal(SHIP:GEOPOSITION).
	LOCAL upError IS VANG(SHIP:FACING:TOPVECTOR,srfNormal).
	IF steerNotLocked AND ((upError > 10) OR (SHIP:STATUS <> "LANDED")) {
		LOCK STEERING TO steerDir.
		SET steerNotLocked TO FALSE.
	} ELSE IF (NOT steerNotLocked) AND (upError < 5) {
		UNLOCK STEERING.
		SET steerNotLocked TO TRUE.
	}
}
ABORT OFF.
BRAKES ON.
SET SHIP:CONTROL:WHEELTHROTTLE TO 0.
SET SHIP:CONTROL:WHEELSTEER TO 0.
UNLOCK WHEELSTEERING.
UNLOCK WHEELTHROTTLE.
UNLOCK STEERING.
SET STEERINGMANAGER:ROLLCONTROLANGLERANGE TO 5.
CLEARVECDRAWS().


FUNCTION screen_update {
	PARAMETER tarDist,pointBearing,forSpeed,speedDif.
	LOCAL printList IS LIST().
	printList:ADD("       ").
	printList:ADD("Roving To: " + destName).
	printList:ADD("Distance : " + si_formating(tarDist,"m")).
	printList:ADD("ETA      :" + time_formating(average_eta(tarDist - stopDist),5)).
	printList:ADD(" ").
	printList:ADD("Curent Speed    :" + padding(forSpeed,2,2) + "m/s").
	printList:ADD("Target Speed    :" + padding(throttlePID:SETPOINT,2,2) + "m/s").
	printList:ADD("Speed Difference:" + padding(speedDif,2,2) + "m/s").
	printList:ADD("  Wheel Throttle: " + padding(SHIP:CONTROL:WHEELTHROTTLE,1,2)).
	printList:ADD(" ").
	printList:ADD(" Bearing to Point:" + padding(pointBearing,2,1)).
	printList:ADD("Wheel Steering Is: " + padding(SHIP:CONTROL:WHEELSTEER,1,2)).

	FROM { LOCAL i IS printList:LENGTH - 1. } UNTIL 0 > i STEP { SET i TO i - 1. } DO {
		PRINT printList[i] + " " AT(0,i).
	}
}

FUNCTION signed_speed {		//the speed of the rover positive for forward movement negative for reverse movement
	LOCAL shipVel IS SHIP:VELOCITY:SURFACE.
	IF VDOT(shipVel,SHIP:FACING:FOREVECTOR) > 0 {
		RETURN shipVel:MAG.
	} ELSE {
		RETURN -shipVel:MAG.
	}
}

FUNCTION generate_dist_list {
	PARAMETER waypointList.
	LOCAL returnList IS LIST(0).
	LOCAL totalDist IS 0.
	FROM { LOCAL i IS waypointList:LENGTH - 2. } UNTIL i < 0 STEP { SET i TO i - 1 . } DO {
		SET totalDist TO totalDist + dist_between_coordinates(waypointList[i],waypointList[i + 1]).
		returnList:INSERT(0,totalDist).
	}
	RETURN returnList.
}

FUNCTION accel_dist_to_speed {
	PARAMETER accel,dist,speedLimit,deadZone IS 0.
	LOCAL localAccel IS accel.
	LOCAL posNeg IS 1.
	IF dist < 0 { SET posNeg TO -1. }
	IF (deadZone <> 0) AND (ABS(dist) < deadZone) { SET localAccel to accel / 10. }
	RETURN MIN(MAX((SQRT(2 * ABS(dist) / localAccel) * localAccel) * posNeg,-speedLimit),speedLimit).
}

FUNCTION brake_check {	//a check for over speed to turn on the brakes
	PARAMETER speedDif,forSpeed.
	IF speedDif < 0 AND SHIP:CONTROL:WHEELTHROTTLE = -1 {
		BRAKES ON.
	} ELSE { IF forSpeed < -0.5 {
			BRAKES ON.
		} ELSE {
			BRAKES OFF.
		}
	}
}

FUNCTION was_v_pressed {
	LOCAL termIn IS TERMINAL:INPUT.
	IF termIn:HASCHAR {
		RETURN termIn:GETCHAR() = "v".
	} ELSE {
		RETURN FALSE.
	}
}