FUNCTION low_pass_filter_init {
	PARAMETER lowPassCoef, initalVal.
	LOCAL newValCoef TO 1 / lowPassCoef.
	LOCAL persistCoef TO (lowPassCoef - 1) / lowPassCoef.
	LOCAL persistantVal TO initalVal.
	RETURN {
		PARAMETER newVal.
		SET persistantVal TO persistantVal * persistCoef + newVal * newValCoef.
		RETURN persistantVal.
	}.
}

FUNCTION delta_time_init {
	PARAMETER initalT TO TIME:SECONDS.
	LOCAL oldT TO initalT.
	LOCAL deltaT TO 0.
	RETURN {
		PARAMETER newT TO TIME:SECONDS.
		IF newT <> oldT {
			SET deltaT TO newT - oldT.
			SET oldT TO newT.
		}
		RETURN deltaT.
	}.
}

FUNCTION delta_init {
    PARAMETER initalX.
    LOCAL oldX TO initalX.
    LOCAL deltaX TO initalX - initalX.
    RETURN {
        PARAMETER newX, deltaT.
        IF deltaT <> 0 {
            SET deltaX TO (newX - oldX) / deltaT.
            SET oldX TO newX.
        }
		RETURN deltaX.
    }.

}