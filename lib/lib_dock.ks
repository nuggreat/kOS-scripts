@LAZYGLOBAL OFF.
LOCAL lib_dock_lex IS LEX("sizeConversion",LEX(
	"size4","5m",				//from: NearFuture(lifters)
	"size2","2.5m",				//from: stock
	"conSize2","2.5m Con",		//from: USI konstruction
	"spinal","Spinal",			//from: NearFuture(construction)
	"octo","Octo",				//from: NearFuture(construction)
	"sizeh","Hab",				//from: kerbal planetary base systems
	"size1","1.25m",			//from: stock
	"conSize1","1.25m Con",		//from: USI konstruction
	"size0","0.625m",			//from: stock
	"conSize0","0.625m Con")).	//from: USI konstruction

FUNCTION port_scan_of {
	PARAMETER craft, canDeploy IS TRUE.	//-----the ship that is scanned for ports-----
	LOCAL portLex IS LEX().
	LOCAL sizeConversion IS lib_dock_lex["sizeConversion"].

	LOCAL portLex IS LEX().//adding keys to lex in order of size
	FOR key IN sizeConversion:KEYS {
		portLex:ADD(sizeConversion[key],LIST()).
	}

	FOR port IN craft:DOCKINGPORTS {
		IF NOT sizeConversion:KEYS:CONTAINS(port:NODETYPE) {//check for unknown port sizes
			sizeConversion:ADD(port:NODETYPE,port:NODETYPE).
			portLex:ADD(sizeConversion[port:NODETYPE],LIST()).
		}

		IF port:STATE = "Ready" {
			portLex[sizeConversion[port:NODETYPE]]:ADD(port).
		} ELSE IF port:STATE = "Disabled" AND canDeploy {
			portLex[sizeConversion[port:NODETYPE]]:ADD(port).
		}
	}

	FOR key IN portLex:KEYS {//removing unused keys
		IF portLex[key]:LENGTH = 0 {
			portLex:REMOVE(key).
		}
	}

	RETURN portLex.
}

FUNCTION port_to_port_size {
	PARAMETER port.
	IF port:ISTYPE("List") {
		LOCAL returnList IS LIST().
		FOR p IN port { returnList:ADD(port_to_port_size(p)). }
		RETURN returnList.
	} ELSE {
		IF NOT lib_dock_lex["sizeConversion"]:HASKEY(port:NODETYPE) {
			lib_dock_lex["sizeConversion"]:ADD(port:NODETYPE,port:NODETYPE).
		}
		RETURN lib_dock_lex["sizeConversion"][port:NODETYPE].
	}
}

FUNCTION port_open {
	PARAMETER port.
	IF port:ISTYPE("DockingPort") { IF (port:STATE = "Disabled") {
		IF port:HASMODULE("ModuleAnimateGeneric") {
			LOCAL portAminate IS port:GETMODULE("ModuleAnimateGeneric").
			LOCAL portOpen IS portAminate:ALLEVENTNAMES[0].
			portAminate:DOEVENT(portOpen).
		}
	}}
}

FUNCTION port_close {
	PARAMETER port.
	IF port:ISTYPE("DockingPort") { IF port:STATE = "Ready" {
		IF port:HASMODULE("ModuleAnimateGeneric") {
			LOCAL portAminate IS port:GETMODULE("ModuleAnimateGeneric").
			LOCAL portClose IS portAminate:ALLEVENTNAMES[0].
			portAminate:DOEVENT(portClose).
		}
	}}
}

FUNCTION port_uid_filter {
	PARAMETER portLex.
	LOCAL portLexFiltered IS LEX().//will be LEX(portSize,LIST(portUid,portDeployFlag,portTag)
	FOR key IN portLex:KEYS {
		portLexFiltered:ADD(key,LIST()).
		FOR port IN portLex[key]{
			IF port:STATE = "Ready" {
				portLexFiltered[key]:ADD(LIST(port:UID,0,port:TAG)).
			} ELSE IF port:STATE = "Disabled" {
				portLexFiltered[key]:ADD(LIST(port:UID,1,port:TAG)).
			}
		}
	}
	RETURN portLexFiltered.
}

FUNCTION port_lock_true {
	PARAMETER shipPortLex,
	stationPortLex,
	portLock.
	IF portLock["match"] {
		LOCAL shipPortTrue IS uid_to_port(shipPortLex,portLock["craftPort"][0]).
		LOCAL stationPortTrue IS uid_to_port(stationPortLex,portLock["stationPort"][0]).
		RETURN LEX("match",TRUE,"craftPort",shipPortTrue,"stationPort",stationPortTrue).
	} ELSE {
		RETURN portLock.
	}
}

LOCAL FUNCTION uid_to_port {
	PARAMETER portLex,
	portUid.
	FOR key IN portLex:KEYS {
		FOR port IN portLex[key]{
			IF port:UID = portUid {
				RETURN port.
			}
		}
	}
}

FUNCTION port_size_matching {
	PARAMETER portLex1,portLex2.
	LOCAL returnList IS LIST().
	FOR shipSize IN portLex1:KEYS {
		IF portLex2:HASKEY(shipSize){
			returnList:ADD(shipSize).
		}
	}
	RETURN returnList.
}

