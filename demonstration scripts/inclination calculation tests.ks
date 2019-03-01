LOCAL vecLex IS LEX().
RCS OFF.
LOCAL degPastLan IS 0.
LOCAL tarInc IS TARGET:ORBIT:INCLINATION.
LOCAL tarECC IS TARGET:ORBIT:ECCENTRICITY.

UNTIL RCS {
	LOCAL tarLng IS TARGET:ORBIT:LAN - BODY:ROTATIONANGLE.
	//LOCAL tarLat IS SIN(degPastLan) * tarInc.
	LOCAL tarLat IS ARCTAN(SIN(degPastLan) * TAN(tarInc)).
	LOCAL adjDegPast IS ta_to_ma(tarECC,degPastLan).
	LOCAL newLat IS ARCSIN(SIN(degPastLan) * COS(tarInc)).
	LOCAL lanLatLng IS LATLNG(tarLat,tarLng + degPastLan).
	LOCAL lanPos IS lanLatLng:POSITION.
	VecDrawAdd(vecLex,BODY:POSITION,(lanPos - BODY:POSITION):NORMALIZED * BODY:RADIUS * 2,RED,"tarLan",1).
	CLEARSCREEN.
	PRINT lanLatLng.
	//PRINT "? " + ARCSIN(TAN(10)/TAN(-tarInc)).
	PRINT newLat.
	WAIT 0.
	SET degPastLan TO MOD(degPastLan + 0.1,360).
}
CLEARVECDRAWS().

//ARCSIN(TAN(degLat)/TAN(tarInc)) = degPastLan.
//TAN(degLat) / TAN(tarInc) = SIN(degPastLan).
//TAN(degLat) = SIN(degPastLan) * TAN(tarInc).
//degLat = ARCTAN(SIN(degPastLan) * TAN(tarInc)).

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