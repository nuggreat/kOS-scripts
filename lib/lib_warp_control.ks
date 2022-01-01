@LAZYGLOBAL OFF.

FUNCTION warp_control_init {
	//plublic 
	PARAMETER easeFactor IS 1.5,//the smaller this number the later the warp control will leave reducing the rate of time warp, to small and you will over shoot target
	warpLimit IS 7,//max number of times function is allowed to increase the warp rate
	maxDelay IS 10.//after a change to warp state not commanded by this library this is how long to delay until starting warp again
	LOCAL warpConLex IS LEX().
	warpConLex:ADD("getEaseFactor", { RETURN easeFactor. }).
	warpConLex:ADD("setEaseFactor", { PARAMETER newEaseFactor IS easeFactor. SET easeFactor TO newEaseFactor. }).
	warpConLex:ADD("getWarpLimit", { RETURN defaultMaxRate. }).
	warpConLex:ADD("setWarpLimit", { PARAMETER newLimit IS maxPossibleRate. SET defaultMaxRate TO MIN(maxPossibleRate,warpLimit). }).
	warpConLex:ADD("getDelay", { RETURN maxDelay. }).
	warpConLex:ADD("setDelay", { PARAMETER newDelay IS maxDelay. SET maxDelay TO newDelay. }).
	warpConLex:ADD("getState", { RETURN warpState. }).
	warpConLex:ADD("triggerCrash", { SET warpState TO "crashing". }).
	warpConLex:ADD("execute", {
		PARAMETER timeIn,//the time in seconds until the target event
		maxRate IS defaultMaxRate.//max number of times function is allowed to increase the warp rate
		IF warpBase:WARP <> expectedWarp {
			SET warpState TO "crashing".
		}
		RETURN stateLex[warpState]:CALL(timeIn,MIN(maxRate,maxPossibleRate)).
	}).
	
	//private
	LOCAL warpState IS "eval_settled".
	LOCAL warpBase IS KUNIVERSE:TIMEWARP.
	LOCAL maxPossibleRate IS warpBase:RAILSRATELIST:LENGTH - 1.
	LOCAL defaultMaxRate IS MIN(maxPossibleRate,warpLimit).
	LOCAL railRateList IS warpBase:RAILSRATELIST.
	LOCAL crashedTimeing IS TIME:SECONDS.
	LOCAL nextIncrease IS TIME:SECONDS.
	LOCAL expectedWarp IS warpBase:WARP.
	
	LOCAL stateLex IS LEX().
	stateLex:ADD("eval_settled", {
		PARAMETER timeIn,maxRate.
		IF warpBase:ISSETTLED {
			SET warpState TO "eval_decrease".
		}
		RETURN FALSE.
	}).
	stateLex:ADD("eval_decrease", {
		PARAMETER timeIn,maxRate.
		IF ((timeIn / railRateList[warpBase:WARP]) < easeFactor) OR (warpBase:WARP > maxRate) {
			IF warpBase:WARP > 0 {
				SET warpState TO "warp_decrease".
			} ELSE {
				RETURN TRUE.
			}
		} ELSE {
			SET warpState TO "eval_increase".
		}
		RETURN FALSE.
	}).
	stateLex:ADD("eval_increase", {
		PARAMETER timeIn,maxRate.
		SET warpState TO "eval_decrease".
		IF (warpBase:WARP < maxRate) AND (TIME:SECONDS > nextIncrease) {
			IF (timeIn / railRateList[warpBase:WARP + 1]) > easeFactor {
				SET warpState TO "warp_increase".
			}
		}
		RETURN FALSE.
	}).
	stateLex:ADD("warp_increase", {
		PARAMETER timeIn,maxRate.
		SET warpBase:WARP TO warpBase:WARP + 1.
		SET expectedWarp TO warpBase:WARP.
		SET nextIncrease TO TIME:SECONDS + railRateList[warpBase:WARP].
		SET warpState TO "eval_settled".
		RETURN FALSE.
	}).
	stateLex:ADD("warp_decrease", {
		PARAMETER timeIn,maxRate.
		SET warpBase:WARP TO warpBase:WARP - 1.
		SET expectedWarp TO warpBase:WARP.
		SET warpState TO "eval_settled".
		RETURN FALSE.
	}).
	stateLex:ADD("crashing", {
		PARAMETER timeIn,maxRate.
		IF warpBase:ISSETTLED {
			IF warpBase:WARP = 0 {
				SET crashedTimeing TO TIME:SECONDS + maxDelay.
				SET expectedWarp TO 0.
				SET warpState TO "delay".
			} ELSE {
				SET warpBase:WARP TO MAX(warpBase:WARP - 1,0).
			}
		}
		RETURN FALSE.
	}).
	stateLex:ADD("delay", {
		PARAMETER timeIn,maxRate.
		IF TIME:SECONDS >= crashedTimeing {
			SET nextIncrease TO TIME:SECONDS.
			SET warpState TO "eval_settled".
		}
		RETURN FALSE.
	}).
	RETURN warpConLex.
}