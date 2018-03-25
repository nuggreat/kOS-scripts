//RUN updater.
//RUN fuel_pump("test").
//PRINT "working".
FOR lib IN LIST("lib_formating","lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
WAIT UNTIL SHIP:UNPACKED.
WAIT 1.
CORE:DOEVENT("Open Terminal").

LOCAL oldLandAt IS 0.
LOCAL newLandAt IS 0.
LOCAL newFirst IS FALSE.
LOCAl logPath IS PATH("0:/landing_log.txt").
IF NOT EXISTS("0:/landing_log.txt") { LOG "distance" TO logPath. }
high_delta_time_init().
clear_all_nodes().
ADD NODE(TIME:SECONDS,0,0,0).

RCS OFF.
SET CONFIG:IPU TO 2000.

LOCAL randLat IS RANDOM() * 180 - 90.
//WAIT 1.
LOCAL randLng IS RANDOM() * 360 - 180.
LOCAL landingTar IS LATLNG(randLat,randLng).
//PRINT "landing at: (" + ROUND(randLat) + "," + ROUND(randLng) + ")".
//WAIT 5.

//RUN land_at(landingTar).
SET CONFIG:IPU TO 200.
//RUN node_burn(TRUE).
clear_all_nodes().
//RUN landing_vac(TRUE,landingTar).

//LOG (landingTar:DISTANCE) TO logPath.


//SET CONFIG:IPU TO 200.

//SHIP:BODY:GEOPOSITIONOF(POSITIONAT(SHIP,TIME:SECONDS + ETA:APOAPSIS))

KUNIVERSE:QUICKLOAD().

FUNCTION screenPrint {
	//CLEARSCREEN.
	PARAMETER oldDelta, newDelta.
	LOCAL deltaDif IS ROUND(newDelta - oldDelta,2).
	//PRINT "time taken for old script: " + time_converter(oldDelta,2).
	//PRINT "time taken for new script: " + time_converter(newDelta,2).
	//PRINT "difference(new - old): "  + deltaDif.
	//PRINT " ".
	LOCAL totalDiff IS ROUND(newLandAt - oldLandAt,2).
	//PRINT "total time taken for old script: " + time_converter(oldLandAt,2).
	//PRINT "total time taken for new script: " + time_converter(newLandAt,2).
	//PRINT "difference(new - old): "  + totalDiff.
	LOG padding(oldDelta,3,2) + "," + padding(newDelta,3,2) + "," +  padding(deltaDif,3,2) + "," + padding(oldLandAt,3,2) + "," + padding(newLandAt,3,2) + "," + padding(totalDiff,3,2) TO logPath.
}

FUNCTION module_scan {
	PARAMETER moduleName.
	LOCAL returnList IS LIST().
	FOR par in SHIP:PARTS{
		IF par:MODULES:CONTAINS(moduleName) {
			returnList:ADD(par).
		}
	}
	RETURN returnList.
}

FUNCTION high_delta_time {
	IF NOT (DEFINED highPrevousTime) { GLOBAL highPrevousTime IS TIME:SECONDS. }
	LOCAL deltaTime IS TIME:SECONDS - highPrevousTime.
	SET highPrevousTime TO TIME:SECONDS.
	RETURN deltaTime.
}

FUNCTION high_delta_time_init {
	IF NOT (DEFINED highPrevousTime) { GLOBAL highPrevousTime IS TIME:SECONDS. } ELSE { SET highPrevousTime TO TIME:SECONDS. }
}