PARAMETER fileName,  //fileName must be a string of the file name with out the extension EXAMPLE: "need_file"
fileExt IS "". //fileExt must be a string of the file extension with out everything before

LOCAL archiveDir IS PATH("0:/").
LOCAL localDir IS PATH(CORE:CURRENTVOLUME).

LOCAL copyNeeded IS TRUE.
FOR localFile IN dir_scan(localDir) {
  IF name_only(localFile[1]) = fileName {
    IF localFile[1]:EXTENSION = fileExt OR fileExt = "" {
      PRINT "Local Copy Found of File: " + fileName.
      PRINT "Local Copy Found at:      " + localFile[0].
      SET copyNeeded TO FALSE.
      WAIT 1.
    }
  }
}

IF copyNeeded {
  PRINT "No Local Copy of File: " + fileName.
  PRINT "Scaning Archive".
  IF HOMECONNECTION:ISCONNECTED {
    FOR archiveFile IN dir_scan(archiveDir) {
      IF name_only(archiveFile[1]) = fileName {
        IF archiveFile[1]:EXTENSION = fileExt OR fileExt = "" {
          LOCAL localPath IS localDir:ROOT:COMBINE(no_root(archiveFile[0])).
          IF NOT EXISTS(localPath) {
            PRINT " Making  dir: " + localPath.
            CREATEDIR(localPath).
          }
          COPYPATH(archiveFile[0]:COMBINE(archiveFile[1]:NAME),localPath).
          PRINT " ".
          PRINT "Copying File: " + archiveFile[1].
          PRINT "        From: " + archiveFile[0] + " To: " + localPath.
          PRINT " ".
        }
      }
    }
  } ELSE { PRINT "Archive Not Found". }
}

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
  PARAMETER segment.
  RETURN segment:SEGMENTS:JOIN("/").
}

FUNCTION name_only {
  PARAMETER fileName.
  RETURN fileName:NAME:SUBSTRING(0,fileName:NAME:LENGTH - (fileName:EXTENSION:LENGTH + 1)).
}