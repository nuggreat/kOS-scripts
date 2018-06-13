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
LOCAL pData IS LIST(" "," "," "," "," "," "," "," "," "," ").
LOCAL done IS FALSE.
LOCAL warping IS autoWarp.
LOCAL aborting IS FALSE.
LOCAL vecTar IS SHIP:FACING:FOREVECTOR.
LOCAL timePre IS TIME:SECONDS.
LOCAL lockedOn IS FALSE.
LOCK STEERING TO vecTar.
SET pData[0] TO "Waiting for Node Lock".
UNTIL done {	//waiting for a node to exist or be locked in
	IF HASNODE {
		LOCAL burnDuration IS burn_duration(shipISP,NEXTNODE:DELTAV:MAG).
		LOCAL burnStart IS NEXTNODE:ETA - burn_duration(shipISP,NEXTNODE:DELTAV:MAG / 2).
		SET vecTar TO NEXTNODE:BURNVECTOR:NORMALIZED.
		SET pData[2] TO "Node Lock In " + ROUND(nodeLock / 60,1) + "min before the node burn begins".
		IF warping {
			SET pData[9] TO "kill warp then actvate ABORT to stop warping".
			LOCAL angle IS ABS(STEERINGMANAGER:ANGLEERROR).
			IF angle < 1 {
				IF (TIME:SECONDS - timePre) >= 10 {
					SET lockedOn TO TRUE.
					SET pData[4] TO "Warping to " + nodeLock / 4 + "s Before the Burn".
				}
			} ELSE {
				SET lockedOn TO FALSE.
				SET timePre TO TIME:SECONDS.
			}
			IF lockedOn {
				IF (KUNIVERSE:TIMEWARP:WARP = 0) {
					IF ((TIME:SECONDS - timePre) >= 10) { KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + (burnStart - (nodeLock / 4 + 1))). }
				} ELSE {
					SET timePre TO TIME:SECONDS.
				}
			} ELSE {
				SET pData[4] TO "Alinging to Burn Vector, Off Vector by " + ROUND(angle,2) + " Degrees".
				IF KUNIVERSE:TIMEWARP:WARP > 0 AND KUNIVERSE:TIMEWARP:ISSETTLED AND (angle > 5) { KUNIVERSE:TIMEWARP:CANCELWARP. }
			}
			SET done TO ((burnStart - nodeLock / 4) < 1).
		} ELSE {
			SET pData[4] TO "Actvate the SAS to to Warp to " + nodeLock / 4 + "s Before the Burn".
			SET pData[9] TO "actvate ABORT to end script".
			SET timePre TO time:SECONDS.
			SET done TO ((burnStart - nodeLock) < 1).
		}
		IF burnStart <= (nodeLock * 60){
			SET pData[6] TO "( Burn In " + ROUND(burnStart / 60,1) + "m )".
		} ELSE {
			IF burnStart <= (nodeLock * 60 * 24) {
				SET pData[6] TO "( Burn In " + ROUND(burnStart / 60 / 60,1) + "h )".
			} ELSE {
				SET pData[6] TO "( Burn In " + ROUND(burnStart / 60 / 60 / 24,1) + "d )".
			}
		}
		SET pData[7] TO "( Burn Length: " + ROUND(burnDuration) + "s)".
		SET aborting TO ABORT AND (NOT warping).
		IF ABORT {
			IF warping {
				ABORT OFF.
				SET warping TO FALSE.
			} ELSE { SET aborting TO TRUE. }
		}
		IF SAS {
			SAS OFF.
			SET warping TO TRUE.
		}
		IF burnStart < (nodeLock / 12) {
			SET aborting TO TRUE.
			PRINT "node burn aborted because the craft is to close to the node".
		}
		screen_update(pData).
	} ELSE {
		CLEARSCREEN.
		PRINT "waiting for node to exist".
		PRINT "or actvate ABORT to end script".
		SET aborting TO ABORT.
	}
	SET done TO done OR aborting.
	WAIT 0.1.
}
SAS OFF.
SET pData[0] TO "node locked in waiting for burn start".
SET pData[2] TO " ".
SET pData[4] TO " ".
SET pData[9] TO "the node burn can still be aborted with ABORT".
IF NOT aborting {
	SET vecTar TO NEXTNODE:BURNVECTOR:NORMALIZED.
	LOCAL burnDV IS NEXTNODE:DELTAV:MAG.
	LOCAL DVvector IS vecTar * burnDV.
	LOCK STEERING TO DVvector.
	LOCAL burnDuration IS burn_duration(shipISP,burnDV).
	LOCAL burnETA IS NEXTNODE:ETA + TIME:SECONDS.
	LOCAL done IS FALSE.
	SET STEERINGMANAGER:MAXSTOPPINGTIME TO MIN(MAX(((SHIP:MASS - 100) / 10),2),5).
	UNTIL done {	//the node is locked waiting for the start of the burn
		SET burnDuration TO burn_duration(shipISP,burnDV).
		LOCAL burnStart IS burnETA - (burn_duration(shipISP,burnDV / 2) + TIME:SECONDS).
		SET pData[6] TO "( burn in " + ROUND(burnStart) + "s )".
		SET pData[7] TO "( burn length: " + ROUND(burnDuration) + "s )".
		SET aborting TO ABORT.
		SET done TO (burnStart < 0.1) OR aborting.
		WAIT 0.01.
		screen_update(pData).
	}

	IF NOT aborting {
		LOCAL timePre IS TIME:SECONDS.
		LOCAL count IS 5.
		WAIT 0.01.
		LOCAL done IS FALSE.
		UNTIL done {	//exicuting the burn
			LOCAL timeNow IS TIME:SECONDS.
			LOCAL curentMass IS SHIP:MASS.
			LOCAL deltaTime IS timeNow - timePre.
			SET timePre TO timeNow.
			LOCAL shipAccel IS SHIP:AVAILABLETHRUST / curentMass.
			LOCK THROTTLE TO MAX(MIN(DVvector:MAG / (shipAccel * 1.25),1),0.01).
			LOCAL shipAcceleration IS (shipAccel * MAX(THROTTLE,0.01)) * deltaTime.
			SET DVvector TO DVvector - (shipAcceleration * SHIP:FACING:FOREVECTOR).
			IF count >= 5 {
				CLEARSCREEN.
				PRINT "DeltaV left on burn: " + ROUND(DVvector:MAG,1) + "m/s".
				PRINT "  Time left on burn: " + ROUND(burn_duration(shipISP,DVvector:MAG)) + "s".
				SET count TO 1.
			} ELSE {
				SET count TO count + 1.
			}
			IF stage_check(doStage) { SET shipISP TO isp_calc(). }
			WAIT 0.01.
			SET done TO DVvector:MAG < 0.01 OR ABORT.
		}
	}
} ELSE { KUNIVERSE:TIMEWARP:CANCELWARP(). }
ABORT OFF.
UNLOCK THROTTLE.
UNLOCK STEERING.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
SET STEERINGMANAGER:MAXSTOPPINGTIME TO 2.


//end of core logic start of functions
FUNCTION screen_update {
	PARAMETER printList.
	CLEARSCREEN.
	FOR printLine IN printList { PRINT printLine. }
}