@LAZYGLOBAL OFF.
LOCAL lib_rocket_utilities_lex IS LEX().
LOCAL gg0 IS CONSTANT:g0.//defining local copies of constants so they don't need to be looked up at run time
LOCAL ee IS CONSTANT:E.

FUNCTION isp_calc {	//returns the average isp of all of the active engines on the ship
	LOCAL engineList IS LIST().
	LOCAL totalFlow IS 0.
	LOCAL totalThrust IS 0.
	LIST ENGINES IN engineList.
	FOR engine IN engineList {
		IF engine:IGNITION AND NOT engine:FLAMEOUT {
			SET totalFlow TO totalFlow + (engine:AVAILABLETHRUST / (engine:ISP * gg0)).
			SET totalThrust TO totalThrust + engine:AVAILABLETHRUST.
		}
	}
	IF totalThrust = 0 {//avoid div0 errors later
		RETURN 1.
	}
	RETURN (totalThrust / (totalFlow * gg0)).
}

lib_rocket_utilities_lex:ADD("nextStageTime",TIME:SECONDS).
FUNCTION stage_check {	//a check for if the rocket needs to stage
	PARAMETER enableStage IS TRUE, stageDelay IS 3.
	LOCAL needStage IS FALSE.
	IF enableStage AND STAGE:READY AND (lib_rocket_utilities_lex["nextStageTime"] < TIME:SECONDS) {
		IF MAXTHRUST = 0 {
			SET needStage TO TRUE.
		} ELSE {
			LOCAL engineList IS LIST().
			LIST ENGINES IN engineList.
			FOR engine IN engineList {
				IF engine:IGNITION AND engine:FLAMEOUT {
					SET needStage TO TRUE.
					BREAK.
				}
			}
		}
		IF needStage	{
			STAGE.
			STEERINGMANAGER:RESETPIDS().
			SET lib_rocket_utilities_lex["nextStageTime"] TO TIME:SECONDS + stageDelay.
			PRINT "Staged".
		}
	} ELSE {
		SET needStage TO TRUE.
	}
	RETURN needStage.
}

lib_rocket_utilities_lex:ADD("nextDropTime",TIME:SECONDS).
FUNCTION drop_tanks {
	PARAMETER tankTag IS "dropTank".
	LOCAL tankList IS SHIP:PARTSTAGGED(tankTag).
	IF (tankList:LENGTH > 0) AND STAGE:READY AND lib_rocket_utilities_lex["nextDropTime"] < TIME:SECONDS {
		LOCAL drop IS FALSE.
		FOR tank IN tankList {
			FOR res IN tank:RESOURCES {
				IF res:AMOUNT < 0.01 {
					SET drop TO TRUE.
					BREAK. BREAK.
				}
			}
		}
		IF drop {
			STAGE.
			SET lib_rocket_utilities_lex["nextDropTime"] TO TIME:SECONDS + 10.
			PRINT "Tank Dropped".
		}
	}
	RETURN tankList:LENGTH > 0.
}

FUNCTION active_engine { // check for a active engine on ship
	PARAMETER doPrint IS TRUE.
	LOCAL engineList IS LIST().
	LIST ENGINES IN engineList.
	LOCAL haveEngine IS FALSE.
	FOR engine IN engineList {
		IF engine:IGNITION AND NOT engine:FLAMEOUT {
			SET haveEngine TO TRUE.
			BREAK.
		}
	}
	IF haveEngine AND doPrint {
		CLEARSCREEN.
		PRINT "Active Engine Found.".
	} ELSE IF NOT haveEngine {
		CLEARSCREEN.
		PRINT "No Active Engines Found.".
	}
	WAIT 0.1.
	RETURN haveEngine.
}

FUNCTION burn_duration {	//from isp and dv using current mass of the ship returns the amount of time needed for the provided DV
	PARAMETER ISPs, DV, wMass IS SHIP:MASS, sThrust IS SHIP:AVAILABLETHRUST.
	LOCAL dMass IS wMass / (ee^ (DV / (ISPs * gg0))).
	LOCAL flowRate IS sThrust / (ISPs * gg0).
	RETURN (wMass - dMass) / flowRate.
}

FUNCTION control_point {
	PARAMETER pTag IS "controlPoint".
	LOCAL controlList IS SHIP:PARTSTAGGED(pTag).
	IF controlList:LENGTH > 0 {
		controlList[0]:CONTROLFROM().
	} ELSE {
		IF SHIP:ROOTPART:HASSUFFIX("CONTROLFROM") {
			SHIP:ROOTPART:CONTROLFROM().
		}
	}
}

FUNCTION not_warping {
	RETURN (KUNIVERSE:TIMEWARP:RATE = 1) AND KUNIVERSE:TIMEWARP:ISSETTLED.
}

FUNCTION clear_all_nodes {
	IF HASNODE { PRINT "havenode". UNTIL NOT HASNODE { REMOVE NEXTNODE. PRINT "removed node". WAIT 0. }}
}

lib_rocket_utilities_lex:ADD("steering_alinged_duration",LEX("maxError",1,"careAboutRoll",FALSE,"alignedTime",TIME:SECONDS)).
FUNCTION steering_alinged_duration {//wait until steering is aligned with what it is locked to
	LOCAL dataLex IS lib_rocket_utilities_lex["steering_alinged_duration"].
	PARAMETER configure IS FALSE,
	maxError IS dataLex["maxError"],
	careAboutRoll IS dataLex["careAboutRoll"].

	IF configure {
		SET dataLex["maxError"] TO maxError.
		SET dataLex["careAboutRoll"] TO careAboutRoll.
		SET dataLex["alignedTime"] TO TIME:SECONDS.
		RETURN 0.
	} ELSE {
		LOCAL localTime IS TIME:SECONDS.

		LOCAL steerError IS ABS(STEERINGMANAGER:ANGLEERROR).
		IF careAboutRoll {
			SET steerError TO steerError + ABS(STEERINGMANAGER:ROLLERROR).
		}

		IF steerError > maxError {
			SET dataLex["alignedTime"] TO localTime.
		}
		RETURN localTime - dataLex["alignedTime"].
	}
}

FUNCTION signed_eta_ap {
	IF ETA:APOAPSIS <= ETA:PERIAPSIS {
		RETURN ETA:APOAPSIS.
	} ELSE {
		RETURN ETA:APOAPSIS - SHIP:ORBIT:PERIOD.
	}
}