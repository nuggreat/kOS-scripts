RUNONCEPATH("1:/lib/lib_dock.ks").
CLEARSCREEN.
ABORT OFF.
PARAMETER stationMove IS FALSE,
transSpeed IS 1.
LOCAL craftPortListRaw IS port_scan(SHIP).
IF craftPortListRaw:LENGTH = 0 {SET craftPortListRaw TO port_scan(SHIP).}
LOCAL buffer IS SHIP:MESSAGES.
buffer:CLEAR().

//PID setup PIDLOOP(kP,kI,kD,min,max)
SET forRCS_PID TO PIDLOOP(4,0.01,0,-1,1).
SET topRCS_PID TO PIDLOOP(4,0.01,0,-1,1).
SET starRCS_PID TO PIDLOOP(4,0.01,0,-1,1).

LOCAL done IS FALSE.
UNTIL done {
	CLEARSCREEN.
	PRINT "Waiting Until a Target to Dock to is Selected.".
	IF HASTARGET {
		SET done TO (TARGET:ISTYPE("vessel") OR TARGET:ISTYPE("part")).
	}
	WAIT 0.1.
}

LOCAL station IS TARGET.
IF station:ISTYPE("part") {
	SET station TO station:SHIP.
}
LOCAL stationPortListRaw IS port_scan(station).
IF stationPortListRaw:LENGTH = 0 {SET stationPortListRaw TO port_scan(station).}
SET NAVMODE TO "TARGET".
LOCAL stationConect IS station:CONNECTION.
PRINT "Waiting for Handshake.".
UNTIL NOT buffer:EMPTY {
	IF buffer:EMPTY {stationConect:SENDMESSAGE("Handshake").}	//sending handshake
	WAIT 1.
}
buffer:CLEAR().			//handshake receved
stationConect:SENDMESSAGE("Docking Request").
message_wait(buffer).
buffer:CLEAR().

stationConect:SENDMESSAGE(stationMove).	//sending if station should move
PRINT "Docking Requested".

