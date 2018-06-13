IF NOT EXISTS("1:/lib/lib_rocket_utilities.ks") { copypath("0:/lib/lib_rocket_utilities.ks","1:/lib/"). }
RUNONCEPATH("1:/lib/lib_rocket_utilities.ks").
control_point().
RCS OFF.
//LOCAL ipuBackup IS CONFIG:IPU.
//SET CONFIG:IPU TO 2000.
CLEARSCREEN.
SET TERMINAL:WIDTH TO 55.
SET TERMINAL:HEIGHT TO 15.
PARAMETER landingTar.
LOCAL landingCoordinates IS 0.
LOCAL targetGo IS TRUE.
IF landingTar:ISTYPE("string") {SET landingTar TO WAYPOINT(landingTar).}
IF landingTar:ISTYPE("vessel") or landingTar:ISTYPE("waypoint") {
	SET landingCoordinates TO landingTar:GEOPOSITION.
} ELSE {
	IF landingTar:ISTYPE("part") {
		SET landingCoordinates TO BODY:GEOPOSITIONOF(landingTar:POSITION).
	} ELSE {
		IF landingTar:ISTYPE("geocoordinates") {
			SET landingCoordinates TO landingTar.
		} ELSE {
			PRINT "I don't know how ues a dest type of :" + landingTar:TYPENAME.
			SET targetGo TO false.
		}
	}
}
IF targetGo {

LOCAL nodeStartTime IS TIME:SECONDS + (SHIP:ORBIT:PERIOD / 8).
LOCAL localBody IS SHIP:BODY.
LOCAL orbitalSpeed IS ROUND((localBody:MU / SHIP:ORBIT:SEMIMAJORAXIS)^0.5).
LOCAL maxDv IS orbitalSpeed * 0.75.
LOCAL marginHeight IS 100 + margen_error() * 5.
GLOBAL varConstants IS LEX("landingCoordinates",landingCoordinates,"marginHeight",marginHeight,"initalStep",orbitalSpeed/10,"peTarget",(localBody:RADIUS / -1.5),"mode",0,"manipList",LIST("eta","pro","nor","rad"),"maxDv",maxDv).

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
IF varConstants["mode"] = 0 { periapsis_manipulaiton(NEXTNODE). }
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
		periapsis_manipulaiton(NEXTNODE).
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
		LOCAL anyGood IS FALSE.
		LOCAL bestNode IS LIST(hillValues["score"],posTime,"no",0,hillValues["dist"]).
		FOR manipType IN  varConstants["manipList"] {
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
			SET stepMod TO MAX(stepMod - 0.025,-0.1).
			SET hillValues["score"] TO bestNode[0].
			SET hillValues["posTime"] TO bestNode[1].
			SET hillValues["dist"] TO bestNode[4].
			SET hillValues["stepVal"] TO varConstants["initalStep"] / (10^stepMod).
			CLEARSCREEN.
			PRINT "score: " + ROUND(hillValues["score"]) + " dist: " + ROUND(hillValues["dist"]) + " pedif: " + ROUND(NEXTNODE:ORBIT:PERIAPSIS - varConstants["peTarget"]) + " stepVal: " + ROUND(hillValues["stepVal"],3).
			PRINT "deltaTime: " + ROUND(delta_time(),2).
		} ELSE {
			SET stepMod TO stepMod + 1.
			SET hillValues["stepVal"] TO varConstants["initalStep"] / (10^stepMod).
		}
		SET done TO (hillValues["stepVal"] < 0.001) OR (NEXTNODE:ETA < 120) OR (NEXTNODE:DELTAV:MAG > varConstants["maxDv"]).
	}
	SET close TO ((hillValues["dist"] < 2000) AND (NEXTNODE:DELTAV:MAG < varConstants["maxDv"])) OR (varConstants["mode"] = 1).
}}
//SET CONFIG:IPU TO ipuBackup.

//end of core logic start of functions
FUNCTION node_set { //manipulates the targetNode in one of 4 ways depending on manipType for a value of stepVal
	PARAMETER targetNode,manipType,stepVal.
	IF manipType = "eta" { SET targetNode:ETA TO targetNode:ETA + stepVal * 2. } ELSE {
	IF manipType = "pro" { SET targetNode:PROGRADE TO targetNode:PROGRADE + stepVal. } ELSE {
	IF manipType = "nor" { SET targetNode:NORMAL TO targetNode:NORMAL + stepVal. } ELSE {
	IF manipType = "rad" { SET targetNode:RADIALOUT TO targetNode:RADIALOUT + stepVal. }}}}
}

