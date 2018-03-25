@LAZYGLOBAL OFF.
//COPYPATH("0:/randevu.ks","1:/").
//RUN randevu.

FUNCTION orbital_speed_at_altitude_from_ap_pe {
	PARAMETER altitudeIn IS SHIP:ALTITUDE, APin IS SHIP:ORBIT:APOAPSIS, PEin IS SHIP:ORBIT:PERIAPSIS, localBody IS SHIP:BODY.
	LOCAL sma IS (APin + PEin) / 2 + localBody:RADIUS.
	RETURN orbital_speed_at_altitude_from_sma(altitudeIn,sma,localBody).
}

FUNCTION orbital_speed_at_altitude_from_sma {
	PARAMETER altitudeIn IS SHIP:ALTITUDE, sma IS SHIP:ORBIT:SEMIMAJORAXIS, localBody IS SHIP:BODY.
	LOCAL shipRadius IS altitudeIn + localBody:RADIUS.
	RETURN SQRT((localBody:MU * (2 * SMA - shipRadius)) / (SMA * shipRadius)).
}

FUNCTION uts_of_nodes {//will return the UTs of the ascending and descending nodes
	PARAMETER craft1,craft2.//craft1 should be a craft in orbit, craft2 can be a craft or body
	WAIT 0.//capturing all needed elements in the same physics frame
	LOCAL c1Period IS craft1:ORBIT:PERIOD.
	LOCAL tAnomaly IS craft1:ORBIT:TRUEANOMALY.
	LOCAL localTime IS TIME:SECONDS.
	LOCAL taOfNode IS ta_of_node(craft1,craft2).
	LOCAL timeFromPe IS ta_to_time_from_pe(craft1:ORBIT,tAnomaly).
	
	LOCAL etaToNode1 IS MOD(ta_to_time_from_pe(craft1:ORBIT,taOfNode) - timeFromPe + c1Period,c1Period).
	LOCAL etaToNode2 IS MOD(ta_to_time_from_pe(craft1:ORBIT,taOfNode + 180) - timeFromPe + c1Period,c1Period).
	LOCAL UTsOFnode1 IS etaToNode1 + localTime.
	LOCAL UTsOFnode2 IS etaToNode2 + localTime.
	
	LOCAL refVec IS normal_of_orbit(craft2).//vector to check if craft1 is going up or down against
	IF craft2:ISTYPE("BODY") { IF craft1:BODY = craft2 { SET refVec TO -craft2:NORTH. } }//use south vector if in orbit around craft2
	
	IF VDOT(VELOCITYAT(craft1,UTsOfNode1):ORBIT,refVec) < 0 {//checks if node1 is the ascending node
		RETURN LEX("an",UTsOfNode1,"dn",UTsOFnode2).
	} ELSE {
		RETURN LEX("an",UTsOfNode2,"dn",UTsOFnode1).
	}
}

FUNCTION ta_to_time_from_pe {//converts a true anomaly to a time after pe (seconds)
	PARAMETER orbitIn, taDeg. //orbit to predict for, true anomaly in degrees
	
	LOCAL ecc is orbitIn:ECCENTRICITY.
	LOCAL eccentricAnomalyDeg is ARCTAN2( SQRT(1-ecc^2)*SIN(taDeg), ecc + COS(taDeg) ).
	LOCAL eccentricAnomalyRad is eccentricAnomalyDeg * CONSTANT:DEGtoRAD.
	LOCAL meanAnomalyRad is eccentricAnomalyRad - ecc*SIN(eccentricAnomalyDeg).

	RETURN meanAnomalyRad / SQRT( orbitIn:BODY:MU / orbitIn:SEMIMAJORAXIS^3 ).
}

FUNCTION ta_of_node {//returns the true anomaly of a node for craft1 relative to the orbit of craft2 or equator of craft2 if craft1 is in orbit of craft2
	PARAMETER craft1,craft2.
	LOCAL vecC1Normal IS normal_of_orbit(craft1).//normal of craft 1 orbit 
	LOCAL vecC2Normal IS normal_of_orbit(craft2).//normal of craft 2 orbit
	IF craft2:ISTYPE("BODY") {//check to see if craft1 is in orbit of craft2
		IF craft1:BODY = craft2 {
			SET vecC2Normal TO -craft2:NORTH.
		}
	}
	
	LOCAL vecBodyToNode IS VCRS(vecC1Normal,vecC2Normal).//vector from body to node
	LOCAL vecBodyToC1 IS craft1:POSITION - craft1:BODY:POSITION.//vector from body to craft 1
//	vecDrawList:ADD(VECDRAW(craft1:BODY:POSITION,vecBodyToNode:NORMALIZED * (craft1:POSITION - craft1:BODY:POSITION):MAG,WHITE,"node",1,TRUE,0.2)).
	LOCAL relitiveAnomaly IS VANG(vecBodyToNode,vecBodyToC1).//the angle between the node and craft 1
//	vecDrawList:ADD(VECDRAW(craft1:BODY:POSITION,VCRS(vecBodyToC1,vecC1Normal):NORMALIZED * (craft1:POSITION - craft1:BODY:POSITION):MAG,WHITE,"checkVec",1,TRUE,0.2)).
	
	IF VDOT(vecBodyToNode,VCRS(vecC1Normal,vecBodyToC1):NORMALIZED) < 0 {//adjusts relative Anomaly for it it is ahead or behind of craft 1
		SET relitiveAnomaly TO 360 - relitiveAnomaly.
	}
	
	RETURN MOD(relitiveAnomaly + craft1:ORBIT:TRUEANOMALY,360).
}

FUNCTION normal_of_orbit {//returns the normal of a crafts orbit, will point north if orbiting clockwise on equator
	PARAMETER craft.
	RETURN VCRS(craft:VELOCITY:ORBIT, craft:BODY:POSITION - craft:POSITION):NORMALIZED.
}

FUNCTION phase_angle {
	PARAMETER object1,object2.
	LOCAL localBody IS object1:BODY.
	LOCAL vecBodyToC1 IS object1:POSITION - localBody:POSITION.
	LOCAL vecBodyToC2 IS object2:POSITION - localBody:POSITION.
	LOCAL phaseAngle IS VANG(vecBodyToC1,vecBodyToC2).
	IF VDOT(vecBodyToC2,VCRS(vecBodyToC1,VCRS(object1:VELOCITY:ORBIT, -vecBodyToC1)):NORMALIZED) > 0 {//corrects for if object2 is ahead or behind object1
		SET phaseAngle TO 360 - phaseAngle.
	}
	RETURN phaseAngle.
}


FUNCTION orbital_period {
	PARAMETER sma,localBody.
	RETURN 2 * CONSTANT:PI * SQRT(sma^3 / localBody:MU).
}