PARAMETER landingCoordinates.
LOCAL ipuBackup IS CONFIG:IPU.
SET CONFIG:IPU TO 2000.
CLEARSCREEN.
LOCAL nodeStartTime IS TIME:SECONDS+ETA:APOAPSIS.
LOCAL localBody IS SHIP:BODY.
LOCAL orbitalSpeed IS ROUND((localBody:MU / SHIP:ORBIT:SEMIMAJORAXIS)^0.5).
LOCAL marginHeight IS 100 + margen_error() * 5.
GLOBAL varConstants IS LEX("craft",SHIP,"landingCoordinates",landingCoordinates,"marginHeight",marginHeight,"localBody",localBody,"initalStep",orbitalSpeed/100,"peTarget",(localBody:RADIUS / -1.5),"mode",0,"manipList",LIST("eta","pro","nor","rad"),"orbitalSpeed",orbitalSpeed).

IF SHIP:ORBIT:PERIAPSIS < 0 {
	SET varConstants["mode"] TO 1.
	SET nodeStartTime TO (score(SHIP,TIME:SECONDS + (SHIP:ORBIT:PERIOD / 8))["posTime"] + TIME:SECONDS) / 2.
	varConstants["manipList"]:REMOVE(0).
} ELSE IF ETA:APOAPSIS < 600 {
	SET nodeStartTime TO nodeStartTime + (SHIP:ORBIT:PERIOD / 8).
}
IF HASNODE { UNTIL NOT HASNODE { REMOVE NEXTNODE. WAIT 0. }}
LOCAL baseNode IS NODE(nodeStartTime,0,0,0).
ADD baseNode.
IF varConstants["mode"] = 0 { periapsis_manipulaiton(NEXTNODE,varConstants["peTarget"]). }
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
		periapsis_manipulaiton(NEXTNODE,varConstants["peTarget"]).
		LOCAL scored IS score(NEXTNODE,(NEXTNODE:ETA + TIME:SECONDS + (NEXTNODE:ORBIT:PERIOD / 4))).
		SET hillValues["stepVal"] TO varConstants["initalStep"].
		SET hillValues["score"] TO scored["score"].
		SET hillValues["posTime"] TO scored["posTime"].
	}
	LOCAL stepMod IS 0.
	UNTIL done {
		LOCAL timePre IS TIME:SECONDS.
		LOCAL stepVal IS hillValues["stepVal"].
		LOCAL posTime IS hillValues["posTime"].
		LOCAL manipList IS varConstants["manipList"].
		LOCAL anyGood IS FALSE.
		LOCAL bestNode IS LIST(hillValues["score"],posTime,"no",0,hillValues["dist"]).
		FOR manipType IN  manipList {
			FOR stepTmp IN LIST(stepVal,-stepVal) {

				node_set(NEXTNODE,manipType,stepTmp).
				LOCAL scoreNew IS score(NEXTNODE,posTime).
				node_set(NEXTNODE,manipType,-stepTmp).
				LOCAL nodeTmp IS LIST(scoreNew["score"],scoreNew["posTime"],manipType,stepTmp,scoreNew["dist"]).

				IF bestNode[0] > nodeTmp[0] {
					SET bestNode TO nodeTmp.
					SET anyGood TO TRUE.
					BREAK.
				}
			}
			IF anyGood { BREAK. }
		}

		IF anyGood {
			node_set(NEXTNODE,bestNode[2],bestNode[3]).
			SET hillValues["score"] TO bestNode[0].
			SET hillValues["posTime"] TO bestNode[1].
			SET hillValues["dist"] TO bestNode[4].
			SET hillValues["stepVal"] TO (varConstants["initalStep"] / (10^FLOOR(stepMod))).
			SET stepMod TO MAX(stepMod - 0.025,0).
			CLEARSCREEN.
			PRINT "score: " + ROUND(hillValues["score"]) + " dist: " + ROUND(hillValues["dist"]) + " pedif: " + ROUND(NEXTNODE:ORBIT:PERIAPSIS - varConstants["peTarget"]).
			PRINT "deltaTime: " + ROUND(delta_time(),2).
		} ELSE {
			SET hillValues["stepVal"] TO hillValues["stepVal"] / 10.
			SET stepMod TO stepMod + 0.5.
		}
		SET done TO (hillValues["stepVal"] < 0.001) OR (NEXTNODE:ETA < 120).
	}
	SET close TO (hillValues["dist"] < 2000) OR (varConstants["mode"] = 1).
}
SET CONFIG:IPU TO ipuBackup.
IF varConstants ["mode"] = 0 {
	LOCAL deltaTimeFull IS ROUND(TIME:SECONDS - timePreFull,2).
	RUN node_burn.ks.
	RUN land_at.ks(landingCoordinates).
	PRINT "time delta: " + deltaTimeFull.
} ELSE {
	RUN node_burn.ks.
	IF HASNODE { UNTIL NOT HASNODE { REMOVE NEXTNODE. WAIT 0. }}
	RUN landing.ks.
	PRINT "dist: " + ROUND(dist_betwene_coordinates(varConstants["landingCoordinates"],SHIP:GEOPOSITION),2).
	PRINT "head: " + ROUND(varConstants["landingCoordinates"]:HEADING).
}

