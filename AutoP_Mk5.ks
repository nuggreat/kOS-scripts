//-----program set up-----
PARAMETER dest,	//-----destinations as a waypoint, geocoordinate, vessel, part, or "ksc" -----
	cruseHeight,	//-----height to cruse at in Km-----
	pitchMax,	//-----max pitch in deg-----
	rollMax,		//-----mac roll  in deg-----
	cruseSpeed,	//-----cruse speed in m/s-----
	landingSpeed.//-----landing speed in m/s-----
FOR lib IN LIST("lib_navball","lib_navball2","lib_geochordnate","lib_formating") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNPATH("1:/lib/" + lib + ".ks"). }}
SET TERMINAL:WIDTH TO 60.
SET TERMINAL:HEIGHT TO 15.
CLEARSCREEN.
SAS OFF.
RCS OFF.
GEAR OFF.
BRAKES OFF.
//SET pitchMax TO pMax.
//SET rollMax TO rMax.
LOCAL cruseAltitude TO cruseHeight * 1000.
//SET cruseSpeed TO cSpeed.
//SET landingSpeed TO lSpeed.
LOCAL latOffset IS (cruseHeight / 3) + (cruseSpeed / 400).


LOCAL goFlight IS TRUE.
LOCAL doLanding IS FALSE.
LOCAL endDist IS 3000.
LOCAL mark IS LATLNG(0,-74.5 + latOffset).
LOCAL point IS dest.

IF dest:ISTYPE("string") AND dest = "KSC" OR dest = "Kerbal Space Center" {
	SET point TO "Kerbal Space Center".
	SET doLanding TO TRUE.
	SET endDist TO 5000.
} ELSE {
	LOCAL destData IS mis_types_to_geochordnate(dest).
	SET mark TO destData["chord"].
	SET point TO destData["name"].
}

//PID setup PIDLOOP(kP,kI,kD,min,max)
SET throttle_PID TO PIDLOOP(0.1,0.001,1,0,1).
SET rollTar_PID TO PIDLOOP(3,0.01,0.5,0 - rollMax,rollMax). //was (3,0.01,0.5)
SET rollCon_PID TO PIDLOOP(0.025,0.00125,0.0125,-1,1). //was (0.025,0.00125,0.0125)
SET pitchTar_PID TO PIDLOOP(0.003,0.00002,0.05,0 - pitchMax,pitchMax).
SET vSpeedCon_PID TO PIDLOOP(0.75,0.1,0.01,0 - (pitchMax * 2),pitchMax).
SET pitchCon_PID TO PIDLOOP(0.025,0.00125,0.0125,-1,1).
SET yawCon_PID TO PIDLOOP(0.025,0,0.0125,-0.25,0.25).

