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

LOCAl logPath IS PATH("0:/log_land_at_tester.txt").
//IF EXISTS(logPath) { DELETEPATH(logPath). }
//IF NOT EXISTS(logPath) { LOG "timeOld,timeNew,old-new,old/new,total count" TO logPath. }

LOCAl logPathOld IS PATH("0:/log_land_at.txt").
//IF EXISTS(logPathOld) { DELETEPATH(logPathOld). }

LOCAl logPathNew IS PATH("0:/log_land_at_v6.txt").
//IF EXISTS(logPathNew) { DELETEPATH(logPathNew). }

high_delta_time_init().
clear_all_nodes().
SET CONFIG:IPU TO 2000.

RCS OFF.
UNTIL RCS {

	LOCAL randLat IS RANDOM() * 180 - 90.
	//WAIT 1.
	LOCAL randLng IS RANDOM() * 360 - 180.
	LOCAL landingTar IS LATLNG(randLat,randLng).
	LOCAL startTime IS TIME:SECONDS + SHIP:ORBIT:PERIOD.
	WAIT 0.

	SET oldTime TO TIME:SECONDS.
	RUN land_at(landingTar,startTime).
	LOCAL oldDelta IS TIME:SECONDS - oldTime.
	clear_all_nodes().

	WAIT 0.
	SET oldTime TO TIME:SECONDS.
	RUN land_at_v6(landingTar,startTime).
	LOCAL newDelta IS TIME:SECONDS - oldTime.
	LOCAL better IS 1.
	IF newDelta > oldDelta { SET better TO 0. }
	LOG padding(oldDelta,3,2) + "," + padding(newDelta,3,2) + "," + padding(oldDelta-newDelta,3,2) + "," + better + ",1" TO logPath.

	LOCAL randLat IS RANDOM() * 180 - 90.
	//WAIT 1.
	LOCAL randLng IS RANDOM() * 360 - 180.
	LOCAL landingTar IS LATLNG(randLat,randLng).
	LOCAL startTime IS TIME:SECONDS + SHIP:ORBIT:PERIOD.
	WAIT 0.

	SET oldTime TO TIME:SECONDS.
	RUN land_at_v6(landingTar,startTime).
	LOCAL newDelta IS TIME:SECONDS - oldTime.
	clear_all_nodes().

	WAIT 0.
	SET oldTime TO TIME:SECONDS.
	RUN land_at(landingTar,startTime).
	LOCAL oldDelta IS TIME:SECONDS - oldTime.
	LOCAL better IS 1.
	IF newDelta > oldDelta { SET better TO 0. }
	LOG padding(oldDelta,3,2) + "," + padding(newDelta,3,2) + "," + padding(oldDelta-newDelta,3,2) + "," + better + ",1" TO logPath.
}
SET CONFIG:IPU TO 200.


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