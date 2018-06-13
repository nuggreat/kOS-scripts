//TODO: 1) status display of some kind
//TODO: 2) just point at target translation mode

CLEARGUIS().
CLEARSCREEN.
FOR lib IN LIST("lib_dock","lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
LOCAL varConstants IS LEX("numList",LIST("0","1","2","3","4","5","6","7","8","9"),"translationPIDs",LIST("Fore","Star","Top")).

LOCAL scriptData IS LEX("done",FALSE).
LOCAL burnData IS LEX("state",0,"stop",FALSE,"steerVec",SHIP:FACING:FOREVECTOR,"throttle",0).

LOCAL portData IS LEX("matchingSize",LIST(),"shipList",LIST(),"targetList",LIST(),
"highlighting",LIST(),"targetPorts",LIST(),"changedTarget",FALSE).

LOCAL translateData IS LEX("steerVec",SHIP:FACING:FOREVECTOR,
"state",0,"foreVal",0,"topVal",0,"starVal",0,
"pitch",0,"yaw",0,"roll",0,"topSpeed",5,"accel",0.05,
"stop",FALSE,"targetPorts",FALSE,"distControl",TRUE,"oldTarget",-1).

//           PID setup PIDLOOP(kP,kI,kD,min,max)
LOCAL PID IS LEX(	"Fore",PIDLOOP(4,0.1,0.01,-1,1),
					"Star",PIDLOOP(4,0.1,0.01,-1,1),
					 "Top",PIDLOOP(4,0.1,0.01,-1,1)).

LOCAL interface IS GUI(500).
 LOCAL iModeSelect IS interface:ADDHBOX.
 LOCAL imsBurn IS iModeSelect:ADDRADIOBUTTON("Burn Mode",TRUE).
  //SET imsBurn:STYLE:ALIGN TO "LEFT".
 LOCAL imsPortSelect IS iModeSelect:ADDRADIOBUTTON("Port Selection",FALSE).
  //SET imsPortSelect:STYLE:ALIGN TO "CENTER".
 LOCAL imsDockingMode IS iModeSelect:ADDRADIOBUTTON("Translation Mode",FALSE).
  //SET imsDockingMode:STYLE:ALIGN TO "RIGHT".

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
  LOCAL ipsLabel0 IS iPortSelect:ADDLABEL("Docking Port Selection").
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
    LOCAL itmmatFace IS itmmAlingnType:ADDRADIOBUTTON("Align Relative to Target",TRUE).
    LOCAL itmmatSettings IS itmmAlingnType:ADDRADIOBUTTON("Translation Settings",FALSE).
   LOCAL itmmMoveType IS itmModes:ADDHLAYOUT.
    LOCAL itmmmtSpeed IS itmmMoveType:ADDRADIOBUTTON("Set Speed",FALSE).
    LOCAL itmmmtDist IS itmmMoveType:ADDRADIOBUTTON("Set Distance",TRUE).
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
     LOCAL itmnfl0Pitch IS itmnfLayout0:ADDTEXTFIELD("0").
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
//facing
// port
//  roll.
// target.
//  relative pitch
//  relative yaw
//  relative roll

//speed
// fore
// top
// star

//dist
// accel
// fore
// top
// star


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

change_mode_translate_facing(itmmatFace).
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
LOCAL fieldCount IS 0.
LOCAL runStack IS LIST().
fieldCycle(LIST(ibslField,ibdlField,itmnfl0Pitch,itmnfl1Yaw,itmnfl2Roll,itmntl0Fore,itmntl1Top,itmntl2Star,itmsl0Speed,itmsl1Accel)).
interface:SHOW.//set up done waiting on user input
UNTIL scriptData["done"] {
	IF runStack:LENGTH > 0 {
		FROM { LOCAL i IS runStack:LENGTH -1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
			IF runStack[i]:CALL() {
				runStack:REMOVE(i).
			}
		}
	}
	WAIT 0.01.
	IF ABORT { shutdown_stack(). }
}
interface:DISPOSE.
enable_disable_highlight(FALSE).
SAS ON.

FUNCTION fieldCycle {
	PARAMETER fieldList,fieldCount IS 0.
	field_to_numbers_only(fieldList[fieldCount]).
	IF fieldCount < (fieldList:LENGTH - 1) {
		SET fieldCount TO fieldCount + 1.
		runStack:ADD(fieldCycle@:BIND(fieldList,fieldCount)).
	} ELSE {
		runStack:ADD(fieldCycle@:BIND(fieldList)).
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
	} ELSE {
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
		IF portData["targetPorts"]:LENGTH > 0 {
			itmNavigation:SHOW.
			itmControl:SHOW.
			itmSettings:HIDE.
			itmnfLayout0:HIDE.
			itmnfLayout1:HIDE.
			SET itmnfLabel0:TEXT TO "Port Relative Adjustment".
		} ELSE {
			SET itmmatFace:PRESSED TO TRUE.
			SET imsPortSelect:PRESSED TO TRUE.
			PRINT "Mode: " + selectedMode:TEXT + ", Needs a Target Port Selected".
		}
	}
	IF selectedMode = itmmatFace {
		itmNavigation:SHOW.
		itmControl:SHOW.
		itmSettings:HIDE.
		itmnfLayout0:SHOW.
		itmnfLayout1:SHOW.
		SET itmnfLabel0:TEXT TO "Target Relative Adjustments".
	}
	IF selectedMode = itmmatSettings {
		itmNavigation:HIDE.
		itmControl:HIDE.
		itmSettings:SHOW.
	}
}

FUNCTION change_translate_type {
	PARAMETER selectedType.
	IF selectedType = itmmmtDist {
		SET itmntl0Label0:TEXT TO "Target Distances in m".
		itmntl0GetDist:SHOW.
	} ELSE {
	//IF selectedType = itmmmtDist {
		SET itmntl0Label0:TEXT TO "Target Speeds in m/s".
		itmntl0GetDist:HIDE.
	}

}

FUNCTION run_Burn { IF have_valid_target {
	control_point().
	WAIT UNTIL active_engine(FALSE).
	ibStop:SHOW.
	hide_start_buttons(TRUE).
	LOCAL localTarget IS target_craft(TARGET).

	IF ibbmRetro:PRESSED {
		//runStack:ADD(retro_burn@).
		runStack:ADD(burn@:BIND(localTarget,0)).
		PRINT "running retro_burn".
	} ELSE {
		LOCAL targetSpeed IS get_number(ibslField,1).

		IF ibbmTarget:PRESSED {
			LOCAL speedLimit IS (localTarget:POSITION - SHIP:POSITION):MAG / 90.
			runStack:ADD(burn@:BIND(localTarget,MIN(targetSpeed,speedLimit))).
			PRINT "running burn_at_target".
			//runStack:ADD(burn_at_target@).
		} ELSE IF ibbmClose:PRESSED {
			LOCAL targetDist IS get_number(ibdlField,100).
			LOCAL speedLimit IS ABS((localTarget:POSITION - SHIP:POSITION):MAG - targetDist) / 90.

			runStack:ADD(burn@:BIND(localTarget,MIN(targetSpeed,speedLimit),targetDist)).
			PRINT "running close_to_target".
			//runStack:ADD(close_to_target@).
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
	PARAMETER localTarget,targetSpeed,targetDist IS -1.
	IF burnData["stop"] {
		SET burnData["state"] TO 3.
		SET burnData["stop"] TO FALSE.
	}
	LOCAL tarSpeed IS targetSpeed.

	LOCAL vecToTarget IS localTarget:POSITION - SHIP:POSITION.
	LOCAL relitaveVelocityVec IS SHIP:VELOCITY:ORBIT - localTarget:VELOCITY:ORBIT.
	LOCAL shipAcceleration IS SHIP:AVAILABLETHRUST / SHIP:MASS.
	LOCAL targetVelocityVec IS vecToTarget:NORMALIZED * tarSpeed.
	LOCAL relitaveSpeed IS (targetVelocityVec - relitaveVelocityVec):MAG.
	LOCAL throtCoeficent IS 1.

	LOCAL done IS relitaveSpeed < 0.05.

	IF targetDist <> -1 {
		SET tarSpeed TO ABS(tarSpeed).
		//LOCAL deccelCoeficent IS MAX(60 / MIN(tarSpeed / shipAcceleration,1),1).
		LOCAL deccelCoeficent IS MIN(tarSpeed / 60, shipAcceleration) / shipAcceleration.
		LOCAL distToTarget IS (vecToTarget):MAG - targetDist.
		SET tarSpeed TO accel_dist_to_speed(shipAcceleration * deccelCoeficent,distToTarget,tarSpeed).
		SET targetVelocityVec TO vecToTarget:NORMALIZED * tarSpeed.
		SET throtCoeficent TO 0.5.
		SET done TO FALSE.
		IF ABS(distToTarget) < 1 {
			runStack:ADD(burn@:BIND(localTarget,0)).
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

	SET burnData["steerVec"] TO (targetVelocityVec - relitaveVelocityVec).

	IF burnData["state"] = 0 {
		SAS OFF.
		RCS OFF.
		//SET burnData["steerVec"] TO SHIP:FACING:FOREVECTOR.
		SET burnData["throttle"] TO 0.
		LOCK STEERING TO burnData["steerVec"].
		LOCK THROTTLE TO burnData["throttle"].
		steering_alinged_duration(FALSE,1,TRUE).
		SET burnData["state"] TO 1.
		RETURN FALSE.
	} ELSE IF burnData["state"] = 1 {
		IF steering_alinged_duration() > 10 {
			SET burnData["state"] TO 2.
		}
		RETURN FALSE.
	} ELSE IF burnData["state"] = 2 {
		LOCAL maxThrot IS MAX(1 - LOG10(MAX(ABS(STEERINGMANAGER:ANGLEERROR) * 100,1))/3.35,0).
		//LOCAL maxThrot IS MAX(1 - ABS(STEERINGMANAGER:ANGLEERROR),0).
		//LOCAL maxThrot IS 1.
		//LOCAL speedCoeficent IS COS(MIN(ABS(STEERINGMANAGER:ANGLEERROR*10),90)).
		//PRINT "speedCoeficent: " + ROUND(speedCoeficent,2)  + "   " AT(0,0).
		SET burnData["throttle"] TO MAX(MIN(relitaveSpeed / (shipAcceleration * throtCoeficent),maxThrot),0).

		IF done {
			SET burnData["state"] TO 3.
		}
		RETURN FALSE.
	} ELSE IF burnData["state"] = 3 {
		UNLOCK STEERING.
		UNLOCK THROTTLE.
		SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
		SET burnData["state"] TO 0.
		PRINT "Done With Engines".
		ibStop:HIDE.
		hide_start_buttons(FALSE).
		RETURN TRUE.
	}

}

FUNCTION burn_abort {
	SET burnData["stop"] TO TRUE.
}

FUNCTION run_port_scan { IF have_valid_target {
	portData["shipList"]:CLEAR().
	portData["targetList"]:CLEAR().
	portData["shipList"]:ADD(port_scan(SHIP)).
	IF portData["shipList"][0]:KEYS:LENGTH = 0 {
		portData["shipList"]:ADD(port_scan(SHIP)).
	}
	LOCAL station IS TARGET.
	IF NOT station:ISTYPE("Vessel") {
		SET station TO station:SHIP.
	}
	portData["targetList"]:ADD(port_scan(station,FALSE)).
	IF portData["targetList"][0]:KEYS:LENGTH = 0 {
		portData["targetList"]:ADD(port_scan(station,FALSE)).
	}

	SET portData["matchingSize"] TO port_size_matching(portData["shipList"][0],portData["targetList"][0]).
	portData["shipList"]:ADD(make_port_GUI_lex(portData["shipList"][0])).
	portData["targetList"]:ADD(make_port_GUI_lex(portData["targetList"][0])).

	IF portData["matchingSize"]:LENGTH > 0 {
		PRINT "Matching Docking Ports Found".
		SET ipspl0PortSize:OPTIONS TO portData["matchingSize"].
		index_in_range(ipspl0PortSize).
		port_menue_update(ipspl0PortSize:VALUE).
		ipsPorts:SHOW.
		ipsLabel1:SHOW.
	} ELSE {
		ipsPorts:HIDE.
		ipsLabel1:HIDE.
	}
	RETURN TRUE.
}}

FUNCTION make_port_GUI_lex {
	PARAMETER portLex.
	LOCAL returnLex IS LEX().
	LOCAL portNumber IS 0.
	FOR key IN portLex:KEYS {
		returnLex:ADD(key,LIST()).
		FOR port IN portLex[key] {
			returnLex[key]:ADD("Tag: " + port:TAG + ", Port Number: " + portNumber).
			SET portNumber TO portNumber + 1.
		}
	}
	RETURN returnLex.
}

FUNCTION port_menue_update {
	PARAMETER pSize.
	SET ipspl1PortSelectVes:OPTIONS TO portData["shipList"][1][pSize].
	index_in_range(ipspl1PortSelectVes).
	SET ipspl2PortSelectTar:OPTIONS TO portData["targetList"][1][pSize].
	index_in_range(ipspl2PortSelectTar).
	port_highlighting().
}

FUNCTION port_save {
	portData["targetPorts"]:CLEAR().
	LOCAL portSize IS ipspl0PortSize:VALUE.
	portData["targetPorts"]:ADD(portData["shipList"][0][portSize][ipspl1PortSelectVes:INDEX]).
	portData["targetPorts"]:ADD(portData["targetList"][0][portSize][ipspl2PortSelectTar:INDEX]).
	SET portData["changedTarget"] TO TRUE.
	SET ipstSize:TEXT TO "           Size: " + ipspl0PortSize:VALUE.
	SET ipstTar:TEXT TO " Target Port: " + ipspl1PortSelectVes:VALUE.
	SET ipstVes:TEXT TO "Vessel Port: " + ipspl2PortSelectTar:VALUE.
	ipsTarget:SHOW.
	ipsLabel1:SHOW.
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
		portData["highlighting"]:ADD(HIGHLIGHT(portData["targetList"][0][portSize][ipspl2PortSelectTar:INDEX],brightYellow)).
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
	IF translateData["targetPorts"] {
		SET shipPoint TO portData["targetPorts"][0].
		SET targetPoint TO portData["targetPorts"][1].
	}
	runStack:ADD(translate@:BIND(shipPoint,targetPoint)).
}}

FUNCTION update_translate { IF have_valid_target {
	PRINT "updating translation data".
	LOCAL targetPoint IS target_craft(TARGET).
	LOCAL shipPoint IS SHIP.
	SET translateData["steerVec"] TO SHIP:FACING:FOREVECTOR.

	SET translateData["Roll"] TO get_number(itmnfl2Roll,0).
	IF itmmatFace:PRESSED {
		control_point().
		SET translateData["pitch"] TO get_number(itmnfl0Pitch,0).
		SET translateData["Yaw"] TO get_number(itmnfl1Yaw,0).
		SET translateData["targetPorts"] TO FALSE.
	} ELSE {
		SET shipPoint TO portData["targetPorts"][0].
		SET targetPoint TO portData["targetPorts"][1].
		shipPoint:CONTROLFROM().
		SET translateData["targetPorts"] TO TRUE.
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
	IF translateData["oldTarget"] = -1 {
		SET translateData["oldTarget"] TO targetPoint.
	} ELSE IF translateData["oldTarget"] <> targetPoint {
		SET portData["changedTarget"] TO TRUE.
		SET translateData["oldTarget"] TO targetPoint.
	}
}}

FUNCTION load_distance { IF have_valid_target {
	LOCAL targetPoint IS target_craft(TARGET).
	LOCAL shipPoint IS SHIP.
	IF NOT itmmatFace:PRESSED {
		SET shipPoint TO portData["targetPorts"][0].
		SET targetPoint TO portData["targetPorts"][1].
	}
	LOCAL distTemp IS axis_distance(targetPoint,shipPoint).
	SET itmntl0Fore:TEXT TO ROUND(distTemp[1],2):TOSTRING.
	SET itmntl1Top:TEXT TO ROUND(-distTemp[2],2):TOSTRING.
	SET itmntl2Star:TEXT TO ROUND(distTemp[3],2):TOSTRING.
}}

FUNCTION translate {
	PARAMETER shipPoint,targetPoint.
	LOCAL targetFacing IS targetPoint:FACING.
	//LOCAL localTargetPorts IS translateData["targetPorts"].
	//LOCAL localDistControl IS translateData["distControl"].
	IF translateData["targetPorts"] {
		IF portData["changedTarget"] {
			SET portData["changedTarget"] TO FALSE.
			IF (shipPoint <> portData["targetPorts"][0]) OR (targetPoint <> portData["targetPorts"][1]) {
				portData["targetPorts"][0]:CONTROLFROM().
				runStack:ADD(translate@:BIND(portData["targetPorts"][0],portData["targetPorts"][1])).
				PRINT "target change".
				RETURN TRUE.
			}
		}
		SET targetFacing TO targetPoint:PORTFACING.
		SET translateData["steerVec"] TO ANGLEAXIS(translateData["Roll"],-targetFacing:FOREVECTOR) * LOOKDIRUP(-targetFacing:FOREVECTOR, targetFacing:TOPVECTOR).
		IF shipPoint:STATE:CONTAINS("Docked") {
			SET translateData["state"] TO 3.
			runStack:ADD(shutdown_stack@).
		}
		//SET translateData["steerVec"] TO port_alingment(portData["targetPorts"][1],translateData["Roll"]).
	} ELSE {
		LOCAL returnDir IS ANGLEAXIS(-translateData["Pitch"],targetFacing:STARVECTOR) * targetFacing.
		SET returnDir TO ANGLEAXIS(translateData["Roll"],returnDir:FOREVECTOR) * returnDir.
		SET translateData["steerVec"] TO ANGLEAXIS(translateData["Yaw"],returnDir:TOPVECTOR) * returnDir.

		IF portData["changedTarget"] {
			SET portData["changedTarget"] TO FALSE.
			runStack:ADD(translate@:BIND(SHIP,target_craft(TARGET))).
			RETURN TRUE.
		}
	}
	IF translateData["stop"] {
		SET translateData["stop"] TO FALSE.
		SET translateData["state"] TO 3.
	}
	IF translateData["state"] = 0 {
		SAS OFF.
		LOCK STEERING TO translateData["steerVec"].
		steering_alinged_duration(TRUE,1,TRUE).
		LOCK THROTTLE TO 0.
		SET translateData["state"] TO 1.
		FOR key IN varConstants["translationPIDs"] { PID[key]:RESET(). }
		RETURN FALSE.
	} ELSE IF translateData["state"] = 1 {
		IF steering_alinged_duration(TRUE) > 1 {
			SET translateData["state"] TO 2.
			PRINT "Starting Translation".
		}
		RETURN FALSE.
	} ELSE IF translateData["state"] = 2 {
		IF translateData["distControl"] {
			LOCAL targetPosition IS targetPoint:POSITION.
			SET targetPosition TO targetPosition + (targetFacing:FOREVECTOR * translateData["foreVal"]).
			SET targetPosition TO targetPosition + (-targetFacing:TOPVECTOR * translateData["topVal"]).
			SET targetPosition TO targetPosition + (targetFacing:STARVECTOR * translateData["starVal"]).
			LOCAL vecToTarget IS targetPosition - shipPoint:POSITION.
			LOCAL speedCoeficent IS accel_dist_to_speed(translateData["accel"],vecToTarget:MAG,translateData["topSpeed"],0).
			LOCAL controlVec IS vecToTarget:NORMALIZED * speedCoeficent + angular_velocity_vector(target_craft(targetPoint),targetPosition).
			translation_control(controlVec,targetPoint,shipPoint).
			//CLEARSCREEN.
			//PRINT "distError: " + ROUND(vecToTarget:MAG,2).
		} ELSE {
			LOCAL controlVec IS v(0,0,0).
			SET controlVec TO controlVec + (-targetFacing:FOREVECTOR * translateData["foreVal"]).
			SET controlVec TO controlVec + (  targetFacing:TOPVECTOR * translateData["topVal"]).
			SET controlVec TO controlVec + (-targetFacing:STARVECTOR * translateData["starVal"]).
			IF controlVec:MAG > translateData["topSpeed"] {
				SET controlVec TO controlVec:NORMALIZED * translateData["topSpeed"].
			}
			translation_control(controlVec,targetPoint,shipPoint).
			RETURN FALSE.
		}
	} ELSE IF translateData["state"] = 3 {
		SET translateData["state"] TO 0.
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

FUNCTION angular_velocity_vector {//returns a vector pointing in direction of motion with MAG of m/s of motion
	PARAMETER targetCraft,targetPosition.
	LOCAL angleVec IS targetPosition - targetCraft:POSITION.
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
	field_to_numbers_only(field).
	LOCAL num IS field:TEXT:TONUMBER(default).
	SET field:ENABLED TO TRUE.
	RETURN num.
}

FUNCTION field_to_numbers_only {
	PARAMETER field.
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
	IF didChange {
		SET field:TEXT TO localString.
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
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
	SET SHIP:CONTROL:FORE TO 0.
	SET SHIP:CONTROL:TOP TO 0.
	SET SHIP:CONTROL:STARBOARD TO 0.
	SET scriptData["done"] TO TRUE.
}