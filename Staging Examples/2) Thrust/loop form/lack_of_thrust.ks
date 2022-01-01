//The function staging_check looks at avilableThrust and if it reads as 0 then the function stages

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