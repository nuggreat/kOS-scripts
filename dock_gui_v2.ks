//TODO: 1) add edge cases to status display (function ended/not started)
//TODO: 2) fix distance load to respect current pressed buttons
//TODO: 3) check that distance loading works for COM targeting
//TODO: 4) settings should not disapear on translation targeting type change
//TODO: 5) add to translation settings a toggle for if tumble compinsation should be on or not
//TODO: 6) add PID to throttle control for burn mode
//TODO: 7) relitave speed should be 0 or not displayed when burn mode kill rel is used
//TODO: 8) live update on target speed when in close with mode

CLEARGUIS().
CLEARSCREEN.
//IF NOT EXISTS ("1:/lib/lib_mis_utilities.ks") { COPYPATH("0:/lib/lib_mis_utilities.ks","1:/lib/lib_mis_utilities.ks"). }
FOR lib IN LIST("lib_dock","lib_rocket_utilities","lib_formating") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
LOCAL varConstants IS LEX("numList",LIST("0","1","2","3","4","5","6","7","8","9"),"translationPIDs",LIST("Fore","Star","Top")).

LOCAL scriptData IS LEX("done",FALSE).
LOCAL burnData IS LEX("stop",FALSE,"steerVec",SHIP:FACING:FOREVECTOR,"throttle",0).//lexicon for burn function

LOCAL portData IS LEX("matchingSize",LIST(),"shipList",LIST(),"targetList",LIST(),//lexicon for docking port selection
"highlighting",LIST(),"targetPorts",LIST(),"changedTarget",FALSE,"isKlaw",FALSE).

LOCAL translateData IS LEX("steerVec",SHIP:FACING:FOREVECTOR,//lexicon of needed to run translation function
"foreVal",0,"topVal",0,"starVal",0,
"pitch",0,"yaw",0,"roll",0,"topSpeed",5,"accel",0.05,
"stop",FALSE,"targetIsType",TRUE,"targetPorts",FALSE,"oldTarget",LIST(-1,-1)
,"doTranslation",TRUE,"distControl",LEX("for",TRUE,"top",TRUE,"star",TRUE)).

LOCAL statusData IS LEX("dispType",0,"data",LIST(0,0,0,0,0,0,0,0,0),"dispOn",FALSE).

//		   PID setup PIDLOOP(kP,kI,kD,min,max)
LOCAL PID IS LEX(	"Fore",PIDLOOP(4,0.1,0.01,-1,1),
					"Star",PIDLOOP(4,0.1,0.01,-1,1),
					 "Top",PIDLOOP(4,0.1,0.01,-1,1)).

