{	//-----program set up-----
SAS OFF.
RCS OFF.
BRAKES OFF.
RUN ONCE lib_navball.ks.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:HEIGHT TO 15.
CLEARSCREEN.
PARAMETER dest, cruseHeight, pMax, rMax.
SET pitchMax TO pMax.
SET rollMax TO rMax.
SET goFlight TO TRUE.
SET cruseAltitude TO cruseHeight * 1000.

IF dest:ISTYPE("string") AND dest = "KSC" OR dest = "ksc" OR dest = "Kerbal Space Center" OR dest = "kerbal space center" {
	SET dest TO LATLNG(0,-75).
	SET landingYN TO TRUE.
} ELSE {
	SET landingYN TO FALSE.
}
IF dest:ISTYPE("string") {SET dest TO WAYPOINT(dest).}
IF dest:ISTYPE("vessel") or dest:ISTYPE("waypoint") {
	SET point TO dest:NAME.
	SET mark TO dest:GEOPOSITION.
} ELSE {
	IF dest:ISTYPE("part") {
		SET point TO dest:NAME.
		SET mark TO BODY:GEOPOSITIONOF(dest:POSITION).
	} ELSE {
		IF dest:ISTYPE("geocoordinates") {
			SET point TO dest.
			SET mark TO dest.
		} ELSE {
			PRINT "I don't know how ues a dest type of :" + dest:typename.
			SET goFlight TO FALSE.
		}
	}
}
SET listETA TO LIST(LIST(target_distance(),TIME:SECONDS,1)).

{	//-----PID setup-----
	SET throttlePID TO PIDLOOP().
	SET throttlePID:KP TO 0.1.
	SET throttlePID:KI TO 0.001.
	SET throttlePID:KD TO 0.01.
	SET throttlePID:MAXOUTPUT TO 1.
	SET throttlePID:MINOUTPUT TO 0.

	SET pitchTar TO PIDLOOP().
	SET pitchTar:KP TO 0.005.
	SET pitchTar:KI TO 0.00002.
	SET pitchTar:KD TO 0.05.
	SET pitchTar:MAXOUTPUT TO pitchMax.
	SET pitchTar:MINOUTPUT TO 0 - pitchMax.

	SET pitchCon TO PIDLOOP().
	SET pitchCon:KP TO 0.05.
	SET pitchCon:KI TO 0.005.
	SET pitchCon:KD TO 0.01.
	SET pitchCon:MAXOUTPUT TO 1.
	SET pitchCon:MINOUTPUT TO -1.

	SET rollTar TO PIDLOOP().
	SET rollTar:KP TO 2.
	SET rollTar:KI TO 0.001.
	SET rollTar:KD TO 2.
	SET rollTar:MAXOUTPUT TO rollMax.
	SET rollTar:MINOUTPUT TO 0 - rollMax.

	SET rollCon TO PIDLOOP().
	SET rollCon:KP TO 0.01.
	SET rollCon:KI TO 0.0005.
	SET rollCon:KD TO 0.005.
	SET rollCon:MAXOUTPUT TO 1.
	SET rollCon:MINOUTPUT TO -1.
}}

IF goFlight {	//-----start of core logic-----
LOCAL done IS FALSE.
LOCAL count IS 0.
LOCAL dist IS target_distance().
UNTIL done{	//-----fly to target-----
	LOCAL pitchTo IS pitchTar:UPDATE(TIME:SECONDS,ALTITUDE - cruseAltitude).
	LOCAL rollTo IS rollTar:UPDATE(TIME:SECONDS,0 - mark:BEARING).
	LOCAL shipPitch IS pitch_for(SHIP).
	LOCAL shipRoll IS roll_for(SHIP).
	roll_to(rollTo,shipRoll).
	pitch_to(pitchTo,shipRoll,shipPitch).
	IF count >= 20 {
		CLEARSCREEN.
		SET dist TO target_distance().
		LOCAL targetETA IS target_eta(dist).
		screen_update(dist,targetETA,rollTo,shipRoll,pitchTo,shipPitch).
		SET done TO dist < 30000 OR RCS.
		SET count TO 1.
	}	ELSE {
	SET count TO count + 1.
	}
	WAIT 0.01.
}}
SET SHIP:CONTROL:NEUTRALIZE to True.
RCS OFF.
SAS ON.

