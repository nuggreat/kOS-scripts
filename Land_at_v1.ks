PARAMETER landingCoordinates,marginHeight.
CLEARSCREEN.
LOCAL nodeStartTime IS TIME:SECONDS+ETA:APOAPSIS.
LOCAL localBody IS SHIP:BODY.
LOCAL varConstants IS LEX("craft",SHIP,"landingCoordinates",landingCoordinates,"marginHeight",marginHeight,"localBody",localBody,"initalStep",10).
IF ETA:APOAPSIS < 600 {
	SET nodeStartTime TO nodeStartTime + (SHIP:ORBIT:PERIOD / 8).
}
LOCAL baseNode IS NODE(nodeStartTime,0,0,0).
IF HASNODE { UNTIL NOT HASNODE { REMOVE NEXTNODE. WAIT 0. }}
ADD baseNode.
LOCAL timePre IS TIME:SECONDS.
periapsis_manipulaiton(NEXTNODE,-10000).
LOCAL pos IS pos_at_height(NEXTNODE,NEXTNODE:ETA + TIME:SECONDS,(NEXTNODE:ORBIT:PERIOD / 60),varConstants).
LOCAL nodeBackup IS NEXTNODE.
SET hillValues TO LEX("nodeBackup",nodeBackup,"score",score(pos,NEXTNODE,varConstants),"posTime",pos["time"],"stepVal",varConstants["initalStep"]).
PRINT "timeDelta 1: " + ROUND(TIME:SECONDS - timePre,2).
LOCAL timePre IS TIME:SECONDS.
LOCAL done IS FALSE.
UNTIL done {
	SET hillValues TO node_manipulation("normal",NEXTNODE,varConstants,hillValues).
	IF (NOT hillValues["found"]) { SET hillValues TO node_manipulation("time",NEXTNODE,varConstants,hillValues). }
	IF (NOT hillValues["found"]) { SET hillValues TO node_manipulation("radial",NEXTNODE,varConstants,hillValues). }
	IF (NOT hillValues["found"]) { SET hillValues["stepVal"] TO hillValues["stepVal"] / 2. }
	CLEARSCREEN.
	PRINT "score: " + hillValues["score"].
	SET done TO (NOT hillValues["found"]) AND (hillValues["stepVal"] < 0.01).
	WAIT 0.1.
}
LOCAL nodeGood IS FALSE.
IF hillValues["score"] > 1000 { UNTIL nodeGood {
	SET nodeStartTime TO nodeStartTime + (SHIP:ORBIT:PERIOD / 8).
	SET baseNode TO NODE(nodeStartTime,0,0,0).
	IF HASNODE { UNTIL NOT HASNODE { REMOVE NEXTNODE. WAIT 0. }}
	ADD baseNode.
	LOCAL timePre IS TIME:SECONDS.
	periapsis_manipulaiton(NEXTNODE,-10000).
	LOCAL timePre IS TIME:SECONDS.
	LOCAL pos IS pos_at_height(NEXTNODE,NEXTNODE:ETA + TIME:SECONDS,(NEXTNODE:ORBIT:PERIOD / 60),varConstants).
	LOCAL nodeBackup IS NEXTNODE.
	SET hillValues TO LEX("nodeBackup",nodeBackup,"score",score(pos,NEXTNODE,varConstants),"posTime",pos["time"],"stepVal",varConstants["initalStep"]).
	LOCAL done IS FALSE.
	UNTIL done {
		SET hillValues TO node_manipulation("normal",NEXTNODE,varConstants,hillValues).
		IF (NOT hillValues["found"]) { SET hillValues TO node_manipulation("time",NEXTNODE,varConstants,hillValues). }
		IF (NOT hillValues["found"]) { SET hillValues TO node_manipulation("radial",NEXTNODE,varConstants,hillValues). }
		IF (NOT hillValues["found"]) { SET hillValues["stepVal"] TO hillValues["stepVal"] / 2. }
		CLEARSCREEN.
		PRINT "score: " + hillValues["score"].
		SET done TO (NOT hillValues["found"]) AND (hillValues["stepVal"] < 0.01).
		WAIT 0.1.
	}
	SET nodeGood TO hillValues["score"] < 1000.
}}
PRINT "timeDelta 2: " + ROUND(TIME:SECONDS - timePre,2).
//RUN node_burn.ks.
//RUN landing.ks.
//PRINT "time: " + pos["time"].
//PRINT "dist: " + dist_betwene_coordinates(pos_to_choordinates(pos,varConstants),varConstants).

