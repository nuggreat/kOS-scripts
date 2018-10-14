//TODO: 1) status display of some kind
//TODO: 2) vector facing only as a translation control mode
//TODO: 3) change speed/dist modes for docking to be individual for each axis
//TODO: 4) change angular velocity compensation to use the craft running this script as the lever arm not the target port

CLEARGUIS().
CLEARSCREEN.
IF NOT EXISTS ("1:/lib/lib_mis_utilities.ks") { COPYPATH("0:/lib/lib_mis_utilities.ks","1:/lib/lib_mis_utilities.ks"). }
FOR lib IN LIST("lib_dock","lib_rocket_utilities","lib_mis_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
LOCAL varConstants IS LEX("numList",LIST("0","1","2","3","4","5","6","7","8","9"),"translationPIDs",LIST("Fore","Star","Top")).

LOCAL scriptData IS LEX("done",FALSE).
LOCAL burnData IS LEX("stop",FALSE,"steerVec",SHIP:FACING:FOREVECTOR,"throttle",0).

LOCAL portData IS LEX("matchingSize",LIST(),"shipList",LIST(),"targetList",LIST(),
"highlighting",LIST(),"targetPorts",LIST(),"changedTarget",FALSE,"isKlaw",FALSE).

LOCAL translateData IS LEX("steerVec",SHIP:FACING:FOREVECTOR,
"foreVal",0,"topVal",0,"starVal",0,
"pitch",0,"yaw",0,"roll",0,"topSpeed",5,"accel",0.05,
"stop",FALSE,"targetIsType",TRUE,"targetPorts",FALSE,"distControl",TRUE,"oldTarget",LIST(-1,-1)).

//           PID setup PIDLOOP(kP,kI,kD,min,max)
LOCAL PID IS LEX(	"Fore",PIDLOOP(4,0.1,0.01,-1,1),
					"Star",PIDLOOP(4,0.1,0.01,-1,1),
					 "Top",PIDLOOP(4,0.1,0.01,-1,1)).

LOCAL interface IS GUI(500).
 LOCAL iModeSelect IS interface:ADDHBOX.
 LOCAL imsBurn IS iModeSelect:ADDRADIOBUTTON("Burn Mode",TRUE).
 LOCAL imsPortSelect IS iModeSelect:ADDRADIOBUTTON("Port Selection",FALSE).
 LOCAL imsDockingMode IS iModeSelect:ADDRADIOBUTTON("Translation Mode",FALSE).

 LOCAL iLabel0 IS interface:ADDLABEL(" ").

 LOCAL iBurn IS interface:ADDVBOX.
  LOCAL ibLabel0 IS iBurn:ADDLABEL("Burn Options").
  LOCAL ibBurnMode IS iBurn:ADDHBOX.
   LOCAL ibbmRetro IS ibBurnMode:ADDRADIOBUTTON("Kill Relative Speed",TRUE).
    SET ibbmRetro:STYLE:ALIGN TO "LEFT".
   LOCAL ibbmTarget IS ibBurnMode:ADDRADIOBUTTON("Burn Towards Target",FALSE).
    SET ibbmTarget:STYLE:ALIGN TO "CENTER".
   LOCAL ibbmClose IS ibBurnMode:ADDRADIOBUTTON("Close With Target",FALSE).
    SET ibbmClose:STYLE:ALIGN TO "RIGHT".
  LOCAL ibSpeedLayout IS iBurn:ADDHLAYOUT.
   LOCAL ibslLabel0 IS ibSpeedLayout:ADDLABEL("Minimum Relative Speed in m/s: ").//label for speed field
    SET ibslLabel0:STYLE:ALIGN TO "RIGHT".
   LOCAL ibslField IS ibSpeedLayout:ADDTEXTFIELD("0").//input for speed
    SET ibslField:STYLE:WIDTH TO 275.
  LOCAL ibDistanceLayout IS iBurn:ADDHLAYOUT.
   LOCAL ibdlLabel0 IS ibDistanceLayout:ADDLABEL("Distance To Stop At m: ").//label for distance field
    SET ibdlLabel0:STYLE:ALIGN TO "RIGHT".
   LOCAL ibdlField IS ibDistanceLayout:ADDTEXTFIELD("0").//input for distance
    SET ibdlField:STYLE:WIDTH TO 275.
  LOCAL ibStart IS iBurn:ADDBUTTON("Start Burn").
  LOCAL ibStop IS iBurn:ADDBUTTON("Abort Burn").
   ibStop:HIDE.

 LOCAL iPortSelect IS interface:ADDVBOX.
  LOCAL ipsLabel0 IS iPortSelect:ADDLABEL("Control Selection").
  LOCAL ispScan IS iPortSelect:ADDBUTTON("Scan Target for Ports").
  LOCAL ipsLabel1 IS iPortSelect:ADDLABEL(" ").
   ipsLabel1:HIDE.
  LOCAL ipsPorts IS iPortSelect:ADDVBOX.
   ipsPorts:HIDE.
   LOCAL ipspLayout0 IS ipsPorts:ADDHLAYOUT.
    LOCAL ipspl0Label0 IS ipspLayout0:ADDLABEL("Docking Port Size:").
    LOCAL ipspl0PortSize IS ipspLayout0:ADDPOPUPMENU().
	 SET ipspl0PortSize:STYLE:WIDTH TO 330.
   LOCAL ipspLayout1 IS ipsPorts:ADDHLAYOUT.
    LOCAL ipspl1Label0 IS ipspLayout1:ADDLABEL("Ship Docking Port:").
    LOCAL ipspl1PortSelectVes IS ipspLayout1:ADDPOPUPMENU().
	 SET ipspl1PortSelectVes:STYLE:WIDTH TO 330.
   LOCAL ipspLayout2 IS ipsPorts:ADDHLAYOUT.
    LOCAL ipspl2Label0 IS ipspLayout2:ADDLABEL("Target Docking Port:").
    LOCAL ipspl2PortSelectTar IS ipspLayout2:ADDPOPUPMENU().
	 SET ipspl2PortSelectTar:STYLE:WIDTH TO 330.
   LOCAL ipspHighlight IS ipsPorts:ADDHLAYOUT.
    LOCAL ipsphHighlight IS ipspHighlight:ADDRADIOBUTTON("Turn On Port Highlighting",TRUE).
	SET ipsphHighlight:EXCLUSIVE TO FALSE.
    LOCAL ipsphRefresh IS ipspHighlight:ADDBUTTON("Refresh port Highlighting").
   LOCAL ipspSavePorts IS ipsPorts:ADDBUTTON("Select Current Ports For Docking").
  LOCAL ipsLabel1 IS iPortSelect:ADDLABEL(" ").
   ipsLabel1:HIDE.
  LOCAL ipsTarget IS iPortSelect:ADDVBOX.
   ipsTarget:HIDE.
   LOCAL ipstLabel IS ipsTarget:ADDLABEL("Selected Target Ports").
   LOCAL ipstSize IS ipsTarget:ADDLABEL(" ").
   LOCAL ipstTar IS ipsTarget:ADDLABEL(" ").
   LOCAL ipstVes IS ipsTarget:ADDLABEL(" ").
   LOCAL ipstClear IS ipsTarget:ADDBUTTON("Clear Selected Ports").

 LOCAL iTranslateMode IS interface:ADDVBOX.
  LOCAL itmLabel0 IS iTranslateMode:ADDLABEL("Translation Mode").
  LOCAL itmModes IS iTranslateMode:ADDVBOX.
   LOCAL itmmAlingnType IS itmModes:ADDHLAYOUT.
    LOCAL itmmatPort IS itmmAlingnType:ADDRADIOBUTTON("Align With Target Port",FALSE).
    LOCAL itmmatTar IS itmmAlingnType:ADDRADIOBUTTON("Align Relative to Target",TRUE).
	LOCAL itmmatFace IS itmmAlingnType:ADDRADIOBUTTON("Face Target COM",FALSE).
   LOCAL itmmMoveType IS itmModes:ADDHLAYOUT.
    LOCAL itmmmtSpeed IS itmmMoveType:ADDRADIOBUTTON("Set Speed",FALSE).
    LOCAL itmmmtDist IS itmmMoveType:ADDRADIOBUTTON("Set Distance",TRUE).
    LOCAL itmmmtSettings IS itmmMoveType:ADDRADIOBUTTON("Translation Settings",FALSE).
  LOCAL itmControl IS iTranslateMode:ADDHLAYOUT.
   LOCAL itmcStart IS itmControl:ADDBUTTON("Start Translation").
   LOCAL itmcStop IS itmControl:ADDBUTTON("Stop Translation").
    itmcStop:HIDE.
   LOCAL itmcUpdate IS itmControl:ADDBUTTON("Update Translation").
    itmcUpdate:HIDE.

  LOCAL itmNavigation IS iTranslateMode:ADDVLAYOUT.
   LOCAL itmnTarget IS itmNavigation:ADDVBOX.
    LOCAL itmntLayout0 IS itmnTarget:ADDHLAYOUT.
     LOCAL itmntl0Label0 IS itmntLayout0:ADDLABEL(" ").
	 LOCAL itmntl0GetDist IS itmntLayout0:ADDBUTTON("load Current Distance").
    LOCAL itmntLayout1 IS itmnTarget:ADDHLAYOUT.
     LOCAL itmntl0Label IS itmntLayout1:ADDLABEL("Fore/Back (+/-): ").
     LOCAL itmntl0Fore IS itmntLayout1:ADDTEXTFIELD("0").
 	 SET itmntl0Fore:STYLE:WIDTH TO 330.
    LOCAL itmntLayout2 IS itmnTarget:ADDHLAYOUT.
     LOCAL itmntl1Label IS itmntLayout2:ADDLABEL("Up/Down (+/-): ").
     LOCAL itmntl1Top IS itmntLayout2:ADDTEXTFIELD("0").
	  SET itmntl1Top:STYLE:WIDTH TO 330.
    LOCAL itmntLayout3 IS itmnTarget:ADDHLAYOUT.
     LOCAL itmntl2Label IS itmntLayout3:ADDLABEL("Left/Right (+/-): ").
     LOCAL itmntl2Star IS itmntLayout3:ADDTEXTFIELD("0").
	  SET itmntl2Star:STYLE:WIDTH TO 330.
   LOCAL itmnFacing IS itmNavigation:ADDVBOX.
    LOCAL itmnfLabel0 IS itmnFacing:ADDLABEL(" ").
    LOCAL itmnfLayout0 IS itmnFacing:ADDHLAYOUT.
     LOCAL itmnfl0Label IS itmnfLayout0:ADDLABEL("Adjust Pitch By: ").
     LOCAL itmnfl0Pitch IS itmnfLayout0:ADDTEXTFIELD("180").
	  SET itmnfl0Pitch:STYLE:WIDTH TO 330.
    LOCAL itmnfLayout1 IS itmnFacing:ADDHLAYOUT.
     LOCAL itmnfl1Label IS itmnfLayout1:ADDLABEL("Adjust Yaw By: ").
     LOCAL itmnfl1Yaw IS itmnfLayout1:ADDTEXTFIELD("0").
	  SET itmnfl1Yaw:STYLE:WIDTH TO 330.
    LOCAL itmnfLayout2 IS itmnFacing:ADDHLAYOUT.
     LOCAL itmnfl2Label IS itmnfLayout2:ADDLABEL("Adjust Roll By: ").
     LOCAL itmnfl2Roll IS itmnfLayout2:ADDTEXTFIELD("0").
	  SET itmnfl2Roll:STYLE:WIDTH TO 330.

  LOCAL itmSettings IS iTranslateMode:ADDVBOX.
   LOCAL itmsLable0 IS itmSettings:ADDLABEL("Translation Limits").
   LOCAL itmsLayout0 IS itmSettings:ADDHLAYOUT.
    LOCAL itmsl0Label IS itmsLayout0:ADDLABEL("Top Speed Limit: ").
    LOCAL itmsl0Speed IS itmsLayout0:ADDTEXTFIELD("5").
	 SET itmsl0Speed:STYLE:WIDTH TO 330.
   LOCAL itmsLable2 IS itmSettings:ADDLABEL("Acceleration Limit Only Applies to Distance Mode").
   LOCAL itmsLayout1 IS itmSettings:ADDHLAYOUT.
    LOCAL itmsl1Label IS itmsLayout1:ADDLABEL("Acceleration Limit: ").
    LOCAL itmsl1Accel IS itmsLayout1:ADDTEXTFIELD("0.05").
	 SET itmsl1Accel:STYLE:WIDTH TO 330.
   LOCAL itmsUpdate IS itmSettings:ADDBUTTON("Apply Changes").

change_menu(imsBurn).
SET iModeSelect:ONRADIOCHANGE TO change_menu@.

change_mode_burn(ibbmRetro).
SET ibBurnMode:ONRADIOCHANGE TO change_mode_burn@.
SET ibStart:ONCLICK TO run_Burn@.
SET ibStop:ONCLICK TO burn_abort@.

SET ispScan:ONCLICK TO run_port_scan@.
SET ipspl0PortSize:ONCHANGE TO port_menue_update@.
SET ipspl1PortSelectVes:ONCHANGE TO port_highlighting@.
SET ipspl2PortSelectTar:ONCHANGE TO port_highlighting@.
SET ipspSavePorts:ONCLICK TO port_save@.
SET ipstClear:ONCLICK TO port_clear@.
SET ipsphHighlight:ONTOGGLE TO enable_disable_highlight@.
SET ipsphRefresh:ONCLICK TO port_highlighting@.

change_mode_translate_facing(itmmatTar).
change_translate_type(itmmmtDist).
SET itmmAlingnType:ONRADIOCHANGE TO change_mode_translate_facing@.
SET itmmMoveType:ONRADIOCHANGE TO change_translate_type@.
SET itmsUpdate:ONCLICK TO settings_update@.
SET itmcStart:ONCLICK TO run_translate@.
SET itmcStop:ONCLICK TO stop_translation@.
SET itmcUpdate:ONCLICK TO update_translate@.
SET itmntl0GetDist:ONCLICK TO load_distance@.

RCS OFF.
SAS OFF.
ABORT OFF.

LOCAL tarPort IS FALSE.
LOCAL taskList IS LIST().
field_cycle(LIST(ibslField,ibdlField,itmnfl0Pitch,itmnfl1Yaw,itmnfl2Roll,itmntl0Fore,itmntl1Top,itmntl2Star,itmsl0Speed,itmsl1Accel)).
interface:SHOW.//set up done waiting on user input
UNTIL scriptData["done"] {
	IF taskList:LENGTH > 0 {
		FROM { LOCAL i IS taskList:LENGTH -1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
			IF taskList[i]:CALL() {
				taskList:REMOVE(i).
			}
		}
	}
	WAIT 0.01.
	IF ABORT { shutdown_stack(). }
}
interface:DISPOSE.
enable_disable_highlight(FALSE).
SAS ON.

FUNCTION field_cycle {
	PARAMETER fieldList,fieldInex IS 0.

	SET fieldList[fieldInex]:TEXT TO field_to_numbers_only(fieldList[fieldInex]).
	IF fieldInex < (fieldList:LENGTH - 1) {
		SET fieldInex TO fieldInex + 1.
		taskList:ADD(field_cycle@:BIND(fieldList,fieldInex)).
	} ELSE {
		taskList:ADD(field_cycle@:BIND(fieldList)).
	}
	RETURN TRUE.
}

FUNCTION change_menu {
	PARAMETER selectedMenu.
	PRINT "changing menu to " + selectedMenu:TEXT.
	IF selectedMenu = imsBurn {
		iBurn:SHOW.
	} ELSE {
		iBurn:HIDE.
	}
	IF selectedMenu = imsPortSelect {
		iPortSelect:SHOW.
	} ELSE {
		iPortSelect:HIDE.
	}
	IF selectedMenu = imsDockingMode {
		iTranslateMode:SHOW.
	} ELSE {
		iTranslateMode:HIDE.
	}
}

FUNCTION change_mode_burn {
	PARAMETER selectedMode.
	IF selectedMode = ibbmTarget {
		SET ibslLabel0:TEXT TO "Relative Towards Target m/s: ".
		ibSpeedLayout:SHOW.
	}
	IF selectedMode = ibbmClose {
		SET ibslLabel0:TEXT TO "Speed to Close At m/s: ".
		ibSpeedLayout:SHOW.
		ibDistanceLayout:SHOW.
	} ELSE {
		ibDistanceLayout:HIDE.
	}
	IF selectedMode = ibbmRetro {
		ibSpeedLayout:HIDE.
	}
}

FUNCTION change_mode_translate_facing {
	PARAMETER selectedMode.
	//PRINT "changing docking mode to: " + selectedMode:TEXT.

	IF selectedMode = itmmatPort {
		IF (portData["targetPorts"]:LENGTH > 0) AND NOT portData["isKlaw"] {
			itmnfLayout0:HIDE.
			itmnfLayout1:HIDE.
			SET itmnfLabel0:TEXT TO "Port Relative Adjustment".
		} ELSE {
			SET itmmatTar:PRESSED TO TRUE.
			SET imsPortSelect:PRESSED TO TRUE.
			PRINT "Mode: " + selectedMode:TEXT + ", Needs a Target Port Selected".
		}
	}
	IF selectedMode = itmmatTar {
		itmNavigation:SHOW.
		itmControl:SHOW.
		itmSettings:HIDE.
		itmnfLayout0:SHOW.
		itmnfLayout1:SHOW.
		SET itmnfLabel0:TEXT TO "Target Relative Adjustments".
	}
	IF selectedMode = itmmatFace {
		itmNavigation:SHOW.
		itmControl:SHOW.
		itmSettings:HIDE.
		itmnfLayout0:HIDE.
		itmnfLayout1:HIDE.
		SET itmnfLabel0:TEXT TO "Ship Relative Adjustments".
	}
}

FUNCTION change_translate_type {
	PARAMETER selectedType.
	IF selectedType = itmmmtDist {
		SET itmntl0Label0:TEXT TO "Target Distances in m".
		itmntl0GetDist:SHOW.
		itmNavigation:SHOW.
		itmControl:SHOW.
		itmSettings:HIDE.
	}// ELSE {
	IF selectedType = itmmmtSpeed {
		SET itmntl0Label0:TEXT TO "Target Speeds in m/s".
		itmNavigation:SHOW.
		itmControl:SHOW.
		itmSettings:HIDE.
		itmntl0GetDist:HIDE.
	}
	IF selectedType = itmmmtSettings {
		itmNavigation:HIDE.
		itmControl:HIDE.
		itmSettings:SHOW.
	}

}

FUNCTION run_Burn { IF have_valid_target {
	control_point().
	WAIT UNTIL active_engine(FALSE).
	ibStop:SHOW.
	hide_start_buttons(TRUE).
	LOCAL localTarget IS target_craft(TARGET).

	IF ibbmRetro:PRESSED {
		//taskList:ADD(retro_burn@).
		taskList:ADD(burn@:BIND(0,localTarget,0)).
		PRINT "running retro_burn".
	} ELSE {
		LOCAL targetSpeed IS get_number(ibslField,1).

		IF ibbmTarget:PRESSED {
			LOCAL speedLimit IS (localTarget:POSITION - SHIP:POSITION):MAG / 90.
			taskList:ADD(burn@:BIND(0,localTarget,MIN(targetSpeed,speedLimit))).
			PRINT "running burn_at_target".
			//taskList:ADD(burn_at_target@).
		} ELSE IF ibbmClose:PRESSED {
			LOCAL targetDist IS get_number(ibdlField,100).
			LOCAL speedLimit IS ABS((localTarget:POSITION - SHIP:POSITION):MAG - targetDist) / 90.

			taskList:ADD(burn@:BIND(0,localTarget,MIN(targetSpeed,speedLimit),targetDist)).
			PRINT "running close_to_target".
			//taskList:ADD(close_to_target@).
		}
	}
}}

FUNCTION hide_start_buttons {
	PARAMETER buttonHide.
	IF buttonHide {
		ibStart:HIDE.
		itmcStart:HIDE.
	} ELSE {
		ibStart:SHOW.
		itmcStart:SHOW.
	}
}

FUNCTION burn {
	PARAMETER burnState,localTarget,targetSpeed,targetDist IS -1.
	IF burnData["stop"] {
		SET burnData["stop"] TO FALSE.
		taskList:ADD(burn@:BIND(3,localTarget,targetSpeed,targetDist)).
		RETURN TRUE.
	}
	LOCAL tarSpeed IS targetSpeed.

	LOCAL vecToTarget IS localTarget:POSITION - SHIP:POSITION.
	LOCAL relitaveVelocityVec IS SHIP:VELOCITY:ORBIT - localTarget:VELOCITY:ORBIT.
	LOCAL shipAcceleration IS SHIP:AVAILABLETHRUST / SHIP:MASS.
	LOCAL targetVelocityVec IS vecToTarget:NORMALIZED * tarSpeed.
	LOCAL relitaveSpeed IS (targetVelocityVec - relitaveVelocityVec):MAG.
	LOCAL vecMod IS 0.
	LOCAL throtCoeficent IS 1.

	LOCAL done IS relitaveSpeed < 0.05.

	IF targetDist <> -1 {
		SET tarSpeed TO ABS(tarSpeed).
		//LOCAL deccelCoeficent IS MAX(60 / MIN(tarSpeed / shipAcceleration,1),1).
		LOCAL deccelCoeficent IS MIN(tarSpeed / 60, shipAcceleration) / (shipAcceleration * 2).
		LOCAL distToTarget IS (vecToTarget):MAG - targetDist.
		SET tarSpeed TO accel_dist_to_speed(shipAcceleration * deccelCoeficent,distToTarget,tarSpeed).
		SET targetVelocityVec TO vecToTarget:NORMALIZED * tarSpeed.
		SET throtCoeficent TO 0.5.
		SET vecMod TO 0.
		SET done TO FALSE.
		IF (ABS(distToTarget) < 10) AND (relitaveSpeed < 1) {
			taskList:ADD(burn@:BIND(0,localTarget,0)).
			PRINT "calling all stop".
			RETURN TRUE.
		}
		//SET done TO (relitaveVelocityVec:MAG < 0.05) AND (ABS(distToTarget) < 1).
		//CLEARSCREEN.
		//PRINT "relSpeed: " + ROUND(relitaveVelocityVec:MAG,2).
		//PRINT "tarSpeed: " + ROUND(tarSpeed,2).
		//PRINT "deccelCoeficent: " + ROUND(deccelCoeficent,2).
		//PRINT "dist: " + ROUND(distToTarget,2).
		//PRINT "state: " + burnData["state"] AT(0,0).
	}

	SET burnData["steerVec"] TO (targetVelocityVec - relitaveVelocityVec + (targetVelocityVec:NORMALIZED * vecMod)).

	IF burnState = 0 {
		SAS OFF.
		RCS OFF.
		//SET burnData["steerVec"] TO SHIP:FACING:FOREVECTOR.
		SET burnData["throttle"] TO 0.
		LOCK STEERING TO burnData["steerVec"].
		LOCK THROTTLE TO burnData["throttle"].
		steering_alinged_duration(TRUE,1,FALSE).
		taskList:ADD(burn@:BIND((burnState + 1),localTarget,targetSpeed,targetDist)).
		RETURN TRUE.
	} ELSE IF burnState = 1 {
		IF steering_alinged_duration() > 10 {
			taskList:ADD(burn@:BIND((burnState + 1),localTarget,targetSpeed,targetDist)).
			RETURN TRUE.
		} ELSE {
			RETURN FALSE.
		}
	} ELSE IF burnState = 2 {
		LOCAL maxThrot IS MAX(1 - LOG10(MAX(ABS(STEERINGMANAGER:ANGLEERROR) * 100,1))/3.35,0).
		//LOCAL maxThrot IS MAX(1 - ABS(STEERINGMANAGER:ANGLEERROR),0).
		//LOCAL maxThrot IS 1.
		//LOCAL speedCoeficent IS COS(MIN(ABS(STEERINGMANAGER:ANGLEERROR*10),90)).
		//PRINT "speedCoeficent: " + ROUND(speedCoeficent,2)  + "   " AT(0,0).
		SET burnData["throttle"] TO MAX(MIN(relitaveSpeed / (shipAcceleration * throtCoeficent),maxThrot),0).

		IF done {
			taskList:ADD(burn@:BIND((burnState + 1),localTarget,targetSpeed,targetDist)).
			RETURN TRUE.
		} ELSE {
			RETURN FALSE.
		}
	} ELSE IF burnState = 3 {
		UNLOCK STEERING.
		UNLOCK THROTTLE.
		SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
		PRINT "Done With Engines".
		ibStop:HIDE.
		hide_start_buttons(FALSE).
		RETURN TRUE.
	}
}

FUNCTION burn_abort {
	SET burnData["stop"] TO TRUE.
}

FUNCTION run_port_scan {
	IF have_valid_target {
		portData["shipList"]:CLEAR().
		portData["targetList"]:CLEAR().
		taskList:ADD(port_scan@:BIND(0,target_craft(TARGET))).
		ispScan:HIDE.
		ipsPorts:HIDE.
		ipsLabel1:HIDE.
	}
}

FUNCTION port_scan {
	PARAMETER scanState,targetVessel.
	IF scanState = 0 {
		portData["shipList"]:ADD(port_scan_of(SHIP)).
		IF portData["shipList"][0]:LENGTH = 0 {
			portData["shipList"]:REMOVE(0).
			portData["shipList"]:ADD(port_scan_of(SHIP)).
		}
		taskList:ADD(port_scan@:BIND(scanState + 1,targetVessel)).
		RETURN TRUE.
	} ELSE IF scanState = 1 {
		portData["targetList"]:ADD(port_scan_of(targetVessel,FALSE)).
		IF portData["targetList"][0]:LENGTH = 0 {
			portData["targetList"]:REMOVE(0).
			portData["targetList"]:ADD(port_scan_of(targetVessel,FALSE)).
		}
		taskList:ADD(port_scan@:BIND(scanState + 1,targetVessel)).
		RETURN TRUE.
	} ELSE IF scanState = 2 {
		LOCAL klawList IS SHIP:PARTSNAMED("GrapplingDevice").
		IF klawList:LENGTH > 0 {
			portData["shipList"][0]:ADD("Klaw",klawList).
			portData["targetList"][0]:ADD("Klaw",LIST()).
		}
		taskList:ADD(port_scan@:BIND(scanState + 1,targetVessel)).
		RETURN TRUE.
	} ELSE IF scanState = 3 {
		SET portData["matchingSize"] TO port_size_matching(portData["shipList"][0],portData["targetList"][0]).
		portData["shipList"]:ADD(make_port_GUI_lex(portData["shipList"][0])).
		portData["targetList"]:ADD(make_port_GUI_lex(portData["targetList"][0])).
		LOCAL klawFound IS FALSE.
		IF portData["matchingSize"]:LENGTH > 0 {
			PRINT "Matching Docking Ports Found".
			SET ipspl0PortSize:OPTIONS TO portData["matchingSize"].
			index_in_range(ipspl0PortSize).
			port_menue_update(ipspl0PortSize:VALUE).
			ipsPorts:SHOW.
			ipsLabel1:SHOW.
		}
		ispScan:SHOW.
		RETURN TRUE.
	}
}

FUNCTION make_port_GUI_lex {
//	PRINT "make Lex".
	PARAMETER portLex.
//	PRINT "portLex: " + portLex.
	LOCAL returnLex IS LEX().
	LOCAL portNumber IS 0.
	FOR key IN portLex:KEYS {
		returnLex:ADD(key,LIST()).
//		PRINT "key: " + key.
		FOR port IN portLex[key] {
			returnLex[key]:ADD("Tag: " + port:TAG + ", Port Number: " + portNumber).
			SET portNumber TO portNumber + 1.
		}
	}
//	PRINT "returnLex: " + returnLex.
	RETURN returnLex.
}

FUNCTION port_menue_update {
	PARAMETER pSize.
//	PRINT "pSize: " + pSize.
//	PRINT portData["shipList"][1].
	SET ipspl1PortSelectVes:OPTIONS TO portData["shipList"][1][pSize].
	index_in_range(ipspl1PortSelectVes).
	IF pSize = "Klaw" {
		ipspl2PortSelectTar:HIDE.
	} ELSE {
		ipspl2PortSelectTar:SHOW.
		SET ipspl2PortSelectTar:OPTIONS TO portData["targetList"][1][pSize].
		index_in_range(ipspl2PortSelectTar).
	}
	port_highlighting().
}

FUNCTION port_save {
	portData["targetPorts"]:CLEAR().
	LOCAL portSize IS ipspl0PortSize:VALUE.
	IF portSize = "Klaw" {
		portData["targetPorts"]:ADD(portData["shipList"][0][portSize][ipspl1PortSelectVes:INDEX]).
		SET portData["changedTarget"] TO TRUE.
		SET portData["isKlaw"] TO TRUE.
		SET ipstSize:TEXT TO "           Size: " + ipspl0PortSize:VALUE.
		SET ipstVes:TEXT TO "Vessel Port: " + ipspl1PortSelectVes:VALUE.
		ipstTar:HIDE.
		ipsTarget:SHOW.
		ipsLabel1:SHOW.
	} ELSE {
		portData["targetPorts"]:ADD(portData["shipList"][0][portSize][ipspl1PortSelectVes:INDEX]).
		portData["targetPorts"]:ADD(portData["targetList"][0][portSize][ipspl2PortSelectTar:INDEX]).
		SET portData["isKlaw"] TO FALSE.
		SET portData["changedTarget"] TO TRUE.
		SET ipstSize:TEXT TO "           Size: " + ipspl0PortSize:VALUE.
		SET ipstTar:TEXT TO "Target Port: " + ipspl2PortSelectTar:VALUE.
		SET ipstVes:TEXT TO "Vessel Port: " + ipspl1PortSelectVes:VALUE.
		ipstTar:SHOW.
		ipsTarget:SHOW.
		ipsLabel1:SHOW.

	}
	port_highlighting().
}

FUNCTION port_clear {
	portData["targetPorts"]:CLEAR().
	ipsTarget:HIDE.
	ipsLabel1:HIDE.
	port_highlighting().
}

FUNCTION port_highlighting {
	PARAMETER null IS FALSE.
	IF ipsphHighlight:PRESSED {
		LOCAL portSize IS ipspl0PortSize:VALUE.
		LOCAL lightBlue IS RGBA(0.25,0.75,1,2).
		LOCAL brightYellow IS RGBA(1.75,1.25,0,2).
		LOCAL brightGreen IS RGBA(0,1,0,2).
		show_highlight(FALSE).
		portData["highlighting"]:CLEAR().

		portData["highlighting"]:ADD(HIGHLIGHT(portData["shipList"][0][portSize],lightBlue)).
		portData["highlighting"]:ADD(HIGHLIGHT(portData["targetList"][0][portSize],lightBlue)).
		portData["highlighting"]:ADD(HIGHLIGHT(portData["shipList"][0][portSize][ipspl1PortSelectVes:INDEX],brightYellow)).
		IF portSize <> "Klaw" {
			portData["highlighting"]:ADD(HIGHLIGHT(portData["targetList"][0][portSize][ipspl2PortSelectTar:INDEX],brightYellow)).
		}
		FOR port IN portData["targetPorts"] {
			portData["highlighting"]:ADD(HIGHLIGHT(port,brightGreen)).
		}
		show_highlight(TRUE).
	}
}

FUNCTION enable_disable_highlight {
	PARAMETER enableDisable.
	IF enableDisable{
		ipsphRefresh:SHOW.
		port_highlighting().
	} ELSE {
		ipsphRefresh:HIDE.
		show_highlight(enableDisable).
	}
	RETURN TRUE.
}

FUNCTION show_highlight {
	PARAMETER enableDisable.
	FOR hl IN portData["highlighting"] {
		SET hl:ENABLED TO enableDisable.
	}
}

FUNCTION settings_update {
	PRINT "Updated Translate Settings".
	SET translateData["topSpeed"] TO ABS(get_number(itmsl0Speed,1)).
	SET translateData["accel"] TO get_number(itmsl1Accel,0.05).
}

FUNCTION run_translate { IF have_valid_target {
	update_translate().
	itmcStop:SHOW.
	itmcUpdate:SHOW.
	hide_start_buttons(TRUE).

	LOCAL targetPoint IS target_craft(TARGET).
	LOCAL shipPoint IS SHIP.
	IF translateData["targetIsType"] = "port" {
		SET shipPoint TO portData["targetPorts"][0].
		SET targetPoint TO portData["targetPorts"][1].
	} ELSE IF portData["isKlaw"] {
		SET shipPoint TO portData["targetPorts"][0].
	}
	PRINT shipPoint:NAME.
	SET portData["changedTarget"] TO FALSE.
	taskList:ADD(translate@:BIND(0,shipPoint,targetPoint,portData["isKlaw"])).
}}

FUNCTION update_translate { IF have_valid_target {
	PRINT "updating translation data".
	LOCAL targetPoint IS target_craft(TARGET).
	LOCAL shipPoint IS SHIP.
	SET translateData["steerVec"] TO SHIP:FACING:FOREVECTOR.

	LOCAL steerType IS "".
	SET translateData["Roll"] TO MOD(get_number(itmnfl2Roll,0),360).
	IF itmmatTar:PRESSED {
		control_point().
		SET translateData["pitch"] TO MOD(get_number(itmnfl0Pitch,0),360).
		SET translateData["Yaw"] TO MOD(get_number(itmnfl1Yaw,0),360).
		SET translateData["targetPorts"] TO FALSE.
		SET translateData["targetIsType"] TO TRUE.
		SET translateData["targetIsType"] TO "craft".
		IF portData["isKlaw"] {
			SET shipPoint TO portData["targetPorts"][0].
		}
	} ELSE IF itmmatPort:PRESSED {
		SET shipPoint TO portData["targetPorts"][0].
		SET targetPoint TO portData["targetPorts"][1].
		shipPoint:CONTROLFROM().
		SET translateData["targetPorts"] TO TRUE.
		SET translateData["targetIsType"] TO "port".
	} ELSE IF itmmatFace:PRESSED {
		SET translateData["targetIsType"] TO "com".
		IF portData["isKlaw"] {
			SET shipPoint TO portData["targetPorts"][0].
		}
	}
	IF itmmmtSpeed:PRESSED {
		SET translateData["foreVal"] TO get_number(itmntl0Fore,0).
		SET translateData["topVal"] TO get_number(itmntl1Top,0).
		SET translateData["starVal"] TO get_number(itmntl2Star,0).
		SET translateData["distControl"] TO FALSE.
	} ELSE {
	//IF itmmmtDist:PRESSED {
		LOCAL distTemp IS axis_distance(targetPoint,shipPoint).
		SET translateData["foreVal"] TO get_number(itmntl0Fore,distTemp[1]).
		SET translateData["topVal"] TO get_number(itmntl1Top,-distTemp[2]).
		SET translateData["starVal"] TO get_number(itmntl2Star,distTemp[3]).
		SET translateData["distControl"] TO TRUE.
	}
	LOCAL targetData IS LIST(shipPoint,targetPoint).
	IF translateData["oldTarget"] = LIST(-1,-1) {
		SET translateData["oldTarget"][0] TO targetData[0].
		SET translateData["oldTarget"][1] TO targetData[1].
	} ELSE IF translateData["oldTarget"][0] <> targetData[0] {
		SET portData["changedTarget"] TO TRUE.
		PRINT "update flagged change in ship point".
		SET translateData["oldTarget"][0] TO targetData[0].
	} ELSE IF  translateData["oldTarget"][1] <> targetData[1] {
		SET portData["changedTarget"] TO TRUE.
		PRINT "update flagged change in target point".
		SET translateData["oldTarget"][1] TO targetData[1].
	}
}}

FUNCTION load_distance { IF have_valid_target {
	LOCAL targetPoint IS target_craft(TARGET).
	LOCAL shipPoint IS SHIP.
	IF translateData["targetIsType"] = "tar" {
		SET shipPoint TO portData["targetPorts"][0].
		IF NOT portData["isKlaw"] {
			SET targetPoint TO portData["targetPorts"][1].
		}
	}
	LOCAL distTemp IS axis_distance(targetPoint,shipPoint).
	SET itmntl0Fore:TEXT TO ROUND(distTemp[1],2):TOSTRING.
	SET itmntl1Top:TEXT TO ROUND(-distTemp[2],2):TOSTRING.
	SET itmntl2Star:TEXT TO ROUND(distTemp[3],2):TOSTRING.
}}

FUNCTION translate {
	PARAMETER translateState,shipPoint,targetPoint,isKlaw.
	LOCAL targetFacing IS targetPoint:FACING.
	IF translation_new_target(translateState,shipPoint,targetPoint,isKlaw) { RETURN TRUE. }
	IF translateData["targetIsType"] = "port" {
		SET targetFacing TO targetPoint:PORTFACING.
		SET translateData["steerVec"] TO ANGLEAXIS(translateData["Roll"],-targetFacing:FOREVECTOR) * LOOKDIRUP(-targetFacing:FOREVECTOR, targetFacing:TOPVECTOR).
		IF shipPoint:STATE:CONTAINS("Docked") {
			taskList:ADD(shutdown_stack@).
			RETURN TRUE.
		}
	} ELSE IF translateData["targetIsType"] = "craft" {
		LOCAL steerDir IS ANGLEAXIS(-translateData["Pitch"],targetFacing:STARVECTOR) * targetFacing.
		SET steerDir TO ANGLEAXIS(translateData["Yaw"],steerDir:TOPVECTOR) * steerDir.
		SET translateData["steerVec"] TO ANGLEAXIS(translateData["Roll"],steerDir:FOREVECTOR) * steerDir.

	} ELSE IF translateData["targetIsType"] = "com" {
		SET translateData["steerVec"] TO LOOKDIRUP(targetPoint:POSITION - shipPoint:POSITION,SHIP:FACING:TOPVECTOR).
	}
	IF translateData["stop"] {
		//SET translateData["state"] TO 3.
		SET translateData["stop"] TO FALSE.
		taskList:ADD(translate@:BIND(3,shipPoint,targetPoint,isKlaw)).
		RETURN TRUE.
	}
	IF translateState = 0 {
		SAS OFF.
		LOCK STEERING TO translateData["steerVec"].
		steering_alinged_duration(TRUE,1,TRUE).
		LOCK THROTTLE TO 0.
		//SET translateData["state"] TO 1.
		FOR key IN varConstants["translationPIDs"] { PID[key]:RESET(). }
		taskList:ADD(translate@:BIND((translateState + 1),shipPoint,targetPoint,isKlaw)).
		RETURN TRUE.
	} ELSE IF translateState = 1 {
		IF steering_alinged_duration() > 1 {
			//SET translateData["state"] TO 2.
			PRINT "Starting Translation".
			delta_time("translate").
			taskList:ADD(translate@:BIND((translateState + 1),shipPoint,targetPoint,isKlaw)).
			RETURN TRUE.
		} ELSE {
			RETURN FALSE.
		}
	} ELSE IF translateState = 2 {
		IF translateData["distControl"] {
			LOCAL targetPosition IS targetPoint:POSITION.
			LOCAL vecToTarget IS targetPosition - shipPoint:POSITION.
			LOCAL controlVec IS v(0,0,0).
			IF translateData["targetIsType"] = "com" {
				//SET targetPosition TO targetPosition - (shipPoint:POSITION - targetPosition):NORMALIZED * translateData["foreVal"].
				SET targetPosition TO targetPosition - vecToTarget:NORMALIZED * translateData["foreVal"].
				SET controlVec TO controlVec + (shipPoint:FACING:TOPVECTOR * translateData["topVal"]).
				SET controlVec TO controlVec + (shipPoint:FACING:STARVECTOR * translateData["starVal"]).
			} ELSE {
				SET targetPosition TO targetPosition + (targetFacing:FOREVECTOR * translateData["foreVal"]).
				SET targetPosition TO targetPosition + (-targetFacing:TOPVECTOR * translateData["topVal"]).
				SET targetPosition TO targetPosition + (targetFacing:STARVECTOR * translateData["starVal"]).
				SET controlVec TO angular_velocity_vector(targetPoint,shipPoint).
			}
			//CLEARSCREEN.
			//PRINT "name: " + shipPoint:NAME.
			//LOCAL targetSpinVector IS angular_velocity_vector(target_craft(targetPoint),targetPosition).

			//SET vecToTarget TO (targetPosition + (targetSpinVector * delta_time("translate"))) - shipPoint:POSITION.
			SET vecToTarget TO targetPosition - shipPoint:POSITION.

			LOCAL speedCoeficent IS accel_dist_to_speed(translateData["accel"],vecToTarget:MAG,translateData["topSpeed"],0).
			//SET controlVec TO vecToTarget:NORMALIZED * speedCoeficent + targetSpinVector * 2.
			SET controlVec TO controlVec + vecToTarget:NORMALIZED * speedCoeficent.
			//PRINT "angularVelMag: " + ROUND(targetSpinVector:MAG,2).
			//PRINT "distError: " + ROUND((targetPosition - shipPoint:POSITION):MAG,2).
			//PRINT "deltaTIme: " + ROUND(delta_time("translate"),2).
			translation_control(controlVec,targetPoint,shipPoint).
		} ELSE {
			LOCAL controlVec IS v(0,0,0).
			IF translateData["targetIsType"] = "com" {
				SET controlVec TO controlVec + (shipPoint:FACING:FOREVECTOR * translateData["foreVal"]).
				SET controlVec TO controlVec + (shipPoint:FACING:TOPVECTOR * translateData["topVal"]).
				SET controlVec TO controlVec + (shipPoint:FACING:STARVECTOR * translateData["starVal"]).
			} ELSE {
				SET controlVec TO controlVec + (-targetFacing:FOREVECTOR * translateData["foreVal"]).
				SET controlVec TO controlVec + (  targetFacing:TOPVECTOR * translateData["topVal"]).
				SET controlVec TO controlVec + (-targetFacing:STARVECTOR * translateData["starVal"]).
			}
			IF controlVec:MAG > translateData["topSpeed"] {
				SET controlVec TO controlVec:NORMALIZED * translateData["topSpeed"].
			}
			translation_control(controlVec,targetPoint,shipPoint).
			RETURN FALSE.
		}
	} ELSE IF translateState = 3 {
		//SET translateData["state"] TO 0.
		RCS OFF.
		UNLOCK STEERING.
		UNLOCK THROTTLE.
		SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
		SET SHIP:CONTROL:FORE TO 0.
		SET SHIP:CONTROL:TOP TO 0.
		SET SHIP:CONTROL:STARBOARD TO 0.
		itmcStop:HIDE.
		itmcUpdate:HIDE.
		hide_start_buttons(FALSE).
		PRINT "done".
		RETURN TRUE.
	}
}

FUNCTION translation_control {
	PARAMETER controlVec,tar,craft.
	RCS ON.
	LOCAL shipFacing IS SHIP:FACING.
	LOCAL axisSpeed IS axis_speed(craft,tar).
	//PRINT "velocityError: " + ROUND((controlVec - axisSpeed[0]):MAG,2).
	SET PID["Fore"]:SETPOINT TO VDOT(controlVec,shipFacing:FOREVECTOR).
	SET PID["Top"]:SETPOINT TO VDOT(controlVec,shipFacing:TOPVECTOR).
	SET PID["Star"]:SETPOINT TO VDOT(controlVec,shipFacing:STARVECTOR).

	SET SHIP:CONTROL:FORE TO PID["Fore"]:UPDATE(TIME:SECONDS,axisSpeed[1]).
	SET SHIP:CONTROL:TOP TO PID["Top"]:UPDATE(TIME:SECONDS,axisSpeed[2]).
	SET SHIP:CONTROL:STARBOARD TO PID["Star"]:UPDATE(TIME:SECONDS,axisSpeed[3]).
	//pid_debug(PID["Fore"]).
	//pid_debug(PID["Top"]).
	//pid_debug(PID["Star"]).
}

FUNCTION translation_new_target {
	PARAMETER translateState,shipPoint,targetPoint,isKlaw.
	IF portData["changedTarget"] {
		IF translateData["targetIsType"] = "port" {
			SET portData["changedTarget"] TO FALSE.
			IF shipPoint <> portData["targetPorts"][0] {
				port_open(portData["targetPorts"][0]).
				port_close(shipPoint).
				portData["targetPorts"][0]:CONTROLFROM().
			}
			taskList:ADD(translate@:BIND(translateState,portData["targetPorts"][0],portData["targetPorts"][1],portData["isKlaw"])).
		} ELSE {// IF (translateData["targetIsType"] = "craft") OR (translateData["targetIsType"] = "com") {
			SET portData["changedTarget"] TO FALSE.
			LOCAL shipTemp IS SHIP.
			IF portData["isKlaw"] {
				SET shipTemp TO portData["targetPorts"][0].
			}
			taskList:ADD(translate@:BIND(translateState,shipTemp,target_craft(TARGET),portData["isKlaw"])).
		}
		PRINT "target change".
		RETURN TRUE.
	} ELSE {
		RETURN FALSE.
	}
}

FUNCTION angular_velocity_vector {//returns a vector pointing in direction of motion with MAG of m/s of motion
	PARAMETER targetPoint,shipPoint.
	LOCAL targetCraft IS target_craft(targetPoint).
	LOCAL angleVec IS shipPoint:POSITION - targetCraft:POSITION.
	LOCAL angularVelVecNormal IS targetCraft:ANGULARVEL.

	RETURN VCRS(angularVelVecNormal,angleVec).
}

FUNCTION have_valid_target {
	IF HASTARGET {
		IF NOT TARGET:ISTYPE("Body"){
			RETURN TRUE.
		}
	}
	PRINT "Can't Preform Action Current Target Is Invalid".
	RETURN FALSE.
}

FUNCTION stop_translation {
	PRINT "stopping translation".
	SET translateData["stop"] TO TRUE.
}

FUNCTION get_number {
	PARAMETER field,default.
	SET field:ENABLED TO FALSE.
	LOCAL num IS field_to_numbers_only(field,TRUE):TONUMBER(default).
	SET field:ENABLED TO TRUE.
	RETURN num.
}

FUNCTION field_to_numbers_only {
	PARAMETER field,removeEndDP IS FALSE.
	LOCAL didChange IS FALSE.
	LOCAL localString IS field:TEXT.
	LOCAL dpLocation IS 0.
	FROM {LOCAL i IS localString:LENGTH - 1.} UNTIL i < 0 STEP {SET i TO i - 1.} DO {
		IF NOT varConstants["numList"]:CONTAINS(localString[i]) {
			IF localString[i] = "." {
				IF dpLocation <> 0 {
					SET didChange TO TRUE.
					SET localString TO localString:REMOVE(dpLocation,1).
				}
				SET dpLocation TO i.
			} ELSE IF NOT (i = 0 AND localString[i] = "-" ) {
				SET didChange TO TRUE.
				SET localString TO localString:REMOVE(i,1).
			}
		}
	}
	IF removeEndDP AND (dpLocation = (localString:LENGTH - 1)) {
		SET didChange TO TRUE.
		localString:REMOVE(localString:LENGTH - 1,1).
	}
	IF localString:LENGTH = 0 {
		SET didChange TO TRUE.
		SET localString TO "0".
	}
	IF didChange {
		RETURN localString.
	} ELSE {
		RETURN field:TEXT.
	}
}

FUNCTION index_in_range {//keeps INDEX for popUp in range
	PARAMETER popUp.
	IF popUp:INDEX < 0  {
		SET popUp:INDEX TO 0.
	} ELSE IF popUp:INDEX > (popUp:OPTIONS:LENGTH - 1) {
		SET popUp:INDEX TO popUp:OPTIONS:LENGTH - 1.
	} ELSE {
		SET popUp:INDEX TO popUp:INDEX.
	}
}

FUNCTION accel_dist_to_speed {
	PARAMETER accel,dist,speedLimit,deadZone IS 0.
	LOCAL localAccel IS accel.
	LOCAL posNeg IS 1.
	IF dist < 0 { SET posNeg TO -1. }
	IF (deadZone <> 0) AND (ABS(dist) < deadZone) { SET localAccel to accel / 10. }
	RETURN MIN(MAX((SQRT(2 * ABS(dist) / localAccel) * localAccel) * posNeg,-speedLimit),speedLimit).
}

FUNCTION shutdown_stack {
	RCS OFF.
	UNLOCK STEERING.
	UNLOCK THROTTLE.
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
	SET SHIP:CONTROL:FORE TO 0.
	SET SHIP:CONTROL:TOP TO 0.
	SET SHIP:CONTROL:STARBOARD TO 0.
	SET scriptData["done"] TO TRUE.
}