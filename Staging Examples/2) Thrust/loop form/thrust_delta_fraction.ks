FUNCTION staging_start {
  PARAMETER stageThreshold IS 0.99.
  LOCAL threshold IS SHIP:AVAILABLETHRUSTAT(0) * stageThreshold.

  RETURN LEX(
    "shouldStage", {
      LOCAL newThrust IS SHIP:AVAILABLETHRUSTAT(0).
      LOCAL shouldStage IS newThrust <= threshold.
      SET threshold TO newThrust * stageThreshold.
      RETURN shouldStage.
    },
    "tReset", {
      SET threshold TO SHIP:AVAILABLETHRUSTAT(0)  * stageThreshold.
    }
  ).
}

FUNCTION staging_check {
  PARAMETER stagingStruct.
  IF stagingStruct:shouldStage {
    IF NOT STAGE:READY {
      WAIT UNTIL STAGE:READY.
    }
    PRINT "Staging due to thrust decrease".
    STAGE.
    stagingStruct:tReset.
    RETURN TRUE.
  }
  RETURN FALSE.
}