IF goFlight {	//-----start of core logic-----
LOCAL count IS 0.
LOCAL dist IS target_distance(mark).
average_eta(dist,20,TRUE).
SET pitchTar_PID:SETPOINT TO cruseAltitude.
SET throttle_PID:SETPOINT TO cruseSpeed.
LOCAL done IS FALSE.

UNTIL done {	//-----fly to target-----
	WAIT 0.01.
	LOCAL tarBearing IS mark:BEARING.

	LOCAL pitchTo IS pitchTar_PID:UPDATE(TIME:SECONDS,ALTITUDE).
	LOCAL rollTo IS rollTar_PID:UPDATE(TIME:SECONDS,0 - tarBearing).

	LOCAL shipPitch IS pitch_for(SHIP).
	LOCAL shipRoll IS roll_for(SHIP).

	SET SHIP:CONTROL:ROLL TO roll_to(rollTo,shipRoll).
	SET SHIP:CONTROL:PITCH TO pitch_to(pitchTo,shipRoll,shipPitch).
	SET SHIP:CONTROL:YAW TO yaw_to().
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO throttle_PID:UPDATE(TIME:SECONDS,SHIP:AIRSPEED).
	IF count >= 20 {
		CLEARSCREEN.
		SET dist TO target_distance(mark).
		LOCAL targetETA IS average_eta(dist).
		PRINT "Mode:        Long Distance Flight".
		PRINT "Destination: " + point.
		PRINT " ".
		PRINT "Distance:    " + si_formating(dist,"m").
		PRINT "ETA:         " + time_formating(targetETA,0,0).
		PRINT " ".
		PRINT "Altitude:    " + si_formating(ALTITUDE,"m").
		PRINT "Air Speed:   " + si_formating(SHIP:AIRSPEED,"m/s").
		PRINT " ".
		PRINT "Bearing:     " + padding(tarBearing,2,3).
		PRINT "Roll:        " + padding(shipRoll,2,3).
		PRINT "Pitch:       " + padding(shipPitch,2,3).
		PRINT " ".
//		PRINT " rollTo: " + ROUND(rollTo,2).
//		PRINT "rollFor: " + ROUND(shipRoll,2).
//		PRINT "yawDif: " + ROUND(yawCon_PID:INPUT,3).
//		PRINT " yawCon_PID: " + ROUND(SHIP:CONTROL:YAW,3).
//		PRINT "      P: " + ROUND(yawCon_PID:PTERM,3).
//		PRINT "      I: " + ROUND(yawCon_PID:ITERM,3).
//		PRINT "      D: " + ROUND(yawCon_PID:DTERM,3).
//		PRINT " ".
//		PRINT "pitchDif: " + ROUND(cruseAltitude - ALTITUDE,0).
//		PRINT " pitchTo: " + ROUND(pitchTo,2).
//		PRINT "pitchCon_PID: " + ROUND(SHIP:CONTROL:PITCH,2).
//		PRINT "       P: " + ROUND(pitchCon_PID:PTERM,3).
//		PRINT "       I: " + ROUND(pitchCon_PID:ITERM,3).
//		PRINT "       D: " + ROUND(pitchCon_PID:DTERM,3).
		SET done TO dist < endDist OR RCS.
		SET count TO 1.
		drop_tanks().
	}	ELSE {
		SET count TO count + 1.
	}
}

IF doLanding AND NOT RCS {	//-----start of runway landing-----
LOCAL centerlineWest IS LATLNG(-0.0485,-74.7290).	//runway start for take off
LOCAL centerLineCenter IS LATLNG(-0.0495,74.6085).
LOCAL centerlineEast IS LATLNG(-0.0502,-74.4879).	//runway end for take off
LOCAL runwayStart IS centerlineEast.
LOCAL runwayEnd IS centerlineWest.
LOCAL point IS "Start of Runway".
LOCAL isAligned IS FALSE.

UNTIL isAligned {	//-----aligning to runway-----
	WAIT 0.01.
	SET dist TO target_distance(runwayStart).
	LOCAL vertSpeedTar IS 0 - ((ALTITUDE - 100) / ((dist - 100) / (GROUNDSPEED * 1.25))).
	SET vSpeedCon_PID:SETPOINT TO vertSpeedTar.

	LOCAL tarBearing IS runwayStart:BEARING.

	LOCAL pitchTo IS vSpeedCon_PID:UPDATE(TIME:SECONDS,VERTICALSPEED).

	LOCAL headingError IS runwayEnd:HEADING - runwayStart:HEADING.
	LOCAL rollTo IS rollTar_PID:UPDATE(TIME:SECONDS,MAX(MIN(headingError * (dist / 1000),90),-90) - tarBearing).

	LOCAL speedTar IS MIN(MAX(landingSpeed,(dist - 100) / 100),landingSpeed * 2).
	SET throttle_PID:SETPOINT TO speedTar.

	LOCAL shipPitch IS pitch_for(SHIP).
	LOCAL shipRoll IS roll_for(SHIP).

	SET SHIP:CONTROL:ROLL TO roll_to(rollTo,shipRoll).
	SET SHIP:CONTROL:PITCH TO pitch_to(pitchTo,shipRoll,shipPitch).
	SET SHIP:CONTROL:YAW TO yaw_to().
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO throttle_PID:UPDATE(TIME:SECONDS,SHIP:AIRSPEED).
	IF count >= 20 {
		CLEARSCREEN.
		PRINT "Mode:        Alignging to Runway".
		PRINT "Destination: " + point.
		PRINT " ".
		PRINT "Distance:    " + si_formating(dist,"m").
		PRINT "Altitude:    " + si_formating(ALTITUDE,"m").
		PRINT " ".
		PRINT "Vert Speed:  " + si_formating(VERTICALSPEED,"m/s").
		PRINT "Air Speed:   " + si_formating(SHIP:AIRSPEED,"m/s").
		PRINT " ".
		PRINT "Bearing:     " + padding(tarBearing,2,3).
//		PRINT "Roll Tar:    " + ROUND(rollTo,3).
		PRINT "Roll:        " + padding(shipRoll,2,3).
//		PRINT "Pitch Tar:   " + ROUND(pitchTo,3).
		PRINT "Pitch:       " + padding(shipPitch,2,3).
		SET count TO 1.
	}	ELSE {
		SET count TO count + 1.
	}
	SET isAligned TO dist < 100.
}
SET vSpeedCon_PID:SETPOINT TO -1.
SET throttle_PID:SETPOINT TO landingSpeed.
LOCAL land IS FALSE.
GEAR ON.

UNTIL land {	//-----landing-----
	WAIT 0.01.
	LOCAL tarBearing IS runwayEnd:BEARING.

	LOCAL pitchTo IS vSpeedCon_PID:UPDATE(TIME:SECONDS,VERTICALSPEED).

	LOCAL rollTo IS rollTar_PID:UPDATE(TIME:SECONDS,0 - tarBearing).

	LOCAL shipPitch IS pitch_for(SHIP).
	LOCAL shipRoll IS roll_for(SHIP).

	SET SHIP:CONTROL:ROLL TO roll_to(rollTo,shipRoll).
	SET SHIP:CONTROL:PITCH TO pitch_to(pitchTo,shipRoll,shipPitch).
	SET SHIP:CONTROL:YAW TO yaw_to().
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO throttle_PID:UPDATE(TIME:SECONDS,SHIP:AIRSPEED).
	IF count >= 20 {
		CLEARSCREEN.
		PRINT "Mode:        Landing".
		PRINT " ".
		PRINT "Altitude:    " + si_formating(ALTITUDE,"m").
		PRINT " ".
		PRINT "Vert Speed:  " + si_formating(VERTICALSPEED,"m/s").
		PRINT "Air Speed:   " + si_formating(SHIP:AIRSPEED,"m/s").
		PRINT " ".
		PRINT "Bearing:     " + padding(tarBearing,2,3).
		PRINT "Roll:        " + padding(shipRoll,2,3).
		PRINT "Pitch:       " + padding(shipPitch,2,3).
		SET count TO 1.
	}	ELSE {
		SET count TO count + 1.
	}
	SET land TO SHIP:STATUS = "LANDED".
}
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
BRAKES ON.
LOCAL stopped IS FALSE.

UNTIL stopped {	//-----coming to a stop-----
	WAIT 0.01.
	LOCAL steerTo IS rollTar_PID:UPDATE(TIME:SECONDS,runwayEnd:BEARING).

	SET SHIP:CONTROL:YAW TO -steerTo.
	SET SHIP:CONTROL:WHEELSTEER TO steerTo.
	IF count >= 20 {
		CLEARSCREEN.
		PRINT "Mode:        STOPIPING".
		PRINT " ".
		PRINT "Air Speed:   " + ROUND(SHIP:AIRSPEED,1).
		PRINT " ".
		PRINT "Bearing:     " + ROUND(runwayEnd:BEARING,3).
		SET count TO 1.
	}	ELSE {
		SET count TO count + 1.
	}
	SET stopped TO GROUNDSPEED < 1.
}}}
SET SHIP:CONTROL:NEUTRALIZE TO True.
RCS OFF.
SAS ON.
//	north west:  -0.0518,-74.7290
//	south west: -0.0452,-74.7290
//	centerpoint west: -0.0485,-74.7290

