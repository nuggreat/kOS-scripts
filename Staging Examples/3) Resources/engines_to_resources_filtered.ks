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

FUNCTION staging_check {
  PARAMETER engList, threshold IS 1.
  LOCAL shouldStage IS FALSE.
  IF STAGE:READY {
    IF engList:LENGTH > 0 {
      FOR eng IN engList {
        LOCAL engRes IS eng:CONSUMEDRESOURCES.
        FOR key IN engRes:KEYS {
          IF engRes[key]:AMOUNT < threshold {
            SET shouldStage TO TRUE.
            PRINT "staging due to resource: " + engRes[key]:NAME + " is below threshold".
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