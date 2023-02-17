FUNCTION low_pass_filter_init {
	PARAMETER lowPassCoef, initalVal.
	LOCAL newValCoef TO 1 - lowPassCoef
	LOCAL persistCoef TO (lowPassCoef - 1) / lowPassCoef.
	LOCAL persistantVal TO initalVal.
	RETURN {
		PARAMETER newVal.
		SET persistantVal TO persistantVal * persistCoef + newVal * newValCoef.
		RETURN persistantVal.
	}.
}

FUNCTION delta_time_init {
	PARAMETER initalTime.
	LOCAL oldTime TO initalTime.
	LOCAL deltaT TO 0.
	RETURN {
		PARAMETER newTime TO TIME:SECONDS.
		IF newTime <> oldTime {
			SET deltaT TO newTime - oldTime.
		}
		RETURN deltaT.
	}
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