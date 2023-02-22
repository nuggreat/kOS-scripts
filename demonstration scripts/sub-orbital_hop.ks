PARAMETER targetObject.
FOR lib IN LIST("lib_rocket_utilities","lib_geochordnate") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNPATH("1:/lib/" + lib + ".ks"). }}

LOCAL targetGeopos IS mis_types_to_geochordnate(targetObject).

LOCAL initalHopData IS inital_hop_calculation(targetGeopos).

//initial calculations
//check range based on estimated flight path (adjust target position based on flight time)
//refine launch data
//launch based on refined data

LOCAL rangeData IS get_range_data().

LOCAL hopData IS refine_hop(targetGeopos,initalHopData,rangeData).


FUNCTION inital_hop_calculation {
	PARAMETER targetGeopos.
	LOCAL pastHopDuration IS 0.
	LOCAL hopRadius IS BODY:RADIUS + (SHIP:ALTITUDE + targetGeopos:TERRAINHEIGHT) / 2.
	LOCAL bodyMu IS BODY:MU.
	UNTIL FALSE {
		LOCAL adjustedTar IS ground_track(targetGeopos:POSITION,TIME:SECONDS + pastHopDuration).
		LOCAL degAroundBody IS VANG(adjustedTar:POSITION - BODY:POSITION,SHIP:POSITION - BODY:POSITION).
		
		LOCAL velocityAngle IS 45 - degAroundBody / 4.
		LOCAL sma IS hopRadius * (1 + SIN(degAroundBody / 2)) / 2.
		LOCAL launchSpeed IS SQRT((bodyMu * (2 * sma - hopRadius)) / (sma * hopRadius)).
		LOCAL obtElements IS obt_elements(bodyMu, hopRadius, launchSpeed, velocityAngle).
		LOCAL hopDuration IS time_betwene_two_ta(obtElements["ecc"],obtElements["period"],180 - degAroundBody, 180 + degAroundBody).
		
		IF  ABS(hopDuration - pastHopDuration) < 0.01 {
			RETURN LEX("initalAngle",velocityAngle,"duration",hopDuration,"obtElements",obtElements).
		}
		SET pastHopDuration TO hopDuration.
	}
}

FUNCTION refine_hop {
	PARAMETER targetGeopos, hopData, rangeData.
	//determine TA of start and end points.
	//compute time again
	//check that angle is correct for angle to target
	
}

FUNCTION obt_elements {
	PARAMETER bodyMu,// is BODY:MU
	rad,//distance from center of body to vessel position
	vel,//magnitude of velocity vector
	lPitch.//pitch from the horizon of the velocity vector
	LOCAL velSqr IS vel^2.
	LOCAL ecc IS SQRT((rad * velSqr / bodyMu - 1)^2 * COS(lPitch)^2 + SIN(lPitch)^2).
	LOCAL sma IS 1/(2 / rad - velSqr / bodyMu).
	LOCAL obtPeriod IS 2 * CONSTANT:PI() * SQRT(sma^3 / bodyMu)
	RETURN LEX("ecc",ecc,"sma",sma,"period",obtPeriod).
}

FUNCTION time_betwene_two_ta {//returns the difference in time between 2 true anomalies, traveling from taDeg1 to taDeg2
	PARAMETER ecc,periodIn,taDeg1,taDeg2.
	
	LOCAL maDeg1 IS ta_to_ma(ecc,taDeg1).
	LOCAL maDeg2 IS ta_to_ma(ecc,taDeg2).
	
	LOCAL timeDiff IS periodIn * ((maDeg2 - maDeg1) / 360).
	
	RETURN MOD(timeDiff + periodIn, periodIn).
}

FUNCTION ta_to_ma {//converts a true anomaly(degrees) to the mean anomaly (degrees) NOTE: only works for non hyperbolic orbits
	PARAMETER ecc,taDeg.
	LOCAL eaDeg IS ARCTAN2( SQRT(1-ecc^2)*SIN(taDeg), ecc + COS(taDeg)).
	LOCAL maDeg IS eaDeg - (ecc * SIN(eaDeg) * CONSTANT:RADtoDEG()).
	RETURN MOD(maDeg + 360,360).
}