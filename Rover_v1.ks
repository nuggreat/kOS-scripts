SET TERMINAL:WIDTH TO 45.
SET TERMINAL:HEIGHT TO 15.
PARAMETER dest,		//destination as a waypoint, geocoordinate, vessel, or part
	speedTarget,		//desired speed in m/s
	stoppingDist,	//distance to come to final stop at in m
	minSpeed.		//desired minimum speed in m/s will be overridden by slope reductions
IF NOT EXISTS("1:/lib/lib_formating.ks") COPYPATH("0:/lib/lib_formating.ks","1:/lib/").
IF NOT EXISTS("1:/lib/lib_rocket_utilities.ks") COPYPATH("0:/lib/lib_rocket_utilities.ks","1:/lib/").
FOR lib IN LIST("lib_navball","lib_formating","lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}

BRAKES OFF.
RCS OFF.
ABORT OFF.
LOCAL mark IS LATLNG(0,0).
LOCAL doIt IS TRUE.

IF dest:ISTYPE("string") {SET dest TO WAYPOINT(dest).}
IF dest:ISTYPE("vessel") or dest:ISTYPE("waypoint") {
	SET mark TO dest:GEOPOSITION.
} ELSE {
	IF dest:ISTYPE("part") {
		SET mark TO BODY:GEOPOSITIONOF(dest:POSITION).
	} ELSE {
		IF dest:ISTYPE("geocoordinates") {
			SET mark TO dest.
		} ELSE {
			PRINT "I don't know how ues a dest type of :" + dest:TYPENAME.
			SET doIt TO false.
		}
	}
}

SET listETA TO LIST(LIST(target_distance(mark),TIME:SECONDS,1)).

//PID setup
LOCAL speed_PID IS PIDLOOP().
SET speed_PID:KP TO 0.5.
SET speed_PID:KI TO 0.2.
SET speed_PID:KD TO 0.02.
SET speed_PID:MAXOUTPUT TO 1.
SET speed_PID:MINOUTPUT TO -1.

LOCAL steer_PID IS PIDLOOP().
SET steer_PID:KP TO 1/(8*2.5).//2.5-/-10
SET steer_PID:KI TO 1/(8*16).//16-/-64
SET steer_PID:KD TO 1/(8*8).//8-/-16
SET steer_PID:MAXOUTPUT TO 1.
SET steer_PID:MINOUTPUT TO -1.

control_point("roverControl").
IF doIt {	//start of core logic
CLEARSCREEN.
LOCAL roving IS false.
LOCAL stopping IS false.
LOCAL count IS 1.
LOCAL dist IS target_distance(mark).
SET speed_PID:SETPOINT TO speed_adv(dist).

UNTIL roving {	//roving to mark

	LOCAL forSpeed IS forward_speed().
	LOCAL timeStep IS TIME:SECONDS.
	SET SHIP:CONTROL:WHEELTHROTTLE TO speed_PID:UPDATE(timeStep,forSpeed).
	IF forSpeed > 0 {
		SET SHIP:CONTROL:WHEELSTEER TO steer_PID:UPDATE(timeStep,mark:BEARING).
	} ELSE {
		SET SHIP:CONTROL:WHEELSTEER TO 0 - steer_PID:UPDATE(timeStep,mark:BEARING).
	}
	PID_minMax(forSpeed,steer_PID).

	IF count > 5 {
		SET dist TO target_distance(mark).
		SET speed_PID:SETPOINT TO speed_adv(dist).
		LOCAL speedDif IS speed_PID:SETPOINT - forSpeed.
		brake_check(speedDif,forSpeed).
		screen_update(dist,forSpeed,speedDif).
		SET count TO 1.
	} ELSE {
		SET count TO count + 1.
	}
	SET roving TO stoppingDist > mark:DISTANCE OR ABORT.
	WAIT 0.01.
}
BRAKES ON.
ABORT OFF.
WAIT 0.01.
SET speed_PID:SETPOINT TO 0.
UNTIL stopping {	//stopping once close to mark

	LOCAL forSpeed IS forward_speed().
	LOCAL timeStep IS TIME:SECONDS.
	SET SHIP:CONTROL:WHEELTHROTTLE TO speed_PID:UPDATE(timeStep,forSpeed).
	SET SHIP:CONTROL:WHEELSTEER TO steer_PID:UPDATE(timeStep,mark:BEARING).
	PID_minMax(forSpeed,steer_PID).

	IF count > 5 {
		SET dist TO target_distance(mark).
		LOCAL speedDif IS speed_PID:SETPOINT - forSpeed.
		screen_update(dist,forSpeed,speedDif,TRUE).
		SET count TO 1.
	} ELSE {
		SET count TO count + 1.
	}
	SET stopping TO 1 > forward_speed() OR ABORT.
	WAIT 0.01.
}
}
SET SHIP:CONTROL:WHEELTHROTTLE TO 0.
SET SHIP:CONTROL:WHEELSTEER TO 0.
UNLOCK WHEELSTEERING.
UNLOCK WHEELTHROTTLE.

//end of core logic start of functions
FUNCTION speed_adv {		//target speed reduced by how off targetBearing the rover is and how steep the slope is
	PARAMETER dist,localAccel IS 0.025.
	LOCAL offMark IS (LOG10(ABS(mark:BEARING) + 1) / 2.25).
	LOCAL slope IS (ABS(pitch_for(SHIP)) + ABS(roll_for(SHIP)) + 0.01).
//	LOCAL dist IS MAX((dist - stoppingDist) / 125,minSpeed).
	LOCAL dist IS MIN(MAX(((2 * MAX(dist - stoppingDist,0.01) / localAccel)^.5) * localAccel,minSpeed),speedTarget).
	RETURN MIN(MAX(speedTarget - (slope / 60 * speedTarget) - (offMark * speedTarget) , 1),dist).
}

FUNCTION forward_speed {		//the speed of the rover positave for forward movment negitave for reverse movment
	RETURN VDOT( SHIP:VELOCITY:SURFACE, ANGLEAXIS(0, SHIP:FACING:STARVECTOR) * SHIP:FACING:FOREVECTOR).
}

FUNCTION screen_update {		//updates the terminal
	PARAMETER dist,forSpeed,speedDif,stopping IS FALSE..
	LOCAL targetETA IS target_eta(dist - stoppingDist).
//	CLEARSCREEN.
	LOCAL printList IS LIST().
	printList:ADD("Distance      : " + si_formating(dist,"m")).
	IF NOT stopping {
		printList:ADD("ETA           :" + time_formating(targetETA,5)).
	} ELSE {
		printList:ADD("                       ").
	}
	printList:ADD(" ").
	printList:ADD("Curent Speed  :" + padding(forSpeed,2,2)).
	printList:ADD("Target Speed  :" + padding(speed_PID:SETPOINT,2,2)).
	printList:ADD("Speed Differce:" + padding(speedDif,2,2)).
	printList:ADD("Wheel Throttle: " + padding(SHIP:CONTROL:WHEELTHROTTLE,1,2)).
//	printList:ADD("     P: " + ROUND(speed_PID:PTERM,3)).
//	printList:ADD("     I: " + ROUND(speed_PID:ITERM,3)).
//	printList:ADD("     D: " + ROUND(speed_PID:DTERM,3)).
//	printList:ADD("Output: " + ROUND(speed_PID:OUTPUT,2)).
	printList:ADD(" ").
	printList:ADD("Bearing to Target:" + padding(mark:BEARING,2,1)).
//	printList:ADD("     P: " + ROUND(steer_PID:PTERM,3)).
//	printList:ADD("     I: " + ROUND(steer_PID:ITERM,3)).
//	printList:ADD("     D: " + ROUND(steer_PID:DTERM,3)).
//	printList:ADD("Output: " + ROUND(steer_PID:OUTPUT,2)).
	printList:ADD("Wheel Steering Is: " + padding(SHIP:CONTROL:WHEELSTEER,1,2)).
	IF stopping {
		CLEARSCREEN.
		FOR line IN printList { PRINT line. }
		PRINT "stopping".
	} ELSE {
		printList:ADD("       ").
		FROM { LOCAL i IS printList:LENGTH - 1. } UNTIL 0 > i STEP { SET i TO i - 1. } DO {
			PRINT printList[i] + "      " AT(0,i).
		}
	}
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

FUNCTION target_distance {	//calculates distance to target using Law of Cosines for over land distance
	PARAMETER distTar.
	LOCAL bodyRadius IS SHIP:BODY:RADIUS.
	LOCAL aVal IS (distTar:TERRAINHEIGHT + bodyRadius).
	LOCAL bVal IS (ALTITUDE + bodyRadius).
	LOCAL cVal IS (distTar:DISTANCE).
	LOCAL cosOfC IS ARCCOS((cVal ^ 2 - (aVal ^ 2 + bVal ^ 2)) / (-2 * aVal *bVal)).
	RETURN (cosOfC / 360) * (CONSTANT():PI * bodyRadius * 2).
}

FUNCTION target_eta {	//calculates ETA to target
	PARAMETER dist.
	LOCAL deltaDist IS listETA[0][0] - dist.
	LOCAL deltaTime IS TIME:SECONDS - listETA[0][1].
	LOCAL stepETA IS dist / (deltaDist / deltaTime).
	LOCAL totalETA IS 0.
	listETA:ADD(LIST(dist,TIME:SECONDS,stepETA)).
	IF listETA:LENGTH > 10 {listETA:REMOVE(0).}
	FOR value IN listETA {
		SET totalETA TO totalETA + value[2].
	}
	RETURN totalETA / listETA:LENGTH.
}

FUNCTION PID_minMax {	//resets the max/min for a given pid depending on the speed that gets passed in
	PARAMETER forSpeed,pid.
	SET pid:MAXOUTPUT TO MIN(2 / ABS(forSpeed),1).
	SET pid:MINOUTPUT TO MAX(-2 / ABS(forSpeed),-1).
}