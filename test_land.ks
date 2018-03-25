CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
IF NOT SHIP:UNPACKED { PRINT "waiting for unpack". WAIT UNTIL SHIP:UNPACKED. WAIT 1. PRINT "unpacked". }
FOR lib IN LIST("lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}

//RUN updater.

LOCAL startDV IS curent_DV().
LOCAL randLat IS RANDOM() * 90 - 45.
//WAIT 1.
LOCAL randLng IS RANDOM() * 360 - 180.
//PRINT "landing at: (" + ROUND(randLat) + "," + ROUND(randLng) + ")".
LOCAL landingTar IS LATLNG(randLat,randLng).
//WAIT 5.
LOCAL thrustLimitBackup IS twr_restriction(7.5).

//SET CONFIG:IPU TO 2000.
//UNTIL FALSE {
//	LOCAL randLat IS RANDOM() * 90 - 45.
//	//WAIT 1.
//	LOCAL randLng IS RANDOM() * 360 - 180.
//	//PRINT "landing at: (" + ROUND(randLat) + "," + ROUND(randLng) + ")".
//	SET landingTar TO LATLNG(randLat,randLng).
//	RUN land_at(landingTar).
//}

SET CONFIG:IPU TO 200.
RUN land_at(landingTar).
SET CONFIG:IPU TO 200.
RUN node_burn_local(TRUE).

//SET CONFIG:IPU TO 2000.
//RUN land_at(landingTar).
//SET CONFIG:IPU TO 200.
//RUN node_burn_local(TRUE).

LOCAL burnDV IS ROUND(startDV - curent_DV(),2).
REMOVE NEXTNODE.
RUN landing_vac(TRUE,landingTar).

twr_restore(thrustLimitBackup).

PRINT "Distance: " + ROUND(landingTar:DISTANCE).
PRINT "Heading:  " + ROUND(landingTar:HEADING).
IF NOT EXISTS("0:/landing_log.txt") { LOG "Distance,lat,lng,Inital DV, Deorbit DV, Total DV used" TO "0:/landing_log.txt". }
LOG landingTar:DISTANCE + "," + randLat + "," + randLng + "," + startDV + "," + burnDV + "," + ROUND(startDV - curent_DV(),2) TO "0:/landing_log.txt".
WAIT 5.
WAIT UNTIL SHIP:VELOCITY:SURFACE:MAG < 0.1.
KUNIVERSE:QUICKLOAD().

FUNCTION curent_DV {
	RETURN ROUND(isp_calc()*9.80665*LN(SHIP:MASS/(SHIP:DRYMASS+0.15)),2).
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