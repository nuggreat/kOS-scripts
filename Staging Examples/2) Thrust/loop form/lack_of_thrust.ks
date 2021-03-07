FUNCTION staging_check {
  IF SHIP:AVAILABLETHRUST = 0 {
    IF STAGE:READY {
      PRINT "Staging due to no thrust".
      STAGE.
      RETURN TRUE.
    }
  }
  RETURN FALSE.
}