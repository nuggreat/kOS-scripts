@LAZYGLOBAL OFF.
//	a lib for file list creation
//	dir_scan_list_for_files(path list, extension list)
//		path list: a list of paths,volumes, or strings pointing at paths EXAMPLE: LIST("1:/","2:/",...) OR LIST(PATH("1:/"),PATH("2:/"),...)
//		extension list: see dir_scan_for_files for extension list formating and function
//		will call dir_scan_for_files for every path in the path list
//		will merge the returned lists from dir_scan_for_files calls into one x,y list of the same formating as dir_scan_for_files
//		returns the merged list

//	dir_scan_for_files(path, extension list,cd revert)
//		path: should a Path or a Volume EXAMPLE: PATH("1:/")
//		extension list: should be a list of everthing after the "." at the end of a file EXAMPLE: LIST("ks","ksm","txt",...)
//		cd revert: should be a boolean sets if the curent directory should be saved before the scan starts so it can be reset after the scan is done
//		will only return files with a extension in the extension list
//			sending a extension list of LIST("-99999") will disable extension filtering
//		will scan though all sub-paths of the givin path EXAMPLE: PATH("1:/lib") is a sub-path of PATH("1:/")
//		returns a x,y list in the form of LIST(LIST(path of file1, name of file1),LIST(path of file2, name of file2),...)
//			"path of file" is of type path, EXAMPLE: PATH("1:/lib/")
//			"name of file" is of type VolumeItem

//	no_root(path)
//		path: should be a path EXAMPLE: PATH("1:/lib/lib_file_util.ks")
//		returns a string of the input path with the root removed, EXAMPLE: PATH("1:/lib/lib_file_util.ks") becomes "lib/lib_file_util.ks"

// name_only(file)
//		file: should be of type VolumeItem EXAMPLE: a single item in the list created by the use of: LIST FILES IN fileList.
//		returns the name of the VolumeItem with out the extension EXAMPLE: "lib/lib_file_util.ks" becomes "lib/lib_file_util"

FUNCTION dir_scan_list_for_files {
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