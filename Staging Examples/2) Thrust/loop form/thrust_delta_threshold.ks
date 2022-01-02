//the function staging_start creates 2 helper functions for use by staging_check to trigger stagingStruct
// gets passed the number of kN the thrust must fall by to trigger staging defaulted to 20
//
// the first helper function is shouldStage and it decides when staging should occur
//  staging is determined to be required when there has been a reduction in thrust greater than the threshold passed into staging_start
//  the change in thrust is computed by simply taking the difference in thrust between last time shouldStage was called and the current thrust
//  the stored thrust will be updated each time shouldStage is called incase there is an increase in thrust for any reason
//
// the second helper function tReset will store the current thrust as the old thrust useful 

FUNCTION staging_start {
  PARAMETER stageThreshold IS 20.
  LOCAL oldThrust IS SHIP:AVAILABLETHRUSTAT(0).

  RETURN LEX(
    "shouldStage", {
      LOCAL newThrust IS SHIP:AVAILABLETHRUSTAT(0).
      LOCAL shouldStage IS (oldThrust - newThrust) >= stageThreshold.
      SET oldThrust TO newThrust.
      RETURN shouldStage.
    },
    "tReset", {
      SET oldThrust TO SHIP:AVAILABLETHRUSTAT(0).
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
    PRINT "Staging due to thrust decrease".
    STAGE.
    stagingStruct:tReset().
    RETURN TRUE.
  }
  RETURN FALSE.
}