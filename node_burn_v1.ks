PARAMETER autoWarp IS FALSE, doStage IS FALSE.
IF NOT SHIP:UNPACKED { PRINT "waiting for unpack". WAIT UNTIL SHIP:UNPACKED. WAIT 1. PRINT "unpacked". }
FOR lib IN LIST("lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
control_point().
SAS OFF.
ABORT OFF.
SET TERMINAL:WIDTH TO 55.
SET TERMINAL:HEIGHT TO 15.
WAIT UNTIL active_engine().
LOCAL shipISP IS isp_calc().
LOCAL nodeLock IS 120.	//the number of sec before the node is locked in

//start of core logic
LOCAL done IS FALSE.
LOCAL warping IS autoWarp.
IF autoWarp { SAS ON. }
LOCAL aborting IS FALSE.
UNTIL done {	//waiting for a node to exist or be locked in
	CLEARSCREEN.
	IF HASNODE {
		LOCAL burnDuration IS burn_duration(shipISP,NEXTNODE:DELTAV:MAG).
		LOCAL burnStart IS NEXTNODE:ETA - burn_duration(shipISP,NEXTNODE:DELTAV:MAG / 2).
		PRINT "waiting for node lock in".
		PRINT " ".
		IF warping {
			PRINT "warping to " + nodeLock + "s before the burn".
		} ELSE {
			PRINT "actvate the SAS to to warp to " + nodeLock + "s before the burn".
		}
		PRINT " ".
		PRINT "or wait untill " + ROUND(nodeLock / 60,1) + "min before the node burn begins".
		PRINT " ".
		IF burnStart <= (nodeLock * 60){
			PRINT "( burn in " + ROUND(burnStart / 60,1) + "m )".
		} ELSE {
			IF burnStart <= (nodeLock * 60 * 24) {
				PRINT "( burn in " + ROUND(burnStart / 60 / 60,1) + "h )".
			} ELSE {
				PRINT "( burn in " + ROUND(burnStart / 60 / 60 / 24,1) + "d )".
			}
		}
		PRINT "( burn length: " + ROUND(burnDuration) + "s)".
		PRINT " ".
		PRINT "or actvate ABORT to end script".
		SET aborting TO ABORT.
		IF SAS {
			SAS OFF.
			SET warping TO TRUE.
			KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + (burnStart - (nodeLock + 1))).
		}
		SET done TO ((burnStart - nodeLock) < 1).
		IF burnStart < (nodeLock / 12) {
			SET aborting TO TRUE.
			PRINT "node burn aborted because the craft is to close to the node".
		}
	} ELSE {
		PRINT "waiting for node to exist".
		PRINT "or actvate ABORT to end script".
		SET aborting TO ABORT.
	}
	SET done TO done OR aborting.
	WAIT 0.1.
}
SAS OFF.
KUNIVERSE:TIMEWARP:CANCELWARP.

IF NOT aborting {
	LOCAL burnVec IS NEXTNODE:BURNVECTOR:NORMALIZED.
	LOCK STEERING TO burnVec.
	LOCAL burnDV IS NEXTNODE:DELTAV:MAG - 0.01.
	LOCAL burnDuration IS burn_duration(shipISP,burnDV).
	LOCAL burnETA IS NEXTNODE:ETA + TIME:SECONDS.
	LOCAL done IS FALSE.
	SET STEERINGMANAGER:MAXSTOPPINGTIME TO MIN(MAX(((SHIP:MASS - 100) / 10),2),5).
	UNTIL done {	//the node is locked waiting for the start of the burn
		CLEARSCREEN.
		SET burnDuration TO burn_duration(shipISP,burnDV).
		LOCAL burnStart IS burnETA - (burn_duration(shipISP,burnDV / 2) + TIME:SECONDS).
		PRINT "node locked in waiting for burn start".
		PRINT " ".
		PRINT " ".
		PRINT " ".
		PRINT " ".
		PRINT " ".
		PRINT "( burn in " + ROUND(burnStart) + "s )".
		PRINT "( burn length: " + ROUND(burnDuration) + "s )".
		PRINT " ".
		PRINT "the node burn can still be aborted with ABORT".
		SET aborting TO ABORT.
		SET done TO (burnStart < 0.1) OR aborting.
		WAIT 0.01.
	}
	IF NOT aborting {
		LOCAL timePre IS TIME:SECONDS.
		LOCAL count IS 2.
		WAIT 0.01.
		LOCAL done IS FALSE.
		UNTIL done {	//exicuting the burn
			LOCAL timeNow IS TIME:SECONDS.
			LOCAL deltaTime IS timeNow - timePre.
			SET timePre TO timeNow.
			stage_check(doStage).
			LOCAL shipMass IS SHIP:MASS.
			LOCAL shipMaxAcceleration IS SHIP:AVAILABLETHRUST / shipMass.
			LOCK THROTTLE TO MAX(MIN(burnDV / (shipMaxAcceleration * 1.5),1),0.01).
			LOCAL shipAcceleration IS (shipMaxAcceleration * MAX(THROTTLE,0.01)) * deltaTime.
			SET burnDV TO burnDV - shipAcceleration.
			IF count >= 5 {
				SET shipISP TO isp_calc().
				CLEARSCREEN.
				PRINT "DeltaV left on burn: " + ROUND(burnDV,1) + "m/s".
				PRINT "  Time left on burn: " + ROUND(burn_duration(shipISP,burnDV)) + "s".
				SET count TO 1.
			} ELSE {
				SET count TO count + 1.
			}
			WAIT 0.01.
			SET done TO burnDV < 0.01 OR ABORT.
		}
	}
} ELSE { KUNIVERSE:TIMEWARP:CANCELWARP(). }
ABORT OFF.
UNLOCK THROTTLE.
UNLOCK STEERING.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
SET STEERINGMANAGER:MAXSTOPPINGTIME TO 2.

//end of core logic start of functions