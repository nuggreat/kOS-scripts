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

RCS ON.
LOCAL reffList IS LIST(craftPort,stationPort,transSpeed).
IF NOT stationMove {
	translate(reffList,"Moving out of No Fly Zone of Station.",TRUE,LIST(0,1,1),noFlyZone).
	RCS ON.
	translate(reffList,"Translating Infront of Target Port.",FALSE,LIST(1,0,0),LIST(noFlyZone,0,0)).
	RCS ON.
	translate(reffList,"Aligning With Target Port.",FALSE,LIST(0,1,1),LIST(0,0,0)).
	RCS ON.
	translate(reffList,"Docking.",FALSE,LIST(1,1,1),LIST(0,0,0)).
} ELSE {
	translate(reffList,"Docking.",FALSE,LIST(1,0,0),LIST(0,0,0)).
}

} ELSE {
	PRINT "no Matching Unused Dockingports.".
}
SET NAVMODE TO "ORBIT".
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
WAIT 1.
RCS OFF.

//end of core logic start of functions
FUNCTION translate {
	PARAMETER neededRef, //is LIST(craftPort,stationPort,station)
	screenText,			//a string that will be pased to the screen
	leaveNoFlyZone,		//true/false for what type of translation to use
	maxSpeed,			//fastest translation speed usable
	vecMode,				//list of what translation vectors to use, order: for,top,star
	distTar,				//list of 3 target distances along a vector, order: for,top,star or the noFlyZone sent by the station if leaveNoFlyZone is true
	translationAccel IS 0.05.		//the target acceleration for translation only used if leaveNoFlyZone is false
	LOCAL craftPort IS neededRef[0]. LOCAL stationPort IS neededRef[1]. LOCAL station IS stationPort[0]:SHIP. LOCAL maxSpeed IS neededRef[2].
	LOCAL axisSpeed IS axis_speed(SHIP,station).
	LOCAL axisDist IS axis_distance(craftPort[0],stationPort[0]).

	LOCAL  forDistDif IS 0.
	LOCAL  topDistDif IS 0.
	LOCAL starDistDif IS 0.
	LOCAL distDif IS (forDistDif^2 + topDistDif^2 + starDistDif^2)^0.5.
	LOCAL noFlyDist IS MAX(axisDist[1]^2 * vecMode[0] + axisDist[2]^2 * vecMode[1] + axisDist[3]^2 * vecMode[2],1)^0.5.

	IF vecMode[0] = 0 { SET forRCS_PID:SETPOINT TO 0. }
	IF vecMode[1] = 0 { SET topRCS_PID:SETPOINT TO 0. }
	IF vecMode[2] = 0 {SET starRCS_PID:SETPOINT TO 0. }
	IF NOT leaveNoFlyZone {
		IF vecMode[0] > 0 { SET forDistDif TO axisDist[1] - distTar[0]. }
		IF vecMode[1] > 0 { SET topDistDif TO axisDist[2] - distTar[1]. }
		IF vecMode[2] > 0 {SET starDistDif TO axisDist[3] - distTar[2]. }
		IF vecMode[0] = 2 { SET forRCS_PID:SETPOINT TO maxSpeed * forDistDif / ABS(forDistDif). }
		IF vecMode[1] = 2 { SET topRCS_PID:SETPOINT TO maxSpeed * topDistDif / ABS(topDistDif). }
		IF vecMode[2] = 2 {SET starRCS_PID:SETPOINT TO maxSpeed * starDistDif/ABS(starDistDif). }
		SET distDif TO (forDistDif^2 + topDistDif^2 + starDistDif^2)^0.5.
	} ELSE {
		IF vecMode[0] = 1 { SET forRCS_PID:SETPOINT TO maxSpeed * -(axisDist[1] / ABS(axisDist[1])). }
		IF vecMode[1] = 1 { SET topRCS_PID:SETPOINT TO maxSpeed * -(axisDist[2] / ABS(axisDist[2])). }
		IF vecMode[2] = 1 {SET starRCS_PID:SETPOINT TO maxSpeed * -(axisDist[3] / ABS(axisDist[3])). }
		SET noFlyDist TO MAX(axisDist[1]^2 * vecMode[0] + axisDist[2]^2 * vecMode[1] + axisDist[3]^2 * vecMode[2],1)^0.5.
		SET distDif TO distTar - noFlyDist.
	}

	LOCAL docked IS (stationPort[0]:STATE = "Docked (docker)") OR (stationPort[0]:STATE = "Docked (dockee)").
	LOCAL done IS distDif < 0.1 OR docked.
	UNTIL done {
		SET axisDist TO axis_distance(craftPort[0],stationPort[0]).

		IF leaveNoFlyZone {
			SET noFlyDist TO MAX(axisDist[1]^2 * vecMode[0] + axisDist[2]^2 * vecMode[1] + axisDist[3]^2 * vecMode[2],1)^0.5.
			SET distDif TO distTar - noFlyDist.
		} ELSE {
			IF vecMode[0] = 1 {
				SET forDistDif TO axisDist[1] - distTar[0].
				SET forRCS_PID:SETPOINT TO RCS_decel_setpoint(translationAccel,forDistDif,maxSpeed,1).
			}
			IF vecMode[1] = 1 {
				SET topDistDif TO axisDist[2] - distTar[1].
				SET topRCS_PID:SETPOINT TO RCS_decel_setpoint(translationAccel,topDistDif,maxSpeed,1).
			}
			IF vecMode[2]= 1 {
				SET starDistDif TO axisDist[3] - distTar[2].
				SET starRCS_PID:SETPOINT TO RCS_decel_setpoint(translationAccel,starDistDif,maxSpeed,1).
			}
			SET distDif TO (forDistDif^2 + topDistDif^2 + starDistDif^2)^0.5.
		}

		LOCAL timeS IS TIME:SECONDS.
		SET axisSpeed TO axis_speed(SHIP,station).
		SET SHIP:CONTROL:FORE TO forRCS_PID:UPDATE(timeS,axisSpeed[1]).
		SET SHIP:CONTROL:TOP TO topRCS_PID:UPDATE(timeS,axisSpeed[2]).
		SET SHIP:CONTROL:STARBOARD TO starRCS_PID:UPDATE(timeS,axisSpeed[3]).

		WAIT 0.01.
		CLEARSCREEN.
		PRINT screenText.
		PRINT " ".
		PRINT "Port Size: " + craftPort[1].
		PRINT "Disttance: " + ROUND(distDif,1).

		SET docked TO (stationPort[0]:STATE = "Docked (docker)") OR (stationPort[0]:STATE = "Docked (dockee)").
		SET done TO distDif < 0.1 OR docked.
	}
	SET SHIP:CONTROL:FORE TO 0.
	SET SHIP:CONTROL:TOP TO 0.
	SET SHIP:CONTROL:STARBOARD TO 0.
}

FUNCTION RCS_decel_setpoint {
	PARAMETER accel,dist,speedLimit,deadZone.
	LOCAL localAccel IS accel.
	IF ABS(dist) > deadZone { SET localAccel to accel / 4. }
	RETURN MIN(MAX((((ABS(dist) / (localAccel / 2))^.5) * localAccel) * (dist/MAX(ABS(dist),0.0001)),-speedLimit),speedLimit).
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