CLEARGUIS().
FOR lib IN LIST("lib_file_util") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNPATH("1:/lib/" + lib + ".ks"). }}
IF HOMECONNECTION:ISCONNECTED {

LOCAL archiveRoot IS PATH("0:/").
LOCAL localRoot IS PATH(CORE:VOLUME).
//LOCAL localRoot IS CORE:CURRENTVOLUME.

LOCAL localDirs IS dir_scan(localRoot,FALSE).
LOCAL archiveDirs IS dir_scan(archiveRoot,FALSE).
LOCAL needRebuild IS TRUE.
LOCAL done IS FALSE.

LOCAL interface IS GUI(500).
SET interface:Y TO 150.
LOCAL ifdSlect IS interface:ADDHBOX.
 LOCAL ifdsFile IS ifdSlect:ADDRADIOBUTTON("File Tools",TRUE).
 LOCAL ifdsDir IS ifdSlect:ADDRADIOBUTTON("Directory Tools",FALSE).
LOCAL iModeList IS interface:ADDPOPUPMENU().

LOCAL SubMenu IS interface:ADDVBOX.
 LOCAL smLabel IS SubMenu:ADDLABEL("").
 LOCAL mdWarning IS SubMenu:ADDLABEL("").
 LOCAL ddWarning IS SubMenu:ADDLABEL("").
 LOCAL smNew IS SubMenu:ADDHBOX.
  LOCAL smnLabel IS smNew:ADDLABEL("").
   SET smnLabel:STYLE:ALIGN TO "RIGHT".
  LOCAL smnName IS smNew:ADDTEXTFIELD("").
   SET smnName:STYLE:WIDTH TO 350.
 LOCAL smOptions IS SubMenu:ADDVBOX.
  LOCAL uvExt IS smOptions:ADDCHECKBOX("Files Must Have Matching Extensions",TRUE).
  LOCAL uvPath IS smOptions:ADDCHECKBOX("Files Must Have Matching Paths Ignoring Root",TRUE).
  LOCAL uvSize IS smOptions:ADDCHECKBOX("Files Must NOT Have Matching Size",FALSE).
  LOCAL uvCompile IS smOptions:ADDCHECKBOX("Compile if Local File Has .ksm Extension",TRUE).

LOCAL iGoButton IS interface:ADDBUTTON("").
LOCAL iWorking IS interface:ADDBUTTON("").
iWorking:HIDE.
LOCAL iLabel0 IS interface:ADDLABEL(" ").

LOCAL iSourceMenu IS interface:ADDVBOX.//set up source interface
 LOCAL ismLabel IS iSourceMenu:ADDLABEL("Source").
 LOCAL ismVolume IS iSourceMenu:ADDHBOX.
  LOCAL ismvLabel IS ismVolume:ADDLABEL("Source Volume: ").
  LOCAL ismvList IS ismVolume:ADDPOPUPMENU().
   SET ismvList:OPTIONS TO LIST("Archive","Local").
   SET ismvList:STYLE:WIDTH TO 300.
 LOCAL ismDirectory IS iSourceMenu:ADDHBOX.
  LOCAL ismdLabel IS ismDirectory:ADDLABEL("Source Directory: ").
  LOCAL ismdList IS ismDirectory:ADDPOPUPMENU().
   SET ismdList:STYLE:WIDTH TO 300.
 LOCAL ismFile IS iSourceMenu:ADDHBOX.
  LOCAL ismfBox IS ismFile:ADDVBOX.
   LOCAL ismfbLabel IS ismfBox:ADDLABEL("Source File: ").
   LOCAL ismfbSize IS ismfBox:ADDLABEL("").
  LOCAL ismfList IS ismFile:ADDPOPUPMENU().
   SET ismfList:STYLE:WIDTH TO 300.

LOCAL iDestinationMenu IS interface:ADDVBOX.//set up destination interface
 LOCAL idmLabel IS iDestinationMenu:ADDLABEL("Destination").
 LOCAL idmVolume IS iDestinationMenu:ADDHBOX.
  LOCAL idmvBox IS idmVolume:ADDVBOX.
   LOCAL idmvbLabel IS idmvBox:ADDLABEL("Destination Volume: ").
   LOCAL idmvbSize IS idmvBox:ADDLABEL("").
  LOCAL idmvList IS idmVolume:ADDPOPUPMENU().
   SET idmvList:OPTIONS TO LIST("Archive","Local").
   SET idmvList:STYLE:WIDTH TO 300.
 LOCAL idmDirectory IS iDestinationMenu:ADDHBOX.
  LOCAL idmdLabel IS idmDirectory:ADDLABEL("Destination Directory: ").
  LOCAL idmdList IS idmDirectory:ADDPOPUPMENU().
   SET idmdList:STYLE:WIDTH TO 300.

LOCAL iLabel1 IS interface:ADDLABEL(" ").
LOCAL doneButton IS interface:ADDBUTTON("Done").

//setting up triggers
file_directory_slector(TRUE).
SET ifdsFile:ONTOGGLE TO file_directory_slector@.
SET iModeList:ONCHANGE TO subMenu_slector@.

SET ismvList:INDEX TO 0.
source_dir_slector(ismvList:VALUE).
SET ismvList:ONCHANGE TO source_dir_slector@.
SET ismdList:ONCHANGE TO source_file_slector@.
SET ismfList:ONCHANGE TO source_file_info_updater@.

SET idmvList:INDEX TO 1.
destination_dir_slector(idmvList:VALUE).
SET idmvList:ONCHANGE TO destination_dir_slector@.
SET idmdList:ONCHANGE TO destination_dir_print@.

//mode trigers
GLOBAL modeLex IS LEX().
modeLex:ADD("Copy Files",copy_from_to@).
modeLex:ADD("Compile Files",compile_file_from_to@).
modeLex:ADD("Move Files",move_from_to@).
modeLex:ADD("Change Bootfile",change_bootfile@).
modeLex:ADD("Delete Files",delete_at@).
modeLex:ADD("Rename Files",rename_file_at@).
modeLex:ADD("Edit Files",edit_file@).
modeLex:ADD("Copy Directory",copy_from_to@).
modeLex:ADD("Move Directory",move_from_to@).
modeLex:ADD("New Directory",new_directory_at@).
modeLex:ADD("Unpack Directory",unpack_directory_at@).
modeLex:ADD("Update Local Volume",update_local_volume@).
modeLex:ADD("Delete Directory",delete_at@).
SET iGoButton:ONCLICK TO run_mode@.
SET doneButton:ONCLICK TO { SET done TO TRUE. }.

interface:SHOW.//set up done waiting on user input
WAIT UNTIL done.
interface:DISPOSE.



FUNCTION run_mode {//calls chosen mode,rebuild of source/destination lists
	LOCAL menuValue IS ismvList:VALUE.   //info needed for rebuild
	IF iDestinationMenu:VISIBLE { SET menuValue TO idmvList:VALUE. }

	iGoButton:HIDE.
	iWorking:SHOW.

	LOCAL chosenMode IS iModeList:VALUE.
	PRINT " ".
	modeLex[chosenMode]:CALL().
	PRINT " ".

	IF needRebuild {//rebuild source/destination dir/file lists after a mode runs
		PRINT "rebuilding file list".
		IF menuValue = "archive" {
			SET archiveDirs TO dir_scan(archiveRoot,FALSE).
		}
		IF menuValue = "local" {
			SET localDirs TO dir_scan(localRoot,FALSE).
		}
		PRINT "rebuilt file list".
	}
	destination_dir_slector(idmvList:VALUE).
	source_dir_slector(ismvList:VALUE).//end of rebuild

	iWorking:HIDE.
	iGoButton:SHOW.
}

FUNCTION file_directory_slector {//cycles mode list between file and directory options
	PARAMETER slection.
	PRINT ifdSlect:RADIOVALUE.
	IF ifdSlect:RADIOVALUE = "File Tools" {
		SET iModeList:OPTIONS TO LIST("Copy Files","Compile Files","Move Files","Delete Files","Rename Files","Edit Files").//doesn't have "Change Bootfile" as an option due to problems with how boot files are set
	}
	IF ifdSlect:RADIOVALUE = "Directory Tools" {
		SET iModeList:OPTIONS TO LIST("Copy Directory","Move Directory","New Directory","Unpack Directory","Update Local Volume","Delete Directory").
	}
	SET iModeList:INDEX TO 0.
	subMenu_slector(iModeList:VALUE).
}

FUNCTION subMenu_slector {//changed visible mode and if a rebuild is needed for a given mode
	PARAMETER chosenMode.
	PRINT "mode: " + chosenMode.
	IF ifdsFile:PRESSED {
		IF chosenMode = "Copy Files" {
			SET smLabel:TEXT TO "Copy File From Source To Destination".
			SET iGoButton:TEXT TO "Copy".
			SET iWorking:TEXT TO "Copying".
			SET needRebuild TO TRUE.
			show_hide_inputs(1,1,1,0).
		}
		IF chosenMode = "Compile Files" {
			SET smLabel:TEXT TO "Compile File From Source To Destination".
			SET iGoButton:TEXT TO "Compile".
			SET iWorking:TEXT TO "Compiling".
			SET needRebuild TO TRUE.
			show_hide_inputs(1,1,1,0).
		}
		IF chosenMode = "Move Files" {
			SET smLabel:TEXT TO "Move File From Source To Destination".
			SET iGoButton:TEXT TO "Move".
			SET iWorking:TEXT TO "Moving".
			SET needRebuild TO TRUE.
			show_hide_inputs(1,1,1,0).
		}
		IF chosenMode = "Change Bootfile"{
			SET smLabel:TEXT TO "Change Bootfile To File Set With Source".
			SET ismvList:INDEX TO 1.//defaulting source volume to local
			source_dir_slector(ismvList:VALUE).
			SET iGoButton:TEXT TO "Change".
			SET iWorking:TEXT TO "Changing".
			SET needRebuild TO FALSE.
			show_hide_inputs(1,0,1,0).
		}
		IF chosenMode = "Delete Files" {
			SET smLabel:TEXT TO "Delete File Set With Source".
			SET iGoButton:TEXT TO "Delete".
			SET iWorking:TEXT TO "Deleting".
			SET needRebuild TO TRUE.
			show_hide_inputs(1,0,1,0).
		}
		IF chosenMode = "Rename Files" {
			SET smLabel:TEXT TO "Rename File Set With Source".
			SET smnLabel:TEXT TO "New Name: ".
			SET iGoButton:TEXT TO "Rename".
			SET iWorking:TEXT TO "Renaming".
			SET smnName:TEXT TO ismfList:VALUE:NAME.
			SET needRebuild TO TRUE.
			show_hide_inputs(1,0,1,1).
		}
		IF chosenMode = "Edit Files" {
			SET smLabel:TEXT TO "Edit File Set With Source".
			SET iGoButton:TEXT TO "Edit".
			SET iWorking:TEXT TO "Editing".
			SET needRebuild TO FALSE.
			show_hide_inputs(1,0,1,0).
		}
	} ELSE {
		IF chosenMode = "Copy Directory" {
			SET smLabel:TEXT TO "Copy Directory From Source To Destination".
			SET iGoButton:TEXT TO "Copy".
			SET iWorking:TEXT TO "Copying".
			SET needRebuild TO TRUE.
			show_hide_inputs(1,1,0,0).
		}
		IF chosenMode = "Move Directory" {
			SET smLabel:TEXT TO "Move Directory From Source To Destination".
			SET iGoButton:TEXT TO "Move".
			SET iWorking:TEXT TO "Moving".
			SET needRebuild TO TRUE.
			show_hide_inputs(1,1,0,2).
		}
		IF chosenMode = "New Directory" {
			SET smLabel:TEXT TO "Create New Directory At Source".
			SET smnLabel:TEXT TO "New Directory: ".
			SET iGoButton:TEXT TO "Create".
			SET iWorking:TEXT TO "Creating".
			SET smnName:TEXT TO "".
			SET needRebuild TO TRUE.
			show_hide_inputs(1,0,0,1).
		}
		IF chosenMode = "Unpack Directory" {
			SET smLabel:TEXT TO "Unpack Contents of Source Directory in Destination".
			SET iGoButton:TEXT TO "Unack".
			SET iWorking:TEXT TO "Unacking".
			SET needRebuild TO TRUE.
			show_hide_inputs(1,1,0,0).
		}
		IF chosenMode = "Update Local Volume" {
			SET smLabel:TEXT TO "Update Local Volume".
			SET iGoButton:TEXT TO "Update".
			SET iWorking:TEXT TO "Updating".
			SET needRebuild TO FALSE.
			show_hide_inputs(0,0,0,4).
		}
		IF chosenMode = "Delete Directory" {
			SET smLabel:TEXT TO "Delete Directory Set With Source".
			SET iGoButton:TEXT TO "Delete".
			SET iWorking:TEXT TO "Deleting".
			SET needRebuild TO TRUE.
			show_hide_inputs(1,0,0,3).
		}
	}
}

FUNCTION show_hide_inputs {
	PARAMETER ism,idm,ismf,ismx.
	IF ism = 1 { iSourceMenu:SHOW. } ELSE { iSourceMenu:HIDE. }
	IF idm = 1 { iDestinationMenu:SHOW. } ELSE { iDestinationMenu:HIDE. }
	IF ismf = 1 { ismFile:SHOW. } ELSE { ismFile:HIDE. }

	IF ismx = 1 { smNew:SHOW. } ELSE { smNew:HIDE. }
	IF ismx = 2 { mdWarning:SHOW. } ELSE { mdWarning:HIDE. }
	IF ismx = 3 { ddWarning:SHOW. } ELSE { ddWarning:HIDE. }
	IF ismx = 4 { smOptions:SHOW. } ELSE { smOptions:HIDE. }
}

FUNCTION source_dir_slector {//build source directory list
	PARAMETER vol.
	PRINT "Source vol: " + vol.
	IF vol = "archive" {
		SET ismdList:OPTIONS TO archiveDirs.
	} ELSE {
		SET ismdList:OPTIONS TO localDirs.
	}
	SET mdWarning:TEXT TO "NOTE: Can Not Move Directory: " + ismdList:OPTIONS[0].
	SET ddWarning:TEXT TO "NOTE: Can Not Delete Directory: " + ismdList:OPTIONS[0].
	index_in_range(ismdList).
	source_file_slector(ismdList:VALUE).
}

FUNCTION source_file_slector {//build source file list
	PARAMETER dir.
	PRINT "Source dir: " + dir.
	LOCAL fileList IS get_files(dir).
	SET ismfList:OPTIONS TO file_filter(fileList).
	index_in_range(ismfList).
	source_file_info_updater(ismfList:VALUE).
}

FUNCTION source_file_info_updater {//update information about slected source file
	PARAMETER sFile.
	IF ismfList:OPTIONS:LENGTH <> 0 {
		PRINT "Source File: " + sFile.
		SET ismfbSize:TEXT TO "File Size: " + sFile:SIZE.
		IF iModeList:VALUE = "Rename Files" { SET smnName:TEXT TO sFile:NAME. }
		ismfList:SHOW.
	} ELSE {
		SET ismfbSize:TEXT TO "No Files in Directory".
		ismfList:HIDE.
	}
}

FUNCTION destination_dir_slector {//build destination directory list
	PARAMETER vol.
	PRINT "Destination vol: " + vol.
	IF vol = "archive" {
		SET idmdList:OPTIONS TO archiveDirs.
		SET idmvbSize:TEXT TO "Free Space: Infinite".
	} ELSE {
		SET idmdList:OPTIONS TO localDirs.
		SET idmvbSize:TEXT TO "Free Space: " + localRoot:VOLUME:FREESPACE.
	}
	index_in_range(idmdList).
	destination_dir_print(idmdList:VALUE).
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

FUNCTION destination_dir_print {//did more once
	PARAMETER dir.
	PRINT "Destination dir: " + dir.
}

FUNCTION copy_from_to {
	LOCAL fromPath IS PATH(ismdList:VALUE).
	LOCAL toPath IS PATH(idmdList:VALUE).
	LOCAL fileName IS ismfList:VALUE:NAME.
	IF ifdsFile:PRESSED {
		PRINT "Copying File: " + fileName.
		PRINT "        From: " + fromPath + " To: " + toPath.
		COPYPATH(fromPath:COMBINE(fileName),toPath).
	} ELSE {
		PRINT "Copying Directory From: " + fromPath.
		PRINT "                    To: " + toPath.
		COPYPATH(fromPath,toPath).
	}
}

FUNCTION move_from_to {
	LOCAL fromPath IS PATH(ismdList:VALUE).
	LOCAL toPath IS PATH(idmdList:VALUE).
	LOCAL fileName IS ismfList:VALUE:NAME.
	IF ifdsFile:PRESSED {
		PRINT "Moving File: " + fileName.
		PRINT "       From: " + fromPath + " To: " + toPath.
		MOVEPATH(fromPath:COMBINE(fileName),toPath).
	} ELSE {
		IF ismdList:INDEX = 0 {
			PRINT "Can Not Move Root".
		} ELSE {
			PRINT "Moving Directory: " + fromPath:NAME.
			PRINT "            From: " + fromPath + " To: " + toPath.
			MOVEPATH(fromPath,toPath).
		}
	}
}

FUNCTION change_bootfile {//not working core:bootfilename can only be set to files on the root directory
	LOCAL fromPath IS PATH(ismdList:VALUE).
	LOCAL fileName IS ismfList:VALUE:NAME.
	LOCAL oldBootFile IS CORE:BOOTFILENAME.
	SET CORE:BOOTFILENAME TO fromPath:COMBINE(fileName).
	PRINT "Changing Bootfile".
	PRINT "            From: " + oldBootFile.
	PRINT "              To: " + CORE:BOOTFILENAME.
}

FUNCTION delete_at {
	LOCAL fromPath IS PATH(ismdList:VALUE).
	LOCAL fileName IS ismfList:VALUE:NAME.
	IF ifdsFile:PRESSED {
		DELETEPATH(fromPath:COMBINE(fileName)).
		PRINT "Deleted File: " + fileName.
		PRINT "          At: " + fromPath.
	} ELSE {
		IF ismdList:INDEX = 0 {
			PRINT "Can Not Delete Root".
		} ELSE {
			DELETEPATH(fromPath).
			PRINT "Deleted Directory At: " + fromPath.
		}
	}
}

FUNCTION compile_file_from_to {
	LOCAL fromPath IS PATH(ismdList:VALUE).
	LOCAL toPath IS PATH(idmdList:VALUE).
	LOCAL fileName IS ismfList:VALUE:NAME.
	PRINT "Compiling File: " + fileName.
	PRINT "          From: " + fromPath + " To: " + toPath.
	COMPILE (fromPath:COMBINE(fileName)) TO (toPath:COMBINE(name_only(ismfList:VALUE)+".ksm")).
	PRINT "Done Compiling: " + fileName.
}

FUNCTION rename_file_at {
	LOCAL fromPath IS PATH(ismdList:VALUE).
	LOCAL fileName IS ismfList:VALUE:NAME.
	LOCAL newName IS smnName:TEXT.
	MOVEPATH(fromPath:COMBINE(fileName),fromPath:COMBINE(newName)).
	PRINT "Renamed File From: " + fileName.
	PRINT "               To: " + newName.
	PRINT "               At: " + fromPath.
}

FUNCTION edit_file {
	LOCAL fromPath IS PATH(ismdList:VALUE).
	LOCAL fileName IS ismfList:VALUE:NAME.
	EDIT(fromPath:COMBINE(fileName)).
	PRINT "Editing File: " + fileName.
	PRINT "          At: " + fromPath.
}

FUNCTION new_directory_at {
	LOCAL fromPath IS PATH(ismdList:VALUE).
	LOCAL newDirName IS smnName:TEXT.
	IF NOT EXISTS(fromPath:COMBINE(newDirName)) {
		CREATEDIR(fromPath:COMBINE(newDirName)).
		PRINT "Making New Directory: " + newDirName.
		PRINT "                  At: " + fromPath.
	} ELSE {
		PRINT "Directory Already Exists".
	}
	SET smnName:TEXT TO "".
}

FUNCTION unpack_directory_at {
	LOCAL fromPath IS PATH(ismdList:VALUE).
	LOCAL toPath IS PATH(idmdList:VALUE).
	PRINT "Unpacking: " + fromPath.
	PRINT "       At: " + toPath.
	LOCAL localFiles IS get_files(fromPath).
	LOCAL localFileList IS file_filter(localFiles).
	LOCAL localDirList IS dir_filter(localFiles).
	FOR lFile IN localFileList { COPYPATH (fromPath:COMBINE(lFile:NAME),toPath). }
	FOR dFile IN localDirList { COPYPATH (fromPath:COMBINE(dFile:NAME),toPath). }
}

FUNCTION update_local_volume {
	LOCAL notUsePath IS NOT uvPath:PRESSED.
	LOCAL notUseSize IS NOT uvSize:PRESSED.
	LOCAL notUseExtension IS NOT uvExt:PRESSED.
	LOCAL useCompile IS uvCompile:PRESSED.
	PRINT "Starting Update".
	PRINT " ".
	LOCAL lFiles IS dir_scan(localRoot).
	LOCAL aFiles IS dir_scan(archiveRoot).
	LOCAL lfNameOnly IS name_only(lFiles).
	LOCAL afNameOnly IS name_only(aFiles).
	LOCAL lfNoRoot IS no_root(lFiles).
	LOCAL afNoRoot IS no_root(aFiles).
	FROM {LOCAL iL IS 0.} UNTIL iL >= lFiles:LENGTH STEP {SET iL TO iL + 1.} DO {
		FROM {LOCAL iA IS 0.} UNTIL iA >= aFiles:LENGTH STEP {SET iA TO iA + 1.} DO {
			IF afNameOnly[iA] = lfNameOnly[iL] {//name check
				IF notUsePath OR (afNoRoot[iA] = lfNoRoot[iL]) {//path check
					IF notUseSize OR (aFiles[iA][1]:SIZE <> lFiles[iL][1]:SIZE) {//size check
						IF notUseExtension OR (aFiles[iA][1]:EXTENSION = lFiles[iL][1]:EXTENSION) {//extension check
							COPYPATH(aFiles[iA][0]:COMBINE(aFiles[iA][1]:NAME),lFiles[iL][0]).
							PRINT "Copying File: " + aFiles[iA][1].
							PRINT "        From: " + aFiles[iA][0] + " To: " + lFiles[iL][0].
							PRINT " ".
						}
					}
					IF useCompile AND (aFiles[iA][1]:EXTENSION = "ks") AND (lFiles[iL][1]:EXTENSION = "ksm") {
						PRINT "Compiling File: " + aFiles[iA][1].
						PRINT "          From: " + aFiles[iA][0] + " To: " + lFiles[iL][0].
						COMPILE aFiles[iA][0]:COMBINE(aFiles[iA][1]:NAME) TO lFiles[iL][0]:COMBINE(name_only(lFiles[iL][1]) + ".ksm").
						PRINT "Done Compiling: " + aFiles[iA][1].
						PRINT " ".
					}
				}
			}
		}
	}
	PRINT "Done Updating Files".
}

FUNCTION get_files {
	PARAMETER dir.
	LOCAL dirRevert IS PATH().
	CD(PATH(dir)).
	LOCAL fileList IS LIST().
	LIST FILES IN fileList.
	WAIT 0.
	CD(dirRevert).
	RETURN fileList.
}

FUNCTION file_filter {//filters a list for files
	PARAMETER rawList.
	LOCAL localList IS LIST().
	FOR raw IN rawList { IF raw:ISFILE { localList:ADD(raw). } }
	RETURN localList.
}

FUNCTION dir_filter {//filters a list for files
	PARAMETER rawList.
	LOCAL localList IS LIST().
	FOR raw IN rawList { IF NOT raw:ISFILE { localList:ADD(raw). } }
	RETURN localList.
}
}