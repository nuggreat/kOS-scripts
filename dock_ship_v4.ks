//intended to be used with lib_dock_v1
PARAMETER transSpeed IS 5,stationMove IS FALSE.
FOR lib IN LIST("lib_dock","lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNPATH("1:/lib/" + lib + ".ks"). }}
control_point().
WAIT UNTIL active_engine().
CLEARSCREEN.
ABORT OFF.

LOCAL craftPortListRaw IS port_scan_of(SHIP).
IF craftPortListRaw:LENGTH = 0 {SET craftPortListRaw TO port_scan_of(SHIP).}
LOCAL buffer IS SHIP:MESSAGES.
buffer:CLEAR().

//PID setup PIDLOOP(kP,kI,kD,min,max)
SET forRCS_PID TO PIDLOOP(4,0.02,0,-1,1).
SET topRCS_PID TO PIDLOOP(4,0.02,0,-1,1).
SET starRCS_PID TO PIDLOOP(4,0.02,0,-1,1).

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
LOCAL stationPortListRaw IS port_scan_of(station).
IF stationPortListRaw:LENGTH = 0 {SET stationPortListRaw TO port_scan_of(station).}
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
LOCAL stationPortListUid IS signal:CONTENT.	//receiving stationPortList in UID form
LOCAL craftPortListUid IS port_uid_filter(craftPortListRaw).
LOCAL portLock IS port_lock(craftPortListUid,stationPortListUid,"enabled","disabled").
stationConect:SENDMESSAGE(portLock).			//sending the ports selected for use in UID form
IF portLock["match"] {
LOCAL portLock IS port_lock_true(craftPortListRaw,stationPortListRaw,portLock).	//changing the ports selected for use from UID to TYPE:PART

message_wait(buffer).
LOCAL signal IS buffer:POP().
LOCAL noFlyZone IS signal:CONTENT.	//receiving noFlyZone size

LOCAL stationPort IS portLock["stationPort"].
LOCAL craftPort IS portLock["craftPort"].

LOCAL axisSpeed IS axis_speed(SHIP,station).
SAS OFF.
RCS OFF.
PRINT " ".
PRINT "Coming to 0/0 Relitave Stop.".
IF axisSpeed[0]:MAG > 0.1 {
	LOCK STEERING TO -axisSpeed[0]:NORMALIZED.
	//LOCAL timePre IS TIME:SECONDS.
	//LOCAL done IS FALSE.
	steering_alinged_duration(TRUE,0.5,FALSE).
	UNTIL (steering_alinged_duration() >= 2.5) OR ABORT {
		SET axisSpeed TO axis_speed(SHIP,station).
	}
	//UNTIL done {
	//	SET axisSpeed TO axis_speed(SHIP,station).
	//	LOCAL angleTo IS ABS(STEERINGMANAGER:ANGLEERROR).
	//	IF angleTo < 0.5 {
	//		IF (TIME:SECONDS - timePre) >= 2.5 { SET done TO TRUE. }
	//	} ELSE {
	//		SET timePre TO TIME:SECONDS.
	//		SET done TO ABORT.
	//	}
	//	WAIT 0.01.
	//}
	ABORT OFF.

	LOCAL done IS FALSE.
	//SET done TO FALSE.
	UNTIL done {
		SET axisSpeed TO axis_speed(SHIP,station).
		LOCAL stationSpeed IS -axisSpeed[1].
		LOCAL shipAcceleration IS SHIP:AVAILABLETHRUST / SHIP:MASS.
		SET SHIP:CONTROL:PILOTMAINTHROTTLE TO MAX(MIN(ABS(stationSpeed) / (shipAcceleration * 1.25),1),0.01).
		WAIT 0.01.
		SET done TO stationSpeed < 0.05 OR ABORT.
	}
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
}
RCS OFF.
ABORT OFF.
PRINT "Ship at 0/0 Relitave to Target.".
PRINT " ".

port_open(craftPort).

PRINT "Waiting for Station to Stablise.".
craftPort:CONTROLFROM().
LOCK STEERING TO LOOKDIRUP(-stationPort:PORTFACING:FOREVECTOR, stationPort:PORTFACING:TOPVECTOR).
message_wait(buffer).
SET signal TO buffer:POP().

PRINT "Alineing to Target.".
steering_alinged_duration(TRUE,0.5,TRUE).
WAIT UNTIL (steering_alinged_duration() >= 5) OR ABORT.
//LOCAL timePre IS TIME:SECONDS.
//LOCAL done IS FALSE.
//SET done TO FALSE.
//UNTIL done {
//	LOCAL angleTo IS ABS(STEERINGMANAGER:ANGLEERROR) + ABS(STEERINGMANAGER:ROLLERROR).
////	LOCAL angleTo IS VANG(craftPort:PORTFACING:FOREVECTOR, -stationPort:PORTFACING:FOREVECTOR) + VANG(craftPort:PORTFACING:TOPVECTOR, stationPort:PORTFACING:TOPVECTOR).
//	IF angleTo < 0.5 {
//		IF (TIME:SECONDS - timePre) >= 5 { SET done TO TRUE. }
//	} ELSE {
//		SET timePre TO TIME:SECONDS.
//		SET done TO ABORT.
//	}
//	WAIT 0.01.
//}
ABORT OFF.

RCS ON.
LOCAL reffList IS LIST(craftPort,stationPort,transSpeed).
IF NOT stationMove {
	IF axis_distance(craftPort,stationPort)[1] < noFlyZone {
		translate(reffList,"Moving out of No Fly Zone of Station.",TRUE,LIST(0,1,1),noFlyZone).
		RCS ON.
		translate(reffList,"Translating Infront of Target Port.",FALSE,LIST(1,0,0),LIST(noFlyZone,0,0),1).
	}
	RCS ON.
	translate(reffList,"Aligning With Target Port.",FALSE,LIST(0,1,1),LIST(0,0,0),0.5).
	RCS ON.
	translate(reffList,"Docking.",FALSE,LIST(1,1,1),LIST(0,0,0)).
} ELSE {
	translate(reffList,"Docking.",FALSE,LIST(1,0,0),LIST(0,0,0)).
}

} ELSE {
	PRINT "no Matching Unused Dockingports.".
}
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
WAIT 5.
RCS OFF.

//end of core logic start of functions

//ANGLEAXIS(degreesOfRotation,SHIP:FACING:FOREVECTOR) * (LOOKDIRUP(-TARGET:PORTFACING:FOREVECTOR,TARGET:PORTFACING:TOPVECTOR))

FUNCTION translate {
	PARAMETER neededRef,screenText,leaveNoFlyZone,vecMode,distTar,minDist IS 0.1,translationAccel IS 0.04.
	LOCAL craftPort IS neededRef[0]. LOCAL stationPort IS neededRef[1]. LOCAL station IS stationPort:SHIP. LOCAL maxSpeed IS neededRef[2].
	LOCAL portSize IS port_to_port_size(craftPort).
	LOCAL axisSpeed IS axis_speed(SHIP,station).
	LOCAL axisDist IS axis_distance(craftPort,stationPort).

	LOCAL  forDistDif IS 0.
	LOCAL  topDistDif IS 0.
	LOCAL starDistDif IS 0.
	LOCAL distDif IS 0.
	LOCAL noFlyDist IS 0.

	IF vecMode[0] = 0 { SET forRCS_PID:SETPOINT TO 0. }
	IF vecMode[1] = 0 { SET topRCS_PID:SETPOINT TO 0. }
	IF vecMode[2] = 0 {SET starRCS_PID:SETPOINT TO 0. }
	IF NOT leaveNoFlyZone {
		IF vecMode[0] = 1 { SET forDistDif TO axisDist[1] - distTar[0]. }
		IF vecMode[1] = 1 { SET topDistDif TO axisDist[2] - distTar[1]. }
		IF vecMode[2] = 1 {SET starDistDif TO axisDist[3] - distTar[2]. }
		SET distDif TO SQRT(forDistDif^2 + topDistDif^2 + starDistDif^2).
	} ELSE {
		IF vecMode[0] = 1 { SET forRCS_PID:SETPOINT TO maxSpeed * -(axisDist[1] / ABS(axisDist[1])). }
		IF vecMode[1] = 1 { SET topRCS_PID:SETPOINT TO maxSpeed * -(axisDist[2] / ABS(axisDist[2])). }
		IF vecMode[2] = 1 {SET starRCS_PID:SETPOINT TO maxSpeed * -(axisDist[3] / ABS(axisDist[3])). }
		SET noFlyDist TO MAX(axisDist[1]^2 * vecMode[0] + axisDist[2]^2 * vecMode[1] + axisDist[3]^2 * vecMode[2],1)^0.5.
		SET distDif TO distTar - noFlyDist.
	}

	LOCAL done IS distDif < minDist OR (stationPort:STATE = "Docked (docker)") OR (stationPort:STATE = "Docked (dockee)").
	
	LOCAL trigClear IS FALSE.
	ON (stationPort:STATE OR trigClear) {
		IF stationPort:STATE <> "Ready" AND NOT trigClear {
			SET done TO TRUE.
		}
	}
	
	UNTIL done {
		SET axisDist TO axis_distance(craftPort,stationPort).
		SET axisSpeed TO axis_speed(SHIP,station).

		IF leaveNoFlyZone {
			SET noFlyDist TO MAX(SQRT(axisDist[1]^2 * vecMode[0] + axisDist[2]^2 * vecMode[1] + axisDist[3]^2 * vecMode[2]),1).
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
			SET distDif TO SQRT(forDistDif^2 + topDistDif^2 + starDistDif^2).
		}

		LOCAL timeS IS TIME:SECONDS.
		SET SHIP:CONTROL:FORE TO forRCS_PID:UPDATE(timeS,axisSpeed[1]).
		SET SHIP:CONTROL:TOP TO topRCS_PID:UPDATE(timeS,axisSpeed[2]).
		SET SHIP:CONTROL:STARBOARD TO starRCS_PID:UPDATE(timeS,axisSpeed[3]).

		WAIT 0.01.
		CLEARSCREEN.
		PRINT screenText.
		PRINT " ".
		PRINT "Port Size: " + portSize.
		PRINT "Distance:  " + ROUND(distDif,1).

		SET done TO (distDif < minDist) OR (stationPort:STATE = "Docked (docker)") OR (stationPort:STATE = "Docked (dockee)") OR (axisDist[0] < 1.5).
	}
	SET trigClear TO TRUE.
	SET SHIP:CONTROL:FORE TO 0.
	SET SHIP:CONTROL:TOP TO 0.
	SET SHIP:CONTROL:STARBOARD TO 0.
}

FUNCTION RCS_decel_setpoint {
	PARAMETER accel,dist,speedLimit,deadZone.
	LOCAL localAccel IS accel.
	LOCAL posNeg IS 1.
	IF dist < 0 { SET posNeg TO -1. }
	IF ABS(dist) < deadZone { SET localAccel to accel / 10. }
	RETURN MIN(MAX((SQRT(2 * ABS(dist) / localAccel) * localAccel) * posNeg,-speedLimit),speedLimit).
}

FUNCTION port_lock {
	PARAMETER craftPortLex,stationPortLex,use,ignore.
	//LOCAL matchingSizeList IS port_size_matching(craftPortLex,stationPortLex).

	LOCAL matchingPort IS LEX("match",FALSE).
	FOR pSize IN port_size_matching(craftPortLex,stationPortLex) {
		FOR shipP IN craftPortLex[pSize] { FOR stationP IN stationPortLex[pSize] {
			IF shipP[1] = stationP[1] {
				IF ignore = -99999 OR ((shipP[2] <> ignore) AND (stationP[2] <> ignore)) {
					IF use = -99999 OR ((shipP[2] = use) AND (stationP[2] = use)) {
						RETURN LEX("match",TRUE,"craftPort",shipP,"stationPort",stationP).
					}
					IF use <> -99999 AND ((shipP[2] = use) OR (stationP[2] = use)) AND (NOT matchingPort["match"]) {
						SET matchingPort TO LEX("match",TRUE,"craftPort",shipP,"stationPort",stationP).
					}
				}
			}
		}}
	}
	IF matchingPort["match"] {
		RETURN matchingPort.
	} ELSE IF use <> -99999 {
		PRINT "Overriding Port Priority Tag".
		RETURN port_lock(craftPortLex,stationPortLex,-99999,ignore).
	} ELSE IF ignore <> -99999{
		PRINT "Overriding Port Disable Tag".
		RETURN port_lock(craftPortLex,stationPortLex,-99999,-99999).
	} ELSE {
		RETURN LEX("match",FALSE).
	}
}