LOCAL interface IS GUI(500).
 LOCAL iModeSelect IS interface:ADDHBOX.
 LOCAL imsBurn IS iModeSelect:ADDRADIOBUTTON("Burn Mode",TRUE).
 LOCAL imsPortSelect IS iModeSelect:ADDRADIOBUTTON("Port Selection",FALSE).
 LOCAL imsDockingMode IS iModeSelect:ADDRADIOBUTTON("Translation Mode",FALSE).
 LOCAL imsUpdateStatus IS iModeSelect:ADDRADIOBUTTON("Status Display",FALSE).

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
	i_width_to(ibslField,275).
  LOCAL ibDistanceLayout IS iBurn:ADDHLAYOUT.
   LOCAL ibdlLabel0 IS ibDistanceLayout:ADDLABEL("Distance To Stop At m: ").//label for distance field
	SET ibdlLabel0:STYLE:ALIGN TO "RIGHT".
   LOCAL ibdlField IS ibDistanceLayout:ADDTEXTFIELD("0").//input for distance
	i_width_to(ibdlField,275).
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
	 i_width_to(ipspl0PortSize,330).
   LOCAL ipspLayout1 IS ipsPorts:ADDHLAYOUT.
	LOCAL ipspl1Label0 IS ipspLayout1:ADDLABEL("Ship Docking Port:").
	LOCAL ipspl1PortSelectVes IS ipspLayout1:ADDPOPUPMENU().
	 i_width_to(ipspl1PortSelectVes,330).
   LOCAL ipspLayout2 IS ipsPorts:ADDHLAYOUT.
	LOCAL ipspl2Label0 IS ipspLayout2:ADDLABEL("Target Docking Port:").
	LOCAL ipspl2PortSelectTar IS ipspLayout2:ADDPOPUPMENU().
	 i_width_to(ipspl2PortSelectTar,330).
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
	LOCAL itmmmtRot IS itmmMoveType:ADDRADIOBUTTON("Rotation Only",FALSE).
	LOCAL itmmmtTrans IS itmmMoveType:ADDRADIOBUTTON("Full Translation",TRUE).
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
	 LOCAL itmntl0Label IS itmntLayout0:ADDLABEL("Speeds in m/s, Distances in m").
	 LOCAL itmntl0GetDist IS itmntLayout0:ADDBUTTON("load Current Distance").
	LOCAL itmntLayout1 IS itmnTarget:ADDHLAYOUT.
	 LOCAL itmntl1Speed IS itmntLayout1:ADDBUTTON("Speed").
	 LOCAL itmntl1Dist IS itmntLayout1:ADDBUTTON("Distance").
	  i_speed_dist_formating(itmntl1Speed,itmntl1Dist).
	 LOCAL itmntl1Label IS itmntLayout1:ADDLABEL("Fore/Back (+/-): ").
	 LOCAL itmntl1Fore IS itmntLayout1:ADDTEXTFIELD("0").
 	  i_width_to(itmntl1Fore,240).
	LOCAL itmntLayout2 IS itmnTarget:ADDHLAYOUT.
	 LOCAL itmntl2Speed IS itmntLayout2:ADDBUTTON("Speed").
	 LOCAL itmntl2Dist IS itmntLayout2:ADDBUTTON("Distance").
	  i_speed_dist_formating(itmntl2Speed,itmntl2Dist).
	 LOCAL itmntl2Label IS itmntLayout2:ADDLABEL("Up/Down (+/-): ").
	 LOCAL itmntl2Top IS itmntLayout2:ADDTEXTFIELD("0").
	  i_width_to(itmntl2Top,240).
	LOCAL itmntLayout3 IS itmnTarget:ADDHLAYOUT.
	 LOCAL itmntl3Speed IS itmntLayout3:ADDBUTTON("Speed").
	 LOCAL itmntl3Dist IS itmntLayout3:ADDBUTTON("Distance").
	  i_speed_dist_formating(itmntl3Speed,itmntl3Dist).
	 LOCAL itmntl3Label IS itmntLayout3:ADDLABEL("Left/Right (+/-): ").
	 LOCAL itmntl3Star IS itmntLayout3:ADDTEXTFIELD("0").
	  i_width_to(itmntl3Star,240).
   LOCAL itmnFacing IS itmNavigation:ADDVBOX.
	LOCAL itmnfLabel0 IS itmnFacing:ADDLABEL(" ").
	LOCAL itmnfLayout0 IS itmnFacing:ADDHLAYOUT.
	 LOCAL itmnfl0Label IS itmnfLayout0:ADDLABEL("Adjust Pitch By: ").
	 LOCAL itmnfl0Pitch IS itmnfLayout0:ADDTEXTFIELD("0").
	  i_width_to(itmnfl0Pitch,330).
	LOCAL itmnfLayout1 IS itmnFacing:ADDHLAYOUT.
	 LOCAL itmnfl1Label IS itmnfLayout1:ADDLABEL("Adjust Yaw By: ").
	 LOCAL itmnfl1Yaw IS itmnfLayout1:ADDTEXTFIELD("180").
	  i_width_to(itmnfl1Yaw,330).
	LOCAL itmnfLayout2 IS itmnFacing:ADDHLAYOUT.
	 LOCAL itmnfl2Label IS itmnfLayout2:ADDLABEL("Adjust Roll By: ").
	 LOCAL itmnfl2Roll IS itmnfLayout2:ADDTEXTFIELD("0").
	  i_width_to(itmnfl2Roll,330).

  LOCAL itmSettings IS iTranslateMode:ADDVBOX.
   LOCAL itmsLable0 IS itmSettings:ADDLABEL("Translation Limits").
   LOCAL itmsLayout0 IS itmSettings:ADDHLAYOUT.
	LOCAL itmsl0Label IS itmsLayout0:ADDLABEL("Top Speed Limit: ").
	LOCAL itmsl0Speed IS itmsLayout0:ADDTEXTFIELD("5").
	 i_width_to(itmsl0Speed,330).
   LOCAL itmsLable2 IS itmSettings:ADDLABEL("Acceleration Limit Only Applies to Distance Mode").
   LOCAL itmsLayout1 IS itmSettings:ADDHLAYOUT.
	LOCAL itmsl1Label IS itmsLayout1:ADDLABEL("Acceleration Limit: ").
	LOCAL itmsl1Accel IS itmsLayout1:ADDTEXTFIELD("0.05").
	 i_width_to(itmsl1Accel,330).
   LOCAL itmsUpdate IS itmSettings:ADDBUTTON("Apply Changes").
   
 LOCAL iStatusDisp IS interface:ADDVBOX.
  LOCAL isdLayout00 IS iStatusDisp:ADDHLAYOUT.
   LOCAL isdl00Text0 IS isdLayout00:ADDLABEL(" ").
   LOCAL isdl00Text1 IS isdLayout00:ADDLABEL(" ").
  LOCAL isdLayout01 IS iStatusDisp:ADDHLAYOUT.
   LOCAL isdl01Text0 IS isdLayout01:ADDLABEL(" ").
   LOCAL isdl01Text1 IS isdLayout01:ADDLABEL(" ").
  LOCAL isdLayout02 IS iStatusDisp:ADDHLAYOUT.
   LOCAL isdl02Text0 IS isdLayout02:ADDLABEL(" ").
   LOCAL isdl02Text1 IS isdLayout02:ADDLABEL(" ").
  LOCAL isdLayout03 IS iStatusDisp:ADDHLAYOUT.
   LOCAL isdl03Text0 IS isdLayout03:ADDLABEL(" ").
   LOCAL isdl03Text1 IS isdLayout03:ADDLABEL(" ").
  LOCAL isdLayout04 IS iStatusDisp:ADDHLAYOUT.
   LOCAL isdl04Text0 IS isdLayout04:ADDLABEL(" ").
   LOCAL isdl04Text1 IS isdLayout04:ADDLABEL(" ").
  LOCAL isdLayout05_1 IS iStatusDisp:ADDHLAYOUT.
    LOCAL isdl051l0Text0 IS isdLayout05_1:ADDLABEL(" ").
    LOCAL isdl051l0Text1 IS isdLayout05_1:ADDLABEL(" ").
    LOCAL isdl051l1Text0 IS isdLayout05_1:ADDLABEL(" ").
    LOCAL isdl051l1Text1 IS isdLayout05_1:ADDLABEL(" ").
  LOCAL isdLayout05_2 IS iStatusDisp:ADDHLAYOUT.
   LOCAL isdl052Text0 IS isdLayout05_2:ADDLABEL(" ").
   LOCAL isdl052Text1 IS isdLayout05_2:ADDLABEL(" ").
  LOCAL isdLayout06 IS iStatusDisp:ADDHLAYOUT.
   LOCAL isdl06Text0 IS isdLayout06:ADDLABEL(" ").
   LOCAL isdl06Text1 IS isdLayout06:ADDLABEL(" ").
  LOCAL isdLayout07 IS iStatusDisp:ADDHLAYOUT.
   LOCAL isdl07Text0 IS isdLayout07:ADDLABEL(" ").
   LOCAL isdl07Text1 IS isdLayout07:ADDLABEL(" ").
  LOCAL isdLayout08 IS iStatusDisp:ADDHLAYOUT.
   LOCAL isdl08Text0 IS isdLayout08:ADDLABEL(" ").
   LOCAL isdl08Text1 IS isdLayout08:ADDLABEL(" ").
  LOCAL isdLayout09 IS iStatusDisp:ADDHLAYOUT.
   LOCAL isdl09Text0 IS isdLayout09:ADDLABEL(" ").
   LOCAL isdl09Text1 IS isdLayout09:ADDLABEL(" ").
  LOCAL isdLayout10 IS iStatusDisp:ADDHLAYOUT.
   LOCAL isdl10Text0 IS isdLayout10:ADDLABEL(" ").
   LOCAL isdl10Text1 IS isdLayout10:ADDLABEL(" ").
  LOCAL isdLayout11 IS iStatusDisp:ADDHLAYOUT.
   LOCAL isdl11Text0 IS isdLayout11:ADDLABEL(" ").
   LOCAL isdl11Text1 IS isdLayout11:ADDLABEL(" ").
  LOCAL isdLayout12 IS iStatusDisp:ADDHLAYOUT.
   LOCAL isdl12Text0 IS isdLayout12:ADDLABEL(" ").
   LOCAL isdl12Text1 IS isdLayout12:ADDLABEL(" ").

