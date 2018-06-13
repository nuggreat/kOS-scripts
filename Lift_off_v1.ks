//program set up
RUNONCEPATH("1:/lib/lib_navball2.ks").
PARAMETER apHeight,launchHeading.
SET targetAP TO apHeight * 1000.
SET targetHeading TO launchHeading.

RCS OFF.
SAS OFF.
SET bodyAtmosphere TO SHIP:BODY:ATM.

//PID setup PIDLOOP(kP,kI,kD,min,max)
SET throttlePID TO PIDLOOP(0.5,0.1,0,0,1).
SET circulisePID TO PIDLOOP(0.02,0.0002,0.002,-20,20).

//launch parameter verificaton
CLEARSCREEN.
PRINT "Lanuching to an apolapsis of: " + (targetAP / 1000) + "Km".
IF bodyAtmosphere:EXISTS AND targetAP < bodyAtmosphere:HEIGHT {
	PRINT "Warning target apolapsis is below atmosphere height".
}
PRINT "Lanuching with heaidng of:    " + targetHeading.
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
//start of flight
LOCK STEERING TO HEADING(targetHeading,90).
LOCAL vertSpeed IS 25.
LOCAL pitchTo IS 40.
LOCK THROTTLE TO throttle_PID(55,0.25).
IF bodyAtmosphere:EXISTS {
	SET vertSpeed TO 100.
	SET pitchTo TO 80.
	LOCK THROTTLE TO throttle_PID(55,1).
}
stage_check().
PRINT "Beginning Roll Program".
WAIT UNTIL SHIP:VERTICALSPEED > vertSpeed.
LOCK STEERING TO HEADING(targetHeading,pitchTo).
PRINT "Beginning Pitch Program".
WAIT 1.
IF bodyAtmosphere:EXISTS {	//liftoff
	UNTIL pitchTo > pitch_of_vector(SHIP,SHIP:SRFPROGRADE:FOREVECTOR) OR SHIP:ORBIT:APOAPSIS > targetAP {
		LOCK THROTTLE TO throttle_PID(55,0.25).
		stage_check().
		WAIT 0.01.
	}
} ELSE {
	UNTIL pitchTo > pitch_of_vector(SHIP,SHIP:PROGRADE:FOREVECTOR) OR SHIP:ORBIT:APOAPSIS > targetAP {
		LOCK THROTTLE TO throttle_PID(55,0.15).
		stage_check().
		WAIT 0.01.
	}
}
PRINT "Roll Program Complete".

//pitch and boost to apolapsis
PRINT "Boosting to Apoapsis".

LOCAL throttleLimit IS 0.25.
IF bodyAtmosphere:EXISTS {
	LOCK STEERING TO SHIP:SRFPROGRADE.
} ELSE {
	LOCK STEERING TO SHIP:PROGRADE.
	SET throttleLimit TO 0.15.
}

UNTIL SHIP:ORBIT:APOAPSIS > targetAP	{
	LOCK THROTTLE TO throttle_PID(55,throttleLimit).
	stage_check().
	WAIT 0.01.
}
PRINT "Pitch Program Complete".
PRINT "Done With Boost".

//delays the start of circularization if the time to ap is high
LOCK STEERING TO SHIP:PROGRADE:FOREVECTOR.
IF ETA:APOAPSIS > 120 {
	UNTIL ETA:APOAPSIS < 120{
		IF SHIP:ORBIT:APOAPSIS < targetAP {
			LOCK THROTTLE TO throttle_PID(55,MAX((targetAP - SHIP:ORBIT:APOAPSIS) / 1000,0.001)).
		} ELSE {
			LOCK THROTTLE TO throttle_PID(55,0).
		}
		WAIT 0.01.
	}
}

//circularization of orbit
PRINT "Beging Circularization".
LOCAL pitchTo IS 0.
LOCAL apDiff IS 0.
LOCAL etaTarget IS 0.
SET circulisePID:SETPOINT TO targetAP.
UNTIL SHIP:ORBIT:PERIAPSIS > (targetAP * 0.99) {
	IF SHIP:VERTICALSPEED > 0 {
		SET etaTarget TO MAX(MIN(SHIP:ORBIT:ECCENTRICITY * 250,55),30).
		IF SHIP:ORBIT:APOAPSIS < targetAP {
			LOCK THROTTLE TO throttle_PID(etaTarget,0.02).
		} ELSE {
			LOCK THROTTLE TO throttle_PID(etaTarget,0).
		}
		SET pitchTo TO circulisePID:UPDATE(TIME:SECONDS, SHIP:ORBIT:APOAPSIS).
	} ELSE {
		SET etaTarget TO MAX(MIN((SHIP:ALTITUDE - SHIP:ORBIT:PERIAPSIS) / 5000,55),30).
		LOCK THROTTLE TO (SHIP:ORBIT:PERIOD - ETA:APOAPSIS)/etaTarget/2.5 .
		SET pitchTo TO 0 - circulisePID:UPDATE(TIME:SECONDS, SHIP:ORBIT:APOAPSIS).
	}

	LOCAL headingTo IS heading_of_vector(SHIP,SHIP:PROGRADE:FOREVECTOR).
	LOCK STEERING TO HEADING(headingTo,pitchTo).

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

FUNCTION stage_check {	//a check for if the rocket needs to stage
	LIST ENGINES IN engineList.
	LOCAL needStage IS MAXTHRUST = 0.
	FOR engine IN engineList {
		SET needStage TO needStage OR engine:FLAMEOUT.
	}
	IF needStage	{
		STAGE.
		STEERINGMANAGER:RESETPIDS().
	}
}

FUNCTION throttle_PID {	//throttle PID for assent and circularization
	PARAMETER etaTarget,minThrottle.
	SET throttlePID:SETPOINT TO etaTarget.
	RETURN MAX(throttlePID:UPDATE(TIME:SECONDS,ETA:APOAPSIS),minThrottle).
}
//	start flight for inclination set
//		lock controls
//			to pitch of 90
//			to heading of other for inclination
//				for inclination set 90 - inclination parameter (include degree wrap) + headingPID
//					headingPID how far off inclination, KP about 0.1, KI about 0.01, KD about 0.01