//-----end of core logic start of functions-----
FUNCTION roll_to {	//-----tries to roll craft to givin value-----
	PARAMETER targetRoll,shipRoll.
	LOCAL rollDif IS shipRoll - targetRoll.
	SET SHIP:CONTROL:ROLL TO rollCon:UPDATE(TIME:SECONDS,rollDif).
}

FUNCTION pitch_to {	//-----tries to pitch craft to givin value-----
	PARAMETER targetPitch,shipRoll,shipPitch.
	LOCAL pitchDif IS shipPitch - targetPitch.
	IF shipRoll < 90 OR shipRoll > -90 {
		SET SHIP:CONTROL:PITCH TO pitchCon:UPDATE(TIME:SECONDS,pitchDif).
	}	ELSE {
		SET SHIP:CONTROL:PITCH TO 0 - pitchCon:UPDATE(TIME:SECONDS,pitchDif).
	}
}

FUNCTION screen_update {	//-----updates the terminal-----
	PARAMETER dist,targetETA,rollTo,shipRoll,pitchTo,shipPitch.
    PRINT "Destination: " + point.
    PRINT " ".
    PRINT "Distance:    " + ROUND(dist/1000) + "km".
    PRINT "ETA(Min):    " + ROUND(targetETA/60).
    PRINT " ".
    PRINT "Bearing:     " + ROUND(mark:BEARING,3).
    PRINT "Roll:        " + ROUND(shipRoll,3).
    PRINT "Pitch:       " + ROUND(shipPitch,3).
//	PRINT " ".
//	PRINT " rollTo: " + ROUND(rollTo,2).
//	PRINT "rollFor: " + ROUND(shipRoll,2).
//	PRINT "rollDif: " + ROUND(shipRoll - rollTo,2).
//	PRINT "rollCon: " + ROUND(SHIP:CONTROL:ROLL,2).
//	PRINT "      P: " + ROUND(rollCon:PTERM,3).
//	PRINT "      I: " + ROUND(rollCon:ITERM,3).
//	PRINT "      D: " + ROUND(rollCon:DTERM,3).
//
//	PRINT " ".
//	PRINT "pitchDif: " + ROUND(cruseAltitude - ALTITUDE,0).
//	PRINT " pitchTo: " + ROUND(pitchTo,2).
//	PRINT "pitchCon: " + ROUND(SHIP:CONTROL:PITCH,2).
//	PRINT "       P: " + ROUND(pitchCon:PTERM,3).
//	PRINT "       I: " + ROUND(pitchCon:ITERM,3).
//	PRINT "       D: " + ROUND(pitchCon:DTERM,3).
}

FUNCTION target_distance {	//-----calculates distance to target using Law of Cosines-----
	LOCAL bodyRadius IS SHIP:BODY:RADIUS.
	LOCAL aVal IS (mark:TERRAINHEIGHT + bodyRadius).
	LOCAL bVal IS (ALTITUDE + bodyRadius).
	LOCAL cVal IS (mark:DISTANCE).
	LOCAL cosOfC IS (cVal ^ 2 - (aVal ^ 2 + bVal ^ 2)) / (-2 * aVal *bVal).
	RETURN (ARCCOS(cosOfC) / 360) * (CONSTANT():PI * bodyRadius * 2).
}

FUNCTION target_eta {	//-----calculates ETA to target-----
	PARAMETER dist.
	LOCAL deltaDist IS listETA[0][0] - dist.
	LOCAL deltaTime IS TIME:SECONDS - listETA[0][1].
	LOCAL stepETA IS dist / (deltaDist / deltaTime).
	LOCAL totalETA IS 0.
	listETA:ADD(LIST(dist,TIME:SECONDS,stepETA)).
	IF listETA:LENGTH > 10 {listETA:REMOVE(0).}
	FOR value IN listETA {
		SET totalETA TO totalETA + value[2].
	}
	RETURN totalETA / listETA:LENGTH.
}