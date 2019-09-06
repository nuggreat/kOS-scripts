//TODO: re-add in hillclimb solution for impact for when in hyperbolic orbits
PARAMETER landingTar,margin IS 100.
//IF NOT EXISTS("1/lib/lib_mis_utilities.ks") { COPYPATH("0:/lib/lib_mis_utilities.ks","1:/lib/lib_mis_utilities.ks"). }
//IF NOT EXISTS("1/lib/lib_geochordnate.ks") { COPYPATH("0:/lib/lib_geochordnate.ks","1:/lib/lib_geochordnate.ks"). }
//IF NOT EXISTS("1/lib/lib_hill_climb.ks") { COPYPATH("0:/lib/lib_hill_climb.ks","1:/lib/lib_hill_climb.ks"). }
//COPYPATH("0:/lib/lib_hill_climb.ks","1:/lib/lib_hill_climb.ks").
FOR lib IN LIST("lib_rocket_utilities","lib_mis_utilities","lib_geochordnate","lib_hill_climb") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNPATH("1:/lib/" + lib + ".ks"). }}

//LOCAl logPath IS PATH("0:/log_land_at_v6.txt").
//IF EXISTS(logPath) { DELETEPATH(logPath). }
//IF NOT EXISTS(logPath) { LOG "Cycles,Time" TO logPath. }

//control_point().
//WAIT UNTIL active_engine().
//RCS OFF.
//LOCAL ipuBackup IS CONFIG:IPU.
//SET CONFIG:IPU TO 2000.
CLEARSCREEN.
SET TERMINAL:WIDTH TO 55.
SET TERMINAL:HEIGHT TO 15.
clear_all_nodes().
LOCAL landingData IS mis_types_to_geochordnate(landingTar).
LOCAL landingChord IS landingData["chord"].

IF landingChord:ISTYPE("geocoordinates") {

LOCAL nodeStartTime IS TIME:SECONDS + (SHIP:ORBIT:PERIOD / 8).
LOCAL localBody IS SHIP:BODY.
LOCAL orbitalSpeed IS SQRT(localBody:MU / SHIP:ORBIT:SEMIMAJORAXIS).
LOCAL maxDv IS orbitalSpeed.
LOCAL marginHeight IS margin.// + margin_error(orbitalSpeed).
GLOBAL varConstants IS LEX(
	"landingChord",landingChord,
	"marginHeight",marginHeight,
	"landingAlt",marginHeight + landingChord:TERRAINHEIGHT,
	"initalStep",orbitalSpeed/10,
	"peTarget",(localBody:RADIUS / -1.5),
	"mode",0
).
LOCAL refineDeorbit IS SHIP:ORBIT:PERIAPSIS < 0.


LOCAL terms IS 4.
node_step_init(LIST("eta","norm","pro","rad")).
IF refineDeorbit {
	SET varConstants["mode"] TO 1.
	SET nodeStartTime TO (impact_ETA(ta_to_ma(SHIP:ORBIT:ECCENTRICITY,SHIP:ORBIT:TRUEANOMALY),SHIP:ORBIT,varConstants["landingAlt"]) / 2 + TIME:SECONDS).
	SET terms TO 3.
	node_step_init(LIST("pro","norm","rad")).
} ELSE IF ETA:APOAPSIS < 600 {
	SET nodeStartTime TO nodeStartTime + (SHIP:ORBIT:PERIOD / 4).
}

LOCAL baseNode IS NODE(nodeStartTime,0,0,0).
ADD baseNode.
IF varConstants["mode"] = 0 { periapsis_manipulaiton(NEXTNODE). }
LOCAL climbData IS climb_init("first",terms,varConstants["initalStep"],score(NEXTNODE),0.005,1,0.001,0).

LOCAL shipISP IS isp_calc().
LOCAL timeStart IS TIME:SECONDS.
LOCAL count IS 0.
LOCAL bestDist IS 0.
LOCAL close IS FALSE.
LOCAL done IS FALSE.
delta_time().//first call of delta_time function to set initial start time
UNTIL close {
	IF done AND (varConstants["mode"] = 0) {
		SET done TO FALSE.
		SET nodeStartTime TO nodeStartTime + (SHIP:ORBIT:PERIOD / 4).
		SET baseNode TO NODE(nodeStartTime,0,0,0).
		clear_all_nodes().
		ADD baseNode.
		periapsis_manipulaiton(NEXTNODE).
		SET climbData TO climb_init("first",terms,varConstants["initalStep"],score(NEXTNODE),0.005,1,0.001,0).
	}
	LOCAL hillDone IS FALSE.
	UNTIL done {

		IF refineDeorbit {
			SET hillDone TO climb_hill(NEXTNODE,score@,node_step_dv_only@,climbData).
		} ELSE {
			SET hillDone TO climb_hill(NEXTNODE,score@,node_step_full@,climbData).
		}
		LOCAL nodeDV IS NEXTNODE:DELTAV:MAG.
		SET done TO hillDone OR (nodeDV > maxDv) OR (NOT refineDeorbit) AND (NEXTNODE:ETA < (120 + burn_duration(shipISP,nodeDV))) .

		SET bestDist TO climbData["results"]["dist"].
		LOCAL bestScore IS climbData["results"]["score"].
		SET count TO count + 1.
		CLEARSCREEN.
		PRINT "Target Coordinates: (" + ROUND(varConstants["landingChord"]:LAT,2) + "," + ROUND(varConstants["landingChord"]:LNG,2) + ")".
		PRINT "Score: " + ROUND(bestScore).
		PRINT "Dist:  " + ROUND(bestDist).
		PRINT "Pedif: " + ROUND(NEXTNODE:ORBIT:PERIAPSIS - varConstants["peTarget"]).
		PRINT " ".
		PRINT "   Step Size: " + ROUND(climbData["maxStep"] * 10^climbData["stepExp"],4).
		PRINT "  Total Time: " + ROUND(TIME:SECONDS - timeStart,3).
		PRINT "   Step Time: " + ROUND(delta_time(),2).
		PRINT "Average Time: " + ROUND((TIME:SECONDS - timeStart) / count,3).
	}
	SET close TO ((bestDist < 2000) AND (NEXTNODE:DELTAV:MAG < maxDv)) OR (varConstants["mode"] = 1).
}
//LOG count + "," + ROUND(TIME:SECONDS - timeStart,2) TO logPath.
//IF NOT EXISTS("0:/land_at_log.txt") { LOG "avrage time" TO "0:/land_at_log.txt". }
//LOG ROUND((TIME:SECONDS - timeStart) / count,4) TO "0:/land_at_log.txt".
}
//SET CONFIG:IPU TO ipuBackup.

