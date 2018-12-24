PARAMETER maxSpeed,minSpeed,stopDist,waypointList,waypointRadius,destName.
LOCAL wheelAccel IS 0.025.
IF NOT EXISTS("1:/lib/lib_rocket_utilities.ks") COPYPATH("0:/lib/lib_rocket_utilities.ks","1:/lib/").
FOR lib IN LIST("lib_geochordnate","lib_navball2","lib_formating","lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
CLEARSCREEN.
ABORT OFF.
SAS OFF.
SET STEERINGMANAGER:ROLLCONTROLANGLERANGE TO 180.
//SET CONFIG:IPU TO 200.
//PID setup PIDLOOP(kP,kI,kD,min,max)
LOCAL throttlePID IS PIDLOOP(0.5,0.2,0.02,-1,1).
LOCAL steeringPID IS PIDLOOP(0.5,0.02,0.1,-1,1).

control_point("roverControl").
PRINT "Rover Starting up.".
LOCAL waypointIndex IS 0.
LOCAL wayListLength IS waypointList:LENGTH - 1.
LOCAL distList IS generate_dist_list(waypointList).//calculate distance along path between waypoints
LOCAL limitLex IS LEX("state",-1,"index",0,"maxIndex",wayListLength,"speedRange",(maxSpeed - minSpeed),"minSpeed",minSpeed).
LOCAL speedListDynamic IS LIST().
LOCAL limitFunctionLex IS speed_limit_recalc_function_lex(limitLex,waypointList,distList,speedListDynamic).
//UNTIL speed_limit_recalc(limitFunctionLex,limitLex,waypointList,distList,speedListDynamic).
UNTIL speed_limit_recalc(limitFunctionLex,limitLex).
LOCAL speedListStatic IS speedListDynamic:COPY().
//PRINT speedListDynamic.
//LOCAL speedListDynamic IS generate_speed_limmits(waypointList,maxSpeed,minSpeed,wheelAccel).//calculate speed limits for waypoints
LOCAL pathDist IS distList[waypointIndex].
LOCAL oldSlope IS 0.
LOCAL newSlope IS slope_calculation(waypointList[waypointIndex]).
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

LOCAL done IS TRUE.
LOCAL stopping IS FALSE.
LOCAL steerNotLocked IS TRUE.
//BRAKES OFF.
UNTIL done {
	WAIT 0.
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
			SET newSlope TO slope_calculation(waypointList[waypointIndex]).
			SET grade TO ABS(grade_claculation(waypointList[waypointIndex - 1],waypointList[waypointIndex])).
			//SET slope_grade_error TO SIN(((oldSlope + newSlope) / 2 + grade) / 2).
			SET slope_grade_error TO SIN(MIN(MAX(((oldSlope + newSlope)/2 + grade),0),90)).

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

	LOCAL percentTravled IS MAX(MIN(VDOT(pathVec - offPathVec,pathVec:NORMALIZED) / pathVec:MAG,1),-0.5).//distance of ship along pathVector in % 
	//LOCAL percentError IS (1 - percentTravled) * offPathBy / 180.
	//LOCAL percentError IS (1 - percentTravled) * COS(MIN(offPathBy*2,90)).
	//LOCAL percentError IS COS(MIN(offPathBy * 2,90)).
	LOCAL percentError IS offPathBy / waypointRadius.//converting offPathBy into a %, 0 is on path

	//CLEARSCREEN.
	//PRINT "error: " + percentError.
	//PRINT "%remain: " + percentTravled.
	SET pointMag TO MAX(MIN(percentTravled + MAX(1 - percentError,0) * 0.5,1),0).
	LOCAL pointPos IS preNextVec * pointMag + origenPos.//calculating the target position along the path vec
	LOCAL shipPoinVec IS pointPos - origenPos.

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
		SET throttlePID:SETPOINT TO MIN(MAX(MIN(1 - (slope_grade_error + ABS(steerError * 2) + percentError / 2),1),0) * speedRange,accelLimit) + minSpeed.
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

	LOCAL steerPIDrange IS MIN(MAX(1 - ((forSpeed - minSpeed) / steerLimit),0.025),1).
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
	screen_update(tarGeoDist,pointBearing,forSpeed,speedDif,steerPIDrange).
	IF steerNotLocked AND ((upError > 10) OR (SHIP:STATUS <> "LANDED")) {
		LOCK STEERING TO steerDir.
		SET steerNotLocked TO FALSE.
	} ELSE IF (NOT steerNotLocked) AND ((ABS(STEERINGMANAGER:ANGLEERROR) + ABS(STEERINGMANAGER:ROLLERROR)) < 5) AND (SHIP:STATUS = "LANDED") {
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

	FROM { LOCAL i IS printList:LENGTH + 1. } UNTIL 0 > i STEP { SET i TO i - 1. } DO {
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

FUNCTION generate_speed_limmits {
	PARAMETER waypointList,distList,maxSpeed,minSpeed,wheelAccel.
	LOCAL speedRange IS maxSpeed - minSpeed.
	LOCAL returnList IS LIST(minSpeed).//adding inital point
	LOCAL listLenght IS waypointList:LENGTH - 1.
	FROM { LOCAL i IS 1. } UNTIL i >= listLenght STEP { SET i TO i + 1. } DO {
		LOCAL prePoint IS waypointList[i - 1].
		LOCAL point IS waypointList[i].
		LOCAL nextPoint IS waypointList[i + 1].
		
		LOCAL slope IS MIN(slope_calculation(point),90).
		LOCAL turnAngle IS ABS(bearing_between((prePoint:POSITION - point:POSITION),(nextPoint:POSITION - point:POSITION)) / 2).
		LOCAL gradeDiff IS MIN(ABS(grade_claculation(prePoint,point) - grade_claculation(point,newPoint)) * 2,90).

		LOCAL slopeLimit IS COS(slope).
		LOCAL turnLimit IS SIN(turnAngle).
		LOCAL gradeLimit IS COS(gradeDiff).
		
		LOCAL speedLimit IS MIN(MIN(slopeLimit,turnLimit),gradeLimit) * speedRange + minSpeed.
		returnList:ADD(speedLimit).
	}
	LOCAL slope IS slope_calculation(waypointList[listLenght]).
	returnList:ADD(minSpeed).//adding final point
	
	FROM { LOCAL i IS 1. } UNTIL i >= listLenght STEP { SET i TO i + 1. } DO {//smoothing speed changes based on accel forward along list
		LOCAL distToNext IS distList[i - 1] - distList[i - 1].
		LOCAL deltaSpeed IS accel_dist_to_speed(wheelAccel,distToNext,maxSpeed).
		SET returnList[i] TO MIN(returnList[i],returnList[i - 1] + deltaSpeed).
	}
	
	FROM { LOCAL i IS listLenght - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {//smoothing speed changes based on accel backwards along list
		LOCAL distToNext IS dist_between_coordinates(waypointList[i],waypointList[i + 1]).
		LOCAL deltaSpeed IS accel_dist_to_speed(wheelAccel,distToNext,maxSpeed).
		SET returnList[i] TO MIN(returnList[i],returnList[i + 1] + deltaSpeed).
	}
	
	RETURN returnList.
}

//LOCAL dataLex IS LEX("state",-1,"index",0,"maxIndex",(waypointList:LENGTH - 1),"speedRange",(maxSpeed - minSpeed),"minSpeed",minSpeed).
FUNCTION speed_limit_recalc {
	//PARAMETER functionLex,dataLex,waypointList,distList,speedList.
	PARAMETER functionLex,dataLex.
	PRINT "state: " + dataLex["state"] + "  " AT(0,0).
	PRINT "index: " + dataLex["index"] + "  " AT(0,1).
	//RETURN functionLex[dataLex["state"]]:CALL(dataLex,waypointList,distList,speedList).
	RETURN functionLex[dataLex["state"]]:CALL().
}

FUNCTION speed_limit_recalc_function_lex {
	PARAMETER dataLex,waypointList,distList,speedList.
	LOCAL returnLex IS LEX().
	returnLex:ADD(-1,{
		//PARAMETER dataLex,waypointList,distList,speedList.
		UNTIL speedList:LENGTH >= waypointList:LENGTH { speedList:ADD(0). }
		SET dataLex["state"] TO 0.
		RETURN FALSE.
	}).
	returnLex:ADD(0,{//add in slope value
		//PARAMETER dataLex,waypointList,distList,speedList.
		LOCAL i IS dataLex["index"].
		IF i = 0 OR i = dataLex["maxIndex"] {
			SET speedList[i] TO dataLex["minSpeed"].
			SET dataLex["state"] TO 2.
			RETURN FALSE.
		} ELSE {
			SET speedList[i] TO COS(MIN(slope_calculation(waypointList[i]),90)).
			SET dataLex["state"] TO 1.
			RETURN FALSE.
		}
	}).
	returnLex:ADD(1,{//add in turn value
		//PARAMETER dataLex,waypointList,distList,speedList.
		LOCAL i IS dataLex["index"].
		//SET speedList[i] TO MIN(speedList[i],SIN(ABS(bearing_between((waypointList[i - 1]:POSITION - waypointList[i]:POSITION),(waypointList[i + 1]:POSITION - waypointList[i]:POSITION)) / 2))).
		SET speedList[i] TO speedList[i] - COS(ABS(bearing_between((waypointList[i - 1]:POSITION - waypointList[i]:POSITION),(waypointList[i + 1]:POSITION - waypointList[i]:POSITION)) / 2)).
		SET dataLex["state"] TO 2.
		RETURN FALSE.
	}).
	returnLex:ADD(2,{//adding grade value
		//PARAMETER dataLex,waypointList,distList,speedList.
		LOCAL i IS dataLex["index"].
		IF i <> 0 AND i <> dataLex["maxIndex"] {
			//SET speedList[i] TO MIN(speedList[i],COS(MIN(ABS(grade_claculation(waypointList[i - 1],waypointList[i]) - grade_claculation(waypointList[i],waypointList[i + 1])) * 2,90))) * dataLex["speedRange"] + dataLex["minSpeed"].
			SET speedList[i] TO MIN(speedList[i] - SIN(MIN(ABS(grade_claculation(waypointList[i - 1],waypointList[i]) - grade_claculation(waypointList[i],waypointList[i + 1])) * 2,90)),0) * dataLex["speedRange"] + dataLex["minSpeed"].
		}
		SET dataLex["index"] TO i + 1.
		IF dataLex["index"] > dataLex["maxIndex"] {
			SET dataLex["state"] TO 3.
			SET dataLex["index"] TO 1.
		} ELSE {
			SET dataLex["state"] TO 0.
		}
		RETURN FALSE.
	}).
	returnLex:ADD(3,{//limiting speed forward based on accel limit
		//PARAMETER dataLex,waypointList,distList,speedList.
		LOCAL i IS dataLex["index"].
		LOCAL distToNext IS distList[i - 1] - distList[i].
		LOCAL deltaSpeed IS accel_dist_to_speed(wheelAccel,distToNext,maxSpeed).
		SET speedList[i] TO MIN(speedList[i],speedList[i - 1] + deltaSpeed).
		SET dataLex["index"] TO i + 1.
		IF dataLex["index"] > dataLex["maxIndex"] {
			SET dataLex["state"] TO 4.
			SET dataLex["index"] TO dataLex["maxIndex"] - 1.
		}
		RETURN FALSE.
		
	}).
	returnLex:ADD(4,{//limiting speed backwards based on accel limit
		//PARAMETER dataLex,waypointList,distList,speedList.
		LOCAL i IS dataLex["index"].
		LOCAL distToNext IS distList[i] - distList[i + 1].
		LOCAL deltaSpeed IS accel_dist_to_speed(wheelAccel,distToNext,maxSpeed).
		SET speedList[i] TO MIN(speedList[i],speedList[i + 1] + deltaSpeed).
		SET dataLex["index"] TO i - 1.
		IF dataLex["index"] < 0 {
			SET dataLex["state"] TO 0.
			SET dataLex["index"] TO 0.
			RETURN TRUE.
		} ELSE {
			RETURN FALSE.
		}
	}).
	RETURN returnLex.
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