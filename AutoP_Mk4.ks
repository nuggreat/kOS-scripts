{	//-----program set up-----
SAS OFF.
RCS OFF.
GEAR OFF.
BRAKES OFF.
RUN ONCE lib_navball.ks.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:HEIGHT TO 15.
CLEARSCREEN.
PARAMETER dest,	//-----destnation-----
	cruseHeight,	//-----height to cruse at in Km-----
	pMax,		//-----max pitch in deg-----
	rMax,		//-----mac roll  in deg-----
	lSpeed.		//-----landing speed-----
SET pitchMax TO pMax.
SET rollMax TO rMax.
SET goFlight TO TRUE.
SET cruseAltitude TO cruseHeight * 1000.
SET landingSpeed TO lSpeed.

IF dest:ISTYPE("string") AND dest = "KSC" OR dest = "Kerbal Space Center" {
	SET dest TO LATLNG(0,-75 - (cruseHeight / 3)).
	SET landingYN TO TRUE.
	SET endDist TO 5000.
} ELSE {
	SET landingYN TO FALSE.
	SET endDist TO 30000.
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
			IF dest:LAT = 0 AND dest:LNG = (-75 - (cruseHeight / 3)) {
				SET point TO "Kerbal Space Center".
			} ELSE {
				SET point TO dest.
			}
			SET mark TO dest.
		} ELSE {
			PRINT "I don't know how ues a dest type of :" + dest:typename.
			SET goFlight TO FALSE.
		}
	}
}
SET listETA TO LIST(LIST(target_distance(mark),TIME:SECONDS,1)).

{	//-----PID setup-----
	SET throttlePID TO PIDLOOP().
	SET throttlePID:KP TO 0.1.	//0.1
	SET throttlePID:KI TO 0.001.	//0.001
	SET throttlePID:KD TO 0.01.	//0.01
	SET throttlePID:MAXOUTPUT TO 1.
	SET throttlePID:MINOUTPUT TO 0.

	SET pitchTar TO PIDLOOP().
	SET pitchTar:KP TO 0.006.	//0.006
	SET pitchTar:KI TO 0.00002.	//0.00002
	SET pitchTar:KD TO 0.05.		//0.05
	SET pitchTar:MAXOUTPUT TO pitchMax.
	SET pitchTar:MINOUTPUT TO 0 - pitchMax.

	SET vSpeedCon TO PIDLOOP().
	SET vSpeedCon:KP TO 0.75.	//0.75
	SET vSpeedCon:KI TO 0.1.		//0.02
	SET vSpeedCon:KD TO 0.01.	//0.1
	SET vSpeedCon:MAXOUTPUT TO pitchMax.
	SET vSpeedCon:MINOUTPUT TO 0 - pitchMax.

	SET pitchCon TO PIDLOOP().
	SET pitchCon:KP TO 0.04.		//0.05
	SET pitchCon:KI TO 0.005.	//0.005
	SET pitchCon:KD TO 0.009.	//0.01
	SET pitchCon:MAXOUTPUT TO 1.
	SET pitchCon:MINOUTPUT TO -1.

	SET rollTar TO PIDLOOP().
	SET rollTar:KP TO 1.			//1
	SET rollTar:KI TO 0.001.		//0.001
	SET rollTar:KD TO 1.			//1
	SET rollTar:MAXOUTPUT TO rollMax.
	SET rollTar:MINOUTPUT TO 0 - rollMax.

	SET rollCon TO PIDLOOP().
	SET rollCon:KP TO 0.0075.	//0.01
	SET rollCon:KI TO 0.00025.	//0.0005
	SET rollCon:KD TO 0.0025.	//0.005
	SET rollCon:MAXOUTPUT TO 1.
	SET rollCon:MINOUTPUT TO -1.
}}