FUNCTION periapsis_manipulaiton {
	PARAMETER targetNode,peTarget.
	LOCAL stepVal IS 100.
	LOCAL stepMod IS 10.
	LOCAL lowerLimit IS peTarget - 1.
	LOCAL upperLimit IS peTarget + 1.
	LOCAL done IS FALSE.
	UNTIL done{
		IF targetNode:ORBIT:PERIAPSIS > upperLimit {
			SET targetNode:PROGRADE TO targetNode:PROGRADE - stepVal.
			IF targetNode:ORBIT:PERIAPSIS < lowerLimit {
				SET targetNode:PROGRADE TO targetNode:PROGRADE + stepVal.
				SET stepVal TO stepVal / stepMod.
			}
		} ELSE IF targetNode:ORBIT:PERIAPSIS < lowerLimit {
			SET targetNode:PROGRADE TO targetNode:PROGRADE + stepVal.
			IF targetNode:ORBIT:PERIAPSIS > upperLimit {
				SET targetNode:PROGRADE TO targetNode:PROGRADE - stepVal.
				SET stepVal TO stepVal / stepMod.
			}
		}
		SET done TO (targetNode:ORBIT:PERIAPSIS > lowerLimit) AND (targetNode:ORBIT:PERIAPSIS < upperLimit).
	}
}

FUNCTION node_manipulation {//adjustst burn start time so trajectory is closer to target choordnates
	PARAMETER manipMode,targetNode,varConstants,hillValues.
	LOCAL stepVal IS hillValues["stepVal"].
	LOCAL posTime IS hillValues["posTime"] - 100.
	LOCAL scoreInital IS hillValues["score"].
	LOCAL nodeBackup IS hillValues["nodeBackup"].
	LOCAL found IS FALSE.

	IF manipMode = "time" {
		IF targetNode:ETA < 120 {
			SET hillValues["stepVal"] TO varConstants["initalStep"].
			SET targetNode:ETA TO targetNode:ETA + varConstants["craft"]:ORBIT:PERIOD.
			periapsis_manipulaiton(targetNode,-10000).
			LOCAL pos IS pos_at_height(targetNode,posTime + (varConstants["craft"]:ORBIT:PERIOD / 2),(varConstants["craft"]:ORBIT:PERIOD / 60),varConstants).
			SET posTime TO pos["time"].
			SET scoreInital TO score(pos,targetNode,varConstants).
		}
//		SET stepVal TO hillValues["stepVal"] * 10.
	}
	IF manipMode = "time" {
		SET targetNode:ETA TO targetNode:ETA + stepVal.
	//	PRINT "add eta".
	} ELSE IF manipMode = "normal" {
		SET targetNode:NORMAL TO targetNode:NORMAL + stepVal.
	//	PRINT "add nor".
	} ELSE IF manipMode = "radial" {
		SET targetNode:RADIALOUT TO targetNode:RADIALOUT + stepVal.
	//	PRINT "add rad".
	}
	periapsis_manipulaiton(targetNode,-10000).
	LOCAL pos IS pos_at_height(targetNode,posTime,10,varConstants).
	LOCAL scoreNew IS score(pos,targetNode,varConstants).

	IF scoreNew < scoreInital {
		SET found TO TRUE.
	} ELSE {
		SET targetNode TO nodeBackup.
		IF manipMode = "time" {
			SET targetNode:ETA TO targetNode:ETA - stepVal.
	//		PRINT "sub eta".
		} ELSE IF manipMode = "normal" {
			SET targetNode:NORMAL TO targetNode:NORMAL - (stepVal * 10).
	//		PRINT "sub nor".
		} ELSE IF manipMode = "radial" {
			SET targetNode:RADIALOUT TO targetNode:RADIALOUT - (stepVal * 1).
	//		PRINT "sub rad".
		}
		periapsis_manipulaiton(targetNode,-10000).
		SET pos TO pos_at_height(targetNode,posTime,10,varConstants).
		SET scoreNew TO score(pos,targetNode,varConstants).
		IF scoreNew < scoreInital {
			SET found TO TRUE.
		} ELSE {
			SET targetNode TO nodeBackup.
		}
	}

	IF found {
		SET posTime TO pos["time"].
		SET nodeBackup TO targetNode.
		SET scoreInital TO scoreNew.
	}
	RETURN LEX("found",found,"nodeBackup",nodeBackup,"score",scoreInital,"posTime",posTime,"stepVal",hillValues["stepVal"]).
}

