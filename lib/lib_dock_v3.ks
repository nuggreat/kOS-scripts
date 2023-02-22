@LAZYGLOBAL OFF.
LOCAL sizeConversion TO LEX(	//converts from raw internal node types to human readable types.
	"size4","5m",				//from: NearFuture(lifters)
	"size2","2.5m",				//from: stock
	"conSize2","2.5m Con",		//from: USI konstruction
	"spinal","Spinal",			//from: NearFuture(construction)
	"octo","Octo",				//from: NearFuture(construction)
	"sizeh","Hab",				//from: kerbal planetary base systems
	"size1","1.25m",			//from: stock
	"conSize1","1.25m Con",		//from: USI konstruction
	"size0","0.625m",			//from: stock
	"conSize0","0.625m Con").	//from: USI konstruction
LOCAL sortedSizes TO LIST(//sorted sizes of node types in human readable form
	"5m",			//from: NearFuture(lifters)
	"2.5m",			//from: stock
	"2.5m Con",		//from: USI konstruction
	"Spinal",		//from: NearFuture(construction)
	"Octo",			//from: NearFuture(construction)
	"Hab",			//from: kerbal planetary base systems
	"1.25m",		//from: stock
	"1.25m Con",	//from: USI konstruction
	"0.625m",		//from: stock
	"0.625m Con").	//from: USI konstruction

FUNCTION port_scan_of {
	PARAMETER craft, canDeploy TO TRUE.	//-----the ship that is scanned for ports-----
	LOCAL portLex TO LEX().

	FOR port IN craft:DOCKINGPORTS {
		LOCAL pNodeTypeRaw TO port:NODETYPE.
		IF NOT sizeConversion:HASKEY(pNodeTypeRaw) { //check for unknown port sizes
			sizeConversion:ADD(pNodeTypeRaw,pNodeTypeRaw).
			sortedSizes:ADD(pNodeTypeRaw).
		}
		LOCAL pNodeTypeStr TO sizeConversion[pNodeTypeRaw].
		
		IF NOT portLex:HASKEY(pNodeTypeStr) {//adding new node type to lexicon of ports
			portLex:ADD(pNodeTypeStr,LIST()).
		}

		IF port:STATE = "Ready" {
			portLex[pNodeTypeStr]:ADD(port).
		} ELSE IF port:STATE = "Disabled" AND canDeploy {
			portLex[pNodeTypeStr]:ADD(port).
		}
	}

	FOR key IN portLex:KEYS {//removing unused keys
		IF portLex[key]:LENGTH = 0 {
			portLex:REMOVE(key).
		}
	}
	
	LOCAL haveSizes TO LIST().
	portLex:ADD("sortedSizes",haveSizes).
	FOR pSize IN sortedSizes {
		IF portLex:HASKEY(pSize) {
			haveSizes:ADD(pSize).
		}
	}
	
	RETURN portLex.
}

FUNCTION port_to_port_size {
	PARAMETER port.
	IF port:ISTYPE("List") {
		LOCAL returnList TO LIST().
		FOR p IN port { returnList:ADD(port_to_port_size(p)). }
		RETURN returnList.
	} ELSE {
		LOCAL pNodeTypeRaw TO port:NODETYPE.
		IF NOT sizeConversion:HASKEY(pNodeTypeRaw) {
			sizeConversion:ADD(pNodeTypeRaw).
		}
		RETURN sizeConversion[pNodeTypeRaw].
	}
}

FUNCTION port_open {
	PARAMETER port.
	IF port:ISTYPE("DockingPort") { IF (port:STATE = "Disabled") {
		IF port:HASMODULE("ModuleAnimateGeneric") {
			LOCAL portAminate TO port:GETMODULE("ModuleAnimateGeneric").
			LOCAL portOpen TO portAminate:ALLEVENTNAMES[0].
			portAminate:DOEVENT(portOpen).
		}
	}}
}

FUNCTION port_close {
	PARAMETER port.
	IF port:ISTYPE("DockingPort") { IF port:STATE = "Ready" {
		IF port:HASMODULE("ModuleAnimateGeneric") {
			LOCAL portAminate TO port:GETMODULE("ModuleAnimateGeneric").
			LOCAL portClose TO portAminate:ALLEVENTNAMES[0].
			portAminate:DOEVENT(portClose).
		}
	}}
}

FUNCTION port_uid_filter {
	PARAMETER portLex.
	LOCAL portLexFiltered TO LEX().//will be LEX(portSize,LIST(portUid,portDeployFlag,portTag)
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
		LOCAL shipPortTrue TO uid_to_port(shipPortLex,portLock["craftPort"][0]).
		LOCAL stationPortTrue TO uid_to_port(stationPortLex,portLock["stationPort"][0]).
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
	LOCAL returnList TO LIST().
	FOR shipSize IN portLex1["sortedSizes"] {
		IF portLex2:HASKEY(shipSize){
			returnList:ADD(shipSize).
		}
	}
	RETURN returnList.
}

