//NOTES FOR USE: user must set default for this, deorbit, and resupply scripts
//  scripts expects for there to only be a single docking port in use on the on the resupply craft
//    this is because at this time there is no way to tell the script which port the resupply craft should be undock
LOCAL defaultPath IS "1:/data/station_resupply_default.json".
LOCAL defautlTar IS "Default not set".
IF EXISTS(defaultPath) {
	LOCAL defaultData IS READJSON(defaultPath).
	SET defautlTar TO defaultData[0].
}

PARAMETER tarCraftName IS defautlTar,setDefault IS FALSE.
IF NOT EXISTS("1/lib/lib_geochordnate.ks") { COPYPATH("0:/lib/lib_geochordnate.ks","1:/lib/lib_geochordnate.ks"). }
FOR lib IN LIST("lib_rocket_utilities","lib_geochordnate") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNPATH("1:/lib/" + lib + ".ks"). }}

IF tarCraftName:ISTYPE("vessel") {
	SET tarCraftName TO tarCraftName:NAME.
}

LOCAL tarCraft IS str_to_types(tarCraftName,TRUE,TRUE,FALSE,FALSE,TRUE,FALSE).

IF setDefault {
	IF NOT EXISTS("1:/data/") {CREATEDIR("1:/data/").}
	LOCAL tarName IS tarCraft:NAME.
	WRITEJSON(LIST(tarName),defaultPath).
}

IF (NOT tarCraft:ISTYPE("boolean")) OR (tarCraft = FALSE) {//the tarCraft is a valid craft and can be targeted 
	SET TARGET TO tarCraft.
	
	RUN Dock_to_Station.
	RUN Resupply.
	CLEARSCREEN.
	PRINT "Transfer Done Undocking".
	undock_and_depart().
	
	RUN Deorbit(TRUE).
}

FUNCTION undock_and_depart {
	LOCAL coreElement IS get_core_element().
	LOCAL port IS get_docked_port(coreElement).
	port:CONTROLFROM().
	WAIT 0.
	port:UNDOCK().
	WAIT 0.
	RCS ON.
	LOCAL steerDir IS SHIP:FACING.
	LOCK STEERING TO steerDir.
	SET SHIP:CONTROL:FORE TO -1.
	WAIT 5.
	SET SHIP:CONTROL:FORE TO 0.
	RCS OFF.
}

FUNCTION get_core_element {
	LOCAL corePart IS CORE:PART.
	FOR element IN SHIP:ELEMENTS {
		FOR par IN element:PARTS {
			IF par = corePart {
				RETURN element.
			}
		}
	}
}

FUNCTION get_docked_port {
	PARAMETER element.
	FOR port IN element:DOCKINGPORTS {
		IF port:STATE:CONTAINS("docked") {
			RETURN port.
		}
	}
}
