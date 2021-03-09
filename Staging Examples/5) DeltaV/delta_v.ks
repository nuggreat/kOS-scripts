FUNCTION staging_start {
  PARAMETER threshold IS 0, sDelay IS 1, stableDelay IS 1..
  RETURN LEX(
    "threshold",threshold,
    "betweenDelay",sDelay,
    "nextStageTime",TIME:SECONDS,
    "stableDelay",stableDelay,
    "stableTime",TIME:SECONDS
  ).
}

FUNCTION staging_check {
  PARAMETER stagingData.
  IF STAGE:DELTAV:CURRENT <= stagingData:threshold {
	IF STAGE:READY {
	  IF TIME:SECONDS >= stagingData:stableTime {
        IF TIME:SECONDS >= stagingData:nextStageTime {
		  PRINT "Staging because the deltaV of the current stage is below threshold".
		  STAGE.
		  SET stagingData:nextStageTime TO TIME:SECONDS + stagingData:betweenDelay.
		}
      }
    }
  } ELSE {
    SET stagingData:stableTime TO TIME:SECONDS + stagingData:stableDelay.
  }
  RETURN FALSE.
}