//	south east: -0.0469,-74.4879
//	north east:  -0.0535,-74.4879
//	centerpoint east: -0.0502,-74.4879

//-----end of core logic start of functions-----
FUNCTION roll_to {	//-----returns the value to set roll controls to-----
	PARAMETER targetRoll,shipRoll.
	SET rollCon_PID:SETPOINT TO targetRoll.
	RETURN rollCon_PID:UPDATE(TIME:SECONDS,shipRoll).
}

FUNCTION pitch_to {	//-----returns the value to set pitch controls to-----
	PARAMETER targetPitch,shipRoll,shipPitch.
	SET pitchCon_PID:SETPOINT TO targetPitch.
	IF shipRoll < 90 OR shipRoll > -90 {
		RETURN pitchCon_PID:UPDATE(TIME:SECONDS,shipPitch).
	}	ELSE {
		RETURN 0 - pitchCon_PID:UPDATE(TIME:SECONDS,shipPitch).
	}
}

FUNCTION yaw_to {	//-----returns the value to set yaw controls to-----
	LOCAL shipYaw IS compass_for(SHIP).
	LOCAL proYaw IS heading_of_vector(SHIP:SRFPROGRADE:FOREVECTOR).
	LOCAL yawDif IS shipYaw - proYaw.
	IF yawDif > 180 {SET yawDif TO yawDif - 360. }
	IF yawDif < -180 {SET yawDif TO yawDif + 360. }
	RETURN yawCon_PID:UPDATE(TIME:SECONDS,yawDif).
}

FUNCTION target_distance {
	PARAMETER p1.
	RETURN dist_between_coordinates(p1,SHIP:GEOPOSITION).
}

FUNCTION drop_tanks {
	PARAMETER tankTag IS "dropTank".
	IF NOT (DEFINED nextStageTime) { GLOBAL nextStageTime IS TIME:SECONDS + 10. }
	LOCAL tankList IS SHIP:PARTSTAGGED(tankTag).
	IF (tankList:LENGTH > 0) AND STAGE:READY AND nextStageTime < TIME:SECONDS {
		LOCAL drop IS FALSE.
		FOR tank IN tankList {
			FOR res IN tank:RESOURCES {
				IF res:AMOUNT < 0.01 {
					SET drop TO TRUE.
					BREAK.
				}
			}
		}
		IF drop {
			STAGE.
			SET nextStageTime TO TIME:SECONDS + 10.
		}
	}
	RETURN tankList:LENGTH > 0.
}