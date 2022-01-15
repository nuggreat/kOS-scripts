//The function staging_start constructs a data structure for use by the staging_check function
// It takes one parameter which is the amount a given resource must be less than to trigger staging
// The data structure contains two items
//  One a map of engine UIDs to a resource container with a consumed resource done with the walk_for_resources function starting from the engine
//  Two the threshold required for staging

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
  RETURN stagingData.
}


//The function walk_for_resources will recursively look a resource structure matching a given resource name
// It takes two parameters
//  The first is the current part to check for the given resource name
//  The second is the name of the resource to check for
// It will return the resource structure if it is found and a FALSE should it fail to find the resource
// The part check will only look in parent parts until it runs into a decoupler or the root part of the craft

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

//The staging_check function checks for any engine that has an associated resource structure whose AMOUNT below the threshold stored in stagingData
// The function takes one parameter which is expected to be the lexicon constructed by staging_start

FUNCTION staging_check {
  PARAMETER stagingData.
  IF STAGE:READY {
    LOCAL engList IS LIST().
    LIST ENGINES IN engList.
    FOR eng IN engList {
      IF stagingData:HASKEY(eng:UID) {
        IF stagingData[eng:UID]:AMOUNT < stagingData:threshold {
          PRINT "staging due to resource: " + stagingData[eng:UID]:NAME + " below threshold.".
          STAGE.
          RETURN TRUE.
        }
      }
    }
  }
  RETURN FALSE.
}