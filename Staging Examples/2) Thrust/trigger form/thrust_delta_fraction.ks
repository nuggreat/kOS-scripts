//The function staging_start creates a trigger will stage when there is no thrust or a large enough drop in thrust
// The function will also return a lexicon with a single function delegate in it that allows for removal of the staging trigger
// The function expects to be passed a fractional threshold that they thrust must fall by for staging to happen
//  Should be in the range of 0 to 1

FUNCTION staging_start {
  PARAMETER stageThreshold IS 0.99.
  LOCAL thrustThreshold IS SHIP:AVAILABLETHRUSTAT(0) * stageThreshold.
  
  LOCAL keepStaging IS TRUE.
  ON SHIP:AVAILABLETHRUSTAT(0) {
    IF keepStaging {
      LOCAL currentThrust IS SHIP:AVAILABLETHRUSTAT(0).
      IF currentThrust <= thrustThreshold {
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
  RETURN LEX("clearTrigger",{ SET keepStaging TO FALSE. PRINT "removed thrust delta fraction trigger". }).
}