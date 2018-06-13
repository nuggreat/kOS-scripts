@LAZYGLOBAL OFF.
//	a lib for file list creation
//	scan(path, a list to return the results in, a list of all file extentions to look for in string form)
//		will scan though all directories and subdirectories
//		returns a 2 depth list in the form of LIST(LIST(path to file1, file1 name),LIST(path to file2, file2 name))

//	dir_list(path).
//		return a list of every file and directory in the givin path and with the givin path at index place 0

//	file_filter(list as returned by dir_list,  a list of all file extentions to look for in string form)
//		the return is based what is in the dir_list patameter
//		returns a 2 depth list in the form of LIST(LIST(path to file1, file1 name),LIST(path to file2, file2 name),...)

//	dir_filter(list as returned by dir_list)
//		the return is based what is in the dir_list patameter
//		returns a list in the form of LIST(path1,path2,...)

FUNCTION scan {
	PARAMETER dir,masterList,extL.
	IF NOT (dir = 9999) {
		LOCAL dirList IS dir_list(dir).
		LOCAL fileList IS file_filter(dirList,extL).
		FOR fList IN fileList {
			masterList:ADD(fList).
		}
		LOCAL subDir IS dir_filter(dirList).
		FOR dList IN subDir {
			scan(dList,masterList,extL).
		}
	}
}

FUNCTION dir_list {
	PARAMETER dir.
	LOCAL dirPath IS PATH(dir).
	CD(dirPath).
	LOCAL localList IS LIST().
	LIST FILES IN localList.
	localList:INSERT(0,dirPath).
	RETURN localList.
}

FUNCTION file_filter {
	PARAMETER listIn,extL.
	LOCAL localList IS LIST().
	LOCAL dir IS listIn[0].
	FOR ext IN extL {
		FOR filter IN listIn {
			IF (NOT (filter = dir)) AND filter:ISFILE AND ((filter:EXTENSION = ext) OR (ext = -99999)) {
				localList:ADD(LIST(dir,filter)).
			}
		}
	}
	RETURN localList.
}

FUNCTION dir_filter {
	PARAMETER listIn.
	LOCAL localList IS LIST().
	LOCAL dir IS listIn[0].
	FOR filter IN listIn {
		IF (NOT (filter = dir)) AND (NOT filter:ISFILE) {
			localList:ADD(dir:COMBINE(filter + "/")).
		}
	}
	IF localList:LENGTH = 0 {
		localList:ADD(9999).
	}
	RETURN localList.
}