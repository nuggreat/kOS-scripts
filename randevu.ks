//COPYPATH("0:/lib/lib_formating.ks","1:/lib/").
COPYPATH("0:/lib/lib_orbital_math.ks","1:/lib/").
PARAMETER asap IS FALSE.
FOR lib IN LIST("lib_orbital_math","lib_rocket_utilities","lib_formating") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
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
	}
	WAIT 0.1.
}
clear_all_nodes().

LOCAL nodesUTs IS UTs_of_nodes(SHIP,TARGET).
LOCAL highNode IS "an".
IF asap {
	IF nodesUTs["an"] > nodesUTs["dn"] {
		SEt highNode TO "dn".
	}
} ELSE {
	IF SHIP:BODY:ALTITUDEOF(POSITIONAT(SHIP,nodesUTs["an"])) < SHIP:BODY:ALTITUDEOF(POSITIONAT(SHIP,nodesUTs["dn"])) {
		SEt highNode TO "dn".
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
//PRINT "AN UTs:  " + formated_time(nodesUTs["an"]).
//PRINT "AD UTs:  " + formated_time(nodesUTs["dn"]).
//PRINT "AN time: " + formated_time(nodesUTs["an"] - TIME:SECONDS).
//PRINT "DN time: " + formated_time(nodesUTs["dn"] - TIME:SECONDS).

LOCAL baseNode IS node_from_vector(vecBurn,nodesUTs[highNode]).
ADD baseNode.
RUNPATH("1:/node_burn",TRUE).
clear_all_nodes().
WAIT 1.

LOCAL smaOfTransfer IS (SHIP:ORBIT:SEMIMAJORAXIS + TARGET:ORBIT:SEMIMAJORAXIS) / 2.
LOCAL targetPeriod IS TARGET:ORBIT:PERIOD.
LOCAL shipPeriod IS SHIP:ORBIT:PERIOD.
LOCAL localTime IS TIME:SECONDS.
LOCAL angleToTarget IS phase_angle(SHIP,TARGET).
LOCAL periodOfTransfer IS orbital_period(smaOfTransfer,SHIP:BODY).
LOCAL angleForTransfer IS MOD(360 * (targetPeriod / (periodOfTransfer / 2)),360).//the angle between ship and target for at the start of the transfer
LOCAL phaseChange IS ABS(360 / shipPeriod - 360 / targetPeriod).//the change in angle between ship and target per second
LOCAL UTsOfTransfer IS (MOD(angleForTransfer - angleToTarget + 360,360) / phaseChange) + localTime.
LOCAL speedAtBurn IS orbital_speed_at_altitude_from_sma(SHIP:BODY:ALTITUDEOF(POSITIONAT(SHIP,UTsOfTransfer)),smaOfTransfer).
LOCAL transferDv IS speedAtBurn - VELOCITYAT(SHIP,UTsOfTransfer):ORBIT:MAG.
//PRINT "angleToTarget:    " + angleToTarget.
//PRINT "period of ship:   " + shipPeriod.
//PRINT "period of target: " + targetPeriod.
//PRINT "periodOfTransfer: " + periodOfTransfer.
//PRINT "angleForTransfer: " + angleForTransfer.
//PRINT "phaseChange:      " + phaseChange.
//PRINT "UTsOfTransfer:    " + UTsOfTransfer.
//PRINT "etaOfTransfer:    " + ((UTsOfTransfer - localTime)/60).
ADD NODE(UTsOfTransfer,0,0,transferDv).

//WAIT UNTIL RCS.
CLEARVECDRAWS().

FUNCTION node_from_vector {//only works if you are in the same SOI as the node
	PARAMETER vecTarget,nodeTime,localBody IS SHIP:BODY.
	LOCAL vecNodePrograde IS VELOCITYAT(SHIP,nodeTime):ORBIT.
	LOCAL vecNodeNormal IS VCRS(vecNodePrograde,POSITIONAT(SHIP,nodeTime) - localBody:POSITION).
//	IF SHIP:BODY <> localBody {//untested might not work for nodes outside of SOI
//		SET vecNodeNormal IS VCRS(vecNodePrograde,POSITIONAT(SHIP,nodeTime) - POSITIONAT(localBody,nodeTime):NORMALIZED).
//	}
	LOCAL vecNodeRadial IS VCRS(vecNodePrograde,vecNodeNormal).
	
	LOCAL nodePrograde IS VDOT(vecTarget,vecNodePrograde:NORMALIZED).
	LOCAL nodeNormal IS VDOT(vecTarget,vecNodeNormal:NORMALIZED).
	LOCAL nodeRadial IS VDOT(vecTarget,vecNodeRadial:NORMALIZED).
//	PRINT "pro: " + ROUND(nodePrograde,2).
//	PRINT "nor: " + ROUND(nodeNormal,2).
//	PRINT "rad: " + ROUND(nodeRadial,2).
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