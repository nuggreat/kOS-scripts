//the function staging_check checks all active engines for any flamed out engine and stages if one is found
// a possible issue with the function is that if there are no active engines it will not stage.

FUNCTION staging_check {
  IF STAGE:READY {
    LOCAL engList IS LIST().
    LIST ENGINES IN engList.
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