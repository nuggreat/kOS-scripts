//the function staging_check checks all active engines for any flamed out engine and stages if one is found

FUNCTION staging_check {
  IF STAGE:READY {
    LOCAL engList IS LIST().
    LIST ENGINES IN engList.
    LOCAL shouldStage IS FALSE.
    LOCAL noActiveEngines IS TRUE.
    FOR eng IN engList {
      IF eng:IGNITION {
        SET noActiveEngines TO FALSE.
        IF eng:FLAMEOUT {
          SET shouldStage TO TRUE.
          BREAK.
        }
      }
    }
    IF shouldStage OR noActiveEngines {
      IF noActiveEngines {
        PRINT "Staging due to no active engines".
      } ELSE {
        PRINT "Staging due to engine flame out".
      }
      STAGE.
      RETURN TRUE.
    }
  }
  RETURN FALSE.
}