PARAMETER notUseExtension IS FALSE, //set if the file being updated must have the same extension as the file on the archive to be updated (FALSE = use and TRUE = ignore)
notUsePath IS FALSE, //sets if the file being updated must have the same path ignoring volume to be updated (FALSE = use and TRUE = ignore)
notUseSize IS TRUE, //sets if the file being updated must have a different size compared to the file on the archive to be updated (FALSE = use and TRUE = ignore)
useCompile IS TRUE.//sets if the updater will compile .ks files on archive to .ksm on local if all other conditions match (FALSE = don't compile and TRUE = compile)
IF HOMECONNECTION:ISCONNECTED {
FOR lib IN LIST("lib_file_util") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNPATH("1:/lib/" + lib + ".ks"). }}
CLEARSCREEN.
LOCAL localDir IS LIST().
LIST VOLUMES IN localDir.
LOCAL archiveDir IS localDir[0].
localDir:REMOVE(0).
LOCAL extList IS LIST("ks","ksm").

PRINT "Starting Update".
PRINT " ".
LOCAL lFiles IS dir_scan(localDir,extList).
LOCAL aFiles IS dir_scan(archiveDir,extList).
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
}} ELSE { PRINT "Archive Not Found". }