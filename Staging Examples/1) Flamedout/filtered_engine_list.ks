//the get_engine_list function is for getting the list of active engines and has 2 modes of operations
// The first mode is used by not passing in a list
//  This causes the function to create a list of all active engines
// The second mode is used by passing in a list
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


//The staging_check function checks a list of engines for any that are flamedout and stages if any are found
// Staging will also be triggered if there are no engines in the engine list
// Once staging happens the function will refresh the engine list using the get_engine_list function
// The function takes one parameter which is a list of engines assumed to be the list generated by the get_engine_list function

FUNCTION staging_check {
  PARAMETER engList.
  IF STAGE:READY {
    LOCAL shouldStage IS FALSE.
    IF engList:LENGTH > 0 {
      FOR eng IN engList {
        IF eng:FLAMEOUT {
          SET shouldStage TO TRUE.
          PRINT "Staging due to engine flameout".
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
      RETURN TRUE.
    }
  }
  RETURN FALSE.
}