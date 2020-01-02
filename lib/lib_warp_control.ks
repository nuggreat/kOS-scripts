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
	warpConLex:ADD("warpState","eval_0").
	warpConLex:ADD("maxDelay",maxDelay).
	warpConLex:ADD("crashedTimeing",TIME:SECONDS).
	warpConLex:ADD("expectedWarp",warpBase:WARP).

	warpConLex:ADD("execute", {
		PARAMETER timeIn,//the time in seconds until the target event
		maxRate IS defaultMaxRate.//max number of times function is allowed to increase the warp rate
		RETURN warpConLex[warpConLex["warpState"]]:CALL(timeIn,MIN(maxRate,maxPossibleRate)).
	}).
	warpConLex:ADD("eval_0", {
		PARAMETER timeIn,maxRate.
		IF warpBase:WARP <> warpConLex["expectedWarp"] {
			SET warpConLex["warpState"] TO "crashing".
		} ELSE IF warpBase:ISSETTLED {
			SET warpConLex["warpState"] TO "eval_1".
		}
		RETURN FALSE.
	}).
	warpConLex:ADD("eval_1", {
		PARAMETER timeIn,maxRate.
		SET warpConLex["warpState"] TO "eval_0".
		IF ((timeIn / railRateList[warpBase:WARP]) < easeFactor) OR (warpBase:WARP > maxRate) {
			IF warpBase:WARP <> 0 {
				SET warpConLex["warpState"] TO "warpDecrease".
			} ELSE {
				RETURN TRUE.
			}
		} ELSE {
			IF warpBase:WARP < maxRate {
				IF (timeIn / railRateList[warpBase:WARP + 1]) > easeFactor {
					SET warpConLex["warpState"] TO "warpIncrease".
				}
			}
		}
		RETURN FALSE.
	}).
	warpConLex:ADD("warpIncrease", {
		PARAMETER timeIn,maxRate.
		SET warpBase:WARP TO warpBase:WARP + 1.
		SET warpConLex["expectedWarp"] TO warpBase:WARP.
		SET warpConLex["warpState"] TO "eval_0".
		RETURN FALSE.
	}).
	warpConLex:ADD("warpDecrease", {
		PARAMETER timeIn,maxRate.
		SET warpBase:WARP TO warpBase:WARP - 1.
		SET warpConLex["expectedWarp"] TO warpBase:WARP.
		SET warpConLex["warpState"] TO "eval_0".
		RETURN FALSE.
	}).
	warpConLex:ADD("crashing", {
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
	warpConLex:ADD("delay", {
		PARAMETER timeIn,maxRate.
		IF TIME:SECONDS >= warpConLex["crashedTimeing"] {
			SET warpConLex["warpState"] TO "eval_0".
		}
		RETURN FALSE.
	}).
	RETURN warpConLex.
}