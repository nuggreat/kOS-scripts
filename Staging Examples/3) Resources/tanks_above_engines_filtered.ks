//The function staging_start constructs a data structure for use by the staging_check function
// It takes one parameter which is the amount a given resource must be less than to trigger staging
// The data structure contains three items
//  One a map of engine UIDs to a resource container with a consumed resource done with the walk_for_resources function starting from the engine
//  Two the list of engines returned by the get_engine_list function
//  Three the threshold required for staging

FUNCTION staging_start {
  PARAMETER threshold IS 0.01.
  LOCAL stagingData IS LEX("threshold",threshold).
  LOCAL engList IS LIST().
  LIST ENGINES IN engList.
  FOR eng IN engList {
    LOCAL engResData IS eng:CONSUMEDRESOURCES.
    LOCAL foundPart IS FALSE.
    FOR key IN engResData:KEYS {
      LOCAL resName IS engResData[key]:NAME.
      LOCAL walkResults IS walk_for_resources(eng,resName).
      IF walkResults:ISTYPE("Resource") {
        SET foundPart TO TRUE.
        stagingData:ADD(eng:UID,walkResults).
        BREAK.
      }
    }
  }
  stagingData:ADD("engList",get_engine_list()).
  RETURN stagingData.
}

//The function walk_for_resources will recirsivly look a resource structure matching a given resource name
// It takes two parameters
//  The first is the current part to check for the given resource name
//  The second is the name of the resource to check for
// It will return the resource structure if it is found and a FALSE should it fail to find the resource
// The part check will only look in parent parts until it runs into a Decoupler or the root part of the craft

FUNCTION walk_for_resources {
  PARAMETER toCheck,resName.
  FOR res IN toCheck:RESOURCES {
    IF res:NAME = resName {
      RETURN res.
    }
  }
  IF toCheck:ISTYPE("Decoupler") OR toCheck:UID = SHIP:ROOTPART:UID {
    RETURN FALSE.
  } ELSE {
    RETURN walk_for_resources(toCheck:PARENT,resName).
  }
}


//The get_engine_list function is for getting the list of active engines and has 2 modes of opperations
// The first mode is used by not passing in a list
//  This causes the function to create a list of all active engines
// the second mode is used by passing in a list
//  This causes the function to clear the passed in list of any data contained and then populate the list with all active engines

FUNCTION get_engine_list {
  PARAMETER filteredEngList IS LIST().
  filteredEngList:CLEAR().
  LOCAL engList IS LIST().
  LIST ENGINES IN engList.
  FOR eng IN engList {
    IF eng:IGNITION {
      filteredEngList:ADD(eng).
    }
  }
  RETURN filteredEngList.
}

//The staging_check function checks for any engine in engList that has an assoceated resource structure whos AMOUNT below the threshold stored in stagingData
// Staging will also be triggered if there are no engines in the engline list
// Once staging happens the function will refresh the engine list using the get_engine_list function

FUNCTION staging_check {
  PARAMETER stagingData.
  LOCAL shouldStage IS FALSE.
  IF STAGE:READY {
    IF stagingData:engList:LENGTH > 0 {
      FOR eng IN stagingData:engList {
        IF stagingData:HASKEY(eng:UID) {
          IF stagingData[eng:UID]:AMOUNT < stagingData:threshold {
            SET shouldStage TO TRUE.
            PRINT "staging due to resource: " + stagingData[eng:UID]:NAME + " below threshold.".
            BREAK.
          }
        }
      }
    } ELSE {
      SET shouldStage TO TRUE.
      PRINT "Staging due to no active engines".
    }
    IF shouldStage {
      STAGE.
      get_engine_list(stagingData:engList).
      RETURN TRUE.
    }
  }
  RETURN shouldStage.
}