//COPYPATH("0:/lib/lib_formating.ks","1:/lib/").
COPYPATH("0:/lib/lib_orbital_math.ks","1:/lib/").
COPYPATH("0:/lib/lib_hill_climb.ks","1:/lib/").
PARAMETER incMatch IS TRUE,hohmann IS TRUE,refine IS TRUE,asap IS FALSE,skipConferms IS FALSE.
FOR lib IN LIST("lib_orbital_math","lib_rocket_utilities","lib_formating","lib_hill_climb") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
//control_point().
//WAIT UNTIL active_engine().
GLOBAL vecDrawList IS LIST().

RCS OFF.
LOCAL done IS FALSE.
UNTIL done {
	CLEARSCREEN.
	PRINT "Waiting Until a Target is Selected.".
	IF HASTARGET {
		SET done TO (TARGET:ISTYPE("vessel") OR TARGET:ISTYPE("body")).
		IF TARGET:ISTYPE("body") {
			SET refine TO FALSE.
		}
	}
	WAIT 0.1.
}

IF incMatch {
	clear_all_nodes().
	LOCAL nodesUTs IS UTs_of_nodes(SHIP,TARGET).
	LOCAL highNode IS "an".
	IF asap {
		IF nodesUTs["an"] > nodesUTs["dn"] {
			SET highNode TO "dn".
		}
	} ELSE {
		IF SHIP:BODY:ALTITUDEOF(POSITIONAT(SHIP,nodesUTs["an"])) < SHIP:BODY:ALTITUDEOF(POSITIONAT(SHIP,nodesUTs["dn"])) {
			SET highNode TO "dn".
		}
	}
	IF nodesUTs[highNode] - TIME:SECONDS < 300 {
		IF asap {
			IF highNode = "an" { SET highNode TO "dn". } ELSE { SET highNode TO "an". }
		} ELSE {
			SET nodesUTs[highNode] TO nodesUTs[highNode] + SHIP:ORBIT:PERIOD.
		}
	}

	LOCAL vecSpeedAtNode IS VELOCITYAT(SHIP,nodesUTs[highNode]):ORBIT.
	LOCAL vecBurn IS burn_vector(vecSpeedAtNode,normal_of_orbit(TARGET)).
	//LOCAL vecTarget IS VXCL(vecSpeedAtNode:NORMALIZED,normal_of_orbit(TARGET):NORMALIZED):NORMALIZED * vecSpeedAtNode:MAG.
	//LOCAL vecBurn IS vecTarget - vecSpeedAtNode.//will be a vector of mag = DV of burn with chordates of burn direction
	//PRINT "burnVec: " + ROUND(vecBurn:MAG,2).
	//PRINT " ".
	//PRINT "Alt an:  " + SHIP:BODY:ALTITUDEOF(POSITIONAT(SHIP,nodesUTs["an"])).
	//PRINT "Alt dn:  " + SHIP:BODY:ALTITUDEOF(POSITIONAT(SHIP,nodesUTs["dn"])).
	//PRINT "HighNode:" + highNode.
	//PRINT " ".
	//PRINT "AN UTs:  " + time_formating(nodesUTs["an"]).
	//PRINT "AD UTs:  " + time_formating(nodesUTs["dn"]).
	//PRINT "AN time: " + time_formating(nodesUTs["an"] - TIME:SECONDS).
	//PRINT "DN time: " + time_formating(nodesUTs["dn"] - TIME:SECONDS).

	LOCAL baseNode IS node_from_vector(vecBurn,nodesUTs[highNode]).
	ADD baseNode.
	RUNPATH("1:/node_burn",TRUE).
	WAIT 1.
}

IF hohmann {
	clear_all_nodes().
	LOCAL smaOfTransfer IS (SHIP:ORBIT:SEMIMAJORAXIS + TARGET:ORBIT:SEMIMAJORAXIS) / 2.
	LOCAL targetPeriod IS TARGET:ORBIT:PERIOD.
	LOCAL shipPeriod IS SHIP:ORBIT:PERIOD.
	LOCAL localTime IS TIME:SECONDS.
	LOCAL angleToTarget IS phase_angle(SHIP,TARGET).
	LOCAL periodOfTransfer IS orbital_period(smaOfTransfer,SHIP:BODY).
	LOCAL angleForTransfer IS MOD(360 * ((periodOfTransfer / 2) / targetPeriod) + 180,360).//the angle between ship and target for at the start of the transfer
	LOCAL phaseChange IS ((360 / targetPeriod) - (360 / shipPeriod)).//the change in angle between ship and target per second

	LOCAL transferETA IS (MOD((360 - angleForTransfer) - angleToTarget + 360,360) / phaseChange).
	IF transferETA < 0 {
		SET transferETA TO (MOD((360 - angleForTransfer) - angleToTarget - 360,360) / phaseChange).
	}

	LOCAL UTsOfTransfer IS transferETA + localTime.
	LOCAL speedAtBurn IS orbital_speed_at_altitude_from_sma(SHIP:BODY:ALTITUDEOF(POSITIONAT(SHIP,UTsOfTransfer)),smaOfTransfer).
	LOCAL transferDv IS speedAtBurn - VELOCITYAT(SHIP,UTsOfTransfer):ORBIT:MAG.

	//PRINT "angleToTarget:    " + angleToTarget.
	//PRINT "period of ship:   " + shipPeriod.
	//PRINT "period of target: " + targetPeriod.
	//PRINT "periodOfTransfer: " + periodOfTransfer.
	//PRINT "angleForTransfer: " + angleForTransfer.
	//PRINT "phaseChange:      " + phaseChange.
	//PRINT "UTsOfTransfer:    " + UTsOfTransfer.
	//PRINT "etaOfTransfer:    " + (transferETA / 60).
	ADD NODE(UTsOfTransfer,0,0,transferDv).
	IF NOT refine {
		RCS OFF.
		SAS OFF.
		PRINT "turn on sas to continue".
		PRINT "trun on rcs to burn".
		WAIT UNTIL SAS OR skipConferms.
		IF RCS OR skipConferms {
			RCS OFF.
			RUNPATH("1:/node_burn",TRUE).
			clear_all_nodes().
		}
	}
}

