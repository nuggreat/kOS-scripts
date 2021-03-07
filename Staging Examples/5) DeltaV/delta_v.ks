FUNCTION staging_start {
  PARAMETER threshold, sDelay, stableDelay.
  RETURN LEX(
    "threshold",threshold,
    "betweenDelay",sDelay,
    "nextStageTime",TIME,
    "stableDelay",stableDelay,
    "stableTime",TIME
  ).
}

FUNCTION staging_check {
  PARAMETER stagingData.
  IF STAGE:DELTAV < stagingData:threshold {
	IF STAGE:READY {
	  IF TIME >= stagingData:stableTime {
        IF TIME >= stagingData:nextStageTime {
		  PRINT "Staging because the deltaV of the current stage is below threshold".
		  STAGE.
		  SET stagingData:nextStageTime TO TIME + stageData:sDelay.
		}
      }
    }
  } ELSE {
    SET stageData:stableTime TO TIME + stageData:stableDelay.
  }
  RETURN FALSE.
}