change_menu(imsBurn).
SET iModeSelect:ONRADIOCHANGE TO change_menu@.
i_status_style().
i_clear_status().

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
change_translate_type(itmmmtTrans).
SET itmmAlingnType:ONRADIOCHANGE TO change_mode_translate_facing@.
SET itmmMoveType:ONRADIOCHANGE TO change_translate_type@.
SET itmsUpdate:ONCLICK TO settings_update@.
SET itmcStart:ONCLICK TO run_translate@.
SET itmcStop:ONCLICK TO translation_abort@.
SET itmcUpdate:ONCLICK TO update_translate@.
SET itmntl0GetDist:ONCLICK TO load_distance@.

SET itmntLayout1:ONRADIOCHANGE TO change_translate_type@.
SET itmntLayout2:ONRADIOCHANGE TO change_translate_type@.
SET itmntLayout3:ONRADIOCHANGE TO change_translate_type@.

RCS OFF.
SAS OFF.
ABORT OFF.

LOCAL tarPort IS FALSE.
LOCAL taskList IS LIST().
field_cycle(LIST(ibslField,ibdlField,itmnfl0Pitch,itmnfl1Yaw,itmnfl2Roll,itmntl1Fore,itmntl2Top,itmntl3Star,itmsl0Speed,itmsl1Accel)).
taskList:ADD(update_status@:BIND(0)).
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
	IF selectedMenu = imsUpdateStatus {
		iStatusDisp:SHOW.
	} ELSE {
		iStatusDisp:HIDE.
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
		dist_speed_restrict(selectedMode).
	}
}