IF goFlight {	//-----start of core logic-----
LOCAL count IS 0.
LOCAL dist IS target_distance(mark).
LOCAL done IS FALSE.

UNTIL done {	//-----fly to target-----
	LOCAL pitchTo IS pitchTar:UPDATE(TIME:SECONDS,ALTITUDE - cruseAltitude).
	LOCAL rollTo IS rollTar:UPDATE(TIME:SECONDS,0 - mark:BEARING).

	LOCAL shipPitch IS pitch_for(SHIP).
	LOCAL shipRoll IS roll_for(SHIP).

	SET SHIP:CONTROL:ROLL TO roll_to(rollTo,shipRoll).
	SET SHIP:CONTROL:PITCH TO pitch_to(pitchTo,shipRoll,shipPitch).
	IF count >= 20 {
		CLEARSCREEN.
		SET dist TO target_distance(mark).
		LOCAL targetETA IS target_eta(dist).
		PRINT "Mode:         Long Distance Flight".
		PRINT "Destination:  " + point.
		PRINT " ".
		PRINT "Distance:     " + ROUND(dist/1000,1) + "km".
		PRINT "ETA(Min):     " + ROUND(targetETA/60,1).
		PRINT " ".
		PRINT "Alitude:      " + ROUND(ALTITUDE).
		PRINT "Ground Speed: " + ROUND(GROUNDSPEED,1).
		PRINT " ".
		PRINT "Bearing:      " + ROUND(mark:BEARING,3).
		PRINT "Roll:         " + ROUND(shipRoll,3).
		PRINT "Pitch:        " + ROUND(shipPitch,3).
//		PRINT " ".
//		PRINT " rollTo: " + ROUND(rollTo,2).
//		PRINT "rollFor: " + ROUND(shipRoll,2).
//		PRINT "rollDif: " + ROUND(shipRoll - rollTo,2).
//		PRINT "rollCon: " + ROUND(SHIP:CONTROL:ROLL,2).
//		PRINT "      P: " + ROUND(rollCon:PTERM,3).
//		PRINT "      I: " + ROUND(rollCon:ITERM,3).
//		PRINT "      D: " + ROUND(rollCon:DTERM,3).
//
//		PRINT " ".
//		PRINT "pitchDif: " + ROUND(cruseAltitude - ALTITUDE,0).
//		PRINT " pitchTo: " + ROUND(pitchTo,2).
//		PRINT "pitchCon: " + ROUND(SHIP:CONTROL:PITCH,2).
//		PRINT "       P: " + ROUND(pitchCon:PTERM,3).
//		PRINT "       I: " + ROUND(pitchCon:ITERM,3).
//		PRINT "       D: " + ROUND(pitchCon:DTERM,3).
		SET done TO dist < endDist OR RCS.
		SET count TO 1.
	}	ELSE {
	SET count TO count + 1.
	}
	WAIT 0.01.
}

IF landingYN AND NOT RCS {	//-----start of runway landing-----
LOCAL centerlineWest IS LATLNG(-0.0485,-74.7290).	//runway start
LOCAL centerlineEast IS LATLNG(-0.0502,-74.4879).	//runway end
SET point TO "Start of Runway".
LOCAL align IS FALSE.

UNTIL align {	//-----alignging to runway-----
	SET dist TO target_distance(centerlineWest).
	LOCAL vertSpeedTar IS 0 - ((ALTITUDE - 100) / (dist / (GROUNDSPEED * 1.3))).
	LOCAL pitchTo IS vSpeedCon:UPDATE(TIME:SECONDS,VERTICALSPEED - vertSpeedTar).

	LOCAL headingDif IS centerlineEast:heading - centerlineWest:heading .
	LOCAL rollTo IS rollTar:UPDATE(TIME:SECONDS,(headingDif * (dist / 1000)) - centerlineWest:BEARING).

	LOCAL speedTar IS MAX(landingSpeed,((dist - 1000) / 100)).

	LOCAL shipPitch IS pitch_for(SHIP).
	LOCAL shipRoll IS roll_for(SHIP).
	SET SHIP:CONTROL:ROLL TO roll_to(rollTo,shipRoll).
	SET SHIP:CONTROL:PITCH TO pitch_to(pitchTo,shipRoll,shipPitch).
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO throttlePID:UPDATE(TIME:SECONDS,GROUNDSPEED - speedTar).
	IF count >= 20 {
		CLEARSCREEN.
		PRINT "Mode:         Alignging to Runway".
		PRINT "Destination:  " + point.
		PRINT " ".
		PRINT "Distance:     " + ROUND(dist/1000,1) + "km".
		PRINT "Alitude:      " + ROUND(ALTITUDE,1).
		PRINT " ".
		PRINT "Vert Speed:   " + ROUND(VERTICALSPEED,1).
		PRINT "Ground Speed: " + ROUND(GROUNDSPEED,1).
		PRINT " ".
		PRINT "Bearing:      " + ROUND(centerlineWest:BEARING,3).
		PRINT "Roll:         " + ROUND(shipRoll,3).
		PRINT "Pitch:        " + ROUND(shipPitch,3).
		PRINT " ".
//		PRINT " rollTo: " + ROUND(rollTo,2).
//		PRINT "rollFor: " + ROUND(shipRoll,2).
//		PRINT "vSpTar: " + ROUND(vertSpeedTar,2).
//		PRINT "vSpCon: " + ROUND(vSpeedCon:OUTPUT,3).
//		PRINT "      P: " + ROUND(vSpeedCon:PTERM,3).
//		PRINT "      I: " + ROUND(vSpeedCon:ITERM,3).
//		PRINT "      D: " + ROUND(vSpeedCon:DTERM,3).
		SET count TO 1.
	}	ELSE {
	SET count TO count + 1.
	}
	SET align TO dist < 1000.
	WAIT 0.01.
}
LOCAL land IS FALSE.
GEAR ON.

UNTIL land {	//-----landing-----
	LOCAL pitchTo IS vSpeedCon:UPDATE(TIME:SECONDS,VERTICALSPEED + 1).

	LOCAL rollTo IS rollTar:UPDATE(TIME:SECONDS,0 - centerlineEast:BEARING).

	LOCAL shipPitch IS pitch_for(SHIP).
	LOCAL shipRoll IS roll_for(SHIP).

	SET SHIP:CONTROL:ROLL TO roll_to(rollTo,shipRoll).
	SET SHIP:CONTROL:PITCH TO pitch_to(pitchTo,shipRoll,shipPitch).
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO throttlePID:UPDATE(TIME:SECONDS,GROUNDSPEED - landingSpeed).
	IF count >= 20 {
		CLEARSCREEN.
		PRINT "Mode:         Landing".
		PRINT " ".
		PRINT "Alitude:      " + ROUND(ALTITUDE).
		PRINT " ".
		PRINT "Vert Speed:   " + ROUND(VERTICALSPEED,1).
		PRINT "Ground Speed: " + ROUND(GROUNDSPEED,1).
		PRINT " ".
		PRINT "Bearing:      " + ROUND(centerlineEast:BEARING,3).
		PRINT "Roll:         " + ROUND(shipRoll,3).
		PRINT "Pitch:        " + ROUND(shipPitch,3).
		SET count TO 1.
	}	ELSE {
	SET count TO count + 1.
	}
	SET land TO SHIP:STATUS = "LANDED".
	WAIT 0.01.
}
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
BRAKES ON.
LOCAL stopted IS FALSE.

UNTIL stopted {
	LOCAL steerTo IS rollTar:UPDATE(TIME:SECONDS,0 - centerlineEast:BEARING).
	SET SHIP:CONTROL:YAW TO steerTo.
	SET SHIP:CONTROL:WHEELSTEER TO steerTo.
	IF count >= 20 {
		CLEARSCREEN.
		PRINT "Mode:         STOPIPING".
		PRINT " ".
		PRINT "Ground Speed: " + ROUND(GROUNDSPEED,1).
		PRINT " ".
		PRINT "Bearing:      " + ROUND(centerlineEast:BEARING,3).
		SET count TO 1.
	}	ELSE {
	SET count TO count + 1.
	}
	SET stopted TO GROUNDSPEED < 1.
	WAIT 0.01.
}}}
SET SHIP:CONTROL:NEUTRALIZE TO True.
RCS OFF.
SAS ON.
//	north west:  -0.0518,-74.7290
//	soulth west: -0.0452,-74.7290
//	centerline west: -0.0485,-74.7290