message_wait(buffer).
LOCAL signal IS buffer:POP().
LOCAL stationPortListUid IS signal:CONTENT.	//receving stationPortList in UID form
LOCAL craftPortListUid IS port_uid_filter(craftPortListRaw).
LOCAL portLock IS port_lock(craftPortListUid,stationPortListUid,"enabled","disabled").
stationConect:SENDMESSAGE(portLock).			//sending the ports slected for use in UID form
IF portLock["match"] {
LOCAL portLock IS port_lock_true(craftPortListRaw,stationPortListRaw,portLock).	//changing the ports slected for use from UID to TYPE:PART

message_wait(buffer).
LOCAL signal IS buffer:POP().
LOCAL noFlyZone IS signal:CONTENT.	//receving noFlyZone size

LOCAL stationPort IS portLock["stationPort"].
LOCAL craftPort IS portLock["craftPort"].

SAS OFF.
RCS OFF.
PRINT " ".
PRINT "Coming to 0/0 Relitave Stop.".
IF axis_speed(SHIP,station)[0]:MAG > 0.1 {
	LOCK STEERING TO axis_speed(station,SHIP)[0]:NORMALIZED.
	LOCAL done IS FALSE.
	LOCAL timePre IS TIME:SECONDS.
	UNTIL done {
		LOCAL angleTo IS VANG(SHIP:FACING:FOREVECTOR,axis_speed(station,SHIP)[0]:NORMALIZED).
		IF angleTo < 0.5 {
			IF (TIME:SECONDS - timePre) >= 2.5 { SET done TO TRUE. }
		} ELSE {
			SET timePre TO TIME:SECONDS.
			SET done TO ABORT.
		}
		WAIT 0.01.
	}
	ABORT OFF.

	SET done TO FALSE.
	UNTIL done {
		LOCAL axisSpeed IS axis_speed(SHIP,station).
		LOCAL stationSpeed IS -axisSpeed[1].
		LOCAL shipAcceleration IS SHIP:AVAILABLETHRUST / SHIP:MASS.
		LOCK STEERING TO -axisSpeed[0].
		SET SHIP:CONTROL:PILOTMAINTHROTTLE TO MAX(MIN(ABS(stationSpeed) / (shipAcceleration * 2),1),0.01).
		WAIT 0.01.
		SET done TO stationSpeed < 0.01.
	}
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
}
PRINT "Ship at 0/0 Relitave to Target.".
PRINT " ".

IF craftPort[2] = 1 {
	port_open(craftPort[0]).
}

PRINT "Waiting for Station to Stablise.".
message_wait(buffer).
SET signal TO buffer:POP().
craftPort[0]:CONTROLFROM().

PRINT "Alineing to Target.".
LOCAL timePre IS TIME:SECONDS.
SET done TO FALSE.
UNTIL done {
	LOCK STEERING TO LOOKDIRUP(-stationPort[0]:PORTFACING:FOREVECTOR, stationPort[0]:PORTFACING:TOPVECTOR).
	LOCAL angleTo IS VANG(craftPort[0]:PORTFACING:FOREVECTOR, -stationPort[0]:PORTFACING:FOREVECTOR) + VANG(craftPort[0]:PORTFACING:TOPVECTOR, stationPort[0]:PORTFACING:TOPVECTOR).
	IF angleTo < 0.5 {
		IF (TIME:SECONDS - timePre) >= 5 { SET done TO TRUE. }
	} ELSE {
		SET timePre TO TIME:SECONDS.
		SET done TO ABORT.
	}
	WAIT 0.01.
}
ABORT OFF.

PRINT " ".

RCS ON.
LOCAL axisDist IS axis_distance(craftPort[0],stationPort[0]).
IF NOT stationMove {
	LOCAL noFlyDist IS MAX(axisDist[2]^2 + axisDist[3]^2,4)^0.5.
	SET done TO FALSE.
	IF (noFlyDist < noFlyZone) AND (axisDist[1] < noFlyZone) {
		SET forRCS_PID:SETPOINT TO 0.
		UNTIL done {
			SET axisDist TO axis_distance(craftPort[0],stationPort[0]).
			SET topRCS_PID:SETPOINT TO transSpeed * -(axisDist[2] / ABS(axisDist[2])).
			SET starRCS_PID:SETPOINT TO transSpeed * -(axisDist[3] / ABS(axisDist[3])).
			translation_control().
			SET noFlyDist TO MAX(axisDist[2]^2 + axisDist[3]^2,4)^0.5.
			WAIT 0.01.
			screen_update("Moving out of No Fly Zone of Station.",craftPort,(noFlyZone - noFlyDist)).
			SET done TO noFlyDist > noFlyZone.
		}
	}
RCS ON.
	IF axisDist[1] < noFlyZone {
		SET forRCS_PID:SETPOINT TO -transSpeed.
		SET topRCS_PID:SETPOINT TO 0.
		SET starRCS_PID:SETPOINT TO 0.
		SET done TO FALSE.
		UNTIL done {
			SET axisDist TO axis_distance(craftPort[0],stationPort[0]).
			translation_control().
			WAIT 0.01.
			screen_update("Translating Infront of Target Port.",craftPort,(noFlyZone - axisDist[1])).
			SET done TO axisDist[1] > noFlyZone.
		}
	}
RCS ON.
	IF (ABS(axisDist[2]) + ABS(axisDist[3])) > 1 {
		SET forRCS_PID:SETPOINT TO 0.
		SET done TO FALSE.
		UNTIL done {
			SET axisDist TO axis_distance(craftPort[0],stationPort[0]).
			SET topRCS_PID:SETPOINT TO RCS_decel_setpoint(0.05,axisDist[2],-transSpeed,transSpeed,1).
			SET starRCS_PID:SETPOINT TO RCS_decel_setpoint(0.05,axisDist[3],-transSpeed,transSpeed,1).
			translation_control().
			LOCAL portDist IS (ABS(axisDist[2])^2 + ABS(axisDist[3])^2)^0.5.
			WAIT 0.01.
			screen_update("Aligning With Target Port.",craftPort,portDist).
			SET done TO portDist < 0.5.
		}
	}
}
RCS ON.
IF stationMove {
	SET topRCS_PID:SETPOINT TO 0.
	SET starRCS_PID:SETPOINT TO 0.
}
LOCAL done IS FALSE.
UNTIL done {
	SET axisDist TO axis_distance(craftPort[0],stationPort[0]).
	SET forRCS_PID:SETPOINT TO RCS_decel_setpoint(0.05,axisDist[1],0.1,transSpeed,0).
	IF NOT stationMove {
		SET topRCS_PID:SETPOINT TO RCS_decel_setpoint(0.05,axisDist[2],-transSpeed,transSpeed,1).
		SET starRCS_PID:SETPOINT TO RCS_decel_setpoint(0.05,axisDist[3],-transSpeed,transSpeed,1).
	}
	translation_control().
	WAIT 0.01.
	screen_update("Docking.",craftPort,axisDist[1]).
	SET done TO (craftPort[0]:STATE = "Docked (docker)") OR (craftPort[0]:STATE = "Docked (Dockee)") OR (craftPort[0]:STATE = "PreAttached") OR ABORT OR done.
}
} ELSE {
	PRINT "no Matching Unused Dockingports.".
}
SET NAVMODE TO "ORBIT".
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
WAIT 1.
RCS OFF.

