//the function staging_start creates 2 helpper functions for staging_check to use to determin when thrust has fallen by a given fraction
// expects to be passed in the decmal fraction that the thrust must fall by for staging to occur, defaulted to 0.99
//
// the first helpper function is shouldStage and it decides when staging should occur
//  staging is determined to be required when the thrust of the craft has fallen below a calculated threshold
//  the threshold is calculated using the past thrust multplied by the decemal fraction apssed into staging_start
//  the threshold is recalculated after each call of shouldStage
//
// the second helpper function is tReset and that recalculates the threshold for staging

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

//the fucntion staging_check gets passed the helper functions created by staging_start and uses them to check for if staging should happen and if so stage.
// reads the return of the helper function shouldStage for when the thrust has fallen enough and when true will stage and then reset the threshold

FUNCTION staging_check {
  PARAMETER stagingStruct.
  IF stagingStruct:shouldStage() {
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