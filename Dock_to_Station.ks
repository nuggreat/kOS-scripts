PARAMETER doLiftOff IS TRUE,tar IS TARGET.
FOR lib IN LIST("lib_orbital_math","lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNPATH("1:/lib/" + lib + ".ks"). }}
IF tar:ISTYPE("STRING") {
	LOCAL vesselList IS LIST().
	LIST TARGETS IN vesselList.
	FOR ves IN vesselList {
		IF (ves:BODY = SHIP:BODY) AND ves:NAME:CONTAINS(tar) {
			SET tar TO ves.
			SET TARGET TO tar.
			BREAK.
		}
	}
}

LOCAL go IS TRUE.
IF NOT tar:ISTYPE("VESSEL") { SET go TO FALSE. }

IF go {
	LOCAL targetHeight IS SHIP:BODY:ATM:HEIGHT / 1000 + 26.
	IF doLiftOff {
		IF EXISTS("1:/lift_off_vac.ks") OR EXISTS("1:/lift_off_vac.ksm") {
			RUN lift_off_vac(targetHeight,TRUE,TARGET,TRUE).
		} ELSE {
			RUN lift_off(targetHeight,90,TRUE).
		}
	}
	RUN randevu(TRUE,TRUE,TRUE,FALSE,TRUE).
	warp_to_closest(300).//warps to 5min before closest approach
	warp_to_closest(60).//warps to 60 seconds before closest approach
	PRINT "done with warp".
	LOCK STEERING TO TARGET:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT.
	PANELS OFF.
	RUN dock_ship.
}

FUNCTION warp_to_closest {
	PARAMETER timeGap.
	LOCAL targetTime IS close_aproach_scan(SHIP,TARGET,TIME:SECONDS,SHIP:ORBIT:PERIOD)["uts"] - timeGap.
	LOCAL warpState IS 0.
	LOCAL done IS FALSE.
	UNTIL done {
		IF warpState = 0 {//init of warp calculation
			LOCK STEERING TO TARGET:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT.
			steering_alinged_duration(TRUE,5,FALSE).
			SET warpState TO 1.//state warp state
		} ELSE IF warpState = 1 {//wait for alignment 
			IF (TIME:SECONDS >= (targetTime - 5)) {
				SET warpState TO 3.//done state
				KUNIVERSE:TIMEWARP:CANCELWARP().
			}
			IF (steering_alinged_duration() > 5) {
				KUNIVERSE:TIMEWARP:WARPTO(targetTime).
				//WAIT UNTIL NOT not_warping().
				SET warpState TO 2.//warping state
			}
		} ELSE IF warpState = 2 {//warp so long as craft is aligned 
			IF steering_alinged_duration() <= 5 {
				KUNIVERSE:TIMEWARP:CANCELWARP().
				WAIT UNTIL not_warping().
				SET warpState TO 1.//start warp state
			}
			IF not_warping() {
				IF TIME:SECONDS < (targetTime - 5) {
					SET warpState TO 1.//start warp state
				} ELSE {
					SET warpState TO 3.//done state
					KUNIVERSE:TIMEWARP:CANCELWARP().
				}
			}
		} ELSE {
			IF TIME:SECONDS >= (targetTime + 5) {
				UNLOCK STEERING.
				SET done TO TRUE.
			}
		}
		WAIT 0.
		CLEARSCREEN.
		PRINT "targetETA: " + ((targetTime + timeGap) - TIME:SECONDS).
		PRINT "State " + warpState.
	}
}