//end of core logic start of functions
FUNCTION RCS_decel_setpoint {
	PARAMETER accel,dist,minSpeed,maxSpeed,deadZone.
	LOCAL localAccel IS accel.
	IF ABS(dist) > deadZone { SET localAccel to accel / 4. }
	RETURN MIN(MAX((((ABS(dist) / (localAccel / 2))^.5) * localAccel) * (dist/MAX(ABS(dist),0.0001)),minSpeed),maxSpeed).
}

FUNCTION translation_control {
	LOCAL timeS IS TIME:SECONDS.
	LOCAL axisSpeed IS axis_speed(SHIP,station).
	SET SHIP:CONTROL:FORE TO forRCS_PID:UPDATE(timeS,axisSpeed[1]).
	SET SHIP:CONTROL:TOP TO topRCS_PID:UPDATE(timeS,axisSpeed[2]).
	SET SHIP:CONTROL:STARBOARD TO starRCS_PID:UPDATE(timeS,axisSpeed[3]).
}

FUNCTION port_lock {
	PARAMETER craftPortList,stationPortList,use,ignore.
	LOCAL matchingPort IS LEX("match",FALSE).
	FOR shipP IN craftPortList { FOR stationP IN stationPortList {
		IF shipP[1] = stationP[1] {
			IF ignore = -99999 OR ((shipP[3] <> ignore) AND (stationP[3] <> ignore)) {
				IF use = -99999 OR ((shipP[3] = use) AND (stationP[3] = use)) {
					RETURN LEX("match",TRUE,"craftPort",shipP,"stationPort",stationP).
				}
				IF use <> -99999 AND ((shipP[3] = use) OR (stationP[3] = use)) AND (NOT matchingPort["match"]) {
					SET matchingPort TO LEX("match",TRUE,"craftPort",shipP,"stationPort",stationP).
				}
			}
		}
	}}
	IF matchingPort["match"] {
		RETURN matchingPort.
	} ELSE IF use <> -99999 {
		PRINT "Overiding Port Priority Tag".
		RETURN port_lock(craftPortList,stationPortList,-99999,ignore).
	} ELSE IF ignore <> -99999{
		PRINT "Overiding Port Disable Tag".
		RETURN port_lock(craftPortList,stationPortList,-99999,-99999).
	} ELSE {
		RETURN LEX("match",FALSE).
	}
}

FUNCTION screen_update {
	PARAMETER modeTxt,targetPort,dist.
	CLEARSCREEN.
	PRINT modeTxt.
	PRINT " ".
	PRINT "Port Size: " + targetPort[1].
	PRINT "Disttance: " + ROUND(dist,1).
}