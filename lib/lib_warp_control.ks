@LAZYGLOBAL OFF.

FUNCTION warp_control_init {
	PARAMETER easeFactor IS 1.5,//the smaller this number the later the warp control will leave reducing the rate of time warp, to small and you will over shoot target
	warpLimit IS 7,//max number of times function is allowed to increase the warp rate
	maxDelay IS 10.//after a user initiated change to warp, this is how long to delay until starting warp again
	LOCAL warpBase IS KUNIVERSE:TIMEWARP.
	LOCAL maxPossibleRate IS warpBase:RAILSRATELIST:LENGTH - 1.
	LOCAL defaultMaxRate IS MIN(maxPossibleRate,warpLimit).
	LOCAL railRateList IS warpBase:RAILSRATELIST.

	LOCAL warpConLex IS LEX().
	warpConLex:ADD("warpState","eval_settled").
	warpConLex:ADD("maxDelay",maxDelay).
	warpConLex:ADD("crashedTimeing",TIME:SECONDS).
	warpConLex:ADD("nextIncrease",TIME:SECONDS).
	warpConLex:ADD("expectedWarp",warpBase:WARP).

	warpConLex:ADD("execute", {
		PARAMETER timeIn,//the time in seconds until the target event
		maxRate IS defaultMaxRate.//max number of times function is allowed to increase the warp rate
		IF warpBase:WARP <> warpConLex["expectedWarp"] {
			SET warpConLex["warpState"] TO "crashing".
		}
		RETURN stateLex[warpConLex["warpState"]]:CALL(timeIn,MIN(maxRate,maxPossibleRate)).
	}).
	LOCAL stateLex IS LEX().
	stateLex:ADD("eval_settled", {
		PARAMETER timeIn,maxRate.
		IF warpBase:ISSETTLED {
			SET warpConLex["warpState"] TO "eval_decrease".
		}
		RETURN FALSE.
	}).
	stateLex:ADD("eval_decrease", {
		PARAMETER timeIn,maxRate.
		IF ((timeIn / railRateList[warpBase:WARP]) < easeFactor) OR (warpBase:WARP > maxRate) {
			IF warpBase:WARP > 0 {
				SET warpConLex["warpState"] TO "warp_dec".
			} ELSE {
				RETURN TRUE.
			}
		} ELSE {
			SET warpConLex["warpState"] TO "eval_increase".
		}
		RETURN FALSE.
	}).
	stateLex:ADD("eval_increase", {
		PARAMETER timeIn,maxRate.
		SET warpConLex["warpState"] TO "eval_decrease".
		IF (warpBase:WARP < maxRate) AND (TIME:SECONDS > warpConLex["nextIncrease"]) {
			IF (timeIn / railRateList[warpBase:WARP + 1]) > easeFactor {
				SET warpConLex["warpState"] TO "warp_inc".
			}
		}
		RETURN FALSE.
	}).
	stateLex:ADD("warp_inc", {
		PARAMETER timeIn,maxRate.
		SET warpBase:WARP TO warpBase:WARP + 1.
		SET warpConLex["expectedWarp"] TO warpBase:WARP.
		SET warpConLex["nextIncrease"] TO TIME:SECONDS + railRateList[warpBase:WARP].
		SET warpConLex["warpState"] TO "eval_settled".
		RETURN FALSE.
	}).
	stateLex:ADD("warp_dec", {
		PARAMETER timeIn,maxRate.
		SET warpBase:WARP TO warpBase:WARP - 1.
		SET warpConLex["expectedWarp"] TO warpBase:WARP.
		SET warpConLex["warpState"] TO "eval_settled".
		RETURN FALSE.
	}).
	stateLex:ADD("crashing", {
		PARAMETER timeIn,maxRate.
		IF warpBase:ISSETTLED {
			IF warpBase:WARP = 0 {
				SET warpConLex["crashedTimeing"] TO TIME:SECONDS + warpConLex["maxDelay"].
				SET warpConLex["expectedWarp"] TO 0.
				SET warpConLex["warpState"] TO "delay".
			} ELSE {
				SET warpBase:WARP TO MAX(warpBase:WARP - 1,0).
			}
		}
		RETURN FALSE.
	}).
	stateLex:ADD("delay", {
		PARAMETER timeIn,maxRate.
		IF TIME:SECONDS >= warpConLex["crashedTimeing"] {
			SET warpConLex["nextIncrease"] TO TIME:SECONDS.
			SET warpConLex["warpState"] TO "eval_settled".
		}
		RETURN FALSE.
	}).
	RETURN warpConLex.
}