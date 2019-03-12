PARAMETER autoWarp IS FALSE, degreesOfRotation IS 0, doStage IS FALSE.
IF NOT SHIP:UNPACKED { PRINT "waiting for unpack". WAIT UNTIL SHIP:UNPACKED. WAIT 1. PRINT "unpacked". }
FOR lib IN LIST("lib_rocket_utilities","lib_formating") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
control_point().
SAS OFF.
ABORT OFF.
SET TERMINAL:WIDTH TO 60.
SET TERMINAL:HEIGHT TO 20.
WAIT UNTIL active_engine().
LOCAL shipISP IS isp_calc().
LOCAL nodeLock IS 30.	//the number of sec before the node is locked in

//start of core logic
LOCAL pData IS LIST(" "," "," "," "," "," "," "," "," "," "," ",autoWarp).
LOCAL done IS FALSE.
//LOCAL warping IS autoWarp.
LOCAL aborting IS FALSE.
LOCAL vecTar IS SHIP:FACING:FOREVECTOR.
LOCAL timeCheck IS TIME:SECONDS + 10.
LOCAL resumeWarp IS TRUE.
LOCAL warpState IS -1.
IF autoWarp { SET warpState TO 1. }
LOCK STEERING TO vecTar.
SET pData[0] TO "Waiting for Node Lock".

LOCAL oldSteeringSettings IS LEX(
	"maxStoppingTime",STEERINGMANAGER:MAXSTOPPINGTIME,
	"pitchTS",STEERINGMANAGER:PITCHTS,
	"yawTS",STEERINGMANAGER:YAWTS,
	"rollTS",STEERINGMANAGER:ROLLTS).

IF SHIP:MASS > 200 {
	LOCAL steerCoeficent IS 5.
	SET nodeLock TO 60.
	IF SHIP:MASS > 1000 {
		SET steerCoeficent TO 10.
	}
	SET STEERINGMANAGER:MAXSTOPPINGTIME TO oldSteeringSettings["maxStoppingTime"] * steerCoeficent.
	//SET STEERINGMANAGER:PITCHTS TO oldSteeringSettings["pitchTS"] / steerCoeficent.
	//SET STEERINGMANAGER:YAWTS TO oldSteeringSettings["yawTS"] / steerCoeficent.
	//SET STEERINGMANAGER:ROLLTS TO oldSteeringSettings["rollTS"] / steerCoeficent.
}

