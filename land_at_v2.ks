PARAMETER landingCoordinates.
LOCAL marginHeight IS 100.
LOCAL ipuBackup IS CONFIG:IPU.
SET CONFIG:IPU TO 2000.
CLEARSCREEN.
LOCAL nodeStartTime IS TIME:SECONDS+ETA:APOAPSIS.
LOCAL localBody IS SHIP:BODY.
GLOBAL varConstants IS LEX("craft",SHIP,"landingCoordinates",landingCoordinates,"marginHeight",(marginHeight),"localBody",localBody,"initalStep",10,"peTarget",(localBody:RADIUS / -2.5),"mode",0,"manipList",LIST("eta","pro","nor","rad")).

IF SHIP:ORBIT:PERIAPSIS < 0 {
	SET varConstants["mode"] TO 1.
	SET nodeStartTime TO (score(SHIP,TIME:SECONDS + (SHIP:ORBIT:PERIOD / 8))["posTime"] + TIME:SECONDS) / 2.
	varConstants["manipList"]:REMOVE(0).
	//varConstants["manipList"]:REMOVE(2).
} ELSE IF ETA:APOAPSIS < 600 {
	SET nodeStartTime TO nodeStartTime + (SHIP:ORBIT:PERIOD / 8).
}
IF HASNODE { UNTIL NOT HASNODE { REMOVE NEXTNODE. WAIT 0. }}
LOCAL baseNode IS NODE(nodeStartTime,0,0,0).
ADD baseNode.
//LOCAL timePre IS TIME:SECONDS.
//periapsis_manipulaiton(NEXTNODE,varConstants["peTarget"]).
LOCAL scored IS score(NEXTNODE,(NEXTNODE:ETA + TIME:SECONDS + (NEXTNODE:ORBIT:PERIOD / 4))).
LOCAL hillValues IS LEX("score",scored["score"],"posTime",scored["posTime"],"stepVal",varConstants["initalStep"],"dist",scored["dist"]).
LOCAL timePreFull IS TIME:SECONDS.
LOCAL close IS FALSE.
LOCAL done IS FALSE.
UNTIL close{
	IF done AND (varConstants["mode"] = 0) {
		SET done TO FALSE.
		SET nodeStartTime TO nodeStartTime + (SHIP:ORBIT:PERIOD / 8).
		SET baseNode TO NODE(nodeStartTime,0,0,0).
		IF HASNODE { UNTIL NOT HASNODE { REMOVE NEXTNODE. WAIT 0. }}
		ADD baseNode.
		SET hillValues["stepVal"] TO varConstants["initalStep"].
		SET hillValues["score"] TO score(NEXTNODE,(NEXTNODE:ETA + TIME:SECONDS + (NEXTNODE:ORBIT:PERIOD / 4)))["score"].
	}
	LOCAL stepMod IS 0.
	UNTIL done {
		LOCAL timePre IS TIME:SECONDS.
	//	LOCAL nodeList IS node_manipulation(NEXTNODE,hillValues).

		LOCAL stepVal IS hillValues["stepVal"].
		LOCAL posTime IS hillValues["posTime"].
		LOCAL nodeList IS LIST().
		LOCAL manipList IS varConstants["manipList"].
		//nodeList:ADD(LIST(hillValues["score"],posTime,"no",0,hillValues["dist"])).
		LOCAL bestNode IS LIST(hillValues["score"],posTime,"no",0,hillValues["dist"]).
		FOR manipType IN  manipList {
			nodeList:ADD(node_scoring(NEXTNODE,manipType,stepVal,posTime)).
			nodeList:ADD(node_scoring(NEXTNODE,"-"+manipType,-stepVal,posTime)).
		}

	//	LOCAL bestNode IS nodeList[0].
		LOCAL anyGood IS FALSE.
		FOR nodes IN nodeList {
		//	WAIT 1.
			IF bestNode[0] > nodes[0] {
				SET bestNode TO nodes.
	//			PRINT ROUND(bestNode[0]) + " " + ROUND(nodes[0]) + " t/f: " + (bestNode[0] > nodes[0]) + " type: " + nodes[2] + " step: " + nodes[3].
	//			WAIT 1.
				SET anyGood TO TRUE.
			}
		}
		IF anyGood {
	//		PRINT "node: " + NEXTNODE.
			node_set(NEXTNODE,bestNode[2],bestNode[3]).
			SET hillValues["score"] TO bestNode[0].
			SET hillValues["posTime"] TO bestNode[1].
			SET hillValues["dist"] TO bestNode[4].
			SET hillValues["stepVal"] TO (varConstants["initalStep"] / (10^FLOOR(stepMod))).
			SET stepMod TO MAX(stepMod - 0.025,0).
	//		PRINT "type: " + bestNode[2] + " step: " + bestNode[3].
	//		PRINT "altN: " + NEXTNODE.
	//		PRINT " ".
	//		WAIT 1.
			CLEARSCREEN.
			PRINT "score: " + ROUND(hillValues["score"]) + " dist: " + ROUND(hillValues["dist"]) + " pedif: " + ROUND(NEXTNODE:ORBIT:PERIAPSIS - varConstants["peTarget"]).
			PRINT "deltaTime: " + ROUND(delta_time(),2).
		} ELSE {
			SET hillValues["stepVal"] TO hillValues["stepVal"] / 10.
			SET stepMod TO stepMod + 0.5.
		}
		//PRINT "stepVal " + hillValues["stepVal"].
//		SET done TO ((hillValues["dist"] = 2000) AND (varConstants["mode"] = 0)) OR (hillValues["stepVal"] < 0.001) OR (NEXTNODE:ETA < 120).
		SET done TO (hillValues["stepVal"] < 0.001) OR (NEXTNODE:ETA < 120).
	}
	SET close TO (hillValues["dist"] < 2000) OR (varConstants["mode"] = 1).
}
PRINT "timeDelta 2: " + ROUND(TIME:SECONDS - timePreFull,2).
SET CONFIG:IPU TO ipuBackup.
IF varConstants ["mode"] = 0 {
	RUN node_burn.ks.
	RUN land_at.ks(landingCoordinates).
} ELSE {
	RUN node_burn.ks.
	REMOVE NEXTNODE.
	RUN landing.ks.
	PRINT "dist: " + ROUND(dist_betwene_coordinates(SHIP:GEOPOSITION),2).
}