//end of core logic start of functions
FUNCTION node_set { //manipulates the targetNode in one of 4 ways depending on manipType for a value of stepVal
	PARAMETER targetNode,manipType,stepVal.
	IF manipType = "eta" { SET targetNode:ETA TO targetNode:ETA + stepVal. } ELSE {
	IF manipType = "pro" { SET targetNode:PROGRADE TO targetNode:PROGRADE + stepVal. } ELSE {
	IF manipType = "nor" { SET targetNode:NORMAL TO targetNode:NORMAL + stepVal. } ELSE {
	IF manipType = "rad" { SET targetNode:RADIALOUT TO targetNode:RADIALOUT + stepVal. }}}}
}

FUNCTION score {
	PARAMETER targetNode,posTime.
	LOCAL stepVal IS (targetNode:ORBIT:PERIOD / 72).
	LOCAL peDiff IS ABS(targetNode:ORBIT:PERIAPSIS - varConstants["peTarget"]) / 3.
	IF (targetNode:ORBIT:PERIAPSIS < 0) AND (targetNode:ORBIT:TRANSITION <> "escape") {
		LOCAL pos IS pos_at_height(targetNode,posTime,stepVal).
		LOCAL dist IS dist_betwene_coordinates(varConstants["landingCoordinates"],pos_to_choordinates(pos)).
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
	LOCAL targetAltitudeHi IS varConstants["marginHeight"] + varConstants["landingCoordinates"]:TERRAINHEIGHT + 1.
	LOCAL targetAltitudeLow IS varConstants["marginHeight"] + varConstants["landingCoordinates"]:TERRAINHEIGHT - 1.
	LOCAL altitudeAt IS localBody:ALTITUDEOF(POSITIONAT(craft,scanTime)).
	IF NOT ((altitudeAt < targetAltitudeHi) AND (altitudeAt > targetAltitudeLow)) {
	UNTIL (altitudeAt < targetAltitudeHi) AND (altitudeAt > targetAltitudeLow) {
		IF altitudeAt > targetAltitudeHi {
			SET scanTime TO scanTime + localStepVal.
			SET altitudeAt TO localBody:ALTITUDEOF(POSITIONAT(craft,scanTime)).
			IF altitudeAt < targetAltitudeLow {
				SET scanTime TO scanTime - localStepVal.
				SET altitudeAt TO localBody:ALTITUDEOF(POSITIONAT(craft,scanTime)).
				SET localStepVal TO localStepVal / 2.
			}
		} ELSE IF altitudeAt < targetAltitudeLow {
			SET scanTime TO scanTime - localStepVal.
			SET altitudeAt TO localBody:ALTITUDEOF(POSITIONAT(craft,scanTime)).
			IF altitudeAt > targetAltitudeHi {
				SET scanTime TO scanTime + localStepVal.
				SET altitudeAt TO localBody:ALTITUDEOF(POSITIONAT(craft,scanTime)).
				SET localStepVal TO localStepVal / 2.
			}
		}
		IF maxScanTime < scanTime {
			SET scanTime TO scanTimeBackup.
			SET localStepVal TO localStepVal / 2.
		}
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

FUNCTION dist_betwene_coordinates {	//returns the dist betwene p2 and p1 on the localBody
	PARAMETER p1,p2.
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
	LOCAL stepVal IS varConstants["orbitalSpeed"]/10.
	LOCAL stepMod IS 15.
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

FUNCTION margen_error { //aproximates vertical drop needed for the craft to stop
	LOCAL velSpeed IS (SHIP:BODY:MU / SHIP:ORBIT:SEMIMAJORAXIS)^0.5.
	LOCAL srfGrav IS SHIP:BODY:MU / (SHIP:BODY:RADIUS ^ 2).
	LOCAL burnTime IS 0.
	LOCAL burnTimePre IS 1.
	LOCAL shipMass IS SHIP:MASS.
	LOCAL shipISP IS isp_calc().
	UNTIL FALSE {
//		SET burnTime TO burn_duration(shipISP,((((burnTime * srfGrav)^2) + velSpeed^2)^0.5),shipMass).
		SET burnTime TO burn_duration(shipISP,((((burnTime * srfGrav + velSpeed ^ .5) ^ 2) + velSpeed) ^ 0.5),shipMass).
		IF ABS(burnTime - burnTimePre) <0.01 { RETURN burnTime * srfGrav. }
		SET burnTimePre TO burnTime.
	}
}

FUNCTION burn_duration {	//from isp, dv, and wet mass calculates the amount of time needed for the burn
	PARAMETER sISP, bDV, wMass.
	LOCAL flowRate IS SHIP:AVAILABLETHRUST / (sISP * 9.802).
	LOCAL dMass IS wMass / (CONSTANT:E^ (bDV / (sISP * 9.802))).
	RETURN (wMass - dMass) / flowRate.
}

FUNCTION isp_calc {	//calculates the average isp of the active engins on the ship
	LIST ENGINES IN engineList.
	LOCAL totalFlow IS 0.
	LOCAL totalThrust IS 0.
	FOR engine IN engineList {
		IF engine:IGNITION AND NOT engine:FLAMEOUT {
			SET totalFlow TO totalFlow + (engine:AVAILABLETHRUST / engine:ISP).
			SET totalThrust TO totalThrust + engine:AVAILABLETHRUST.
		}
	}
	IF MAXTHRUST = 0 {
		SET totalThrust TO 1.
		SET totalFlow TO 1.
	}
		RETURN (totalThrust / totalFlow).
}