IF refine {
	LOCAL localBody IS SHIP:BODY.
	
	LOCAL orbitalSpeed IS SQRT(localBody:MU / SHIP:ORBIT:SEMIMAJORAXIS).
	LOCAL refineData IS climb_init("first",4,orbitalSpeed / 10,refine_score(NEXTNODE),0.1,1).
	LOCAL refined IS FALSE.
	UNTIL refined {
		SET refined TO climb_hill(NEXTNODE,refine_score@,node_step_full@,refineData).
		PRINT "close dist: " + refineData["results"]["dist"].
	}
	RCS OFF.
	SAS OFF.
	PRINT "turn on sas to continue".
	PRINT "trun on rcs to burn".
	WAIT UNTIL SAS OR skipConferms.
	IF RCS OR skipConferms {
		RCS OFF.
		RUNPATH("1:/node_burn",TRUE).
		clear_all_nodes().
	}
}

//WAIT UNTIL RCS.
CLEARVECDRAWS().

FUNCTION node_from_vector {//only works if you are in the same SOI as the node
	PARAMETER vecTarget,nodeTime,localBody IS SHIP:BODY.
	LOCAL vecNodePrograde IS VELOCITYAT(SHIP,nodeTime):ORBIT.
	LOCAL vecNodeNormal IS VCRS(vecNodePrograde,POSITIONAT(SHIP,nodeTime) - localBody:POSITION).
	LOCAL vecNodeRadial IS VCRS(vecNodeNormal,vecNodePrograde).

	LOCAL nodePrograde IS VDOT(vecTarget,vecNodePrograde:NORMALIZED).
	LOCAL nodeNormal IS VDOT(vecTarget,vecNodeNormal:NORMALIZED).
	LOCAL nodeRadial IS VDOT(vecTarget,vecNodeRadial:NORMALIZED).
	//PRINT "pro: " + ROUND(nodePrograde,2).
	//PRINT "nor: " + ROUND(nodeNormal,2).
	//PRINT "rad: " + ROUND(nodeRadial,2).
	RETURN NODE(nodeTime,nodeRadial,nodeNormal,nodePrograde).
}

FUNCTION burn_vector {//returns the burn vector to change orbit to new normal vector.
	PARAMETER vecCurentVel,vecNormal.
//	LOCAL vecEast IS VCRS(vecCurentVel,vecNormal).
	LOCAL vecEast IS VCRS(vecNormal,vecCurentVel).
	LOCAL vecTargetVel IS VCRS(vecEast,vecNormal):NORMALIZED * vecCurentVel:MAG.
//	LOCAL vecTargetVel IS VXCL(vecNormal,vecCurentVel):NORMALIZED * vecCurentVel:MAG
	IF VANG(normal_of_orbit(SHIP),vecNormal) > 90 {//inverts vecTargetVel because inclination would be 180 otherwise
		SET vecTargetVel TO -vecTargetVel.
		PRINT "inverting".
	}
	LOCAL vecBurn IS vecTargetVel - vecCurentVel.
//	PRINT "speedAt: " + ROUND(vecCurentVel:MAG,2).
//	PRINT "speedTa: " + ROUND(vecTargetVel:MAG,2).
//	PRINT "angle:   " + ROUND(VANG(vecCurentVel,vecTargetVel),2).
//	vecDrawList:ADD(VECDRAW(SHIP:POSITION,vecCurentVel / 10,GREEN,"curent speed",1,TRUE,0.2)).
//	vecDrawList:ADD(VECDRAW(SHIP:POSITION,vecNormal * 10,WHITE,"normal",1,TRUE,0.2)).
//	vecDrawList:ADD(VECDRAW(SHIP:POSITION,vecTargetVel / 10,RED,"desired speed",1,TRUE,0.2)).
//	vecDrawList:ADD(VECDRAW(vecCurentVel / 10,vecBurn / 10,BLUE,"burnVec",1,TRUE,0.2)).
	RETURN vecBurn.//will be a vector of mag = DV of burn with chordates of burn direction
}

FUNCTION node_step_full { //manipulates the targetNode in one of 4 ways depending on manipType for a value of stepVal
	PARAMETER targetNode,stepDir,stepMag.
	IF stepDir < 0 {
		SET stepMag TO -stepMag.
		SET stepDir TO -stepDir.
	}
	IF stepDir <= 2 {
		IF stepDir <=1 { SET targetNode:ETA TO targetNode:ETA + stepMag * 2.
		} ELSE { SET targetNode:PROGRADE TO targetNode:PROGRADE + stepMag. }
	} ELSE {
		IF stepDir <=3 { SET targetNode:NORMAL TO targetNode:NORMAL + stepMag.
		} ELSE { SET targetNode:RADIALOUT TO targetNode:RADIALOUT + stepMag. }
	}
}

FUNCTION refine_score {
	PARAMETER mNode.
	LOCAL curentClose IS close_aproach_scan(SHIP,TARGET,mNode:ETA + TIME:SECONDS,mNode:ORBIT:PERIOD)["dist"].
	LOCAL score IS ABS(curentClose - 200) + mNode:DELTAV:MAG.
	RETURN LEX("score",score,"dist",curentClose).
}