FUNCTION no_fly_zone {
	PARAMETER station,stationPort.
	LOCAL bigestDist IS 0.
	FOR p IN station:PARTS {
		LOCAL dist IS (p:POSITION - stationPort:POSITION):MAG.
		IF dist > bigestDist {
			SET bigestDist TO dist.
		}
	}
	RETURN bigestDist.
}

FUNCTION message_wait {
	PARAMETER buffer.
	WAIT UNTIL (NOT buffer:EMPTY).
}

FUNCTION axis_speed {
	PARAMETER craft,		//the craft to calculate the speed of (craft using RCS)
	station.				//the target the speed is relative  to
	LOCAL localStation IS target_craft(station).
	LOCAL localCraft IS target_craft(craft).
	LOCAL craftFacing IS localCraft:FACING.
	IF craft:ISTYPE("DOCKINGPORT") { SET craftFacing TO craft:PORTFACING. }
	LOCAL relitaveSpeedVec IS localCraft:VELOCITY:ORBIT - localStation:VELOCITY:ORBIT.	//relitaveSpeedVec is the speed as reported by the navball in target mode as a vector along the target prograde direction
	LOCAL speedFor IS VDOT(relitaveSpeedVec, craftFacing:FOREVECTOR).	//positive is moving forwards, negative is moving backwards
	LOCAL speedTop IS VDOT(relitaveSpeedVec, craftFacing:TOPVECTOR).	//positive is moving up, negative is moving down
	LOCAL speedStar IS VDOT(relitaveSpeedVec, craftFacing:STARVECTOR).	//positive is moving right, negative is moving left
	RETURN LIST(relitaveSpeedVec,speedFor,speedTop,speedStar).
}

FUNCTION axis_distance {
	PARAMETER craft,	//port that all distances are relative to (craft using RCS)
	station.			//port you want to dock to
	LOCAL craftFacing IS target_craft(craft):FACING.
	IF craft:ISTYPE("DOCKINGPORT") { SET craftFacing TO craft:PORTFACING. }
	LOCAL distVec IS station:POSITION - craft:POSITION.//vector pointing at the station port from the craft port
	LOCAL dist IS distVec:MAG.
	LOCAL distFor IS VDOT(distVec, craftFacing:FOREVECTOR).	//if positive then stationPort is ahead of craftPort, if negative than stationPort is behind of craftPort
	LOCAL distTop IS VDOT(distVec, craftFacing:TOPVECTOR).		//if positive then stationPort is above of craftPort, if negative than stationPort is below of craftPort
	LOCAL distStar IS VDOT(distVec, craftFacing:STARVECTOR).	//if positive then stationPort is to the right of craftPort, if negative than stationPort is to the left of craftPort
	RETURN LIST(dist,distFor,distTop,distStar).
}

//    PID setup PIDLOOP(kP,kI,kD,min,max)
LOCAL PIDfore IS PIDLOOP(4,0.1,0.01,-1,1).
LOCAL PIDtop  IS PIDLOOP(4,0.1,0.01,-1,1).
LOCAL PIDstar IS PIDLOOP(4,0.1,0.01,-1,1).
LOCAL RCSdeadZone IS 0.05.//rcs will not fire below this value
LOCAL desiredFore IS 0.
LOCAL desiredTop IS 0.
LOCAL desiredStar IS 0.

FUNCTION translation_control {
	PARAMETER desiredVelocityVec,tar,craft.
	WAIT 0.
	LOCAL shipFacing IS craft:FACING.
	LOCAL axisSpeed IS axis_speed(craft,tar).
	//PRINT "velocityError: " + ROUND((desiredVelocityVec - axisSpeed[0]):MAG,2).
	SET PIDfore:SETPOINT TO VDOT(desiredVelocityVec,shipFacing:FOREVECTOR).
	SET PIDtop:SETPOINT TO VDOT(desiredVelocityVec,shipFacing:TOPVECTOR).
	SET PIDstar:SETPOINT TO VDOT(desiredVelocityVec,shipFacing:STARVECTOR).
	
	SET desiredFore TO PIDfore:UPDATE(TIME:SECONDS,axisSpeed[1]) + desiredFore.
	SET desiredTop TO PIDtop:UPDATE(TIME:SECONDS,axisSpeed[2]) + desiredTop.
	SET desiredStar TO PIDstar:UPDATE(TIME:SECONDS,axisSpeed[3]) + desiredStar.

	SET SHIP:CONTROL:FORE TO desiredFore.
	SET SHIP:CONTROL:TOP TO desiredTop.
	SET SHIP:CONTROL:STARBOARD TO desiredStar.
	
	IF ABS(desiredFore) > RCSdeadZone { SET desiredFore TO 0. }
	IF ABS(desiredTop) > RCSdeadZone { SET desiredTop TO 0. }
	IF ABS(desiredStar) > RCSdeadZone { SET desiredStar TO 0. }
}

FUNCTION translation_control_init {
	PIDfore:RESET().
	PIDtop:RESET().
	PIDstar:RESET().
	SET desiredFore TO 0. 
	SET desiredTop TO 0. 
	SET desiredStar TO 0.
}

FUNCTION target_craft {
	PARAMETER tar.
	IF tar:ISTYPE("Vessel") {
		RETURN tar.
	} ELSE {
		RETURN tar:SHIP.
	}
}