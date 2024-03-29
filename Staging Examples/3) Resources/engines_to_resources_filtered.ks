//The get_engine_list function is for getting the list of active engines and has 2 modes of operations
// The first mode is used by not passing in a list
//  This causes the function to create a list of all active engines
// the second mode is used by passing in a list
//  This causes the function to clear the passed in list of any data contained and then populate the list with all active engines

FUNCTION get_engine_list {
  PARAMETER filteredEngList IS LIST().
  filteredEngList:CLEAR().
  FOR eng IN SHIP:ENGINES {
    IF eng:IGNITION {
      filteredEngList:ADD(eng).
    }
  }
  RETURN filteredEngList.
}


//The staging_check function checks a list of engines for any engines that have a consumed resource amount below the passed in threshold
// Staging will also be triggered if there are no engines in the engine list
// Once staging happens the function will refresh the engine list using the get_engine_list function
// The function takes two parameters one is defaulted
//  The first parameter is the list of engines to check the resources of, it is presumed to be coming from the get_engine_list function
//  The second parameter is the threshold any resource must be below in units
//   Defaulted to 0.01

FUNCTION staging_check {
  PARAMETER engList, threshold IS 0.01.
  LOCAL shouldStage IS FALSE.
  IF STAGE:READY {
    IF engList:LENGTH > 0 {
      FOR eng IN engList {
        LOCAL engRes IS eng:CONSUMEDRESOURCES.
        FOR res IN engRes:VALUES {
          IF res:AMOUNT < threshold {
            SET shouldStage TO TRUE.
            PRINT "Staging due to resource: " + res:NAME + " below threshold".
            BREAK.
          }
        }
        IF shouldStage {
          BREAK.
        }
      }
    } ELSE {
      SET shouldStage TO TRUE.
      PRINT "Staging due to no active engines".
    }
    IF shouldStage {
      STAGE.
      get_engine_list(engList).
    }
  }
  RETURN shouldStage.
}