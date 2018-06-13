@LAZYGLOBAL OFF.

FUNCTION port_scan {
	PARAMETER craft, canDeploy IS TRUE.	//-----the ship that is scanned for ports-----
	LOCAL portList IS LIST().
	FOR port IN craft:DOCKINGPORTS {
		IF port:STATE = "Ready" {
			portList:ADD(list(port,port:NODETYPE,0,port:TAG)).
		} ELSE IF port:STATE = "Disabled" AND canDeploy {
			portList:ADD(list(port,port:NODETYPE,1,port:TAG)).
		}
	}
	RETURN port_sorting(portList).
}

LOCAL FUNCTION port_sorting {
	PARAMETER portList.
	LOCAL sizeConversion IS LEX(
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
	FOR port IN portList {
		IF NOT sizeConversion:KEYS:CONTAINS(port[1]) {
			sizeConversion:ADD(port[1],port[1]).
		}
	}
	LOCAL sortedList IS LIST().
	FOR sort IN sizeConversion:KEYS {
		FOR port IN portList {
			IF port[1] = sort { sortedList:ADD(LIST(port[0],sizeConversion[port[1]],port[2],port[3])). }
		}
	}
	RETURN sortedList.
}

FUNCTION port_open {
	PARAMETER port.
	IF port:STATE = "Disabled" {
		LOCAL portAminate IS port:GETMODULE("ModuleAnimateGeneric").
		LOCAL portOpen IS portAminate:ALLEVENTNAMES[0].
		portAminate:DOEVENT(portOpen).
	}
}

FUNCTION port_uid_filter {
	PARAMETER portList.
	LOCAL portListFiltered IS LIST().
	FOR port IN portList {
		portListFiltered:ADD(LIST(port[0]:UID,port[1],port[2],port[3])).
	}
	RETURN portListFiltered.
}

FUNCTION port_lock_true {
	PARAMETER shipPortList,
	stationPortList,
	portLock.
	IF portLock["match"] {
		LOCAL shipPortTrue IS uid_to_port(shipPortList,portLock["craftPort"][0]).
		LOCAL stationPortTrue IS uid_to_port(stationPortList,portLock["stationPort"][0]).
		RETURN LEX("match",TRUE,"craftPort",shipPortTrue,"stationPort",stationPortTrue).
	} ELSE {
		RETURN portLock.
	}
}

LOCAL FUNCTION uid_to_port {
	PARAMETER portList,
	portUid.
	FOR port IN portList {
		IF port[0]:UID = portUid {
			RETURN port.
		}
	}
}

//FUNCTION no_fly_zone {
//	PARAMETER craft,stationPort.
//	LOCAL bigestDist IS 0.
//	FOR p IN craft:PARTS {
//		LOCAL dist IS (p:POSITION - stationPort:POSITION):MAG.
//		IF dist > bigestDist {
//			SET bigestDist TO dist.
//		}
//	}
//	RETURN bigestDist.
//}

FUNCTION no_fly_zone {
	PARAMETER craft.	//-----the ship used for the calculation
	LOCAL partList IS craft:PARTS.
	LOCAL forDist IS dist_along_vec(partList,craft:FACING:FOREVECTOR).
	LOCAL upDist IS dist_along_vec(partList,craft:FACING:TOPVECTOR).
	LOCAL starDist IS dist_along_vec(partList,craft:FACING:STARVECTOR).
	RETURN sqrt(forDist^2+upDist^2+starDist^2).
}

FUNCTION dist_along_vec {
	PARAMETER partList,	//-----list of things to calculate the dist of-----
	compVec.				//-----the vector along which the dist is calculated-----
	LOCAL compVecLocal IS compVec:NORMALIZED.
	LOCAL posDist IS 0.
	LOCAL negDist IS 0.
	FOR p IN partList {
		LOCAL dist IS VDOT(p:POSITION, compVecLocal).
		IF dist > posDist {
			SET  posDist TO dist.
		} ELSE IF dist < negDist {
			SET negDist TO dist.
		}
	}
	RETURN (posDist - negDist).
}

FUNCTION message_wait {
	PARAMETER buffer.
	WAIT UNTIL (NOT buffer:EMPTY).
}

FUNCTION axis_speed {
	PARAMETER craft,		//the craft to calculate the speed of (craft using RCS)
	//craftPort,			//port that all speeds are relative to (craft using RCS)
	station.				//the target the speed is relative  to
	LOCAL localStation IS station.
	IF station:ISTYPE("dockingPort") { SET localStation TO station:SHIP. }
	LOCAL craftFacing IS craft:FACING.
	LOCAL relitaveSpeedVec IS craft:VELOCITY:ORBIT - localStation:VELOCITY:ORBIT.	//relitaveSpeedVec is the speed as reported by the navball in target mode as a vector along the target prograde direction
	LOCAL speedFor IS VDOT(relitaveSpeedVec, craftFacing:FOREVECTOR).	//positive is moving forwards, negative is moving backwards
	LOCAL speedTop IS VDOT(relitaveSpeedVec, craftFacing:TOPVECTOR).	//positive is moving up, negative is moving down
	LOCAL speedStar IS VDOT(relitaveSpeedVec, craftFacing:STARVECTOR).	//positive is moving right, negative is moving left
	RETURN LIST(relitaveSpeedVec,speedFor,speedTop,speedStar).
}

FUNCTION axis_distance {
	PARAMETER craftPort,	//port that all distances are relative to (craft using RCS)
	stationPort.			//port you want to dock to
	LOCAL craftFacing IS craftPort:FACING.
	IF craftPort:ISTYPE("DOCKINGPORT") { SET craftFacing TO craftPort:PORTFACING. }
	LOCAL distVec IS stationPort:POSITION - craftPort:POSITION.//vector pointing at the station port from the craft port
	LOCAL dist IS distVec:MAG.
	LOCAL distFor IS VDOT(distVec, craftFacing:FOREVECTOR).	//if positive then stationPort is ahead of craftPort, if negative than stationPort is behind of craftPort
	LOCAL distTop IS VDOT(distVec, craftFacing:TOPVECTOR).		//if positive then stationPort is above of craftPort, if negative than stationPort is below of craftPort
	LOCAL distStar IS VDOT(distVec, craftFacing:STARVECTOR).	//if positive then stationPort is to the right of craftPort, if negative than stationPort is to the left of craftPort
	RETURN LIST(dist,distFor,distTop,distStar).
}