FUNCTION no_fly_zone {
	PARAMETER station,stationPort.
	LOCAL bigestDist TO 0.
	FOR p IN station:PARTS {
		LOCAL dist TO (p:POSITION - stationPort:POSITION):MAG.
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

FUNCTION dist_to_vel {
	PARAMETER distVec,accel,maxVel.
	LOCAL targetVel TO MIN(SQRT(2 * distVec:MAG * accel),maxVel).
	RETURN distVec:NORMALIZED * targetVel.
}

FUNCTION axis_speed_dist {
	PARAMETER craft,
	station.
	WAIT 0.
	LOCAL craftFacing,
	LOCAL craftVel,
	LOCAL craftPos,
	LOCAL stationVel,
	LOCAL stationPos.
	LOCAL relVelRaw TO craftVel - stationVel.// is the prograde vector as reported by the navball in target mode
	LOCAL relVelShip TO relVelRaw * craftFacing.//rotates the relative velocity vector from SOI-RAW to SOI-SHIP frame with x mapped to fore, y mapped to top, z mapped to star
	LOCAL relDistRaw TO craftPos - stationPos.//vector pointing at the station port from the craft port
	LOCAL relDistShip TO relDistRaw * craftFacing.//rotates the distance vector from SHIP-RAW to SHIP-SHIP frame with x mapped to fore, y mapped to top, z mapped to star
	RETURN LEX(
		"vel",LIST(relVelShip, relVelShip:x, relVelShip:y, relVelShip:z),
		"dist",LIST(relDistShip, relDistShip:x, relDistShip:y, relDistShip:z)
	).
	
}

FUNCTION axis_speed {
	PARAMETER craft,		//the craft to calculate the speed of (craft using RCS)
	station.				//the target the speed is relative  to
	LOCAL localStation TO target_craft(station).
	LOCAL localCraft TO target_craft(craft).
	LOCAL craftFacing TO localCraft:FACING.
	// IF craft:ISTYPE("DOCKINGPORT") { SET craftFacing TO craft:PORTFACING. }
	LOCAL relVelVecRaw TO localCraft:VELOCITY:ORBIT - localStation:VELOCITY:ORBIT.	// is the prograde vector as reported by the navball in target mode as a vector along the target prograde direction
	// LOCAL velVelVecShip TO relVelVecRaw * craftFacing. //rotates the relative velocity vector from SOI-RAW to SOI-SHIP frame with x mapped to fore, y mapped to top, z mapped to star
	// RETURN LIST(relVelVecRaw, velVelVecShip:x, velVelVecShip:y, velVelVecShip:z).
	LOCAL speedFor TO VDOT(relVelVecRaw, craftFacing:FOREVECTOR).	//positive is moving forwards, negative is moving backwards
	LOCAL speedTop TO VDOT(relVelVecRaw, craftFacing:TOPVECTOR).	//positive is moving up, negative is moving down
	LOCAL speedStar TO VDOT(relVelVecRaw, craftFacing:STARVECTOR).	//positive is moving right, negative is moving left
	RETURN LIST(relVelVecRaw, speedFor, speedTop, speedStar).
}

FUNCTION axis_distance {
	PARAMETER craft,	//port that all distances are relative to (craft using RCS)
	station.			//port you want to dock to
	LOCAL craftFacing TO target_craft(craft):FACING.
	// IF craft:ISTYPE("DOCKINGPORT") { SET craftFacing TO craft:PORTFACING. }
	LOCAL distVecRaw TO station:POSITION - craft:POSITION.//vector pointing at the station port from the craft port
	// LOCAL distVecShip TO distVecRaw * craftFacing. //rotates the distance vector from SHIP-RAW to SHIP-SHIP frame with x mapped to fore, y mapped to top, z mapped to star
	// RETURN LIST(distVecShip:MAG, distVecShip:x, distVecShip:y, distVecShip:z).
	LOCAL distFor TO VDOT(distVecRaw, craftFacing:FOREVECTOR).	//if positive then stationPort is ahead of craftPort, if negative than stationPort is behind of craftPort
	LOCAL distTop TO VDOT(distVecRaw, craftFacing:TOPVECTOR).		//if positive then stationPort is above of craftPort, if negative than stationPort is below of craftPort
	LOCAL distStar TO VDOT(distVecRaw, craftFacing:STARVECTOR).	//if positive then stationPort is to the right of craftPort, if negative than stationPort is to the left of craftPort
	RETURN LIST(distVecRaw:MAG, distFor, distTop, distStar).
}

//    PID setup PIDLOOP(kP,kI,kD,min,max)
LOCAL PIDfore TO PIDLOOP(4,0.1,0.01,-1,1).
LOCAL PIDtop  TO PIDLOOP(4,0.1,0.01,-1,1).
LOCAL PIDstar TO PIDLOOP(4,0.1,0.01,-1,1).
LOCAL RCSdeadZone TO 0.05.//rcs will not fire below this value
LOCAL desiredFore TO 0.
LOCAL desiredTop TO 0.
LOCAL desiredStar TO 0.

FUNCTION translation_control {
	PARAMETER desiredVelVec,tar,craft.
	WAIT 0.
	LOCAL shipFacing TO craft:FACING.
	LOCAL axisSpeed TO axis_speed(craft,tar).
	//PRINT "velocityError: " + ROUND((desiredVelocityVec - axisSpeed[0]):MAG,2).
	SET PIDfore:SETPOINT TO VDOT(desiredVelVec,shipFacing:FOREVECTOR).
	SET PIDtop:SETPOINT TO VDOT(desiredVelVec,shipFacing:TOPVECTOR).
	SET PIDstar:SETPOINT TO VDOT(desiredVelVec,shipFacing:STARVECTOR).
	
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