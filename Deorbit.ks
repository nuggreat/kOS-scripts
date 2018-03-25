PARAMETER landingTar.
FOR lib IN LIST("lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}

LOCAL targetGo IS TRUE.
LOCAL landingCoordinates IS landingTar.
IF landingTar:ISTYPE("string") {SET landingTar TO WAYPOINT(landingTar).}
IF landingTar:ISTYPE("vessel") or landingTar:ISTYPE("waypoint") {
	SET landingCoordinates TO landingTar:GEOPOSITION.
} ELSE {
	IF landingTar:ISTYPE("part") {
		SET landingCoordinates TO BODY:GEOPOSITIONOF(landingTar:POSITION).
	} ELSE {
		IF landingTar:ISTYPE("geocoordinates") {
			SET landingCoordinates TO landingTar.
		} ELSE {
			PRINT "I don't know how ues a dest type of :" + landingTar:TYPENAME.
			SET targetGo TO false.
		}
	}
}
IF targetGo {
//LOCAL thrustLimitBackup IS twr_restriction(7.5).

RUN land_at(landingCoordinates).
RUN node_burn.
//RUN land_at(landingCoordinates).
//RUN node_burn.
REMOVE NEXTNODE.
RUN landing_vac(TRUE,landingCoordinates).

//twr_restore(thrustLimitBackup).

PRINT "Distance: " + ROUND(landingCoordinates:DISTANCE).
}

FUNCTION twr_restriction {
	PARAMETER twrTarget.
	LOCAL surfaceGrav IS SHIP:BODY:MU/(SHIP:BODY:RADIUS)^2.
	LOCAL shipAcceleration IS SHIP:AVAILABLETHRUST / SHIP:MASS.
	LOCAL twr IS shipAcceleration / surfaceGrav.
	LOCAL limiterBackup IS LIST().
	IF twr > twrTarget {
		limiterBackup:ADD(TRUE).
		LOCAL twrCoeficent IS twrTarget / twr.
		LOCAL engineList IS LIST().
		LIST ENGINES IN engineList.
		FOR engine IN engineList {
			IF engine:IGNITION AND NOT engine:FLAMEOUT {
				limiterBackup:ADD(LIST(engine,engine:THRUSTLIMIT)).
				SET engine:THRUSTLIMIT TO MAX(CEILING(engine:THRUSTLIMIT * twrCoeficent * 2) / 2,0.5).
			}
		}
	} ELSE {
		limiterBackup:ADD(FALSE).
	}
	RETURN limiterBackup.
}

FUNCTION twr_restore {
	PARAMETER limiterBackup.
	IF limiterBackup[0] {
		limiterBackup:REMOVE(0).
		FOR engine IN limiterBackup {
			SET engine[0]:THRUSTLIMIT TO engine[1].
		}
	}
}