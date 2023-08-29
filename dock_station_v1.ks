//intended to be used with lib_dock_v1
FOR lib IN LIST("lib_dock") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
CLEARSCREEN.
SAS OFF.
RCS OFF.
ABORT OFF.
LOCAL stationPortListRaw IS port_scan(SHIP).
LOCAL noFlyZone IS ROUND(no_fly_zone(SHIP) + 25).
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
cratConect:SENDMESSAGE("Ready").		//ready to reveve data

LOCAL craftPortListRaw IS port_scan(craft).
message_wait(buffer).
LOCAL signal IS buffer:POP().
LOCAL stationMove IS signal:CONTENT.	//receved if station should move
cratConect:SENDMESSAGE(port_uid_filter(stationPortListRaw)).		//sending stationPortList in UID form

message_wait(buffer).
LOCAL signal IS buffer:POP().
LOCAL portLock IS signal:CONTENT.		//receving the ports slected for use in UID form
IF portLock["match"] {
LOCAL portLock IS port_lock_true(craftPortListRaw, stationPortListRaw, portLock).	//changing the ports slected for use from UID to TYPE:PART
cratConect:SENDMESSAGE(noFlyZone).	//sending noFlyZone
PRINT "Begining Docking Protocalls.".

GLOBAL stationPort IS portLock["stationPort"].
GLOBAL craftPort IS portLock["craftPort"].

stationPort[0]:CONTROLFROM().

IF stationPort[2] = 1 {
	port_open(stationPort[0]).
}

LOCAL timePre IS TIME:SECONDS.
IF stationMove {
	LOCAL upVec IS stationPort[0]:PORTFACING:UPVECTOR.
	LOCAL targetDirection IS craftPort[0]:POSITION - stationPort[0]:POSITION.
	LOCAL stationDirection IS LOOKDIRUP(targetDirection,upVec).
	LOCK STEERING TO stationDirection.
	PRINT "Alineing to Target.".
	LOCAL done IS FALSE.
	UNTIL done {
		SET targetDirection TO craftPort[0]:POSITION - stationPort[0]:POSITION.
		SET stationDirection TO LOOKDIRUP(targetDirection,upVec).
		LOCAL angleTo IS ABS(STEERINGMANAGER:ANGLEERROR).
		IF angleTo < 0.5 {
			IF (TIME:SECONDS - timePre) >= 10 { SET done TO TRUE. }
		} ELSE { SET timePre TO TIME:SECONDS. }
		SET done TO  ABORT OR done.
		WAIT 0.01.
	}
	LOCK STEERING TO LOOKDIRUP(craftPort[0]:POSITION - stationPort[0]:POSITION,upVec).
} ELSE {
	LOCAL stationFacing IS LOOKDIRUP(stationPort[0]:PORTFACING:FOREVECTOR,stationPort[0]:PORTFACING:UPVECTOR).
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


PRINT "Alined and Waiting for Docking.".
cratConect:SENDMESSAGE(noFlyZone).
WAIT 10.
LOCAL done IS FALSE.
LOCK docked TO (stationPort[0]:STATE = "Docked (docker)") OR (stationPort[0]:STATE = "Docked (dockee)") OR (stationPort[0]:STATE = "PreAttached").
UNTIL docked OR done {
	SET done TO screenUpdate(stationPort[0],craftPort[0]) < 1.
}
UNLOCK STEERING.
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
UNTIL docked {
	SET done TO screenUpdate(stationPort[0],craftPort[0]).
}
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
	PRINT " For Speed: " + ROUND(relSpeed[1],2).
	PRINT " ".
	PRINT " Top  Dist: " + ROUND(relDist[2],2).
	PRINT " Top Speed: " + ROUND(relSpeed[2],2).
	PRINT " ".
	PRINT "Star  Dist: " + ROUND(relDist[3],2).
	PRINT "Star Speed: " + ROUND(relSpeed[3],2).
	RETURN relDist[0].
}