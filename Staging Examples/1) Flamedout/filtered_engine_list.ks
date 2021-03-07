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