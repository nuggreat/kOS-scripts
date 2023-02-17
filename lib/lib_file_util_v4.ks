@LAZYGLOBAL OFF.

FUNCTION dir_scan {
	PARAMETER dirIn,extL IS LIST(-99999),doDirRevert IS TRUE.
	LOCAL returnList IS LIST().

	LOCAL dirRevert IS PATH().
	IF dirIn:ISTYPE("list") {
		FOR subDir IN dirIn {
			FOR foundItem IN dir_scan(subDir,extL,FALSE) {
				returnList:ADD(foundItem).
			}
		}
	} ELSE {
		LOCAL dirPath IS PATH(dirIn).
		CD(dirPath).
		LOCAL fileList IS LIST().
		LIST FILES IN fileList.

		LOCAL dirList IS LIST().
		IF NOT extL:ISTYPE("list") { returnList:ADD(dirPath). }
		FOR filter IN fileList {
			IF extL:ISTYPE("list") {
				IF filter:ISFILE AND (extL:CONTAINS(filter:EXTENSION) OR extL:CONTAINS(-99999)) {
					returnList:ADD(LIST(dirPath,filter)).
				}
			}
			IF (NOT filter:ISFILE) {
				dirList:ADD(dirPath:COMBINE(filter + "/")).
			}

		}
		FOR subFile IN dir_scan(dirList,extL,FALSE) {
			returnList:ADD(subFile).
		}
	}
	IF doDirRevert {
		WAIT 0.01.
		CD(dirRevert).
	}
	RETURN returnList.
}

FUNCTION no_root {//if passed in the return of dir_scan will return a list of paths with no root in the same order
	PARAMETER pathIn.
	IF pathIn:ISTYPE("path") {
		RETURN pathIn:SEGMENTS:JOIN("/").
	} ELSE IF pathIn:ISTYPE("list") {
		LOCAL returnList IS LIST().
		FOR p IN pathIn {
			returnList:ADD(no_root(p[0])).
		}
		RETURN returnList.
	}
}

FUNCTION name_only {//if passed in the return of dir_scan will return a list of file names with no extension in the same order
	PARAMETER fileIn.
	IF fileIn:ISTYPE("volumeitem") {
		IF fileIn:ISFILE {
			RETURN fileIn:NAME:SUBSTRING(0,fileIn:NAME:LENGTH - (fileIn:EXTENSION:LENGTH + 1)).
		}
	} ELSE IF fileIn:ISTYPE("list") {
		LOCAL returnList IS LIST().
		FOR f IN fileIn {
			returnList:ADD(name_only(f[1])).
		}
		RETURN returnList.
	}
}