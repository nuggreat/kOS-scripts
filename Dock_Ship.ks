//intended to be used with lib_dock_v1
PARAMETER transSpeed IS 5,stationMove IS FALSE.
FOR lib IN LIST("lib_dock","lib_rocket_utilities","lib_orbital_math") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNPATH("1:/lib/" + lib + ".ks"). }}
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

LOCAL closeData IS close_aproach_scan(SHIP,station,TIME:SECONDS,600).
PRINT "closets approach " + ROUND(closeData["dist"],2) + "m".
UNTIL closeData["dist"] < 1500 {
	burn_closer(1400,station,120).
	SET closeData TO close_aproach_scan(SHIP,station,TIME:SECONDS,600).
	IF closeData["dist"] < 1500 {
		relitave_stop(1000,station).
	}
}

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

LOCAL stationPortListRaw IS port_scan_of(station).
IF stationPortListRaw:LENGTH = 0 {SET stationPortListRaw TO port_scan_of(station).}

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
SET noFlyZone TO noFlyZone + no_fly_zone(SHIP,craftPort).

LOCAL axisSpeed IS axis_speed(SHIP,station).
SAS OFF.
RCS OFF.

PRINT " ".
IF axisSpeed[0]:MAG > 1 {
	relitave_stop(noFlyZone * 1.25,station).
	UNTIL (SHIP:POSITION - station:POSITION):MAG < MIN(noFlyZone * 5,500) {
		burn_closer(noFlyZone * 1.1,station,120).
		relitave_stop(noFlyZone * 1.25,station).
	}
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
ABORT OFF.

RCS ON.
LOCAL rcsThrust IS 1.//assuming 1 kN of thrust
LOCAL accelLimit IS rcsThrust / SHIP:MASS.//script is assuming the same translation thrust for all axis
LOCAL portSize IS port_to_port_size(craftPort).
translation_control_init().
IF NOT stationMove {
	IF axis_distance(craftPort,stationPort)[1] < noFlyZone {
		IF VXCL(craftPort:PORTFACING:FOREVECTOR,craftPort:POSITION - stationPort:POSITION):MAG < noFlyZone {
			UNTIL avoid_trans(noFlyZone,craftPort,stationPort,station,transSpeed,accelLimit,portSize).
		}
		RCS ON.
		UNTIL advance_trans(noFlyZone,craftPort,stationPort,station,transSpeed,accelLimit,portSize).
	}
	RCS ON.
	UNTIL align_trans(noFlyZone,craftPort,stationPort,station,transSpeed,accelLimit,portSize).
	RCS ON.
	UNTIL aquire_trans(noFlyZone,craftPort,stationPort,station,transSpeed,accelLimit,portSize).
} ELSE {
	UNTIL aquire_trans(noFlyZone,craftPort,stationPort,station,transSpeed,accelLimit,portSize).
}

} ELSE {
	PRINT "no Matching Unused Dockingports.".
}
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
WAIT 5.
RCS OFF.

//end of core logic start of functions

FUNCTION relitave_stop {
	PARAMETER distTrigger,station.
	PRINT "Coming to 0m/s Relative.".
	LOCAL relitaveVel IS station:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT.
	LOCAL engOff IS TRUE.
	LOCK STEERING TO relitaveVel.
	LOCK THROTTLE TO 0.
	LOCAL shipAcc IS SHIP:AVAILABLETHRUST / SHIP:MASS.
	LOCAL stopDist IS relitaveVel:SQRMAGNITUDE / (2 * shipAcc).
	
	LOCAL preDist IS ((SHIP:POSITION - relitaveVel:NORMALIZED * stopDist) - station:POSITION):MAG.
	WAIT 0.
	
	UNTIL relitaveVel:MAG < 0.1 {
		SET relitaveVel TO station:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT.
		SET shipAcc TO SHIP:AVAILABLETHRUST / SHIP:MASS.
		IF engOff {
			SET stopDist TO relitaveVel:SQRMAGNITUDE / (2 * shipAcc).
			LOCAL currenDist IS ((SHIP:POSITION - relitaveVel:NORMALIZED * stopDist) - station:POSITION):MAG.
			IF (preDist < currenDist) OR (currenDist < distTrigger) {
				LOCK THROTTLE TO MIN(MAX(2 - ABS(STEERINGMANAGER:ANGLEERROR),0),VDOT(relitaveVel,SHIP:FACING:FOREVECTOR) / shipAcc).
				SET engOFF TO FALSE.
			}
			SET preDist TO currenDist.
		}
		SET relitaveVel TO station:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT.
		WAIT 0.
		//CLEARSCREEN.
		//PRINT "relVel: " + relitaveVel:MAG.
		//PRINT "steerError: " + ABS(STEERINGMANAGER:ANGLEERROR).
	}
	UNLOCK THROTTLE.
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
}

