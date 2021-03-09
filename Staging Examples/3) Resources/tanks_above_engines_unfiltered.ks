FUNCTION staging_start {//construct engine UID to first parent part with the a matching resource mapping
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