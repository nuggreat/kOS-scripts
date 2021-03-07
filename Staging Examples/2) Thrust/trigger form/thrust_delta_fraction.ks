FUNCTION staging_start {
  PARAMETER stageThreshold IS 0.99.
  LOCAL thrustThreshold IS SHIP:AVAILABLETHRUSTAT(0) * stageThreshold.
  
  LOCAL keepStaging IS TRUE.
  ON SHIP:AVAILABLETHRUSTAT(0) {
    IF keepStaging {
      LOCAL currentThrust IS SHIP:AVAILABLETHRUSTAT(0).
      IF currentThrust < thrustThreshold {
        IF NOT STAGE:READY {
          WAIT UNTIL STAGE:READY.
        }
        PRINT "stageing due to thrust drop".
        STAGE.
        SET currentThrust TO SHIP:AVAILABLETHRUSTAT(0).
      }
      SET thrustThreshold TO currentThrust * stageThreshold.
      PRESERVE.
    }
  }
  RETURN LEX("clear",{ SET keepStaging TO FALSE. }).
}