//end of core logic start of functions

FUNCTION score { //returns the score of the node
	PARAMETER targetNode.
	LOCAL nodeOrbit IS targetNode:ORBIT.
	LOCAL peDiff IS ABS(nodeOrbit:PERIAPSIS - varConstants["peTarget"]).
	LOCAL PEweight IS 1 / 3.
//	IF varConstants["mode"] = 1 { SET PEweight TO 1 / 2. }
	IF (nodeOrbit:PERIAPSIS < 0) AND (nodeOrbit:TRANSITION <> "escape") {
		LOCAL nodeUTs IS targetNode:ETA + TIME:SECONDS.
		LOCAL nodeToImpact IS impact_ETA(nodeOrbit:MEANANOMALYATEPOCH,nodeOrbit,varConstants["landingAlt"]).
		LOCAL impactTime IS nodeToImpact + nodeUTs.

		LOCAL dist IS dist_between_coordinates(varConstants["landingChord"],ground_track(POSITIONAT(SHIP,impactTime),impactTime)).
		LOCAL scored IS dist + peDiff * PEweight.
		IF targetNode:ISTYPE("node") { SET scored TO scored + (targetNode:DELTAV:MAG * 6). }
		RETURN LEX("score",scored,"dist",dist).
	} ELSE {
		LOCAL dist IS SHIP:BODY:RADIUS * 2 * CONSTANT():PI.
		//LOCAL peDiff IS targetNode:ORBIT:PERIAPSIS - varConstants["peTarget"].
		LOCAL scored IS dist + peDiff * PEweight.
		RETURN LEX("score",scored,"dist",dist).
	}
}

FUNCTION impact_ETA {//returns the seconds between maDeg1 and terrain impact
	PARAMETER maDeg1,orbitIn,impactAlt.
	LOCAL ecc IS orbitIn:ECCENTRICITY.
	LOCAL orbPer IS orbitIn:PERIOD.
	LOCAL sma IS orbitIn:SEMIMAJORAXIS.
	LOCAL rad IS varConstants["landingAlt"] + orbitIn:BODY:RADIUS.
	LOCAL taOfAlt IS 360 - ARCCOS((-sma * ecc ^2 + sma - rad) / (ecc * rad)).
	
	LOCAL maDeg2 IS ta_to_ma(ecc,taOfAlt).
	
	LOCAL timeDiff IS orbPer * ((maDeg2 - maDeg1) / 360).
	
	RETURN MOD(timeDiff + orbPer, orbPer).
}

FUNCTION ta_to_ma {//converts a true anomaly(degrees) to the mean anomaly (degrees), also found in lib_orbital_math, NOTE: only works for non hyperbolic orbits
	PARAMETER ecc,taDeg.
	LOCAL eaDeg IS ARCTAN2( SQRT(1-ecc^2)*SIN(taDeg), ecc + COS(taDeg)).
	LOCAL maDeg IS eaDeg - (ecc * SIN(eaDeg) * CONSTANT:RADtoDEG).
	RETURN MOD(maDeg + 360,360).
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
	//LOCAL velSpeed IS ((orbitalSpeed^2)/2)^0.5.
	//LOCAL srfGrav IS ((SHIP:BODY:MU / (SHIP:BODY:RADIUS ^ 2)) + (SHIP:BODY:MU / (SHIP:ORBIT:SEMIMAJORAXIS ^ 2))) / 2.
	LOCAL srfGrav IS SHIP:BODY:MU / (SHIP:BODY:RADIUS ^ 2).
	//LOCAL orbGrav IS SHIP:BODY:MU / (SHIP:ORBIT:SEMIMAJORAXIS ^ 2).
	LOCAL burnTime IS 0.
	LOCAL burnTimePre IS 0.
	LOCAL shipISP IS isp_calc().

	UNTIL FALSE {
		//SET surBurnTime TO burn_duration(shipISP,(SQRT((burnTime * srfGrav + velSpeed) ^ 2) + velSpeed ^ 2)).
		//LOCAL orbBurnTime IS burn_duration(shipISP,SQRT(((burnTime * orbGrav + velSpeed) ^ 2) + velSpeed ^ 2)).
		SET burnTime TO burn_duration(shipISP,SQRT(((burnTime * srfGrav) ^ 2) + orbitalSpeed ^ 2)).
		//SET burnTime TO burn_duration(shipISP,(burnTime * srfGrav + orbitalSpeed)).
		IF ABS(burnTime - burnTimePre) < 0.01 { RETURN (1/30 * srfGrav * burnTime^2). }// - (1/2 * orbGrav * burnTime^2). }
		//IF ABS(burnTime - burnTimePre) < 0.01 { RETURN (srfGrav * (burnTime / 2)^2). }// - (1/2 * orbGrav * burnTime^2). }
		SET burnTimePre TO burnTime.
	}
}