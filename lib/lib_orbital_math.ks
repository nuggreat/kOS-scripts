@LAZYGLOBAL OFF.

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

FUNCTION alt_to_ta {//returns a list of the true anomalies of the 2 points where the craft's orbit passes the given altitude
	PARAMETER orbitIn,altIn.
	LOCAL sma IS orbitIn:SEMIMAJORAXIS.
	LOCAL ecc IS orbitIn:ECCENTRICITY.
	LOCAL rad IS altIn + orbitIn:BODY:RADIUS.
	LOCAL taOfAlt IS ARCCOS((-sma * ecc ^2 + sma - rad) / (ecc * rad)).
	RETURN LIST(taOfAlt,360-taOfAlt).//first true anomaly will be as orbit goes from PE to AP
}

FUNCTION ta_to_time_from_pe {//converts a true anomaly to a time (seconds) after pe
	PARAMETER orbitIn, taDeg. //orbit to predict for, true anomaly in degrees
	LOCAL ecc IS orbitIn:ECCENTRICITY.
	LOCAL orbPer IS orbitIn:PERIOD.
	
	LOCAL maDeg IS ta_to_ma(ecc,taDeg).

	LOCAL rawTime IS orbPer * (maDeg / 360).

	RETURN MOD(rawTime + orbPer, orbPer).
}

FUNCTION time_betwene_two_ta {//returns the difference in time between 2 different true anomaly, traveling from taDeg1 to taDeg2
	PARAMETER orbitIn,taDeg1,taDeg2.
	LOCAL ecc IS orbitIn:ECCENTRICITY.
	LOCAL orbPer IS orbitIn:PERIOD.
	
	LOCAL maDeg1 IS ta_to_ma(ecc,taDeg1).
	LOCAL maDeg2 IS ta_to_ma(ecc,taDeg2).
	
	LOCAL timeDiff IS orbPer * ((maDeg2 - maDeg1) / 360).
	
	RETURN MOD(timeDiff + orbPer, orbPer).
}

FUNCTION ta_to_ma {//converts a true anomaly(degrees) to the mean anomaly (degrees) NOTE: only works for non hyperbolic orbits
	PARAMETER ecc,taDeg.
	LOCAL eaDeg IS ARCTAN2( SQRT(1-ecc^2)*SIN(taDeg), ecc + COS(taDeg)).
	LOCAL maDeg IS eaDeg - (ecc * SIN(eaDeg) * CONSTANT:RADtoDEG).
	RETURN MOD(maDeg + 360,360).
}

//FUNCTION ea_to_ma { //converts a eccentric anomaly(degrees) to the mean anomaly(degrees)
//	PARAMETER ecc,eaDeg.
//	LOCAL maDeg IS eaDeg - (ecc * SIN(eaDeg) * CONSTANT:RADtoDEG).
//	RETURN maDeg.
//}
//
//FUNCTION ta_to_ea { //converts a true anomaly(degrees) to the eccentric anomaly (degrees) NOTE: only works for non hyperbolic orbits
//	PARAMETER ecc,taDeg.//orbit to predict for, true anomaly in degrees
//	LOCAL eaDeg IS ARCTAN2( SQRT(1-ecc^2)*SIN(taDeg), ecc + COS(taDeg)).
//	RETURN eaDeg.
//}

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
	LOCAL relitiveAnomaly IS VANG(vecBodyToNode,vecBodyToC1).//the angle between the node and craft 1

	IF VDOT(vecBodyToNode,VCRS(vecC1Normal,vecBodyToC1):NORMALIZED) < 0 {//adjusts relative Anomaly for it it is ahead or behind of craft 1
		SET relitiveAnomaly TO 360 - relitiveAnomaly.
	}

	RETURN MOD(relitiveAnomaly + craft1:ORBIT:TRUEANOMALY,360).
}

FUNCTION normal_of_orbit {//returns the normal of a crafts/bodies orbit, will point north if orbiting clockwise on equator
	PARAMETER object.
	RETURN VCRS(object:VELOCITY:ORBIT:NORMALIZED, (object:BODY:POSITION - object:POSITION):NORMALIZED):NORMALIZED.
}