FUNCTION pos_at_height {
	PARAMETER targetNode,startTime,stepVal,varConstants.
	LOCAL localBody IS varConstants["localBody"].
	LOCAL craft IS varConstants["craft"].
	LOCAL localStartTime IS startTime.
	LOCAL localStepVal IS stepVal.
	LOCAL stepMod IS 10.
	LOCAL targetAltitude IS varConstants["marginHeight"] + varConstants["landingCoordinates"]:TERRAINHEIGHT.
	LOCAL altitudeAt IS localBody:ALTITUDEOF(POSITIONAT(craft,localStartTime)).
	IF NOT ((altitudeAt < targetAltitude + 1) AND (altitudeAt > targetAltitude - 1) ) {
	LOCAL done IS FALSE.
	UNTIL done {
		IF altitudeAt > targetAltitude + 1 {
			SET localStartTime TO localStartTime + localStepVal.
			SET altitudeAt TO localBody:ALTITUDEOF(POSITIONAT(craft,localStartTime)).
			IF altitudeAt < targetAltitude - 1 {
				SET localStartTime TO localStartTime - localStepVal.
				SET altitudeAt TO localBody:ALTITUDEOF(POSITIONAT(craft,localStartTime)).
				SET localStepVal TO localStepVal / stepMod.
			}
		} ELSE IF altitudeAt < targetAltitude - 1 {
			SET localStartTime TO localStartTime - localStepVal.
			SET altitudeAt TO localBody:ALTITUDEOF(POSITIONAT(craft,localStartTime)).
			IF altitudeAt > targetAltitude + 1 {
				SET localStartTime TO localStartTime + localStepVal.
				SET altitudeAt TO localBody:ALTITUDEOF(POSITIONAT(craft,localStartTime)).
				SET localStepVal TO localStepVal / stepMod.
			}
		}
		SET done TO (altitudeAt < targetAltitude + 1) AND (altitudeAt > targetAltitude - 1).
	}}
	RETURN LEX("time",localStartTime,"pos",POSITIONAT(craft,localStartTime)).
}

FUNCTION score {
	PARAMETER pos,targetNode,varConstants.
	RETURN dist_betwene_coordinates(pos_to_choordinates(pos,varConstants),varConstants) + targetNode:DELTAV:MAG.
}

FUNCTION pos_to_choordinates {	//converts return of pos_at_height to a latlng choordnate acounting for body rotation
	PARAMETER pos,varConstants.
	LOCAL localBody IS varConstants["localBody"].
	LOCAL rotationalDir IS VDOT(localBody:NORTH:FOREVECTOR,localBody:ANGULARVEL).
	LOCAL timeDif IS pos["time"] - TIME:SECONDS.
	LOCAL posLATLNG IS localBody:GEOPOSITIONOF(pos["pos"]).
	LOCAL logintudeShift IS (rotationalDir * timeDif * 180) / CONSTANT():PI.
	LOCAL newLNG IS posLATLNG:LNG + logintudeShift.
	IF newLNG < - 180 {
		SET newLNG TO newLNG + 360.
	} ELSE IF newLNG > 180 {
		SET newLNG TO newLNG - 360.
	}
	RETURN LATLNG(posLATLNG:LAT,newLNG).
}

FUNCTION dist_betwene_coordinates {
	PARAMETER p2,varConstants.
	LOCAL p1 IS varConstants["landingCoordinates"].
	LOCAL bodyRadius IS varConstants["localBody"]:RADIUS.
	LOCAL localA is SIN((p1:LAT-p2:LAT)/2)^2 + COS(p1:LAT)*COS(p2:LAT)*SIN((p1:LNG-p2:LNG)/2)^2.
	RETURN bodyRadius*CONSTANT():PI*ARCTAN2(SQRT(localA),SQRT(1-localA))/90.
}