//	soulth east: -0.0469,-74.4879
//	notrh east:  -0.0535,-74.4879
//	centerline east: -0.0502,-74.4879

//-----end of core logic start of functions-----
FUNCTION roll_to {	//-----tries to roll craft to givin value-----
	PARAMETER targetRoll,shipRoll.
	LOCAL rollDif IS shipRoll - targetRoll.
	RETURN rollCon:UPDATE(TIME:SECONDS,rollDif).
}

FUNCTION pitch_to {	//-----tries to pitch craft to givin value-----
	PARAMETER targetPitch,shipRoll,shipPitch.
	LOCAL pitchDif IS shipPitch - targetPitch.
	IF shipRoll < 90 OR shipRoll > -90 {
		RETURN pitchCon:UPDATE(TIME:SECONDS,pitchDif).
	}	ELSE {
		RETURN 0 - pitchCon:UPDATE(TIME:SECONDS,pitchDif).
	}
}

FUNCTION target_distance {	//-----calculates distance to target using Law of Cosines-----
	PARAMETER distTar.
	LOCAL bodyRadius IS SHIP:BODY:RADIUS.
	LOCAL aVal IS (distTar:TERRAINHEIGHT + bodyRadius).
	LOCAL bVal IS (ALTITUDE + bodyRadius).
	LOCAL cVal IS (distTar:DISTANCE).
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