FUNCTION phase_angle {
	PARAMETER object1,object2.//measures the phase of object2 as seen from object 1
	LOCAL localBodyPos IS object1:BODY:POSITION.
	LOCAL vecBodyToC1 IS (object1:POSITION - localBodyPos):NORMALIZED.
	LOCAL vecBodyToC2 IS VXCL(normal_of_orbit(object1),(object2:POSITION - localBodyPos):NORMALIZED):NORMALIZED.//orbit normal is excluded to remove any inclination from calculation
	LOCAL phaseAngle IS VANG(vecBodyToC1,vecBodyToC2).
	IF VDOT(vecBodyToC2,VXCL(UP:VECTOR,object1:VELOCITY:ORBIT)) < 0 {//corrects for if object2 is ahead or behind object1
		SET phaseAngle TO 360 - phaseAngle.
	}
	RETURN phaseAngle.
}

FUNCTION orbital_period {
	PARAMETER sma,localBody.
	RETURN 2 * CONSTANT:PI * SQRT(sma^3 / localBody:MU).
}

FUNCTION close_aproach_scan {//one method to try to find closest approach by checking points of finer and finer resolution 
	PARAMETER object1, object2,//the orbitals to examine for close approach
	startTime,//the start time (UTs) for the scan
	scanTimeRange,//the max seconds after the startTime to check to 
	scanSteps IS 36,//the of points of comparison for each level of resolution
	minTime IS 1.//the smallest that time increment that will be checked
	LOCAL bestAproach IS distance_at(object1,object2,startTime). 
	LOCAL bestAproachTime IS startTime.
	//LOCAL useBasic IS object1:BODY = object2:BODY.
	UNTIL scanTimeRange < minTime {
		LOCAL strFrac IS scanTimeRange / scanSteps.
		LOCAL maxTime IS startTime + scanTimeRange.
		SET startTime TO startTime + strFrac / 2.
		FROM { LOCAL i IS startTime + strFrac. } UNTIL i >= maxTime STEP { SET i TO i + strFrac. } DO {
			LOCAL tmpAproach IS distance_at(object1,object2,i).
			IF tmpAproach < bestAproach {
				SET bestAproach TO tmpAproach.
				SET bestAproachTime TO i.
			}
		}
		SET startTime TO (bestAproachTime - (strFrac / 2)).
		SET scanTimeRange TO strFrac.
		//PRINT bestAproach.
		//WAIT 0.1.
	}
	RETURN LEX("dist",bestAproach,"UTS",bestAproachTime).
}

LOCAL FUNCTION distance_at {
	PARAMETER object1, object2, t.//, useBasic IS object1:BODY = object2:BODY.
	//IF useBasic {
		RETURN (POSITIONAT(object1,t) - POSITIONAT(object2,t)):MAG.
	//} ELSE {
	//	RETURN (solar_relitave_positionAt(object1,t) - solar_relitave_positionAt(object2,t)):MAG.
	//}
}

LOCAL FUNCTION solar_relitave_positionAt {//only works for for non hyperbolic orbits
	PARAMETER orbital,t,firstRun IS TRUE.
	IF firstRun {
		RETURN POSITIONAT(orbital,t) + solar_relitave_positionAt(orbital:BODY,t,FALSE).
	} ELSE {
		IF orbital:HASBODY {
			RETURN (POSITIONAT(orbital,t) - orbital:POSITION) + solar_relitave_positionAt(orbital:BODY,t,FALSE).
		} ELSE {
			RETURN v(0,0,0).
		}
	}
}

FUNCTION ma_at {//calculates the mean anomaly at a given time for the current SHIP
	PARAMETER t.
	LOCAL localTime IS TIME:SECONDS.
	LOCAL obtPer IS SHIP:ORBIT:PERIOD.
	LOCAL obtStart IS (ETA:PERIAPSIS + localTime) - obtPer.
	LOCAL tDiff IS ABS(MOD(t - obtStart,obtPer)).
	RETURN 360 * (tDiff/obtPer).
}