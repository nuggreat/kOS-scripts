@LAZYGLOBAL OFF.
//	a lib for file list creation

//	dir_scan(path, extension list,cd revert)
//		path: should a Path or a Volume EXAMPLE: PATH("1:/")
//		extension list: can accept 2 different inputs extension list defaults to type 1
//			type 1: can be a list of everthing after the "." at the end of a file EXAMPLE: LIST("ks","ksm","txt",...)
//				will cause return of type 1
//			type 2: can be anyother type of value so long as it is not a list EXAMPLE: BODY("kerbin")
//				will cause return of type 2
//		cd revert: should be a boolean sets if the curent directory should be saved before the scan starts so it can be reset after the scan is done intended for internal use
//		will scan though all sub-paths of the givin path EXAMPLE: PATH("1:/lib") is a sub-path of PATH("1:/")
//		has 2 different types of returns depending on what the extension
//			type 1 return is a x,y list in the form of LIST(LIST(path of file1, name of file1),LIST(path of file2, name of file2),...)
//				will only return files with a extension in the extension list
//					sending a extension list of LIST("-99999") will disable extension filtering
//				"path of file" is of type path, EXAMPLE: PATH("1:/lib/")
//				"name of file" is of type VolumeItem
//			type 2 returns a list of all directories found EXAMPLE: LIST(PATH("1:/"),PATH("1:/lib"),...)

//	no_root(path or list)
//		path: should be a path EXAMPLE: PATH("1:/lib/lib_file_util.ks")
//			returns a string of the input path with the root removed, EXAMPLE: PATH("1:/lib/lib_file_util.ks") becomes "lib/lib_file_util.ks"
//		list: should be the return from dir_scan
//			returns a list of paths with the root removed matching the index values of the input list
//				EXAMPLE:
//				input of LIST(
//					LIST(PATH("1:/"),PATH("1:/lib")),
//					LIST("updater.ks","file_util.ks","list_file_util.ks")
//				returns: LIST("1:/","1:/lib")

// name_only(file or list)
//		file: should be of type VolumeItem EXAMPLE: a single item in the list created by the use of: LIST FILES IN fileList.
//			returns the name of the VolumeItem with out the extension EXAMPLE: "lib_file_util.ks" becomes "lib_file_util"
//		list: should be the return from dir_scan
//			returns a list of file names without extensions matching the index values of the input list
//				EXAMPLE:
//				input of LIST(
//					LIST(PATH("1:/"),PATH("1:/lib")),
//					LIST("updater.ks","file_util.ks","list_file_util.ks")
//				returns: LIST("updater","file_util","list_file_util")

FUNCTION dir_scan {
	PARAMETER dirIn,extL IS LIST(-99999),doDirRevert IS TRUE.
	LOCAL masterList IS LIST().

	LOCAL dirRevert IS PATH().
	IF dirIn:ISTYPE("list") {
		FOR subDir IN dirIn {
			FOR foundItem IN dir_scan(subDir,extL,FALSE) {
				masterList:ADD(foundItem).
			}
		}
	} ELSE {
		LOCAL dirPath IS PATH(dirIn).
		CD(dirPath).
		LOCAL fileList IS LIST().
		LIST FILES IN fileList.

		LOCAL dirList IS LIST().
		IF NOT extL:ISTYPE("list") { masterList:ADD(dirPath). }
		FOR filter IN fileList {
			IF extL:ISTYPE("list") {
				FOR ext IN extL {
					IF filter:ISFILE AND ((filter:EXTENSION = ext) OR (-99999 = ext)) {
						masterList:ADD(LIST(dirPath,filter)).
					}
				}
			}
			IF (NOT filter:ISFILE) {
				dirList:ADD(dirPath:COMBINE(filter + "/")).
			}
		}
		FOR subFile IN dir_scan(dirList,extL,FALSE) {
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

FUNCTION name_only {
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