FUNCTION dist_speed_restrict {
	PARAMETER selectedMode.
	IF selectedMode = itmmatFace {
		SET itmntl2Speed:PRESSED TO TRUE.
		SET itmntl3Speed:PRESSED TO TRUE.
	} ELSE IF itmmatFace:PRESSED {
		IF selectedMode = itmntl2Dist {
			SET itmntl2Speed:PRESSED TO TRUE.
			PRINT "up/down can only be speed in COM mode".
		}
		IF selectedMode = itmntl3Dist {
			SET itmntl3Speed:PRESSED TO TRUE.
			PRINT "left/right can only be speed in COM mode".
		}
	}
}

FUNCTION change_translate_type {
	PARAMETER selectedType.
	IF selectedType = itmmmtRot {
		itmNavigation:SHOW.
		itmControl:SHOW.
		itmntl0GetDist:HIDE.
		itmSettings:HIDE.
		itmnTarget:HIDE.
	}
	IF selectedType = itmmmtTrans {
		itmntl0GetDist:SHOW.
		itmNavigation:SHOW.
		itmControl:SHOW.
		itmnTarget:SHOW.
		itmSettings:HIDE.
	}
	IF selectedType = itmmmtSettings {
		itmNavigation:HIDE.
		itmControl:HIDE.
		itmSettings:SHOW.
	}

}

