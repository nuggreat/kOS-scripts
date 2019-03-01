
PARAMETER maxSpeed,minSpeed,stopDist,waypointList,waypointRadius,destName,wheelAccel IS 0.025,turnCoeff IS 1.
IF NOT EXISTS("1:/lib/lib_rocket_utilities.ks") COPYPATH("0:/lib/lib_rocket_utilities.ks","1:/lib/").
FOR lib IN LIST("lib_geochordnate","lib_navball2","lib_formating","lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
CLEARSCREEN.
ABORT OFF.
SAS OFF.
SET STEERINGMANAGER:ROLLCONTROLANGLERANGE TO 180.
//SET CONFIG:IPU TO 200.
//PID setup PIDLOOP(kP,kI,kD,min,max)
LOCAL throttlePID IS PIDLOOP(0.5,0.2,0.02,-1,1).
LOCAL steeringPID IS PIDLOOP((0.5 * turnCoeff),(0.02),(0.1 * turnCoeff),-1,1).

control_point("roverControl").
PRINT "Rover Starting up.".
LOCAL waypointIndex IS 0.
LOCAL wayListLength IS waypointList:LENGTH - 1.
LOCAL offLimit IS waypointRadius * 3.

//LOCAL distList IS generate_dist_list(waypointList).//calculate distance along path between waypoints
LOCAL limitLex IS LEX("state",-3,"index",0).//,"maxIndex",wayListLength,"speedRange",(maxSpeed - minSpeed),"minSpeed",minSpeed).
LOCAL speedListDynamic IS LIST().
LOCAL etaListDynamic IS LIST().
LOCAL distList IS LIST().
LOCAL limitFunctionLex IS speed_limit_states(limitLex,waypointList,distList,speedListDynamic,etaListDynamic,maxSpeed,minSpeed).
UNTIL speed_limit_recalc(limitFunctionLex,limitLex,0) {
	PRINT " " + padding(percent_state_calc(limitLex,wayListLength) * 100,2,2) + "%" AT(0,1).
}
LOCAL speedListStatic IS speedListDynamic:COPY().
LOCAL etaListStatic IS etaListDynamic:COPY().
//PRINT speedListDynamic.
//RCS OFF.
//WAIT UNTIL RCS.
LOCAL pathDist IS distList[waypointIndex].
LOCAL pathETAstring IS time_formating(etaListStatic[waypointIndex],5).
LOCAL oldSlope IS 0.
LOCAL newSlope IS slope_calculation(waypointList[waypointIndex]).
LOCAL oldSpeed IS minSpeed.
LOCAL newSpeed IS speedListStatic[waypointIndex].
LOCAL forSpeed IS 0.
LOCAL speedDif IS 0.
LOCAL pointBearing IS 0.
//LOCAL steerLimit IS MAX((SHIP:BODY:MU / SHIP:BODY:RADIUS^2) * 10 - minSpeed,1).//this is sea level gravity times 10
LOCAL steerLimit IS MAX(15 - minSpeed,1).//defaulting to 15m/s,point where steering is fully restricted
LOCAL percentTravled IS 0.
LOCAL pointMag IS 0.
LOCAL grade IS grade_claculation(SHIP:GEOPOSITION,waypointList[waypointIndex]).
LOCAL slope_grade_error IS COS(((oldSlope + newSlope) / 2 + grade) / 2).
LOCAL speedRange IS maxSpeed - minSpeed.
SET throttlePID:SETPOINT TO slope_grade_error * speedRange + minSpeed.
LOCAL showVectors IS TRUE.
LOCAL pathVecDraw IS VECDRAW(V(0,0,0),V(0,0,0),GREEN,"",1,showVectors,1).
LOCAL pointVecDraw IS VECDRAW(SHIP:POSITION,V(0,0,0),RED,"",1,showVectors,1).
CLEARSCREEN.
PRINT "press V to show/hide vectors" AT(0,13).
average_eta(pathDist - stopDist,360,TRUE).

LOCAL srfNormal IS surface_normal(SHIP:GEOPOSITION).
LOCK steerDir TO LOOKDIRUP(VXCL(srfNormal,SHIP:SRFPROGRADE:FOREVECTOR),srfNormal).

LOCAL done IS FALSE.
//LOCAL done IS TRUE.
LOCAL oldTime IS TIME:SECONDS.
LOCAL stopping IS FALSE.
LOCAL steerNotLocked IS TRUE.
BRAKES OFF.
UNTIL done {
	//WAIT 0.
	LOCAL upVec IS SHIP:UP:VECTOR.
	LOCAL targetPos IS waypointList[waypointIndex]:POSITION.
	LOCAL origenPos IS SHIP:POSITION.
	LOCAL shipWayVec IS targetPos - origenPos.
	LOCAL distToWay IS shipWayVec:MAG.

	//IF (distToWay < waypointRadius) AND (NOT stopping) {
	IF ((distToWay < waypointRadius) OR (pointMag = 1)) AND (NOT stopping) AND (waypointIndex < wayListLength) {
		SET waypointIndex TO MIN(waypointIndex + 1,wayListLength).
		IF waypointIndex > wayListLength { SET stopping TO TRUE. SET waypointIndex TO waypointIndex - 1. } ELSE {
			SET oldSlope TO newSlope.
			SET pathDist TO distList[waypointIndex].
			SET pathETAstring TO time_formating(etaListStatic[waypointIndex],5).
			SET oldSpeed TO newSpeed.
			SET newSpeed TO speedListStatic[waypointIndex].

			SET targetPos TO waypointList[waypointIndex]:POSITION.
			SET shipWayVec TO targetPos - SHIP:POSITION.
			SET distToWay TO shipWayVec:MAG.
			LOCAL localTime IS TIME:SECONDS.
			PRINT "deltaT: " + ROUND(localTime - oldTime,2) + "   " AT(0,15).
			PRINT "deltaE: " + ROUND(etaListStatic[MAX(waypointIndex - 2,0)] - etaListStatic[MAX(waypointIndex - 1,0)],2) + "   " AT(0,16).
			SET oldTime TO localTime.
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

	LOCAL percentTravled IS MAX(MIN(VDOT(pathVec - offPathVec,pathVec:NORMALIZED) / pathVec:MAG,1),-0.5).//distance of ship along pathVector in % 
	//LOCAL percentError IS (1 - percentTravled) * offPathBy / 180.
	//LOCAL percentError IS (1 - percentTravled) * COS(MIN(offPathBy*2,90)).
	//LOCAL percentError IS COS(MIN(offPathBy * 2,90)).
	LOCAL percentError IS offPathBy / offLimit.//converting offPathBy into a %, 0 is on path

	//CLEARSCREEN.
	//PRINT "error: " + percentError.
	//PRINT "%remain: " + percentTravled.
	SET pointMag TO MAX(MIN(percentTravled + MAX(1 - percentError,0) * 0.5,1),0).//% along preNextVec vec the target point is
	LOCAL speedRestrict IS pointMag * newSpeed + (1 - pointMag) * oldSpeed.
	LOCAL pointPos IS preNextVec * pointMag + origenPos.//calculating the target position along the path vec
	LOCAL shipPoinVec IS pointPos - SHIP:POSITION.

	LOCAL tarDist IS pathDist + distToWay.
	LOCAL tarGeoDist IS pathDist + dist_between_coordinates(waypointList[waypointIndex],SHIP:GEOPOSITION).
	SET forSpeed TO signed_speed().
	IF forSpeed > 0 {
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
		LOCAL accelLimit IS accel_dist_to_speed(wheelAccel,tarGeoDist - stopDist,speedRange,0).
		SET throttlePID:SETPOINT TO MIN(MIN(MAX(MIN(1 - (ABS(steerError * 2) + MIN(percentError - 0.1,0) / 2),1),0) * speedRange,accelLimit) + minSpeed,speedRestrict).
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

	LOCAL steerPIDrange IS MIN(MAX(1 - ((forSpeed - minSpeed) / steerLimit),0.025 * turnCoeff),1).
	SET steeringPID:MAXOUTPUT TO steerPIDrange.
	SET steeringPID:MINOUTPUT TO -steerPIDrange.

	LOCAL timeStep IS TIME:SECONDS.
	SET SHIP:CONTROL:WHEELTHROTTLE TO throttlePID:UPDATE(timeStep,forSpeed).
	IF steerNotLocked {
		IF forSpeed > 0 {
			SET SHIP:CONTROL:WHEELSTEER TO steeringPID:UPDATE(timeStep,steerError).
		} ELSE {
			SET SHIP:CONTROL:WHEELSTEER TO 0 - steeringPID:UPDATE(timeStep,steerError).
		}
	} ELSE {
		SET SHIP:CONTROL:WHEELSTEER TO 0.
	}
	SET srfNormal TO surface_normal(SHIP:GEOPOSITION).
	LOCAL upError IS VANG(SHIP:FACING:TOPVECTOR,srfNormal).
	screen_update(tarGeoDist,pathETAstring,pointBearing,forSpeed,speedDif,speedRestrict).
	IF steerNotLocked AND ((upError > 5) OR (SHIP:STATUS <> "LANDED")) {
		LOCK STEERING TO steerDir.
		SET steerNotLocked TO FALSE.
		steering_alinged_duration(TRUE,2.5,TRUE).
	} ELSE IF (NOT steerNotLocked) AND (SHIP:STATUS = "LANDED") AND (steering_alinged_duration() > 2) {
		UNLOCK STEERING.
		steeringPID:RESET.
		SET steerNotLocked TO TRUE.
	}
	IF speed_limit_recalc(limitFunctionLex,limitLex,waypointIndex) {
		SET speedListStatic TO speedListDynamic:COPY().
		SET etaListStatic TO etaListDynamic:COPY().
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
	PARAMETER tarDist,etaStr,pointBearing,forSpeed,speedDif,speedRestrict.
	LOCAL printList IS LIST().
	printList:ADD(" ").
	printList:ADD("Roving To: " + destName).
	printList:ADD("Distance : " + si_formating(tarDist,"m")).
	//printList:ADD("ETA      : " + time_formating(average_eta(tarDist - stopDist),5)).
	printList:ADD("ETA      : " + etaStr).
	printList:ADD(" ").
	printList:ADD("Slope Limit     :" + padding(speedRestrict,2,2) + "m/s").
	printList:ADD("Current Speed   :" + padding(forSpeed,2,2) + "m/s").
	printList:ADD(" Target Speed   :" + padding(throttlePID:SETPOINT,2,2) + "m/s").
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

//LOCAL dataLex IS LEX("state",-1,"index",0,"maxIndex",(waypointList:LENGTH - 1),"speedRange",(maxSpeed - minSpeed),"minSpeed",minSpeed).
FUNCTION speed_limit_recalc {//runs the speed limit state machine
	//PARAMETER functionLex,dataLex,waypointList,distList,speedList.
	PARAMETER functionLex,dataLex,curentIndex.
	//PRINT "state: " + dataLex["state"] + "  " AT(0,0).
	//PRINT "index: " + dataLex["index"] + "  " AT(0,1).
	//WAIT 1.
	RETURN functionLex[dataLex["state"]]:CALL(curentIndex).
}

FUNCTION speed_limit_states {//sets up the various states of the speed limit calculation state machine 
	PARAMETER dataLex,pointList,distList,speedList,etaList,maxSpeed,minSpeed.
	LOCAL speedRange IS maxSpeed - minSpeed.
	LOCAL maxIndex IS pointList:LENGTH - 1.
	LOCAL returnLex IS LEX().
	returnLex:ADD(-3,{//initializing speedList
		PARAMETER curentIndex.
		speedList:ADD(0).
		SET dataLex["index"] TO dataLex["index"] + 1.
		IF dataLex["index"] > maxIndex {
			SET dataLex["index"] TO 0.
			SET dataLex["state"] TO -2.
		}
		RETURN FALSE.
	}).
	returnLex:ADD(-2,{//initializing  etaList
		PARAMETER curentIndex.
		etaList:ADD(0).
		SET dataLex["index"] TO dataLex["index"] + 1.
		IF dataLex["index"] > maxIndex {
			SET dataLex["index"] TO 0.
			SET dataLex["state"] TO -1.
		}
		RETURN FALSE.
	}).
	returnLex:ADD(-1,{//calculating 
		PARAMETER curentIndex.
		LOCAL i IS maxIndex - dataLex["index"] - 1.
		IF dataLex["index"] = 0 { distList:ADD(0). }
		LOCAL pointDist IS dist_between_coordinates(waypointList[i],waypointList[i + 1]).
		distList:INSERT(0,distList[0] + pointDist).
		SET dataLex["index"] TO dataLex["index"] + 1.
		IF dataLex["index"] >= maxIndex {
			SET dataLex["index"] TO 0.
			SET dataLex["state"] TO 0.
		}
		RETURN FALSE.
	}).
	returnLex:ADD(0,{//add in slope value
		PARAMETER curentIndex.
		LOCAL i IS dataLex["index"].
		IF i = 0 OR i = maxIndex {
			SET speedList[i] TO minSpeed.
			SET dataLex["state"] TO 2.
			RETURN FALSE.
		} ELSE {
			SET speedList[i] TO COS(MIN(slope_calculation(pointList[i]),90)).
			//PRINT speedList[i] AT(0,2).
			SET dataLex["state"] TO 1.
			RETURN FALSE.
		}
	}).
	returnLex:ADD(1,{//add in turn value
		PARAMETER curentIndex.
		LOCAL i IS dataLex["index"].
		//SET speedList[i] TO MIN(speedList[i],SIN(ABS(bearing_between((pointList[i - 1]:POSITION - pointList[i]:POSITION),(pointList[i + 1]:POSITION - pointList[i]:POSITION)) / 2))).
		SET speedList[i] TO speedList[i] - COS(ABS(bearing_between((pointList[i - 1]:POSITION - pointList[i]:POSITION),(pointList[i + 1]:POSITION - pointList[i]:POSITION)) / 2)).
		//PRINT speedList[i] AT(0,2).
		SET dataLex["state"] TO 2.
		RETURN FALSE.
	}).
	returnLex:ADD(2,{//adding grade value
		PARAMETER curentIndex.
		LOCAL i IS dataLex["index"].
		IF i <> 0 AND i <> maxIndex {
			//SET speedList[i] TO MIN(speedList[i],COS(MIN(ABS(grade_claculation(pointList[i - 1],pointList[i]) - grade_claculation(pointList[i],pointList[i + 1])) * 2,90))) * dataLex["speedRange"] + dataLex["minSpeed"].
			SET speedList[i] TO MAX(MIN(speedList[i] - SIN(MIN(ABS(grade_claculation(pointList[i - 1],pointList[i]) - grade_claculation(pointList[i],pointList[i + 1])) * 2,90)),1),0) * speedRange + minSpeed.
			//PRINT speedList[i] AT(0,2).
		}
		SET dataLex["index"] TO i + 1.
		IF dataLex["index"] > maxIndex {
			SET dataLex["state"] TO 3.
			SET dataLex["index"] TO 1.
		} ELSE {
			SET dataLex["state"] TO 0.
		}
		RETURN FALSE.
	}).
	returnLex:ADD(3,{//limiting speed forward based on accel limit
		PARAMETER curentIndex.
		LOCAL i IS dataLex["index"].
		LOCAL distToNext IS distList[i - 1] - distList[i].
		LOCAL speedLimit IS SQRT(2 * wheelAccel * distToNext + speedList[i - 1]^2).//calculates new speed from acc dist change and previous speed
		SET speedList[i] TO MIN(speedList[i],speedLimit).
		SET dataLex["index"] TO i + 1.
		IF dataLex["index"] > maxIndex {
			SET dataLex["state"] TO 4.
			SET dataLex["index"] TO maxIndex - 1.
		}
		RETURN FALSE.

	}).
	returnLex:ADD(4,{//limiting speed backwards based on accel limit
		PARAMETER curentIndex.
		LOCAL i IS dataLex["index"].
		LOCAL distToNext IS distList[i] - distList[i + 1].
		LOCAL speedLimit IS SQRT(2 * wheelAccel * distToNext + speedList[i + 1]^2).//calculates new speed from acc dist change and previous speed
		SET speedList[i] TO MIN(speedList[i],speedLimit).
		SET dataLex["index"] TO i - 1.
		IF dataLex["index"] < curentIndex {
			SET dataLex["state"] TO 5.
			SET dataLex["index"] TO maxIndex - 1.
		}
		RETURN FALSE.
	}).
	returnLex:ADD(5,{//ETA calc
		PARAMETER curentIndex.
		LOCAL i IS dataLex["index"].
		LOCAL distToNext IS distList[i] - distList[i + 1].
		LOCAL avrSpeed IS (speedList[i] + speedList[i + 1]) / 2.

		SET etaList[i] TO etaList[i + 1] + distToNext / avrSpeed.
		SET dataLex["index"] TO i - 1.
		IF dataLex["index"] < curentIndex {
			SET dataLex["state"] TO 0.
			SET dataLex["index"] TO curentIndex.
			RETURN TRUE.
		} ELSE {
			RETURN FALSE.
		}
	}).
	RETURN returnLex.
}

FUNCTION percent_state_calc {
	PARAMETER dataLex,maxIndex.
	LOCAL stateVal IS dataLex["state"].
	IF stateVal < 0 {
		RETURN ((maxIndex - dataLex["index"]) / maxIndex) / -3 + ((stateVal + 1) / 3).
	} ELSE IF stateVal < 3 {
		RETURN (((dataLex["index"] + stateVal / 3) / maxIndex) / 2).
	} ELSE IF stateVal = 3 {
		RETURN ((dataLex["index"]/maxIndex) / 6 + 0.5).
	} ELSE {
		RETURN (((maxIndex - dataLex["index"]) / maxIndex) / 6 + (stateVal / 6)).
	}
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