FUNCTION score { //returns the score of the node
	PARAMETER targetNode,posTime.
	LOCAL stepVal IS varConstants["initalStep"].
	LOCAL peDiff IS ABS(targetNode:ORBIT:PERIAPSIS - varConstants["peTarget"]).
	IF (targetNode:ORBIT:PERIAPSIS < 0) AND (targetNode:ORBIT:TRANSITION <> "escape") {
		LOCAL localBody IS SHIP:BODY.
		LOCAL scanTime IS posTime.
		LOCAL maxScanTime IS targetNode:ORBIT:PERIOD + posTime.
		LOCAL targetAltitudeHi IS varConstants["marginHeight"] + varConstants["landingCoordinates"]:TERRAINHEIGHT + 1.
		LOCAL targetAltitudeLow IS varConstants["marginHeight"] + varConstants["landingCoordinates"]:TERRAINHEIGHT - 1.
		LOCAL altitudeAt IS localBody:ALTITUDEOF(POSITIONAT(SHIP,scanTime)).
		UNTIL (altitudeAt < targetAltitudeHi) AND (altitudeAt > targetAltitudeLow) {
			IF altitudeAt > targetAltitudeHi {
				SET scanTime TO scanTime + stepVal.
				SET altitudeAt TO localBody:ALTITUDEOF(POSITIONAT(SHIP,scanTime)).
				IF altitudeAt < targetAltitudeLow {
					SET scanTime TO scanTime - stepVal.
					SET altitudeAt TO localBody:ALTITUDEOF(POSITIONAT(SHIP,scanTime)).
					SET stepVal TO stepVal / 2.
				}
			} ELSE IF altitudeAt < targetAltitudeLow {
				SET scanTime TO scanTime - stepVal.
				SET altitudeAt TO localBody:ALTITUDEOF(POSITIONAT(SHIP,scanTime)).
				IF altitudeAt > targetAltitudeHi {
					SET scanTime TO scanTime + stepVal.
					SET altitudeAt TO localBody:ALTITUDEOF(POSITIONAT(SHIP,scanTime)).
					SET stepVal TO stepVal / 2.
				}
			}
			IF maxScanTime < scanTime {
				SET scanTime TO posTime.
				SET stepVal TO stepVal / 2.
			}
		}

		LOCAL dist IS dist_betwene_coordinates(varConstants["landingCoordinates"],pos_to_choordinates(POSITIONAT(SHIP,scanTime),scanTime)).
		LOCAL scored IS dist + peDiff / 3.
		IF targetNode:ISTYPE("node") { SET scored TO scored + (targetNode:DELTAV:MAG * 6). }
		RETURN LEX("score",scored,"posTime",scanTime,"dist",dist).
	} ELSE {
		LOCAL dist IS SHIP:BODY:RADIUS * 2 * CONSTANT():PI.
		LOCAL peDiff IS targetNode:ORBIT:PERIAPSIS - varConstants["peTarget"].
		LOCAL scored IS dist + peDiff / 3.
		RETURN LEX("score",scored,"posTime",(targetNode:ETA + TIME:SECONDS + (targetNode:ORBIT:PERIOD / 4)),"dist",dist).
	}
}

FUNCTION pos_to_choordinates {	//converts return of POSITIONAT to a latlng choordnate acounting for body rotation
	PARAMETER pos,posTime.
	LOCAL localBody IS SHIP:BODY.
	LOCAL rotationalDir IS VDOT(localBody:NORTH:FOREVECTOR,localBody:ANGULARVEL).
	LOCAL timeDif IS posTime - TIME:SECONDS.
	LOCAL posLATLNG IS localBody:GEOPOSITIONOF(pos).
	LOCAL logintudeShift IS rotationalDir * timeDif * CONSTANT:RADTODEG.
	LOCAL newLNG IS posLATLNG:LNG + logintudeShift.
	IF newLNG < - 180 { SET newLNG TO newLNG + 360. }
	IF newLNG > 180 { SET newLNG TO newLNG - 360. }
	RETURN LATLNG(posLATLNG:LAT,newLNG).
}