FUNCTION node_manipulation {//adjustst burn start time so trajectory is closer to target choordnates
	PARAMETER targetNode,hillValues.
	LOCAL stepVal IS hillValues["stepVal"].
	LOCAL posTime IS hillValues["posTime"].
	LOCAL scoreInital IS hillValues["score"].
	LOCAL dist IS hillValues["dist"].
	LOCAL found IS FALSE.
	LOCAL nodeList IS LIST().

	LOCAL manipList IS varConstants["manipList"].
	nodeList:ADD(LIST(hillValues["score"],posTime,"no",0,dist)).
	FOR manipType IN  manipList {
		nodeList:ADD(node_scoring(targetNode,manipType,stepVal,posTime)).
		nodeList:ADD(node_scoring(targetNode,"-"+manipType,-stepVal,posTime)).
	}
	RETURN nodeList.
}

FUNCTION node_scoring {
	PARAMETER targetNode,manipType,stepVal,posTime.
	node_set(targetNode,manipType,stepVal).
	LOCAL scoreNew IS score(targetNode,posTime).
//	PRINT "type: " + manipType + " step: " + stepVal + " score: " + scoreNew["score"].
//	WAIT 1.
	node_set(targetNode,manipType,-stepVal).
	RETURN LIST(scoreNew["score"],scoreNew["posTime"],manipType,stepVal,scoreNew["dist"]).
}

FUNCTION node_set {
	PARAMETER targetNode,manipType,stepVal.
	IF manipType = "eta" { SET targetNode:ETA TO targetNode:ETA + (stepVal * 10). } ELSE {
	IF manipType = "pro" { SET targetNode:PROGRADE TO targetNode:PROGRADE + stepVal. } ELSE {
	IF manipType = "nor" { SET targetNode:NORMAL TO targetNode:NORMAL + stepVal. } ELSE {
	IF manipType = "rad" { SET targetNode:RADIALOUT TO targetNode:RADIALOUT + stepVal. }}}}
}

FUNCTION score {
	PARAMETER targetNode,posTime.
	LOCAL stepVal IS (targetNode:ORBIT:PERIOD / 72).
	LOCAL peDiff IS ABS(targetNode:ORBIT:PERIAPSIS - varConstants["peTarget"]) / 4.
	IF (targetNode:ORBIT:PERIAPSIS < 0) AND (targetNode:ORBIT:TRANSITION <> "escape") {
		LOCAL pos IS pos_at_height(targetNode,posTime,stepVal).
		LOCAL dist IS dist_betwene_coordinates(pos_to_choordinates(pos)).
		LOCAL scored IS dist + peDiff.
		IF targetNode:ISTYPE("node") { SET scored TO scored + (targetNode:DELTAV:MAG * 6). }
		RETURN LEX("score",scored,"posTime",pos["time"],"dist",dist).
	} ELSE {
		LOCAL dist IS varConstants["localBody"]:RADIUS * 2 * CONSTANT():PI.
		LOCAL peDiff IS targetNode:ORBIT:PERIAPSIS - varConstants["peTarget"].
		LOCAL scored IS dist + peDiff.
		RETURN LEX("score",scored,"posTime",(targetNode:ETA + TIME:SECONDS + (targetNode:ORBIT:PERIOD / 4)),"dist",dist).
	}
}