UNTIL done {	//waiting for a node to exist or be locked in
	IF HASNODE {
		screen_update(pData).
		SET pData[10] TO warpState.
		SET shipISP TO isp_calc().
		LOCAL burnDuration IS burn_duration(shipISP,NEXTNODE:DELTAV:MAG).
		LOCAL burnStart IS NEXTNODE:ETA - burn_duration(shipISP,NEXTNODE:DELTAV:MAG / 2).
		SET vecTar TO ANGLEAXIS(degreesOfRotation,NEXTNODE:BURNVECTOR:NORMALIZED) * LOOKDIRUP(NEXTNODE:BURNVECTOR:NORMALIZED,SHIP:UP:FOREVECTOR).
//		SET vecTar TO NEXTNODE:BURNVECTOR:NORMALIZED.
		SET pData[6] TO "( Burn Start In:" + time_formating(burnStart) + ")".
		SET pData[7] TO "(   Burn Length:" + time_formating(burnDuration) + ")".

		IF warpState = 0 {
			SET timeCheck TO time:SECONDS + 10.
			IF (burnStart - nodeLock * 5) < 1 { SET warpState TO 1. }
			IF SAS {
				SAS OFF.
				SET warpState TO 1.
			}
		} ELSE IF warpState = 1 { //warp close to node
			IF burnStart > nodeLock * 10 + 1 {
				KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + (burnStart - (nodeLock * 10))).
			}
			SET pData[2] TO "Node Lock" + time_formating(nodeLock) + " Before The Node Burn Begins".
			SET pData[4] TO "Warping To" + time_formating(nodeLock * 10) + " Before The Burn".
			SET pData[9] TO "Kill Warp Then Activate ABORT To Stop Auto Warping".
			SET warpState TO 2.
		} ELSE IF warpState = 2 {//aligning to node prior to getting to node
			IF not_warping() AND (burnStart < (nodeLock * 10)) {
				LOCAL angle IS ABS(STEERINGMANAGER:ANGLEERROR).
				IF angle < 1 {
					LOCAL timeDiff IS timeCheck - TIME:SECONDS.
					IF timeDiff < 0 {
						SET warpState TO 3.
						SET pData[4] TO "Warping To" + time_formating(nodeLock) + " Before The Burn".
						KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + (burnStart - (nodeLock + 0.1))).
					} ELSE {
						SET pData[4] TO "Aligned To Burn Vector, resuming warp in" + time_formating(timeDiff,1).
					}
				} ELSE {
					SET pData[4] TO "Aligning To Burn Vector, Off Vector by" + padding(angle,2,2) + " Degrees".
					SET timeCheck TO TIME:SECONDS + 10.
				}
			} ELSE {//logic to resume warping
				IF resumeWarp {
					SET timeCheck TO TIME:SECONDS + 10.
				}
				IF not_warping() {
					LOCAL timeDiff IS timeCheck - TIME:SECONDS.
					IF resumeWarp AND burnStart > (nodeLock * 10.5) {
						SET resumeWarp TO FALSE.
					}
					IF NOT resumeWarp {
						IF timeDiff < 0 {
							SET resumeWarp TO TRUE.
							SET pData[4] TO "Warping To" + time_formating(nodeLock * 10) + " Before The Burn".
							KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + (burnStart - (nodeLock * 10))).
						} ELSE {
							SET pData[4] TO "Resuming Warp In" + time_formating(timeDiff,1).
						}
					}
				}
			}
		} ELSE IF warpState = 3 {
			SET done TO ((burnStart - nodeLock) < 1).
		} ELSE IF warpState = -1 {
			SET pData[2] TO "Node Lock At" + time_formating(nodeLock) + " Before The Node Burn Begins".
			SET pData[4] TO "Activate The SAS To Warp To" + time_formating(nodeLock) + " Before The Burn".
			SET pData[9] TO "Activate ABORT To End Script".
			SET warpState TO 0.
		}
		IF ABORT {
			ABORT OFF.
			IF warpState <> 0 AND not_warping() {
				SET warpState TO -1.
			} ELSE IF warpState = 0 {
				SET aborting TO TRUE.
			}
		}
		IF burnStart < (nodeLock / 12) {
			SET aborting TO TRUE.
			PRINT "node burn aborted because the craft is to close to the node".
		}
	} ELSE {
		CLEARSCREEN.
		PRINT "waiting for node to exist".
		PRINT "or actvate ABORT to end script".
		SET aborting TO ABORT.
	}
	SET done TO done OR aborting.
	WAIT 0.01.
}
SAS OFF.
CLEARSCREEN.
SET pData[0] TO "node locked in waiting for burn start".
SET pData[2] TO " ".
SET pData[4] TO " ".
SET pData[9] TO "the node burn can still be aborted with ABORT".
IF NOT aborting {
	SET vecTar TO NEXTNODE:BURNVECTOR:NORMALIZED.
	LOCAL burnDV IS NEXTNODE:DELTAV:MAG.
	LOCAL DVvector IS vecTar * burnDV.
	LOCK STEERING TO ANGLEAXIS(degreesOfRotation,DVvector) * LOOKDIRUP(DVvector,SHIP:UP:FOREVECTOR).
//	LOCK STEERING TO DVvector.
	LOCAL burnDuration IS burn_duration(shipISP,burnDV).
	LOCAL burnETA IS NEXTNODE:ETA + TIME:SECONDS.
	SET pData[7] TO "(   Burn Length:" + time_formating(burnDuration) + ")            ".
	LOCAL done IS FALSE.
	UNTIL done {	//the node is locked waiting for the start of the burn
		LOCAL burnStart IS burnETA - (burn_duration(shipISP,burnDV / 2) + TIME:SECONDS).
		SET pData[6] TO "( Burn Start In:" + time_formating(burnStart,0,1) + ")            ".
		SET aborting TO ABORT.
		SET done TO (burnStart < 0.1) OR aborting.
		WAIT 0.01.
		screen_update(pData).
	}

	IF NOT aborting {
		LOCAL timePast IS TIME:SECONDS.
		LOCAL shipAccel IS SHIP:AVAILABLETHRUST / SHIP:MASS.
		LOCAL count IS 5.
		WAIT 0.01.
		LOCAL throt IS MAX(MIN(DVvector:MAG / shipAccel,1),0.01).
		LOCK THROTTLE TO throt.
		LOCAL done IS FALSE.
		CLEARSCREEN.
		UNTIL done {	//executing the burn
			WAIT 0.
			SET shipAccel TO SHIP:AVAILABLETHRUST / SHIP:MASS.
			LOCAL timeNow IS TIME:SECONDS.
			LOCAL shipFacingFore IS SHIP:FACING:FOREVECTOR.
			IF shipAccel > 0 {
				SET throt TO MAX(MIN(DVvector:MAG / shipAccel,1),0.01)..
			} ELSE {
				SET throt TO 0.
			}
			LOCAL deltaTime IS timeNow - timePast.
			SET timePast TO timeNow.
			LOCAL shipAcceleration IS (shipAccel * MAX(throt,0.01)) * deltaTime.
			SET DVvector TO DVvector - (shipAcceleration * shipFacingFore).
			IF count >= 5 {
				PRINT " DeltaV left on burn:" + si_formating(DVvector:MAG,"m/s") + "      " AT(0,0).
				PRINT "   Time left on burn:" + time_formating(burn_duration(shipISP,DVvector:MAG),0,1) + "      " AT(0,1).
				SET count TO 0.
			} ELSE {
				SET count TO count + 1.
			}
			IF stage_check(doStage) { SET shipISP TO isp_calc(). }//if i stage recalculate the ISP
			SET done TO DVvector:MAG < 0.01 OR ABORT.
		}
	}
} ELSE { KUNIVERSE:TIMEWARP:CANCELWARP(). }
PRINT " ".
PRINT " ".
ABORT OFF.
UNLOCK THROTTLE.
UNLOCK STEERING.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
SET STEERINGMANAGER:MAXSTOPPINGTIME TO oldSteeringSettings["maxStoppingTime"].
SET STEERINGMANAGER:PITCHTS TO oldSteeringSettings["pitchTS"].
SET STEERINGMANAGER:YAWTS TO oldSteeringSettings["yawTS"].
SET STEERINGMANAGER:ROLLTS TO oldSteeringSettings["rollTS"].


//end of core logic start of functions
FUNCTION screen_update {
	PARAMETER printList.
	CLEARSCREEN.
	FOR printLine IN printList {
		PRINT printLine.
	}
}