FUNCTION run_Burn { IF have_valid_target() {
	control_point().
	WAIT UNTIL active_engine(FALSE).
	ibStop:SHOW.
	hide_start_buttons(TRUE).
	LOCAL localTarget IS target_craft(TARGET).
	SET statusData["dispType"] TO 1.

	IF ibbmRetro:PRESSED {
		taskList:ADD(burn@:BIND(0,localTarget,0)).
		SET statusData["data"][0] TO 1.
		PRINT "running retro_burn".
	} ELSE {
		LOCAL targetSpeed IS get_number(ibslField,1).
		LOCAL speedLimit IS (localTarget:POSITION - SHIP:POSITION):MAG / 90.

		IF ibbmTarget:PRESSED {
			taskList:ADD(burn@:BIND(0,localTarget,targetSpeed,speedLimit)).
			PRINT "running burn_at_target".
			SET statusData["data"][0] TO 1.
		} ELSE IF ibbmClose:PRESSED {
			LOCAL targetDist IS get_number(ibdlField,100).
			SET targetSpeed TO MIN(targetSpeed,speedLimit).
			taskList:ADD(burn@:BIND(0,localTarget,targetSpeed,targetDist)).
			PRINT "running close_to_target".
			SET statusData["data"][0] TO 2.
			SET statusData["data"][3] TO targetDist.
		}
		SET statusData["data"][2] TO targetSpeed.
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
		SET statusData["dispType"] TO 0.
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
		SET relitaveSpeed TO (targetVelocityVec - relitaveVelocityVec):MAG.
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

	SET burnData["steerVec"] TO (targetVelocityVec - (relitaveVelocityVec + (targetVelocityVec:NORMALIZED * vecMod))).
	IF statusData["dispOn"] {
		SET statusData["data"][1] TO burnState.
		SET statusData["data"][4] TO relitaveVelocityVec:MAG.
		SET statusData["data"][5] TO burnData["steerVec"]:MAG.
		SET statusData["data"][6] TO vecToTarget:MAG.
		SET statusData["data"][7] TO ABS(STEERINGMANAGER:ANGLEERROR).
	}

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
		LOCAL alingedTime IS 5 - steering_alinged_duration().
		SET statusData["data"][8] TO alingedTime.
		IF alingedTime <= 0 {
			taskList:ADD(burn@:BIND((burnState + 1),localTarget,targetSpeed,targetDist)).
			RETURN TRUE.
		} ELSE {
			RETURN FALSE.
		}
	} ELSE IF burnState = 2 {
		//LOCAL maxThrot IS MAX(1 - LOG10(MAX(ABS(STEERINGMANAGER:ANGLEERROR) * 100,1))/3.35,0).
		LOCAL maxThrot IS MIN(MAX(1.1 - (ABS(STEERINGMANAGER:ANGLEERROR) / 5),0),1).
		//LOCAL maxThrot IS MAX(1 - ABS(STEERINGMANAGER:ANGLEERROR),0).
		//LOCAL maxThrot IS 1.
		//LOCAL speedCoeficent IS COS(MIN(ABS(STEERINGMANAGER:ANGLEERROR*10),90)).
		//PRINT "speedCoeficent: " + ROUND(speedCoeficent,2)  + "   " AT(0,0).
		SET burnData["throttle"] TO MAX(MIN((relitaveSpeed / shipAcceleration) * throtCoeficent,maxThrot),0).
		//CLEARSCREEN.
		//PRINT "something is off with the throttle math".
		//PRINT "relSpeed: " + relitaveSpeed.
		//PRINT "shipACC: " + shipAcceleration.
		//PRINT "throtCoeficent: " + throtCoeficent.
		//PRINT "maxThrot: " + maxThrot.
		//PRINT "Throt: " + burnData["throttle"].

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
	IF have_valid_target() {
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
		SET ipstSize:TEXT TO "		   Size: " + ipspl0PortSize:VALUE.
		SET ipstVes:TEXT TO "Vessel Port: " + ipspl1PortSelectVes:VALUE.
		ipstTar:HIDE.
		ipsTarget:SHOW.
		ipsLabel1:SHOW.
	} ELSE {
		portData["targetPorts"]:ADD(portData["shipList"][0][portSize][ipspl1PortSelectVes:INDEX]).
		portData["targetPorts"]:ADD(portData["targetList"][0][portSize][ipspl2PortSelectTar:INDEX]).
		SET portData["isKlaw"] TO FALSE.
		SET portData["changedTarget"] TO TRUE.
		SET ipstSize:TEXT TO "		   Size: " + ipspl0PortSize:VALUE.
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

FUNCTION run_translate { IF have_valid_target() {
	update_translate().
	itmcStop:SHOW.
	itmcUpdate:SHOW.
	hide_start_buttons(TRUE).

	LOCAL targetPoint IS target_craft(TARGET).
	LOCAL shipPoint IS SHIP.
	SET statusData["dispType"] TO 2.
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

FUNCTION update_translate { IF have_valid_target() {
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

	IF itmmmtTrans:PRESSED {
		SET translateData["doTranslation"] TO TRUE.
	}
	IF itmmmtRot:PRESSED {
		SET translateData["doTranslation"] TO FALSE.
	}

	LOCAL distTemp IS axis_distance(targetPoint,shipPoint).
	IF itmntl1Speed:PRESSED {
		SET translateData["foreVal"] TO get_number(itmntl1Fore,0).
		SET translateData["distControl"]["for"] TO FALSE.
	} ELSE {
		SET translateData["foreVal"] TO get_number(itmntl1Fore,distTemp[1]).
		SET translateData["distControl"]["for"] TO TRUE.
	}
	IF itmntl2Speed:PRESSED {
		SET translateData["topVal"] TO get_number(itmntl2Top,0).
		SET translateData["distControl"]["top"] TO FALSE.
	} ELSE {
		SET translateData["topVal"] TO get_number(itmntl2Top,-distTemp[2]).
		SET translateData["distControl"]["top"] TO TRUE.
	}
	IF itmntl3Speed:PRESSED {
		SET translateData["starVal"] TO get_number(itmntl3Star,0).
		SET translateData["distControl"]["star"] TO FALSE.
	} ELSE {
		SET translateData["starVal"] TO get_number(itmntl3Star,distTemp[3]).
		SET translateData["distControl"]["star"] TO TRUE.
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

FUNCTION load_distance { IF have_valid_target() {
	LOCAL targetPoint IS target_craft(TARGET).
	LOCAL shipPoint IS SHIP.
	IF translateData["targetIsType"] = "port" {
		SET shipPoint TO portData["targetPorts"][0].
		IF NOT portData["isKlaw"] {
			SET targetPoint TO portData["targetPorts"][1].
		}
	}
	IF translateData["targetIsType"] = "com" {
		IF NOT portData["isKlaw"] {
			SET targetPoint TO portData["targetPorts"][1].
		}
	}
	LOCAL distTemp IS axis_distance(targetPoint,shipPoint).
	IF itmntl1Dist:PRESSED {
		SET itmntl1Fore:TEXT TO ROUND(distTemp[1],2):TOSTRING.
	}
	IF itmntl2Dist:PRESSED {
		SET itmntl2Top:TEXT TO ROUND(distTemp[2],2):TOSTRING.
	}
	IF itmntl3Dist:PRESSED {
		SET itmntl3Star:TEXT TO ROUND(-distTemp[3],2):TOSTRING.
	}
}}

FUNCTION translate {
	PARAMETER translateState,shipPoint,targetPoint,isKlaw.
	LOCAL targetFacing IS targetPoint:FACING.
	LOCAL targetFacingFor IS targetFacing:FOREVECTOR.
	LOCAL targetFacingTop IS targetFacing:TOPVECTOR.
	LOCAL targetFacingStar IS targetFacing:STARVECTOR.
	IF translation_new_target(translateState,shipPoint,targetPoint,isKlaw) { RETURN TRUE. }
	IF translateData["targetIsType"] = "port" {
		SET targetFacing TO targetPoint:PORTFACING.
		SET targetFacingFor TO targetFacing:FOREVECTOR.
		SET targetFacingTop TO targetFacing:TOPVECTOR.
		SET targetFacingStar TO targetFacing:STARVECTOR.
		SET translateData["steerVec"] TO ANGLEAXIS(translateData["Roll"],-targetFacingFor) * LOOKDIRUP(-targetFacingFor, targetFacingTop).
		IF shipPoint:STATE:CONTAINS("Docked") {
			taskList:ADD(shutdown_stack@).
			RETURN TRUE.
		}
		SET statusData["data"][0] TO 0.
	} ELSE IF translateData["targetIsType"] = "craft" {
		LOCAL steerDir IS ANGLEAXIS(-translateData["Pitch"],targetFacingStar) * targetFacing.
		SET steerDir TO ANGLEAXIS(translateData["Yaw"],steerDir:TOPVECTOR) * steerDir.
		SET translateData["steerVec"] TO ANGLEAXIS(translateData["Roll"],steerDir:FOREVECTOR) * steerDir.
		SET statusData["data"][0] TO 1.
	} ELSE IF translateData["targetIsType"] = "com" {
		SET targetFacing TO SHIP:FACING.
		SET targetFacingFor TO targetFacing:FOREVECTOR.
		SET targetFacingTop TO targetFacing:TOPVECTOR.
		SET targetFacingStar TO targetFacing:STARVECTOR.
		SET translateData["steerVec"] TO LOOKDIRUP(targetPoint:POSITION - shipPoint:POSITION,SHIP:FACING:TOPVECTOR).
		SET statusData["data"][0] TO 2.
	}
	IF statusData["dispOn"] {
		SET statusData["data"][1] TO translateState.
		SET statusData["data"][2] TO targetFacing.
		SET statusData["data"][3] TO shipPoint:POSITION - targetPoint:POSITION.
		SET statusData["data"][4] TO SHIP:VELOCITY:ORBIT - target_craft(targetPoint):VELOCITY:ORBIT.
	}
	IF translateData["stop"] {
		SET statusData["dispType"] TO 0.
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
			taskList:ADD(translate@:BIND((translateState + 1),shipPoint,targetPoint,isKlaw)).
			RETURN TRUE.
		} ELSE {
			RETURN FALSE.
		}
	} ELSE IF translateState = 2 {
		IF translateData["doTranslation"] {
			LOCAL targetPosition IS targetPoint:POSITION.
			LOCAL vecToTarget IS targetPosition - shipPoint:POSITION.
			LOCAL desiredVelocityVec IS v(0,0,0).
			//CLEARSCREEN.
			IF translateData["targetIsType"] = "com" {
				IF translateData["distControl"]["for"] {
					SET targetPosition TO targetPosition - vecToTarget:NORMALIZED * translateData["foreVal"].
				} ELSE {
					SET desiredVelocityVec TO desiredVelocityVec + (shipPoint:FACING:FOREVECTOR * translateData["foreVal"]).
					SET targetPosition TO shipPoint:POSITION.
				}
				SET desiredVelocityVec TO desiredVelocityVec + (shipPoint:FACING:TOPVECTOR * translateData["topVal"]).
				SET desiredVelocityVec TO desiredVelocityVec + (shipPoint:FACING:STARVECTOR * translateData["starVal"]).
			} ELSE {
				//PRINT translateData["distControl"].
				IF translateData["distControl"]["For"] {
					SET targetPosition TO targetPosition + (targetFacingFor * translateData["foreVal"]).
				//	PRINT "for dist".
				} ELSE {
					SET desiredVelocityVec TO desiredVelocityVec + (-targetFacingFor * translateData["foreVal"]).
					SET targetPosition TO targetPosition + (-targetFacingFor * VDOT(vecToTarget,targetFacingFor)).
				//	PRINT "for speed".
				}
				IF translateData["distControl"]["top"] {
					SET targetPosition TO targetPosition + (targetFacingTop * translateData["topVal"]).
				//	PRINT "top dist".
				} ELSE {
					SET desiredVelocityVec TO desiredVelocityVec + (targetFacingTop * translateData["topVal"]).
					SET targetPosition TO targetPosition + (-targetFacingTop * VDOT(vecToTarget,targetFacingTop)).
				//	PRINT "top speed".
				}
				IF translateData["distControl"]["star"] {
					SET targetPosition TO targetPosition + (-targetFacingStar * translateData["starVal"]).
				//	PRINT "star dist".
				} ELSE {
					SET desiredVelocityVec TO desiredVelocityVec + (-targetFacingStar * translateData["starVal"]).
					SET targetPosition TO targetPosition + (-targetFacingStar * VDOT(vecToTarget,targetFacingStar)).
				//	PRINT "star speed".
				}
			}

			SET vecToTarget TO targetPosition - shipPoint:POSITION.
			LOCAL speedCoeficent IS accel_dist_to_speed(translateData["accel"],vecToTarget:MAG,translateData["topSpeed"],0).
			SET desiredVelocityVec TO desiredVelocityVec + vecToTarget:NORMALIZED * speedCoeficent.

			IF desiredVelocityVec:MAG > translateData["topSpeed"] {
				SET desiredVelocityVec TO desiredVelocityVec:NORMALIZED * translateData["topSpeed"].
			}

			IF translateData["distControl"]["For"] OR translateData["distControl"]["top"] OR translateData["distControl"]["star"] {
				SET desiredVelocityVec TO desiredVelocityVec + angular_velocity_vector(targetPoint).
			}

			//PRINT "distError: " + ROUND(vecToTarget:MAG,2).
			//CLEARSCREEN.
			//PRINT "name: " + shipPoint:NAME.
			//LOCAL targetSpinVector IS angular_velocity_vector(target_craft(targetPoint),targetPosition).
			//PRINT "angularVelMag: " + ROUND(targetSpinVector:MAG,2).
			translation_control(desiredVelocityVec,targetPoint,shipPoint).
			RETURN FALSE.
		} ELSE {
			SET SHIP:CONTROL:FORE TO 0.
			SET SHIP:CONTROL:TOP TO 0.
			SET SHIP:CONTROL:STARBOARD TO 0.
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

FUNCTION translation_abort {
	PRINT "stopping translation".
	SET translateData["stop"] TO TRUE.
}

FUNCTION translation_control {
	PARAMETER desiredVelocityVec,tar,craft.
	RCS ON.
	LOCAL shipFacing IS SHIP:FACING.
	LOCAL axisSpeed IS axis_speed(craft,tar).
	//PRINT "velocityError: " + ROUND((desiredVelocityVec - axisSpeed[0]):MAG,2).
	SET PID["Fore"]:SETPOINT TO VDOT(desiredVelocityVec,shipFacing:FOREVECTOR).
	SET PID["Top"]:SETPOINT TO VDOT(desiredVelocityVec,shipFacing:TOPVECTOR).
	SET PID["Star"]:SETPOINT TO VDOT(desiredVelocityVec,shipFacing:STARVECTOR).

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
	PARAMETER targetPoint.
	LOCAL targetCraft IS target_craft(targetPoint).
	LOCAL angleVec IS SHIP:POSITION - targetCraft:POSITION.
	LOCAL angularVelVecNormal IS targetCraft:ANGULARVEL.//in radians

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

FUNCTION update_status {
	PARAMETER statusState.
//	CLEARSCREEN.
//	PRINT "statusState: " + statusState.
//	PRINT "distType: " + statusData["dispType"].
//	PRINT "canSee: " + iStatusDisp:VISIBLE.
	IF statusState = 0 {
		IF imsUpdateStatus:PRESSED {
			taskList:ADD(update_status@:BIND(1)).
			SET statusData["dispOn"] TO TRUE.
			RETURN TRUE.
		} ELSE {
			RETURN FALSE.
		}
	}
	IF statusState = 1 {
		IF statusData["dispType"] = 1 {
			IF statusData["data"][0] = 0 {
				SET isdl00Text0:TEXT TO "Stopping Relative to Target".
			} ELSE {
				IF statusData["data"][0] = 1 {
					SET isdl00Text0:TEXT TO "Burning Towards Target".
					SET isdl01Text0:TEXT TO "Speed Target: " + si_formating(statusData["data"][2],"m/s").
				} ELSE {
					SET isdl00Text0:TEXT TO "Closing With Target".
					SET isdl01Text0:TEXT TO "Speed Target: " + si_formating(statusData["data"][2],"m/s").
					SET isdl01Text1:TEXT TO "Distance Target: " + si_formating(statusData["data"][3],"m").
				}
				isdLayout01:SHOW.
			}
			SET isdl02Text0:TEXT TO "Relitave Speed: ".
			SET isdl03Text0:TEXT TO "DV left on burn: ".
			SET isdl04Text0:TEXT TO "Dist to Target: ".
			SET isdl051l0Text0:TEXT TO "Steering Error: ".
			isdLayout00:SHOW.
			isdLayout02:SHOW.
			isdLayout03:SHOW.
			isdLayout04:SHOW.
			isdLayout05_1:SHOW.
		} ELSE IF statusData["dispType"] = 2 {
			SET isdl02Text0:TEXT TO "Distance: ".
			SET isdl03Text0:TEXT TO "Speed: ".
			SET isdl052Text0:TEXT TO "For Dist: ".
			SET isdl06Text0:TEXT TO "For Speed: ".
			SET isdl08Text0:TEXT TO "Top Dist: ".
			SET isdl09Text0:TEXT TO "Top Speed: ".
			SET isdl11Text0:TEXT TO "Star Dist: ".
			SET isdl12Text0:TEXT TO "Star Speed: ".
			isdLayout00:SHOW.
			isdLayout01:SHOW.
			isdLayout02:SHOW.
			isdLayout03:SHOW.
			isdLayout04:SHOW.
			isdLayout05_2:SHOW.
			isdLayout06:SHOW.
			isdLayout07:SHOW.
			isdLayout08:SHOW.
			isdLayout09:SHOW.
			isdLayout10:SHOW.
			isdLayout11:SHOW.
			isdLayout12:SHOW.
		} ELSE {
			//hide all visible fields
			//print error
		}
		taskList:ADD(update_status@:BIND(2)).
		RETURN TRUE.
	}
	IF statusState = 2 {
		IF NOT imsUpdateStatus:PRESSED {
			//hide all fields
			SET statusData["dispOn"] TO FALSE.
			taskList:ADD(update_status@:BIND(0)).
			i_clear_status().
			RETURN TRUE.
		}
		IF statusData["dispType"] = 1 {
			SET isdl00Text1:TEXT TO "State: " + statusData["data"][1].
			SET isdl02Text1:TEXT TO si_formating(statusData["data"][4],"m/s").//relitave speed
			SET isdl03Text1:TEXT TO si_formating(statusData["data"][5],"m/s").//DV on burn
			SET isdl04Text1:TEXT TO si_formating(statusData["data"][6], "m").//dist to target
			IF statusData["data"][1] = 1 {
				SET isdl051l1Text0:TEXT TO "Alignment Time: ".
				SET isdl051l1Text1:TEXT TO time_formating(statusData["data"][8],0,1).
			} ELSE {
				SET isdl051l1Text0:TEXT TO " ".
				SET isdl051l1Text1:TEXT TO " ".
			}
			SET isdl051l0Text1:TEXT TO padding(statusData["data"][7],3,1).//steer error
		} ELSE IF statusData["dispType"] = 2 {
			IF statusData["data"][0] = 0 {
				SET isdl00Text0:TEXT TO "Matching Port, ".
			} ELSE IF statusData["data"][0] = 1{
				SET isdl00Text0:TEXT TO "Matching Target, ".
			} ELSE {
				SET isdl00Text0:TEXT TO "COM targeted, ".
			}
			LOCAL forVec IS statusData["data"][2]:FOREVECTOR.
			LOCAL topVec IS statusData["data"][2]:TOPVECTOR.
			LOCAL starVec IS statusData["data"][2]:STARVECTOR.
			LOCAL distVec IS statusData["data"][3].
			LOCAL speedVec IS statusData["data"][4].
			SET isdl00Text1:TEXT TO "State: " + statusData["data"][1].
			SET isdl02Text1:TEXT TO si_formating(distVec:MAG,"m").//dist
			SET isdl03Text1:TEXT TO si_formating(speedVec:MAG,"m/s").//speed
			SET isdl052Text1:TEXT TO si_formating(VDOT(distVec,forVec),"m").//For Dist
			SET isdl06Text1:TEXT TO si_formating(VDOT(-speedVec,forVec),"m/s").//For Speed
			SET isdl08Text1:TEXT TO si_formating(VDOT(distVec,topVec),"m").//Top Dist
			SET isdl09Text1:TEXT TO si_formating(VDOT(speedVec,topVec),"m/s").//Top Speed: ".
			SET isdl11Text1:TEXT TO si_formating(VDOT(distVec,starVec),"m").//Star Dist
			SET isdl12Text1:TEXT TO si_formating(VDOT(speedVec,starVec),"m/s").//Star Speed: ".
		} ELSE {
			//hide all but 1 field 
			//print some done message
		}
		RETURN FALSE.
	}
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

FUNCTION i_speed_dist_formating {
	PARAMETER s,d.
	SET s:EXCLUSIVE TO TRUE.
	SET s:TOGGLE TO TRUE.
	SET d:PRESSED TO TRUE.
	SET d:EXCLUSIVE TO TRUE.
	SET d:TOGGLE TO TRUE.
}

FUNCTION i_width_to {
	PARAMETER i,w.
	SET i:STYLE:WIDTH TO w.
}

//FUNCTION i_status_style {
//	PARAMETER text0,text1.
//
//	SET text0:STYLE:ALIGN TO "right".
//	SET text1:STYLE:ALIGN TO "left".
//}
FUNCTION i_status_style {
	PARAMETER localItem IS iStatusDisp.
	LOCAL didRight IS FALSE.
	LOCAL layouts IS localItem:WIDGETS.
	LOCAL lSize IS interface:STYLE:WIDTH / layouts:LENGTH.
	FOR layout IN layouts {
		IF layout:ISTYPE("box") {
			i_status_style(layout).
		} ELSE {
			IF didRight {
				SET layout:STYLE:ALIGN TO "left".
				SET didRight TO FALSE.
			} ELSE {
				SET layout:STYLE:ALIGN TO "right".
				SET didRight TO TRUE.
			}
			i_width_to(layout,lSize).
		}
	}
}

FUNCTION i_clear_status {
	PARAMETER localItem IS iStatusDisp.
	IF localItem:ISTYPE("box") {
		FOR layout IN localItem:WIDGETS {
			layout:HIDE.
			i_clear_status(layout).
		}
	} ELSE {
		SET localItem:TEXT TO " ".
		localItem:SHOW.
	}
}

FUNCTION i_show_status {
	PARAMETER localItem IS iStatusDisp.
	IF localItem:ISTYPE("box") {
		FOR layout IN localItem:WIDGETS {
			IF i_show_status(layout) {
				layout:SHOW.
				BREAK.
			}
		}
		RETURN FALSE.
	} ELSE {
		RETURN localItem:TEXT <> " ".
	}
}

FUNCTION i_status_visability {
	PARAMETER doClear IS TRUE, localItem IS iStatusDisp.
	IF localItem:ISTYPE("box") {
		FOR layout IN localItem:WIDGETS {
			IF i_show_status(layout) {
				layout:SHOW.
				BREAK.
			} ELSE {
				layout:HIDE.
			}
		}
		RETURN FALSE.
	} ELSE {
		RETURN localItem:TEXT <> " ".
	}
	
}