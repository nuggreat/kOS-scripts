PARAMETER landingTar,margin IS 100.
FOR lib IN LIST("lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
control_point().
WAIT UNTIL active_engine().
RCS OFF.
//LOCAL ipuBackup IS CONFIG:IPU.
//SET CONFIG:IPU TO 2000.
CLEARSCREEN.
SET TERMINAL:WIDTH TO 55.
SET TERMINAL:HEIGHT TO 15.
delta_time_init.
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
LOCAL orbitalSpeed IS (localBody:MU / SHIP:ORBIT:SEMIMAJORAXIS)^0.5.
LOCAL maxDv IS orbitalSpeed.
LOCAL marginHeight IS margin + margin_error(orbitalSpeed).
GLOBAL varConstants IS LEX("landingCoordinates",landingCoordinates,"marginHeight",marginHeight,"initalStep",orbitalSpeed/10,"peTarget",(localBody:RADIUS / -1.5),"mode",0,"manipList",LIST("eta","pro","nor","rad"),"maxDv",maxDv).

IF SHIP:ORBIT:PERIAPSIS < 0 {
	SET varConstants["mode"] TO 1.
	SET nodeStartTime TO (score(SHIP,TIME:SECONDS + (SHIP:ORBIT:PERIOD / 8))["posTime"] + TIME:SECONDS) / 2.
	varConstants["manipList"]:REMOVE(0).
} ELSE IF ETA:APOAPSIS < 600 {
	SET nodeStartTime TO nodeStartTime + (SHIP:ORBIT:PERIOD / 4).
}
clear_all_nodes().
LOCAL baseNode IS NODE(nodeStartTime,0,0,0).
ADD baseNode.
IF varConstants["mode"] = 0 { periapsis_manipulaiton(NEXTNODE). }
LOCAL scored IS score(NEXTNODE,(NEXTNODE:ETA + TIME:SECONDS + (NEXTNODE:ORBIT:PERIOD / 8))).
LOCAL hillValues IS LEX("score",scored["score"],"posTime",scored["posTime"],"stepVal",varConstants["initalStep"],"dist",scored["dist"]).
LOCAL timePreFull IS TIME:SECONDS.
LOCAL shipISP IS isp_calc().
LOCAL timeStart IS TIME:SECONDS.
LOCAL count IS 0.
LOCAL close IS FALSE.
LOCAL done IS FALSE.
UNTIL close{
	IF done AND (varConstants["mode"] = 0) {
		SET done TO FALSE.
		SET nodeStartTime TO nodeStartTime + (SHIP:ORBIT:PERIOD / 4).
		SET baseNode TO NODE(nodeStartTime,0,0,0).
		clear_all_nodes().
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
			SET stepMod TO MAX(stepMod - 0.005,-0.2).
			SET hillValues["score"] TO bestNode[0].
			SET hillValues["posTime"] TO bestNode[1].
			SET hillValues["dist"] TO bestNode[4].
			SET hillValues["stepVal"] TO varConstants["initalStep"] / (10^stepMod).
			SET count TO count + 1.
			CLEARSCREEN.
			PRINT "Target Coordinates: (" + ROUND(varConstants["landingCoordinates"]:LAT,2) + "," + ROUND(varConstants["landingCoordinates"]:LNG,2) + ")".
			PRINT "Score: " + ROUND(hillValues["score"]).
			PRINT "Dist:  " + ROUND(hillValues["dist"]).
			PRINT "Pedif: " + ROUND(NEXTNODE:ORBIT:PERIAPSIS - varConstants["peTarget"]).
			PRINT " ".
			PRINT "   Step Size: " + ROUND(hillValues["stepVal"],3).
			PRINT "  Total Time: " + ROUND(TIME:SECONDS - timeStart,3).
			PRINT "   Step Time: " + ROUND(delta_time(),2).
			PRINT "Average Time: " + ROUND((TIME:SECONDS - timeStart) / count,3).
		} ELSE {
			SET stepMod TO stepMod + 1.
			SET hillValues["stepVal"] TO varConstants["initalStep"] / (10^stepMod).
		}
		SET done TO (hillValues["stepVal"] < 0.001) OR (NEXTNODE:ETA < (120 + burn_duration(shipISP,NEXTNODE:DELTAV:MAG))) OR (NEXTNODE:DELTAV:MAG > varConstants["maxDv"]).
	}
	SET close TO ((hillValues["dist"] < 2000) AND (NEXTNODE:DELTAV:MAG < varConstants["maxDv"])) OR (varConstants["mode"] = 1).
}
//IF NOT EXISTS("0:/land_at_log.txt") { LOG "avrage time" TO "0:/land_at_log.txt". }
//LOG ROUND((TIME:SECONDS - timeStart) / count,4) TO "0:/land_at_log.txt".
}
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
	LOCAL peDiff IS ABS(targetNode:ORBIT:PERIAPSIS - varConstants["peTarget"]).
	LOCAL PEweight IS 1 / 3.
