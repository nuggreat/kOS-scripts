CLEARSCREEN.
LOCAL oldTime IS TIME:SECONDS.
UNTIL FALSE {
	LOCAL localTime IS TIME:SECONDS.
	IF periapsis > 0 {
		CLEARSCREEN.
		PRINT "no impact detected.".
	} ELSE {
		PRINT       "impact ETA: " + ROUND(impact_ETA,1) + "s  " AT(6,0).
		PRINT "calculation time: " + ROUND(localTime - oldTime,2) + "s  " AT(0,1).
	}
	SET oldTime TO localTime.
	WAIT 0.
}

FUNCTION impact_ETA {//NOTE: only works for non hyperbolic orbits
	PARAMETER craft IS SHIP.
	LOCAL craftOrbit IS craft:ORBIT.
	LOCAL sma IS craftOrbit:SEMIMAJORAXIS.
	LOCAL ecc IS craftOrbit:ECCENTRICITY.
	LOCAL localBody IS craft:BODY.
	LOCAL orbitPeriod IS craftOrbit:PERIOD.
	LOCAL craftTime IS ta_to_time_from_pe(sma,ecc,localBody,orbitPeriod,alt_to_ta(sma,ecc,localBody,SHIP:ALTITUDE)[1]).
	LOCAL impactTime IS ta_to_time_from_pe(sma,ecc,localBody,orbitPeriod,alt_to_ta(sma,ecc,localBody,0)[1]).
	RETURN impactTime - craftTime.
}

FUNCTION alt_to_ta {//returns a list of the true anomalies of the 2 points where the craft's orbit passes the given altitude
	PARAMETER sma,ecc,bodyIn,altIn.
	LOCAL rad IS altIn + bodyIn:RADIUS.
	LOCAL taOfAlt IS ARCCOS((-sma * ecc ^2 + sma - rad) / (ecc * rad)).
	RETURN LIST(taOfAlt,360-taOfAlt).//first true anomaly will be as orbit goes from PE to AP
}

FUNCTION ta_to_time_from_pe {//converts a true anomaly to a time (seconds) after pe
	PARAMETER sma,ecc,bodyIn,periodIn,taDeg.

	LOCAL eccentricAnomalyDeg IS ta_to_ea(ecc,taDeg).
	LOCAL eccentricAnomalyRad IS eccentricAnomalyDeg * CONSTANT:DEGtoRAD.
	LOCAL meanAnomalyRad IS eccentricAnomalyRad - ecc * SIN(eccentricAnomalyDeg).

	LOCAL rawTime IS meanAnomalyRad / SQRT( bodyIn:MU / sma^3 ).

	RETURN MOD(rawTime + periodIn, periodIn).
}

FUNCTION ta_to_ea { //converts a true anomaly to the eccentric anomaly (degrees)
	PARAMETER ecc, taDeg.//Eccentricity, true anomaly in degrees
	LOCAL eccentricAnomalyDeg IS ARCTAN2( SQRT(1-ecc^2)*SIN(taDeg), ecc + COS(taDeg)).
	RETURN eccentricAnomalyDeg.
}