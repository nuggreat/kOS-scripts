PARAMETER myLat.
LOCAL vecLex IS LEX().
RCS OFF.

UNTIL RCS {
	LOCAL lngS IS lat_to_lng(myLat,SHIP:ORBIT).
	LOCAL lanLatLng1 IS LATLNG(myLat,lngS[0]).
	LOCAL lanLatLng2 IS LATLNG(myLat,lngS[1]).
	LOCAL lanPos1 IS lanLatLng1:POSITION.
	LOCAL lanPos2 IS lanLatLng2:POSITION.
	VecDrawAdd(vecLex,BODY:POSITION,(lanPos1 - BODY:POSITION):NORMALIZED * SHIP:ORBIT:SEMIMAJORAXIS,RED,"tarLan1",1).
	VecDrawAdd(vecLex,BODY:POSITION,(lanPos2 - BODY:POSITION):NORMALIZED * SHIP:ORBIT:SEMIMAJORAXIS,RED,"tarLan2",1).
	CLEARSCREEN.
	PRINT lanLatLng1.
	PRINT lanLatLng2.
	WAIT 0.
}
CLEARVECDRAWS().

FUNCTION lat_to_lng {//returns the longitude of the closest point(s) on the orbit to the given latitude
	PARAMETER myLat,tgtOrbit.
	LOCAL tarInc IS tgtOrbit:INCLINATION.
	LOCAL tarLan IS tgtOrbit:LAN - tgtOrbit:BODY:ROTATIONANGLE.
	
	IF tarInc < ABS(myLat) {
		IF myLat > 0 {
			SET myLat TO tarInc.
		} ELSE {
			SET myLat TO -tarInc.
		}
	}
	LOCAL baseLng IS ARCSIN(TAN(myLat) / TAN(tarInc)).
	LOCAL lng1 IS baseLng + tarLan.
	LOCAL lng2 IS (tarLan - 180) - baseLng.
	RETURN LIST(lng1,lng2).
}

FUNCTION VecDrawAdd { // Draw the vector or update it.
	PARAMETER vecDrawLex,vecStart,vecTarget,localColour,localLabel,localScale.

	IF vecDrawLex:KEYS:CONTAINS(localLabel) {
		SET vecDrawLex[localLabel]:START to vecStart.
		SET vecDrawLex[localLabel]:VEC to vecTarget.
		SET vecDrawLex[localLabel]:COLOUR to localColour.
		SET vecDrawLex[localLabel]:SCALE to localScale.
	} ELSE {
		vecDrawLex:ADD(localLabel,VECDRAW(vecStart,vecTarget,localColour,localLabel,localScale,TRUE,0.2)).
	}
}