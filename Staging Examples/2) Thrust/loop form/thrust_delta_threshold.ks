//the function staging_start creates 3 helper functions for use by staging_check to trigger stagingStruct
// gets passed the number of kN the thrust must fall by to trigger staging defaulted to 20
//
// the first helper function is shouldStage and it decides when staging should occur
//  staging is determined to be required when there has been a reduction in thrust greater than the threshold passed into staging_start
//  the change in thrust is computed by simply taking the difference in thrust between last time shouldStage was called and the current thrust
//  the stored thrust will be updated each time shouldStage is called incase there is an increase in thrust for any reason
//
// the second helper function tReset will recalculate the stored threshold value
//
// the third helper function returns the last available thrust value that the function is aware of

FUNCTION staging_start {
  PARAMETER stageThreshold IS 20.
  LOCAL newThrust IS SHIP:AVAILABLETHRUSTAT(0).
  LOCAL threshold IS MAX(0,newThrust - stageThreshold).
  RETURN LEX(
    "shouldStage", {
      SET newThrust TO SHIP:AVAILABLETHRUSTAT(0).
      LOCAL shouldStage IS newThrust <= threshold.
      SET threshold TO MAX(0,newThrust - stageThreshold).
      RETURN shouldStage.
    },
    "tReset", {
      SET newThrust TO SHIP:AVAILABLETHRUSTAT(0).
      SET threshold TO MAX(0,newThrust - stageThreshold).
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