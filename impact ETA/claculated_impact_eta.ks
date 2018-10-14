CLEARSCREEN.
LOCAL oldTime IS TIME:SECONDS.
RCS OFF.
UNTIL RCS {
	LOCAL localTime IS TIME:SECONDS.
	IF periapsis > 0 {
		WAIT 0.
		CLEARSCREEN.
		PRINT "no impact detected.".
	} ELSE {
		LOCAL impactData IS impact_UTs().
		LOCAL tempTime IS TIME:SECONDS.
		LOCAL impactLatLng IS ground_track(POSITIONAT(SHIP,impactData["time"]),impactData["time"]).
		WAIT 0.
		CLEARSCREEN.
		PRINT "impact ETA: " + ROUND(impactData["time"] - TIME:SECONDS,1) + "s".
		PRINT "impactHeight: " + ROUND(impactData["impactHeight"],2).
		PRINT "converged: " + impactData["converged"].
		PRINT "impact  at: latlng(" + ROUND(impactLatLng:LAT,2) + "," + ROUND(impactLatLng:LNG,2) + ")".
		PRINT "calculation time: " + ROUND(tempTime - localTime,2) + "s".
	}
	SET oldTime TO localTime.
}

FUNCTION impact_UTs {//returns the UTs of the ship's impact, NOTE: only works for non hyperbolic orbits
	PARAMETER minError IS 1.
	IF NOT (DEFINED impact_UTs_impactHeight) { GLOBAL impact_UTs_impactHeight IS 0. }
	LOCAL startTime IS TIME:SECONDS.
	LOCAL craftOrbit IS SHIP:ORBIT.
	LOCAL sma IS craftOrbit:SEMIMAJORAXIS.
	LOCAL ecc IS craftOrbit:ECCENTRICITY.
	LOCAL craftTA IS craftOrbit:TRUEANOMALY.
	LOCAL orbitPeriod IS craftOrbit:PERIOD.
	LOCAL impactUTs IS time_betwene_two_ta(ecc,orbitPeriod,craftTA,alt_to_ta(sma,ecc,SHIP:BODY,impact_UTs_impactHeight)[1]) + startTime.
	LOCAL newImpactHeight IS ground_track(POSITIONAT(SHIP,impactUTs),impactUTs):TERRAINHEIGHT.
	SET impact_UTs_impactHeight TO (impact_UTs_impactHeight + newImpactHeight) / 2.
	RETURN LEX("time",impactUTs,//the UTs of the ship's impact
	"impactHeight",impact_UTs_impactHeight,//the aprox altitude of the ship's impact
	"converged",((ABS(impact_UTs_impactHeight - newImpactHeight) * 2) < minError)).//will be true when the change in impactHeight between runs is less than the minError
}

FUNCTION alt_to_ta {//returns a list of the true anomalies of the 2 points where the craft's orbit passes the given altitude
	PARAMETER sma,ecc,bodyIn,altIn.
	LOCAL rad IS altIn + bodyIn:RADIUS.
	LOCAL taOfAlt IS ARCCOS((-sma * ecc^2 + sma - rad) / (ecc * rad)).
	RETURN LIST(taOfAlt,360-taOfAlt).//first true anomaly will be as orbit goes from PE to AP
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
	LOCAL eaDeg IS ARCTAN2(SQRT(1-ecc^2) * SIN(taDeg), ecc + COS(taDeg)).
	LOCAL maDeg IS eaDeg - (ecc * SIN(eaDeg) * CONSTANT:RADtoDEG).
	RETURN MOD(maDeg + 360,360).
}

FUNCTION ground_track {	//returns the geocoordinates of the position vector at a given time(UTs) adjusting for planetary rotation over time
	PARAMETER pos,posTime,localBody IS SHIP:BODY.
	LOCAL rotationalDir IS VDOT(localBody:NORTH:FOREVECTOR,localBody:ANGULARVEL). //the number of radians the body will rotate in one second
	LOCAL posLATLNG IS localBody:GEOPOSITIONOF(pos).
	LOCAL timeDif IS posTime - TIME:SECONDS.
	LOCAL longitudeShift IS rotationalDir * timeDif * CONSTANT:RADtoDEG.
	LOCAL newLNG IS MOD(posLATLNG:LNG + longitudeShift ,360).
	IF newLNG < - 180 { SET newLNG TO newLNG + 360. }
	IF newLNG > 180 { SET newLNG TO newLNG - 360. }
	RETURN LATLNG(posLATLNG:LAT,newLNG).
}