FUNCTION dist_betwene_coordinates {	//returns the dist betwene p1 and p2 on the localBody
	PARAMETER p1,p2.
	LOCAL bodyRadius IS SHIP:BODY:RADIUS.
	LOCAL localA is SIN((p1:LAT-p2:LAT)/2)^2 + COS(p1:LAT)*COS(p2:LAT)*SIN((p1:LNG-p2:LNG)/2)^2.
	RETURN bodyRadius*CONSTANT():PI*ARCTAN2(SQRT(localA),SQRT(1-localA))/90.
}

FUNCTION delta_time {
	IF NOT (DEFINED prevousTime) { GLOBAL prevousTime IS TIME:SECONDS. }
	LOCAL deltaTime IS TIME:SECONDS - prevousTime.
	SET prevousTime TO TIME:SECONDS.
	RETURN deltaTime.
}

FUNCTION periapsis_manipulaiton {//manipulates the PE after node to be below the peTarget
	PARAMETER targetNode.
	LOCAL peTarget IS varConstants["peTarget"].
	LOCAL stepVal IS varConstants["initalStep"].
	LOCAL stepMod IS 10.
	LOCAL lowerLimit IS peTarget - 1.
	LOCAL upperLimit IS peTarget + 1.
	LOCAL done IS FALSE.
	UNTIL done{
		IF targetNode:ORBIT:PERIAPSIS > upperLimit {
			SET targetNode:PROGRADE TO targetNode:PROGRADE - stepVal.
			IF targetNode:ORBIT:PERIAPSIS < lowerLimit {
				SET stepVal TO stepVal / stepMod.
				SET targetNode:PROGRADE TO targetNode:PROGRADE + stepVal.
			}
		} ELSE IF targetNode:ORBIT:PERIAPSIS < lowerLimit {
			SET targetNode:PROGRADE TO targetNode:PROGRADE + stepVal.
			IF targetNode:ORBIT:PERIAPSIS > upperLimit {
				SET stepVal TO stepVal / stepMod.
				SET targetNode:PROGRADE TO targetNode:PROGRADE - stepVal.
			}
		}
		SET done TO (targetNode:ORBIT:PERIAPSIS > lowerLimit) AND (targetNode:ORBIT:PERIAPSIS < upperLimit).
	}
}

FUNCTION margen_error { //aproximates vertical drop needed for the craft to stop
	LOCAL velSpeed IS (((SHIP:BODY:MU / SHIP:ORBIT:SEMIMAJORAXIS)^0.5) / 2)^0.5.
	LOCAL srfGrav IS SHIP:BODY:MU / (SHIP:BODY:RADIUS ^ 2).
	LOCAL burnTime IS 0.
	LOCAL burnTimePre IS 0.
	LOCAL shipMass IS SHIP:MASS.
	LOCAL shipISP IS isp_calc().

	UNTIL FALSE {
		SET burnTime TO burn_duration(shipISP,((((burnTime * srfGrav + velSpeed) ^ 2) + velSpeed ^ 2) ^ 0.5),shipMass).
		IF ABS(burnTime - burnTimePre) <0.01 { RETURN burnTime * srfGrav. }
		SET burnTimePre TO burnTime.
	}
}

FUNCTION isp_calc {	//calculates the average isp of all of the active engins on the ship
	LOCAL engineList IS LIST().
	LOCAL totalFlow IS 0.
	LOCAL totalThrust IS 0.
	LIST ENGINES IN engineList.
	FOR engine IN engineList {
		IF engine:IGNITION AND NOT engine:FLAMEOUT {
			SET totalFlow TO totalFlow + (engine:AVAILABLETHRUST / engine:ISP).
			SET totalThrust TO totalThrust + engine:AVAILABLETHRUST.
		}
	}
	IF MAXTHRUST = 0 {
		RETURN 1.
	}
	RETURN (totalThrust / totalFlow).
}

FUNCTION burn_duration {	//from isp, dv, and wet mass calculates the amount of time needed for the burn
	PARAMETER sISP, DV, wMass.
	LOCAL flowRate IS SHIP:AVAILABLETHRUST / (sISP * 9.806).
	LOCAL dMass IS wMass / (CONSTANT:E^ (DV / (sISP * 9.806))).
	RETURN (wMass - dMass) / flowRate.
}

FUNCTION control_point {
	PARAMETER pTag IS "controlPoint".
	LOCAL controlList IS SHIP:PARTSTAGGED(pTag).
	IF controlList:LENGTH > 0 {
		controlList[0]:CONTROLFROM().
	}
}