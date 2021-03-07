FUNCTION staging_start {
  PARAMETER stageThreshold IS 20.
  LOCAL oldThrust IS SHIP:AVAILABLETHRUSTAT(0).

  RETURN LEX(
    "shouldStage", {
      LOCAL newThrust IS SHIP:AVAILABLETHRUSTAT(0).
      LOCAL shouldStage IS (oldThrust - newThrust) <= threshold.
      SET oldThrust TO newThrust.
      RETURN shouldStage.
    },
    "tReset", {
      SET threshold TO SHIP:AVAILABLETHRUSTAT(0).
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
    stagingStruct:tReset().
    RETURN TRUE.
  }
  RETURN FALSE.
}