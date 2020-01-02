//program set up
PARAMETER apHeight,launchHeading,skipConfirm IS FALSE.
FOR lib IN LIST("lib_navball2","lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNPATH("1:/lib/" + lib + ".ks"). }}
control_point().
LOCAL targetAP IS apHeight * 1000.

RCS OFF.
SAS OFF.
LOCAL bodyAtmosphere IS SHIP:BODY:ATM.

//PID setup PIDLOOP(kP,kI,kD,min,max)
SET throttlePID TO PIDLOOP(0.5,0.1,0,0,1).
SET circulisePID TO PIDLOOP(0.02,0.0002,0.002,-20,20).
LOCAL goNoGo IS TRUE.//true to launch, false to cancel 

//launch parameter verificaton
CLEARSCREEN.
IF NOT skipConfirm {
	PRINT "Lanuching to an apolapsis of: " + (targetAP / 1000) + "Km".
	IF bodyAtmosphere:EXISTS AND targetAP < bodyAtmosphere:HEIGHT {
		PRINT "Warning target apolapsis is below atmosphere height".
		PRINT " ".
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
}

//LOCK twr TO (SHIP:AVAILABLETHRUST / SHIP:MASS) / (SHIP:BODY:MU / SHIP:BODY:RADIUS^2). LOCK THROTTLE TO 2/twr.

IF goNoGo {	//start of core logic
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
count_down(5).
IF GEAR {
	GEAR OFF.
	WAIT 0.
	DEPLOYDRILLS OFF.
	WAIT 0.
}

LOCAL timePast IS TIME:SECONDS + 0.1.
WHEN timePast < TIME:SECONDS THEN{
	SET timePast TO TIME:SECONDS + 0.1.
	IF drop_tanks() {
		PRESERVE.
	}
}

//start of flight
LOCAL etaSet IS 60.
LOCAL vertSpeed IS 50.
PID_config(throttlePID,etaSet,0.25).
LOCK THROTTLE TO throttlePID:UPDATE(TIME:SECONDS,signed_eta_ap()).
LOCAL twr IS (SHIP:AVAILABLETHRUST / SHIP:MASS) / (SHIP:BODY:MU / SHIP:BODY:RADIUS^2).
LOCAL maxPitch IS MAX(MIN(twr * 10,45),22.5).
IF bodyAtmosphere:EXISTS {
	SET vertSpeed TO 100.
	PID_config(throttlePID,etaSet,1).
//	LOCK THROTTLE TO throttlePID:UPDATE(TIME:SECONDS,signed_eta_ap()).
	SET maxPitch TO MAX(MIN(twr * 10,10),5).
}
LOCAL pitchTo IS 90.
LOCK STEERING TO HEADING(launchHeading,pitchTo).
UNTIL SHIP:AVAILABLETHRUST > 0 {
	stage_check().
	WAIT 0.01.
}
PRINT "Beginning Roll and Pitch Program".
UNTIL SHIP:VERTICALSPEED > vertSpeed OR (signed_eta_ap() > (etaSet - 0.1) AND SHIP:VERTICALSPEED > 10) {
	SET pitchTo TO 90 - MIN(SHIP:VERTICALSPEED / vertSpeed * maxPitch,maxPitch).
	stage_check().
}
WAIT 1.
IF bodyAtmosphere:EXISTS {	//liftoff
	PID_config(throttlePID,etaSet,0.25).
//	LOCK THROTTLE TO throttlePID:UPDATE(TIME:SECONDS,signed_eta_ap()).
	UNTIL pitchTo > pitch_target(SHIP:VELOCITY:SURFACE,etaSet,5,-5,20) OR SHIP:ORBIT:APOAPSIS > targetAP {
		SET pitchTo TO 90 - min(SHIP:VERTICALSPEED / vertSpeed * maxPitch,maxPitch).
		stage_check().
		WAIT 0.01.
	}
} ELSE {
	PID_config(throttlePID,etaSet,0.15).
//	LOCK THROTTLE TO throttlePID:UPDATE(TIME:SECONDS,signed_eta_ap()).
	UNTIL pitchTo > pitch_target(SHIP:VELOCITY:ORBIT,etaSet,5,0,20) OR SHIP:ORBIT:APOAPSIS > targetAP {
		SET pitchTo TO 90 - MIN(SHIP:VERTICALSPEED / vertSpeed * maxPitch,maxPitch).
		stage_check().
		WAIT 0.01.
	}
}
PRINT "Roll Program Complete".

//pitch and boost to apolapsis
PRINT "Boosting to Apoapsis".
IF bodyAtmosphere:EXISTS {
	LOCAL gradeVec IS SHIP:VELOCITY:SURFACE.
	LOCAL headingTar IS heading_of_vector(gradeVec).
	LOCAL pitchTar IS pitch_target(gradeVec,etaSet,5,-5,20).
	//LOCAL throttleLimit IS twr_limit(2).
	LOCK STEERING TO HEADING(headingTar,pitchTar).
	//LOCK STEERING TO SHIP:VELOCITY:SURFACE.
//	PID_config(throttlePID,etaSet,0.25).
	PID_config(throttlePID,etaSet,0.5).
//	LOCK THROTTLE TO throttlePID:UPDATE(TIME:SECONDS,signed_eta_ap()).

	UNTIL SHIP:ORBIT:APOAPSIS > targetAP	{
		SET gradeVec TO SHIP:VELOCITY:SURFACE.
		SET headingTar TO heading_of_vector(gradeVec).
		SET pitchTar TO pitch_target(gradeVec,etaSet,5,-5,20).
		//SET throttleLimit TO twr_limit(2).
		stage_check().
		WAIT 0.01.
	}
} ELSE {
	LOCAL gradeVec IS SHIP:VELOCITY:ORBIT.
	LOCAL headingTar IS heading_of_vector(gradeVec).
	LOCAL pitchTar IS pitch_target(gradeVec,etaSet,5,0,20).
	LOCK STEERING TO HEADING(headingTar,pitchTar).
	PID_config(throttlePID,etaSet,0.10).
//	LOCK THROTTLE TO throttlePID:UPDATE(TIME:SECONDS,signed_eta_ap()).

	UNTIL SHIP:ORBIT:APOAPSIS > targetAP	{
		SET gradeVec TO SHIP:VELOCITY:ORBIT.
		SET headingTar TO heading_of_vector(gradeVec).
		SET pitchTar TO pitch_target(gradeVec,etaSet,5,0,20).
		stage_check().
		WAIT 0.01.
	}
}

PRINT "Pitch Program Complete".
PRINT "Done With Boost".

//delays the start of circularization if the time to ap is high
LOCK STEERING TO SHIP:VELOCITY:ORBIT.
LOCAL minThrottle IS 0.
//LOCK THROTTLE TO PID_config(throttlePID,etaSet,minThrottle).

IF bodyAtmosphere:EXISTS AND SHIP:ALTITUDE < bodyAtmosphere:HEIGHT {
	PRINT "Coasting to Edge of Atmosphere".
	LOCAL engActive IS TRUE.
	UNTIL signed_eta_ap() < 151 OR SHIP:ALTITUDE > bodyAtmosphere:HEIGHT {
		IF SHIP:ORBIT:APOAPSIS < targetAP {
			SET minThrottle TO MAX((targetAP - SHIP:ORBIT:APOAPSIS) / 1000,0.001).
			PID_config(throttlePID,etaSet,minThrottle).
			IF NOT engActive {
				SET engActive TO TRUE.
			}
		} ELSE {
			IF engActive {
				PID_config(throttlePID,etaSet,0).
				SET engActive TO FALSE.
			}
		}
		WAIT 0.01.
	}
}
LOCK THROTTLE TO 0.

IF signed_eta_ap() > 151 {
	PRINT "Warping to 150 Seconds Before Ap".
	SET minThrottle TO 0.
	UNTIL signed_eta_ap() < 151 OR NOT not_warping() {
		WAIT 0.01.
		IF SHIP:ALTITUDE > bodyAtmosphere:HEIGHT + 100. {
			SET KUNIVERSE:TIMEWARP:MODE TO "RAILS".
			KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + (signed_eta_ap() - 150)).
		}
	}
}

UNTIL signed_eta_ap() < 90 {
	IF (signed_eta_ap() < 120) AND (KUNIVERSE:TIMEWARP:WARP > 0) { KUNIVERSE:TIMEWARP:CANCELWARP. PRINT "Canceling Warp". }
	WAIT 0.01.
}

//circularization of orbit
PRINT "Beginning Circularization".
LOCAL pitchTo IS 0.
LOCK STEERING TO HEADING(heading_of_vector(SHIP:VELOCITY:ORBIT),pitchTo).
LOCAL apDiff IS 0.
LOCAL etaTar IS etaSet.
SET circulisePID:SETPOINT TO targetAP.
LOCAL beforeAp IS TRUE.
UNTIL SHIP:ORBIT:PERIAPSIS > (targetAP * 0.99) {
	IF SHIP:VERTICALSPEED > 0 {
		SET etaTar TO etaSet.
		SET pitchTo TO circulisePID:UPDATE(TIME:SECONDS, SHIP:ORBIT:APOAPSIS).
		IF beforeAp {
		//	LOCK THROTTLE TO PID_config(throttlePID,etaTar,0.001).
			PID_config(throttlePID,etaTar,0.001).
			LOCK THROTTLE TO throttlePID:UPDATE(TIME:SECONDS,signed_eta_ap()).
			SET beforeAp TO FALSE.
		}
	} ELSE {
		SET etaTar TO MAX(MIN((SHIP:ALTITUDE - SHIP:ORBIT:PERIAPSIS) / 5000,60),30).
		SET pitchTo TO 0 - circulisePID:UPDATE(TIME:SECONDS, SHIP:ORBIT:APOAPSIS).
		IF NOT beforeAp {
			LOCK THROTTLE TO (SHIP:ORBIT:PERIOD - signed_eta_ap())/etaTar/2.5 .
			SET beforeAp TO TRUE.
		}
	}
	stage_check().
	WAIT 0.01.
}
PRINT "Done With Engines".
}

SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
UNLOCK THROTTLE.
UNLOCK STEERING.

//end of core logic start of functions
FUNCTION count_down {	//pre launch count down
	PARAMETER count.
	FROM {LOCAL i IS count.} UNTIL i <= 0 STEP {SET i TO i - 1.} DO {
		HUDTEXT( "T- " + i + "s" , 1, 1, 25, white, true).
		WAIT 1.
	}
	HUDTEXT( "Launch" , 1, 1, 25, white, true).
}

FUNCTION PID_config {	//throttle PID for assent and circularization
	PARAMETER PID,setTarget,minSet,maxSet IS 1.
	SET PID:MAXOUTPUT TO maxSet.
	SET PID:MINOUTPUT TO minSet.
	SET PID:SETPOINT TO setTarget.
	//RETURN throttlePID:UPDATE(TIME:SECONDS,signed_eta_ap()).
}

//FUNCTION twr_limit {
//	PARAMETER twrTarget.
//	LOCAL twr IS (SHIP:AVAILABLETHRUST / SHIP:MASS) / SQRT(SHIP:BODY:MU / (SHIP:ALTITUDE + SHIP:BODY:RADIUS)).
//	RETURN MIN(twrTarget / twr, 1).
//}

FUNCTION pitch_target {	//decreases pitch if craft is close to etatarget
	PARAMETER gradeVec,etaTarget,deviationPos,deviationNeg,etaStart.	//the etaStart number of sec before AP the pitch down will start
	LOCAL gradent IS etaStart / deviationPos.
	LOCAL vecPitch IS pitch_of_vector(gradeVec).
	LOCAL downPitch IS MAX((signed_eta_ap() + (deviationPos * gradent)) - etaTarget, deviationNeg) / gradent.
	RETURN MIN(MAX(vecPitch - downPitch,0),80).
}