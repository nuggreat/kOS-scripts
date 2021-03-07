FUNCTION staging_check {
  IF STAGE:READY {
    LOCAL engList IS LIST().
    LIST ENGINES IN engList.
    LOCAL shouldStage IS FALSE.
    FOR eng IN engList {
      IF eng:IGNITION AND eng:FLAMEOUT {
        PRINT "Staging due to engine flame out".
        STAGE.
        RETURN TRUE.
      }
    }
  }
  RETURN FALSE.
}