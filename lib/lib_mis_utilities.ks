@LAZYGLOBAL OFF.
LOCAL lib_mis_utilities_lex IS LEX().

lib_mis_utilities_lex:ADD("delta_time",LEX()).
FUNCTION delta_time {
	PARAMETER key IS "deltaTime".
	LOCAL localTime IS TIME:SECONDS.
	IF lib_mis_utilities_lex["delta_time"]:HASKEY(key) {
		LOCAL deltaTime IS localTime - lib_mis_utilities_lex["delta_time"][key].
		SET lib_mis_utilities_lex["delta_time"][key] TO localTime.
		RETURN deltaTime.
	} ELSE {
		lib_mis_utilities_lex["delta_time"]:ADD(key,localTime).
		RETURN 0.
	}
}

FUNCTION delta_init {
    PARAMETER initalVal.
    LOCAL oldTime IS TIME:SECONDS.
    LOCAL oldVal IS initalVal.
    LOCAL oldDelta IS initalVal - initalVal.
    RETURN {
        PARAMETER newVal, newTime IS TIME:SECONDS.
        LOCAL deltaT IS newTime - oldTime.
        IF deltaT = 0 {
            RETURN oldDelta.
        } ELSE {
            LOCAL deltaVal IS newVal - oldVal.
            SET oldTime TO newTime.
            SET oldVal TO newVal.
            SET oldDelta TO deltaVal / deltaT.
            RETURN oldDelta.
        }
    }.
}