//	IF varConstants["mode"] = 1 { SET PEweight TO 1 / 2. }
	IF (targetNode:ORBIT:PERIAPSIS < 0) AND (targetNode:ORBIT:TRANSITION <> "escape") {
		LOCAL stepVal IS varConstants["initalStep"].
		LOCAL localBody IS SHIP:BODY.
		LOCAL highPoint IS targetNode:ETA + TIME:SECONDS.
		LOCAL lowPoint IS targetNode:ORBIT:PERIOD / 2 + highPoint.
		LOCAL maxScanTime IS highPoint + targetNode:ORBIT:PERIOD.
		LOCAL targetAltitude IS varConstants["marginHeight"] + varConstants["landingCoordinates"]:TERRAINHEIGHT.
		IF lowPointAlt > targetAltitude {
			LOCAL lowPointAlt IS localBody:ALTITUDEOF(POSITIONAT(SHIP,lowPoint)).
			LOCAL posNeg IS 1.
			IF lowPointAlt < localBody:ALTITUDEOF(POSITIONAT(SHIP,lowPoint["time"] + stepVal)) { SET posNeg TO - 1. }
			
			UNTIL lowPointAlt < targetAltitude {
				SET lowPoint TO lowPoint + stepVal * posNeg.
				SET lowPointAlt TO localBody:ALTITUDEOF(POSITIONAT(SHIP,lowPoint)).
				IF maxScanTime < lowPoint {
					SET lowPoint TO targetNode:ORBIT:PERIOD / 2 + highPoint.
					SET stepVal TO stepVal / 10.
				}
			}
		}
		LOCAL midPoint IS (lowPoint + highPoint) / 2.
		LOCAL midPointAlt IS localBody:ALTITUDEOF(POSITIONAT(SHIP,midPoint)) - targetAltitude.
		UNTIL ABS(midPointAlt) < 1 {
			IF midPointAlt > 0 {
				SET highPoint TO midPoint.
			} ELSE {
				SET lowPoint TO midPoint.
			}
			SET midPoint TO (lowPoint + highPoint) / 2.
			SET midPointAlt TO localBody:ALTITUDEOF(POSITIONAT(SHIP,midPoint)) - targetAltitude.
		}
		
		LOCAL dist IS dist_betwene_coordinates(varConstants["landingCoordinates"],ground_track(midPoint)).
		LOCAL scored IS dist + peDiff * PEweight.
		IF targetNode:ISTYPE("node") { SET scored TO scored + (targetNode:DELTAV:MAG * 6). }
		RETURN LEX("score",scored,"posTime",midPoint,"dist",dist).
	} ELSE {
		LOCAL dist IS SHIP:BODY:RADIUS * 2 * CONSTANT():PI.
		LOCAL peDiff IS targetNode:ORBIT:PERIAPSIS - varConstants["peTarget"].
		LOCAL scored IS dist + peDiff * PEweight.
		RETURN LEX("score",scored,"posTime",(targetNode:ETA + TIME:SECONDS + (targetNode:ORBIT:PERIOD / 4)),"dist",dist).
	}
}

FUNCTION ground_track {	//returns the geocoordinates of the ship at a given time(UTs) adjusting for planetary rotation over time
	PARAMETER posTime.
	LOCAL pos IS POSITIONAT(SHIP,posTime).
	LOCAL localBody IS SHIP:BODY.
	LOCAL rotationalDir IS VDOT(localBody:NORTH:FOREVECTOR,localBody:ANGULARVEL). //the number of radians the body will rotate in one second
	LOCAL timeDif IS posTime - TIME:SECONDS.
	LOCAL posLATLNG IS localBody:GEOPOSITIONOF(pos).
	LOCAL longitudeShift IS rotationalDir * timeDif * CONSTANT:RADTODEG.
	LOCAL newLNG IS MOD(posLATLNG:LNG + longitudeShift ,360).
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

FUNCTION delta_time_init {
	GLOBAL prevousTime IS TIME:SECONDS.
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

FUNCTION margin_error { //approximates vertical drop needed for the craft to stop
	PARAMETER orbitalSpeed.
	LOCAL velSpeed IS ((orbitalSpeed^2)/2)^0.5.
	//LOCAL srfGrav IS ((SHIP:BODY:MU / (SHIP:BODY:RADIUS ^ 2)) + (SHIP:BODY:MU / (SHIP:ORBIT:SEMIMAJORAXIS ^ 2))) / 2.
	LOCAL srfGrav IS SHIP:BODY:MU / (SHIP:BODY:RADIUS ^ 2).
//	LOCAL orbGrav IS SHIP:BODY:MU / (SHIP:ORBIT:SEMIMAJORAXIS ^ 2).
	LOCAL burnTime IS 0.
	LOCAL burnTimePre IS 0.
	LOCAL shipISP IS isp_calc().
	
	UNTIL FALSE {
		//SET surBurnTime TO burn_duration(shipISP,(SQRT((burnTime * srfGrav + velSpeed) ^ 2) + velSpeed ^ 2)).
		//LOCAL orbBurnTime IS burn_duration(shipISP,SQRT(((burnTime * orbGrav + velSpeed) ^ 2) + velSpeed ^ 2)).
		SET burnTime TO burn_duration(shipISP,SQRT(((burnTime * srfGrav) ^ 2) + orbitalSpeed ^ 2)).
		//SET burnTime TO burn_duration(shipISP,(burnTime * srfGrav + orbitalSpeed)).
		IF ABS(burnTime - burnTimePre) < 0.01 { RETURN (1/30 * srfGrav * burnTime^2). }// - (1/2 * orbGrav * burnTime^2). }
		SET burnTimePre TO burnTime.
	}
}