FUNCTION burn_closer {
	PARAMETER distTar,station,flipTime.
	PRINT "Closing to " + ROUND(distTar,1) + "m".
	LOCAL targetPoint IS station:POSITION + normal_of_orbit(station) * distTar.
	LOCAL targetVec IS (targetPoint - SHIP:POSITION).
	LOCAL targetSpeed IS MIN(targetVec:MAG / flipTime,(SHIP:AVAILABLETHRUST / SHIP:MASS * (flipTime/60))).
	LOCAL targetVel IS targetVec:NORMALIZED * targetSpeed.
	
	LOCAL relitaveVel IS (station:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT).
	LOCAL burnVec IS targetVel - relitaveVel.
	LOCK STEERING TO burnVec.
	WAIT 0.
	
	UNTIL (burnVec):MAG < 0.1 {
		SET SHIP:CONTROL:PILOTMAINTHROTTLE TO MIN(MAX(1 - ABS(STEERINGMANAGER:ANGLEERROR),0),burnVec:MAG / (SHIP:AVAILABLETHRUST / SHIP:MASS)).
		
		SET targetPoint TO station:POSITION + normal_of_orbit(station) * distTar.
		SET targetVec TO (targetPoint - SHIP:POSITION).
		SET targetVel TO targetVec:NORMALIZED * targetSpeed.

		SET relitaveVel TO (SHIP:VELOCITY:ORBIT - station:VELOCITY:ORBIT).
		SET burnVec TO targetVel - relitaveVel.
		WAIT 0.
		//CLEARSCREEN.
		//PRINT "tarVel: " + targetVel:MAG.
		//PRINT "relVel: " + relitaveVel:MAG.
		//PRINT "dif: " + burnVec:MAG.
		//PRINT "steerError: " + ABS(STEERINGMANAGER:ANGLEERROR).
	}
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
	LOCK STEERING TO (station:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT).
}

FUNCTION avoid_trans {
	PARAMETER noFlyZone,craftPort,stationPort,station,maxTranslation,accelLimit,portSize.
	//"Moving out of No Fly Zone of Station."

	LOCAL evasionVec IS VXCL(stationPort:PORTFACING:FOREVECTOR,craftPort:POSITION - stationPort:POSITION).
	LOCAL velVec IS evasionVec:NORMALIZED * maxTranslation.

	translation_control(velVec,station,SHIP).
	print_trans((evasionVec:MAG - noFlyZone),"Avoiding the No Fly Zone of Station.",portSize).

	RETURN evasionVec:MAG > noFlyZone.
}

FUNCTION advance_trans {
	PARAMETER noFlyZone,craftPort,stationPort,station,maxTranslation,accelLimit,portSize.

	LOCAL stationForeVec IS stationPort:PORTFACING:FOREVECTOR.

	LOCAL sideVec IS VXCL(stationForeVec,craftPort:POSITION - stationPort:POSITION):NORMALIZED * noFlyZone.
	LOCAL targetPoint IS stationPort:POSITION + stationForeVec * noFlyZone + sideVec.

	LOCAL distVec IS targetPoint - craftPort:POSITION.
	LOCAL velVec IS dist_to_vel(distVec,accelLimit,maxTranslation).

	translation_control(velVec,station,SHIP).
	print_trans(distVec:MAG,"Advancing Infront of Target Port.",portSize).

	RETURN distVec:MAG < 1.
}

FUNCTION align_trans {
	PARAMETER noFlyZone,craftPort,stationPort,station,maxTranslation,accelLimit,portSize.
	
	LOCAL stationForeVec IS stationPort:PORTFACING:FOREVECTOR.
	LOCAL targetPoint IS stationPort:POSITION + stationForeVec * noFlyZone.

	LOCAL distVec IS targetPoint - craftPort:POSITION.
	LOCAL velVec IS dist_to_vel(distVec,accelLimit,maxTranslation).

	translation_control(velVec,station,SHIP).
	print_trans(distVec:MAG,"Aligning With Target Port.",portSize).

	RETURN distVec:MAG < 1.
}

FUNCTION aquire_trans {
	PARAMETER noFlyZone,craftPort,stationPort,station,maxTranslation,accelLimit,portSize.

	LOCAL stationForeVec IS stationPort:PORTFACING:FOREVECTOR.
	LOCAL errorVec IS stationPort:POSITION - craftPort:POSITION.
	LOCAL sideError IS MIN(VXCL(stationForeVec,errorVec):MAG / noFlyZone,1).
	
	LOCAL distAlong IS -VDOT(errorVec,stationForeVec).//dist to docking port only along facing vec
	LOCAL targetPoint IS stationPort:POSITION + stationForeVec * distAlong * sideError.
	
	LOCAL distVec IS targetPoint - craftPort:POSITION.
	LOCAL velVec IS dist_to_vel(distVec,accelLimit,maxTranslation).

	translation_control(velVec,station,SHIP).
	print_trans(errorVec:MAG,"Docking.",portSize).

	RETURN (errorVec:MAG < 1) OR (craftPort:STATE <> "ready").
}

FUNCTION print_trans {
	PARAMETER distDif,screenText,portSize.
	WAIT 0.
	CLEARSCREEN.
	PRINT screenText.
	PRINT " ".
	PRINT "Port Size: " + portSize.
	PRINT "Distance:  " + ROUND(distDif,1).
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