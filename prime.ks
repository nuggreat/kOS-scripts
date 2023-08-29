RCS OFF.
PARAMETER num IS 1,maxNum IS -1.
SET num TO ROUND(num,0).
IF MOD(num,2) = 0 { SET num TO num - 1. }
IF num <= 1 { SET num TO 2. PRINT "1". }
IF num <= 2 { SET num TO 3. PRINT "2". }
IF num <= 3 { SET num TO 5. PRINT "3". }
SET done TO FALSE.
SET timeOld TO TIME:SECONDS.
UNTIL done {
	//LOCAL passed IS FALSE.//135.36
	//LOCAL countMax IS SQRT(num).
	//LOCAL count IS 3.
	//UNTIL FALSE {
	//	IF MOD(num,count) = 0 { IF num <> count { BREAK. }}
	//	SET count TO count + 2.
	//	IF	count > countMax {
	//		SET passed TO TRUE.
	//		BREAK.
	//	}
	//}
	LOCAL passed IS TRUE.
	LOCAL countMax IS SQRT(num).
	FROM {LOCAL count IS 3.} UNTIL count > countMax STEP {SET count TO count + 2.} DO {
		IF MOD(num,count) = 0 {
			SET passed TO FALSE.
			BREAK.
		}
	}
	IF passed {
		PRINT num.
	}
	SET num TO num + 2.
	SET done TO RCS.
	IF RCS OR (maxNum <> -1 AND maxNum <= num) { SET done TO TRUE. }
}
PRINT "Time Elapsed: " + ROUND(TIME:SECONDS - timeOld,2).
//https://clips.twitch.tv/ModernCleanAirGuitarPhilosoraptor