FUNCTION pos_at_height {
	PARAMETER targetNode,startTime,stepVal.
	LOCAL localBody IS varConstants["localBody"].
	LOCAL craft IS varConstants["craft"].
	LOCAL scanTime IS startTime.
	LOCAL scanTimeBackup IS startTime.
	LOCAL maxScanTime IS targetNode:ORBIT:PERIOD + startTime.
	LOCAL localStepVal IS stepVal.
	LOCAL stepMod IS 2.
	LOCAL targetAltitudeHi IS varConstants["marginHeight"] + varConstants["landingCoordinates"]:TERRAINHEIGHT + 1.
	LOCAL targetAltitudeLow IS varConstants["marginHeight"] + varConstants["landingCoordinates"]:TERRAINHEIGHT - 1.
	LOCAL altitudeAt IS localBody:ALTITUDEOF(POSITIONAT(craft,scanTime)).
	IF NOT ((altitudeAt < targetAltitudeHi) AND (altitudeAt > targetAltitudeLow)) {
//	LOCAL done IS FALSE.
	UNTIL (altitudeAt < targetAltitudeHi) AND (altitudeAt > targetAltitudeLow) {
		IF altitudeAt > targetAltitudeHi {
			SET scanTime TO scanTime + localStepVal.
			SET altitudeAt TO localBody:ALTITUDEOF(POSITIONAT(craft,scanTime)).
			IF altitudeAt < targetAltitudeLow {
				SET scanTime TO scanTime - localStepVal.
				SET altitudeAt TO localBody:ALTITUDEOF(POSITIONAT(craft,scanTime)).
				SET localStepVal TO localStepVal / stepMod.
			}
		} ELSE IF altitudeAt < targetAltitudeLow {
			SET scanTime TO scanTime - localStepVal.
			SET altitudeAt TO localBody:ALTITUDEOF(POSITIONAT(craft,scanTime)).
			IF altitudeAt > targetAltitudeHi {
				SET scanTime TO scanTime + localStepVal.
				SET altitudeAt TO localBody:ALTITUDEOF(POSITIONAT(craft,scanTime)).
				SET localStepVal TO localStepVal / stepMod.
			}
		}
		IF maxScanTime < scanTime {
			SET scanTime TO scanTimeBackup.
			SET localStepVal TO localStepVal / stepMod.
		}
		//SET done TO (altitudeAt < targetAltitudeHi) AND (altitudeAt > targetAltitudeLow).
	}}
	RETURN LEX("time",scanTime,"pos",POSITIONAT(craft,scanTime)).
}

FUNCTION pos_to_choordinates {	//converts return of pos_at_height to a latlng choordnate acounting for body rotation
	PARAMETER pos.
	LOCAL localBody IS varConstants["localBody"].
	LOCAL rotationalDir IS VDOT(localBody:NORTH:FOREVECTOR,localBody:ANGULARVEL).
	LOCAL timeDif IS pos["time"] - TIME:SECONDS.
	LOCAL posLATLNG IS localBody:GEOPOSITIONOF(pos["pos"]).
	LOCAL logintudeShift IS rotationalDir * timeDif * CONSTANT:RADTODEG.
	LOCAL newLNG IS posLATLNG:LNG + logintudeShift.
	IF newLNG < - 180 {
		SET newLNG TO newLNG + 360.
	} ELSE IF newLNG > 180 {
		SET newLNG TO newLNG - 360.
	}
	RETURN LATLNG(posLATLNG:LAT,newLNG).
}

FUNCTION dist_betwene_coordinates {	//returns the dist betwene p2 and the landingCoordinates on the localBody
	PARAMETER p2.
	LOCAL p1 IS varConstants["landingCoordinates"].
	LOCAL bodyRadius IS varConstants["localBody"]:RADIUS.
	LOCAL localA is SIN((p1:LAT-p2:LAT)/2)^2 + COS(p1:LAT)*COS(p2:LAT)*SIN((p1:LNG-p2:LNG)/2)^2.
	RETURN bodyRadius*CONSTANT():PI*ARCTAN2(SQRT(localA),SQRT(1-localA))/90.
}

FUNCTION delta_time {
	IF NOT (DEFINED prevousTime) { GLOBAL prevousTime IS TIME:SECONDS. }
	LOCAL deltaTime IS TIME:SECONDS - prevousTime.
	SET prevousTime TO TIME:SECONDS.
	RETURN deltaTime.
}

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