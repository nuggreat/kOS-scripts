//the function staging_start creates 3 helper functions for staging_check to use to determine when thrust has fallen by a given fraction
// expects to be passed in the decimal fraction that the thrust must fall by for staging to occur, defaulted to 0.99
//
// the first helper function is shouldStage and it decides when staging should occur
//  staging is determined to be required when the thrust of the craft has fallen below a calculated threshold
//  the threshold is calculated using the past thrust multiplied by the decimal fraction passed into staging_start
//  the threshold is recalculated after each call of shouldStage
//
// the second helper function is tReset and that recalculates the threshold for staging
//
// the third helper function returns the last available thrust value that the function is aware of

FUNCTION staging_start {
  PARAMETER stageThreshold IS 0.99.
  LOCAL newThrust IS SHIP:AVAILABLETHRUSTAT(0).
  LOCAL threshold IS newThrust * stageThreshold.

  RETURN LEX(
    "shouldStage", {
      SET newThrust TO SHIP:AVAILABLETHRUSTAT(0).
      LOCAL shouldStage IS newThrust <= threshold.
      SET threshold TO newThrust * stageThreshold.
      RETURN shouldStage.
    },
    "tReset", {// updates the staging threshold
      SET newThrust TO SHIP:AVAILABLETHRUSTAT(0).
      SET threshold TO newThrust  * stageThreshold.
    },
    "thrustIs", {
      RETURN newThrust.
    }
  ).
}

//the function staging_check gets passed the helper functions created by staging_start and uses them to check for if staging should happen and if so stage.
// reads the return of the helper function shouldStage for when the thrust has fallen enough and when true will stage and then reset the threshold

FUNCTION staging_check {
  PARAMETER stagingStruct.
  IF stagingStruct:shouldStage() {
    IF NOT STAGE:READY {         
      WAIT UNTIL STAGE:READY.     
    }
    IF stagingStruct:thrustIs() <> 0 {
      PRINT "Staging due to thrust decrease".
    } ELSE {
      PRINT "Staging due to no thrust".
    }
    STAGE.
    stagingStruct:tReset().
    RETURN TRUE.
  }
  RETURN FALSE.
}