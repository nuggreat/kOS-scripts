//intended to be used with lib_dock_v1
FOR lib IN LIST("lib_dock") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNPATH("1:/lib/" + lib + ".ks"). }}
CLEARSCREEN.
SAS OFF.
RCS OFF.
ABORT OFF.
LOCAL stationPortListRaw IS port_scan_of(SHIP).
LOCAL buffer IS SHIP:MESSAGES.
buffer:CLEAR().

PRINT "Waiting Untill Docking Request.".
message_wait(buffer).					//waiting for handshake
PRINT "Request Receved Responding.".
LOCAL signal IS buffer:POP().
LOCAL craft IS signal:SENDER.
LOCAL cratConect IS craft:CONNECTION.
buffer:CLEAR().
cratConect:SENDMESSAGE("Handshake").		//handshake sent
message_wait(buffer).
buffer:CLEAR().
cratConect:SENDMESSAGE("Ready").		//ready to receive data

LOCAL craftPortListRaw IS port_scan_of(craft).
message_wait(buffer).
LOCAL signal IS buffer:POP().
LOCAL stationMove IS signal:CONTENT.	//received if station should move
cratConect:SENDMESSAGE(port_uid_filter(stationPortListRaw)).		//sending stationPortList in UID form

message_wait(buffer).
LOCAL signal IS buffer:POP().
LOCAL portLock IS signal:CONTENT.		//receiving the ports selected for use in UID form
IF portLock["match"] {
LOCAL portLock IS port_lock_true(craftPortListRaw, stationPortListRaw, portLock).	//changing the ports selected for use from UID to TYPE:PART

GLOBAL stationPort IS portLock["stationPort"].
GLOBAL craftPort IS portLock["craftPort"].

LOCAL noFlyZone IS ROUND(no_fly_zone(SHIP,stationPort) + 50).
cratConect:SENDMESSAGE(noFlyZone).	//sending noFlyZone
PRINT "Beginning Docking Protocols.".


stationPort:CONTROLFROM().

port_open(stationPort).

LOCAL timePre IS TIME:SECONDS.
IF stationMove {
	LOCAL upVec IS stationPort:PORTFACING:UPVECTOR.
	LOCAL targetDirection IS craftPort:POSITION - stationPort:POSITION.
	LOCAL stationDirection IS LOOKDIRUP(targetDirection,upVec).
	LOCK STEERING TO stationDirection.
	PRINT "Alineing to Target.".
	LOCAL done IS FALSE.
	UNTIL done {
		SET targetDirection TO craftPort:POSITION - stationPort:POSITION.
		SET stationDirection TO LOOKDIRUP(targetDirection,upVec).
		LOCAL angleTo IS ABS(STEERINGMANAGER:ANGLEERROR).
		IF angleTo < 0.5 {
			IF (TIME:SECONDS - timePre) >= 10 { SET done TO TRUE. }
		} ELSE { SET timePre TO TIME:SECONDS. }
		SET done TO  ABORT OR done.
		WAIT 0.01.
	}
	LOCK STEERING TO LOOKDIRUP(craftPort:POSITION - stationPort:POSITION,upVec).
} ELSE {
	LOCAL stationFacing IS LOOKDIRUP(stationPort:PORTFACING:FOREVECTOR,stationPort:PORTFACING:UPVECTOR).
	LOCK STEERING TO stationFacing.
	LOCAl done IS FALSE.
	UNTIL done {
		LOCAL angleTo IS ABS(STEERINGMANAGER:ANGLEERROR).
		IF angleTo < 0.5 {
			IF (TIME:SECONDS - timePre) >= 10 { SET done TO TRUE. }
		} ELSE { SET timePre TO TIME:SECONDS. }
		SET done TO  ABORT OR done.
		WAIT 0.01.
	}
}

PRINT "Aliened and Waiting for Docking.".
cratConect:SENDMESSAGE(noFlyZone).
WAIT 10.
LOCAL done IS FALSE.
ON stationPort:STATE {
	IF stationPort:STATE <> "Ready" {
		SET done TO TRUE.
	}
}
LOCK docked TO (stationPort:STATE = "Docked (docker)") OR (stationPort:STATE = "Docked (dockee)") OR (stationPort:STATE = "PreAttached").
UNTIL docked OR done {
	//SET done TO
	screenUpdate(stationPort,craftPort).
}
UNLOCK STEERING.
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
//UNTIL docked {
//	SET done TO screenUpdate(stationPort,craftPort).
//}
} ELSE {
	PRINT "no Matching Unused Dockingports.".
}
RCS OFF.

FUNCTION screenUpdate {
	PARAMETER stationPort,craftPort.
	LOCAL relSpeed IS axis_speed(craft,SHIP).
	LOCAL relDist IS axis_distance(craftPort,stationPort).
	WAIT 0.01.
	CLEARSCREEN.
	PRINT "Alined and Waiting for Docking.".
	PRINT " ".
	PRINT "      Dist: " + ROUND(relDist[0],2).
	PRINT "     Speed: " + ROUND(relSpeed[0]:MAG,2).
	PRINT " ".
	PRINT " For  Dist: " + ROUND(relDist[1],2).
	PRINT " For Speed: " + ROUND(-relSpeed[1],2).
	PRINT " ".
	PRINT " Top  Dist: " + ROUND(relDist[2],2).
	PRINT " Top Speed: " + ROUND(-relSpeed[2],2).
	PRINT " ".
	PRINT "Star  Dist: " + ROUND(relDist[3],2).
	PRINT "Star Speed: " + ROUND(-relSpeed[3],2).
	RETURN relDist[0].
}