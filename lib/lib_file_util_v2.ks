@LAZYGLOBAL OFF.

FUNCTION dir_list_scan_for_files {
	PARAMETER dirList,extL.
	LOCAL dirRevert IS PATH().
	LOCAL masterList IS LIST().
	FOR dir IN dirList {
		FOR subFile IN dir_scan_for_files(Dir,extL,FALSE) {
			masterList:ADD(subFile).
		}
	}
	WAIT 0.01.
	CD(dirRevert).
	RETURN masterList.
}

FUNCTION dir_scan_for_files {
	PARAMETER dir,extL,doDirRevert IS TRUE.
	LOCAL masterList IS LIST().

	LOCAL dirRevert IS PATH().
	LOCAL dirPath IS PATH(dir).
	CD(dirPath).
	LOCAL fileList IS LIST().
	LIST FILES IN fileList.

	LOCAL dirList IS LIST().
	FOR filter IN fileList {
		FOR ext IN extL {
			IF filter:ISFILE AND ((filter:EXTENSION = ext) OR (-99999 = ext)) {
				masterList:ADD(LIST(dirPath,filter)).
			}
		}
		IF (NOT filter:ISFILE) {
			dirList:ADD(dirPath:COMBINE(filter + "/")).
		}
	}
	FOR subDir IN dirList {
		FOR subFile IN dir_scan_for_files(subDir,extL,FALSE) {
			masterList:ADD(subFile).
		}
	}
	IF doDirRevert {
		WAIT 0.01.
		CD(dirRevert).
	}
	RETURN masterList.
}

FUNCTION no_root {
	PARAMETER segment.
	RETURN segment:SEGMENTS:JOIN("/").
}

FUNCTION name_only {
	PARAMETER fileName.
	RETURN fileName:NAME:SUBSTRING(0,fileName:NAME:LENGTH - (fileName:EXTENSION:LENGTH + 1)).
}