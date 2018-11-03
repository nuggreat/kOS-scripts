PARAMETER maxSpeed,minSpeed,stopDist,waypointList,waypointRadius,destName.

IF NOT EXISTS("1:/lib/lib_rocket_utilities.ks") COPYPATH("0:/lib/lib_rocket_utilities.ks","1:/lib/").
FOR lib IN LIST("lib_geochordnate","lib_navball2","lib_formating","lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
CLEARSCREEN.
PRINT "press V to show/hide vectors" AT(0,13).
ABORT OFF.
SAS OFF.
SET STEERINGMANAGER:ROLLCONTROLANGLERANGE TO 180.
//PID setup PIDLOOP(kP,kI,kD,min,max)
LOCAL throttlePID IS PIDLOOP(0.5,0.2,0.02,-1,1).
LOCAL steeringPID IS PIDLOOP(0.5,0.02,0.1,-1,1).

control_point("roverControl").
LOCAL waypointIndex IS 0.
LOCAL wayListLength IS waypointList:LENGTH - 1.
LOCAL distList IS generate_dist_list(waypointList).//a list of distances from given waypoints to the end of the path
LOCAL pathDist IS distList[waypointIndex].
LOCAL newSlope IS slope_calculation(waypointList[waypointIndex]).

LOCAL oldSlope IS 0.//var definitions 
LOCAL forSpeed IS 0.
LOCAL speedDif IS 0.
LOCAL pointBearing IS 0.
LOCAL percentTravled IS 0.
LOCAL pointMag IS 0.

//LOCAL speedLimit IS MAX((SHIP:BODY:MU / SHIP:BODY:RADIUS^2) * 10 - minSpeed,1).//this is sea level gravity times 10
LOCAL speedLimit IS MAX(15 - minSpeed,1).//restriction on how much the wheel steering is allowed to use based on speed, defaulting to 15m/s
LOCAL grade IS grade_claculation(SHIP:GEOPOSITION,waypointList[waypointIndex]).
LOCAL slope_grade_error IS COS(((oldSlope + newSlope) / 2 + grade) / 2).
LOCAL speedRange IS maxSpeed - minSpeed.
SET throttlePID:SETPOINT TO slope_grade_error * speedRange + minSpeed.
LOCAL showVectors IS TRUE.
LOCAL pathVecDraw IS VECDRAW(V(0,0,0),V(0,0,0),GREEN,"",1,showVectors,1).
LOCAL pointVecDraw IS VECDRAW(SHIP:POSITION,V(0,0,0),RED,"",1,showVectors,1).
average_eta(pathDist - stopDist,360,TRUE).//setup of ETA calculation

LOCAL srfNormal IS surface_normal(SHIP:GEOPOSITION).//used to measure how off parallel the rover is from the ground
LOCK steerDir TO LOOKDIRUP(VXCL(srfNormal,SHIP:SRFPROGRADE:FOREVECTOR),srfNormal).//what the steering will be locked to when tipping or airborne 

LOCAL done IS FALSE.
LOCAL stopping IS FALSE.
LOCAL steerNotLocked IS TRUE.
BRAKES OFF.
UNTIL done {
	WAIT 0.
	LOCAL upVec IS SHIP:UP:VECTOR.
	LOCAL targetPos IS waypointList[waypointIndex]:POSITION.//the current waypoint
	LOCAL origenPos IS SHIP:POSITION.
	LOCAL shipWayVec IS targetPos - SHIP:POSITION.
	LOCAL distToWay IS shipWayVec:MAG.//distance to current waypoint

	IF ((distToWay < waypointRadius) OR (pointMag = 1)) AND (NOT stopping) AND (waypointIndex < wayListLength) {//advance the target way point if the current one has been reached
		SET waypointIndex TO MIN(waypointIndex + 1,wayListLength).
		IF waypointIndex > wayListLength { SET stopping TO TRUE. SET waypointIndex TO waypointIndex - 1. } ELSE {//index out of range catch
			SET oldSlope TO newSlope.//updating old slope
			SET pathDist TO distList[waypointIndex].//updating distance from current waypoint to end of path
			SET newSlope TO slope_calculation(waypointList[waypointIndex]).// the slope of the current waypoint in degrees off of flat
			SET grade TO ABS(grade_claculation(waypointList[waypointIndex - 1],waypointList[waypointIndex])).// calculating the grade between the previous waypoint and the current waypoint
			SET slope_grade_error TO SIN(MIN(MAX(((oldSlope + newSlope)/2 + grade),0),90)).//calculating the combined slope and grade penalty to speed

			SET targetPos TO waypointList[waypointIndex]:POSITION.//updating for new waypoint
			SET shipWayVec TO targetPos - SHIP:POSITION.//updating for new waypoint
			SET distToWay TO shipWayVec:MAG.//updating for new waypoint
		}
	}
	IF waypointIndex <> 0 {//index out of range catch
		SET origenPos TO waypointList[waypointIndex - 1]:POSITION.
	}
	LOCAL preNextVec IS targetPos - origenPos.//vector pointing from the origenPos to the targetPos with a mag of the distance between them
	LOCAL offPathVec IS VXCL(upVec,shipWayVec).//excluding up vector so latter math doesn't have height errors
	LOCAL pathVec IS VXCL(upVec,preNextVec).//excluding up vector so latter math doesn't have height errors
	LOCAL offPathBy IS VXCL(pathVec,offPathVec):MAG.//number of meters off the pathVector

	LOCAL percentTravled IS MAX(MIN(VDOT(pathVec - offPathVec,pathVec:NORMALIZED) / pathVec:MAG,1),-0.5).//distance of ship along pathVector in % 
	LOCAL percentError IS offPathBy / waypointRadius.//converting offPathBy into a %, 0 is on path

	//CLEARSCREEN.
	//PRINT "error: " + percentError.
	//PRINT "%remain: " + percentTravled.
	SET pointMag TO MAX(MIN(percentTravled + MAX(1 - percentError,0) * 0.5,1),0).//the % along the preNextVec the position the rover will aim at is
	LOCAL pointPos IS preNextVec * pointMag + origenPos.//calculating the position of the point the rover will aim
	LOCAL shipPoinVec IS pointPos - SHIP:POSITION.//vector pointing from ship to rover aim point

	LOCAL tarDist IS pathDist + distToWay.//distance to the end of the path
	LOCAL tarGeoDist IS pathDist + dist_between_coordinates(waypointList[waypointIndex],SHIP:GEOPOSITION).//distance to current waypoint
	SET forSpeed TO signed_speed().//negative if going backwards
	IF forSpeed > 0 {//correct for error in bearing if rover is moving backwards
		SET pointBearing TO bearing_between(SHIP:VELOCITY:SURFACE + SHIP:FACING:FOREVECTOR / 10,shipPoinVec).
	} ELSE {
		SET pointBearing TO bearing_between(-SHIP:VELOCITY:SURFACE + SHIP:FACING:FOREVECTOR / 10,shipPoinVec).
	}
	LOCAL steerError IS SIN(pointBearing / 2).
//	CLEARSCREEN.
//	PRINT "steerError: " + steerError.
	IF stopping {
		SET throttlePID:SETPOINT TO 0.
		BRAKES ON.
		IF forSpeed < 0 OR ABORT { SET done TO TRUE. ABORT OFF. }
	} ELSE {
		IF (tarDist < stopDist) OR ABORT { SET stopping TO TRUE. ABORT OFF. }
		LOCAL accelLimit IS accel_dist_to_speed(0.025,tarGeoDist - stopDist,speedRange,0).//speed limit to help prevent overshoot of target, assumes rover is only capable of 0.025m/s^2 deceleration
		SET throttlePID:SETPOINT TO MIN(MAX(MIN(1 - (slope_grade_error + ABS(steerError * 2) + percentError / 2),1),0) * speedRange,accelLimit) + minSpeed.//sets the target speed of the rover by combining the various error values into a total error % and reducing the max speed by that % to a minimum of the minimum allowed speed
		//PRINT (slope_grade_error) AT(0,15).
		//PRINT ABS(steerError * 2) AT(0,16).
		//PRINT (1 - percentError) AT (0,17).
		SET speedDif TO throttlePID:SETPOINT - forSpeed.
		brake_check(speedDif,forSpeed).
	}

	IF showVectors {
		SET pathVecDraw:START TO origenPos + upVec * 10.
		SET pathVecDraw:VEC TO preNextVec.
		//SET pointVecDraw:START TO SHIP:POSITION.
		SET pointVecDraw:VEC TO shipPoinVec + upVec * 10.
	}

	IF was_v_pressed {
		SET showVectors TO NOT showVectors.
		SET pathVecDraw:SHOW TO showVectors.
		SET pointVecDraw:SHOW TO showVectors.
	}

	LOCAL steerPIDrange IS MIN(MAX(1 - ((forSpeed - minSpeed) / speedLimit),0.025),1).
	SET steeringPID:MAXOUTPUT TO steerPIDrange.
	SET steeringPID:MINOUTPUT TO -steerPIDrange.

	LOCAL timeStep IS TIME:SECONDS.
	SET SHIP:CONTROL:WHEELTHROTTLE TO throttlePID:UPDATE(timeStep,forSpeed).
	IF steerNotLocked {
		IF forSpeed > 0 {//invert wheel steering if going backwards
			SET SHIP:CONTROL:WHEELSTEER TO steeringPID:UPDATE(timeStep,steerError).
		} ELSE {
			SET SHIP:CONTROL:WHEELSTEER TO 0 - steeringPID:UPDATE(timeStep,steerError).
		}
	} ELSE {
		SET SHIP:CONTROL:WHEELSTEER TO 0.
	}
	SET srfNormal TO surface_normal(SHIP:GEOPOSITION).
	LOCAL upError IS VANG(SHIP:FACING:TOPVECTOR,srfNormal).//how parallel to the ground the rover is
	screen_update(tarGeoDist,pointBearing,forSpeed,speedDif,steerPIDrange).
	IF steerNotLocked AND ((upError > 10) OR (SHIP:STATUS <> "LANDED")) {// is rover is airborne or tipping over to far use reaction wheels and disable wheel steering
		LOCK STEERING TO steerDir.
		SET steerNotLocked TO FALSE.
	} ELSE IF (NOT steerNotLocked) AND ((ABS(STEERINGMANAGER:ANGLEERROR) + ABS(STEERINGMANAGER:ROLLERROR)) < 5) AND (SHIP:STATUS = "LANDED") {//re-enable wheel steering and stop using reaction wheels
		UNLOCK STEERING.
		steeringPID:RESET.
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
	PARAMETER tarDist,pointBearing,forSpeed,speedDif,upError.
	LOCAL printList IS LIST().
	printList:ADD(" ").
	printList:ADD("Roving To: " + destName).
	printList:ADD("Distance : " + si_formating(tarDist,"m")).
	printList:ADD("ETA      : " + time_formating(average_eta(tarDist - stopDist),5)).
	printList:ADD(" ").
	printList:ADD("Curent Speed    :" + padding(forSpeed,2,2) + "m/s").
	printList:ADD("Target Speed    :" + padding(throttlePID:SETPOINT,2,2) + "m/s").
	printList:ADD("Speed Difference:" + padding(speedDif,2,2) + "m/s").
	printList:ADD("  Wheel Throttle: " + padding(SHIP:CONTROL:WHEELTHROTTLE,1,2)).
	printList:ADD(" ").
	printList:ADD(" Bearing to Point:" + padding(pointBearing,2,3)).
	printList:ADD("Wheel Steering Is: " + padding(SHIP:CONTROL:WHEELSTEER,1,3)).
//	printList:ADD(" Input: " + ROUND(steeringPID:INPUT,3) + "    ").
//	printList:ADD("     P: " + ROUND(steeringPID:PTERM,3) + "    ").
//	printList:ADD("     I: " + ROUND(steeringPID:ITERM,3) + "    ").
//	printList:ADD("     D: " + ROUND(steeringPID:DTERM,3) + "    ").
//	printList:ADD("Output: " + ROUND(steeringPID:OUTPUT,2) + "    ").
//	printList:ADD(" ").
//	printList:ADD("upError: " + ROUND(upError,2) + "    ").

	FROM { LOCAL i IS printList:LENGTH - 1. } UNTIL 0 > i STEP { SET i TO i - 1. } DO {
		PRINT printList[i] + " " AT(0,i).
	}
}

FUNCTION signed_speed {//the speed of the rover positive for forward movement negative for reverse movement
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

FUNCTION accel_dist_to_speed {//using linear motion equations calculate the speed for a given distance and acceleration
	PARAMETER accel,dist,speedLimit,deadZone IS 0.
	LOCAL localAccel IS accel.
	LOCAL posNeg IS 1.
	IF dist < 0 { SET posNeg TO -1. }
	IF (deadZone <> 0) AND (ABS(dist) < deadZone) { SET localAccel to accel / 10. }
	RETURN MIN(MAX((SQRT(2 * ABS(dist) / localAccel) * localAccel) * posNeg,-speedLimit),speedLimit).
}

FUNCTION brake_check {//a check for over speed to turn on the brakes
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