//LOCAL defautlTar IS LATLNG().
PARAMETER landingTar.
FOR lib IN LIST("lib_rocket_utilities","lib_geochordnate") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}

LOCAL landingChord IS mis_types_to_geochordnate(landingTar)["chord"].

IF landingChord:ISTYPE("geocoordinates") {
//LOCAL thrustLimitBackup IS twr_restriction(7.5).
ABORT OFF.
RUN land_at(landingTar).
IF NOT ABORT {
	RUN node_burn.
	//RUN land_at(landingChord).
	//RUN node_burn.
	REMOVE NEXTNODE.
	IF NOT ABORT {
		RUN landing_vac(TRUE,landingTar).
		//IF landingTar = defautlTar {
		//	DEPLOYDRILLS ON.
		//	WAIT 10.
		//	DRILLS ON.
		//}
	}
}

//twr_restore(thrustLimitBackup).

PRINT "Distance: " + ROUND(landingChord:DISTANCE).
} ELSE {
	PRINT "no target found".
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