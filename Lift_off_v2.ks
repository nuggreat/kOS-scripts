//program set up
PARAMETER apHeight,launchHeading.
FOR lib IN LIST("lib_navball2","lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
control_point().
LOCAL targetAP IS apHeight * 1000.

RCS OFF.
SAS OFF.
LOCAL bodyAtmosphere IS SHIP:BODY:ATM.

//PID setup PIDLOOP(kP,kI,kD,min,max)
SET throttlePID TO PIDLOOP(0.5,0.1,0,0,1).
SET circulisePID TO PIDLOOP(0.02,0.0002,0.002,-20,20).

//launch parameter verificaton
CLEARSCREEN.
PRINT "Lanuching to an apolapsis of: " + (targetAP / 1000) + "Km".
IF bodyAtmosphere:EXISTS AND targetAP < bodyAtmosphere:HEIGHT {
	PRINT "Warning target apolapsis is below atmosphere height".
}
PRINT "Lanuching with heaidng of:    " + launchHeading.
PRINT " ".
IF bodyAtmosphere:EXISTS {
	PRINT SHIP:BODY:NAME + " has a atmosphere height of: " + bodyAtmosphere:HEIGHT / 1000 + "Km".
} ELSE {
	PRINT SHIP:BODY:NAME + " has no atmosphere".
}
PRINT " ".
PRINT "Activate SAS to start Launch, RCS to abort".

UNTIL SAS OR RCS {
	WAIT 1.
	SET goNoGo TO SAS.
}
CLEARSCREEN.
RCS OFF.
SAS OFF.

IF goNoGo {	//start of core logic

SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
count_down(5).
IF GEAR {
	GEAR off.
	DEPLOYDRILLS off.
}
//start of flight
LOCAL etaSet IS 60.
LOCK STEERING TO HEADING(launchHeading,90).
LOCAL vertSpeed IS 50.
LOCK THROTTLE TO throttle_PID(etaSet,0.25).
LOCAL maxPitch IS 22.5.
IF bodyAtmosphere:EXISTS {
	SET vertSpeed TO 100.
	LOCK THROTTLE TO throttle_PID(etaSet,1).
	SET maxPitch TO 10.
}
UNTIL SHIP:AVAILABLETHRUST > 0 {
	stage_check().
	WAIT 0.01.
}
LOCAL pitchTo IS 90 - MAX(MIN(((SHIP:AVAILABLETHRUST / SHIP:MASS) / (SHIP:BODY:MU / SHIP:BODY:RADIUS^2) - 1) * 10,45),maxPitch).
PRINT "Beginning Roll Program".
WAIT UNTIL SHIP:VERTICALSPEED > vertSpeed OR (ETA:APOAPSIS > (etaSet - 0.1) AND SHIP:VERTICALSPEED > 10).
LOCK STEERING TO HEADING(launchHeading,pitchTo).
PRINT "Beginning Pitch Program".
WAIT 1.
IF bodyAtmosphere:EXISTS {	//liftoff
	LOCK THROTTLE TO throttle_PID(etaSet,0.25).
	UNTIL pitchTo > pitch_target(SHIP:SRFPROGRADE:FOREVECTOR,etaSet,5,-5,20) OR SHIP:ORBIT:APOAPSIS > targetAP {
		stage_check().
		WAIT 0.01.
	}
} ELSE {
	LOCK THROTTLE TO throttle_PID(etaSet,0.15).
	UNTIL pitchTo > pitch_target(SHIP:PROGRADE:FOREVECTOR,etaSet,5,0,20) OR SHIP:ORBIT:APOAPSIS > targetAP {
		stage_check().
		WAIT 0.01.
	}
}
PRINT "Roll Program Complete".

//pitch and boost to apolapsis
PRINT "Boosting to Apoapsis".

IF bodyAtmosphere:EXISTS {
	LOCAL gradeVec IS SHIP:SRFPROGRADE:FOREVECTOR.
	LOCAL headingTar IS heading_of_vector(gradeVec).
	LOCAL pitchTar IS pitch_target(gradeVec,etaSet,5,-5,20).
	LOCK STEERING TO HEADING(headingTar,pitchTar).
	LOCK THROTTLE TO throttle_PID(etaSet,0.25).

	UNTIL SHIP:ORBIT:APOAPSIS > targetAP	{
		SET gradeVec TO SHIP:SRFPROGRADE:FOREVECTOR.
		SET headingTar TO heading_of_vector(gradeVec).
		SET pitchTar TO pitch_target(gradeVec,etaSet,5,-5,20).
		stage_check().
		WAIT 0.01.
	}
} ELSE {
	LOCAL gradeVec IS SHIP:PROGRADE:FOREVECTOR.
	LOCAL headingTar IS heading_of_vector(gradeVec).
	LOCAL pitchTar IS pitch_target(gradeVec,etaSet,5,0,20).
	LOCK STEERING TO HEADING(headingTar,pitchTar).
	LOCK THROTTLE TO throttle_PID(etaSet,0.10).

	UNTIL SHIP:ORBIT:APOAPSIS > targetAP	{
		SET gradeVec TO SHIP:PROGRADE:FOREVECTOR.
		SET headingTar TO heading_of_vector(gradeVec).
		SET pitchTar TO pitch_target(gradeVec,etaSet,5,0,20).
		stage_check().
		WAIT 0.01.
	}
}

PRINT "Pitch Program Complete".
PRINT "Done With Boost".

//delays the start of circularization if the time to ap is high
LOCK STEERING TO SHIP:PROGRADE:FOREVECTOR.
LOCK THROTTLE TO throttle_PID(etaSet,0).

IF bodyAtmosphere:EXISTS AND SHIP:ALTITUDE < bodyAtmosphere:HEIGHT {
	PRINT "Coasting to Edge of Atmosphere".
	LOCAL engActive IS FALSE.
	UNTIL ETA:APOAPSIS < 151 OR SHIP:ALTITUDE > bodyAtmosphere:HEIGHT {
		IF SHIP:ORBIT:APOAPSIS < targetAP {
			IF NOT engActive {
				LOCK THROTTLE TO throttle_PID(etaSet,MAX((targetAP - SHIP:ORBIT:APOAPSIS) / 1000,0.001)).
				SET engActive TO TRUE.
			}
		} ELSE {
			IF engActive {
				LOCK THROTTLE TO throttle_PID(etaSet,0).
				SET engActive TO FALSE.
			}
		}
		WAIT 0.01.
	}
}

IF ETA:APOAPSIS > 151 {
	PRINT "Warping to 150 Seconds Before Ap".
	UNTIL ETA:APOAPSIS < 151 OR KUNIVERSE:TIMEWARP:WARP > 0 {
		WAIT 0.01.
		IF SHIP:ALTITUDE > bodyAtmosphere:HEIGHT + 100. {
			SET KUNIVERSE:TIMEWARP:MODE TO "RAILS".
			KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + (ETA:APOAPSIS - 150)).
		}
	}
}

UNTIL ETA:APOAPSIS < 90 {
	IF (ETA:APOAPSIS < 120) AND (KUNIVERSE:TIMEWARP:WARP > 0) { KUNIVERSE:TIMEWARP:CANCELWARP. }
	IF SHIP:ORBIT:APOAPSIS < targetAP {
		LOCK THROTTLE TO throttle_PID(etaSet,MAX((targetAP - SHIP:ORBIT:APOAPSIS) / 1000,0.001)).
	} ELSE {
		LOCK THROTTLE TO throttle_PID(etaSet,0).
	}
	WAIT 0.01.
}

//circularization of orbit
PRINT "Beging Circularization".
LOCAL pitchTo IS 0.
LOCK STEERING TO HEADING(heading_of_vector(SHIP:PROGRADE:FOREVECTOR),pitchTo).
LOCAL apDiff IS 0.
LOCAL etaTar IS etaSet.
SET circulisePID:SETPOINT TO targetAP.
UNTIL SHIP:ORBIT:PERIAPSIS > (targetAP * 0.99) {
	IF SHIP:VERTICALSPEED > 0 {
		SET etaTar TO etaSet.
		LOCK THROTTLE TO throttle_PID(etaTar,0.001).
		SET pitchTo TO circulisePID:UPDATE(TIME:SECONDS, SHIP:ORBIT:APOAPSIS).
	} ELSE {
		SET etaTar TO MAX(MIN((SHIP:ALTITUDE - SHIP:ORBIT:PERIAPSIS) / 5000,60),30).
		LOCK THROTTLE TO (SHIP:ORBIT:PERIOD - ETA:APOAPSIS)/etaTar/2.5 .
		SET pitchTo TO 0 - circulisePID:UPDATE(TIME:SECONDS, SHIP:ORBIT:APOAPSIS).
	}
	stage_check().
	WAIT 0.01.
}
}
PRINT "Done With Engines".

SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
UNLOCK THROTTLE.
UNLOCK STEERING.

//end of core logic start of functions
FUNCTION count_down {	//pre launch count down
	PARAMETER count.
	FROM {LOCAL i IS count.} UNTIL i = 0 STEP {SET i TO i - 1.} DO
	{
		HUDTEXT( "T- " + i + "s" , 1, 1, 25, white, true).
		WAIT 1.
	}
	HUDTEXT( "Launch" , 1, 1, 25, white, true).
}

FUNCTION throttle_PID {	//throttle PID for assent and circularization
	PARAMETER etaTarget,minThrottle.
	SET throttlePID:SETPOINT TO etaTarget.
	RETURN MAX(throttlePID:UPDATE(TIME:SECONDS,ETA:APOAPSIS),minThrottle).
}

FUNCTION pitch_target {	//decreases pitch if craft is close to etatarget
	PARAMETER gradeVec,etaTarget,deviationPos,deviationNeg,etaStart.	//the etaStart number of sec before AP the pitch down will start
	LOCAL gradent IS etaStart / deviationPos.
	LOCAL vecPitch IS pitch_of_vector(gradeVec).
	LOCAL downPitch IS MAX((ETA:APOAPSIS + (deviationPos * gradent)) - etaTarget, deviationNeg) / gradent.
	RETURN MIN(MAX(vecPitch - downPitch,0),80).
}