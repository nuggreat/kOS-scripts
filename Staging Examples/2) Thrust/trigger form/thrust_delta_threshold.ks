//The function staging_start creates a trigger will stage when there is a large enough drop in thrust
// The function will also return a lexicon with a single function delegate in it that allows for removal of the staging trigger
// The function expects to be passed the required drop as a number of kilo-newtons

FUNCTION staging_start {
  PARAMETER stageThreshold IS 20.
  LOCAL threshold IS MIN(0,SHIP:AVAILABLETHRUSTAT(0) - stageThreshold).
  
  LOCAL keepStaging IS TRUE.
  ON SHIP:AVAILABLETHRUSTAT(0) {
    IF keepStaging {
      LOCAL currentThrust IS SHIP:AVAILABLETHRUSTAT(0).
      IF currentThrust <= threshold {
        IF NOT STAGE:READY {
          WAIT UNTIL STAGE:READY.
        }
        PRINT "staging due to thrust drop".
        STAGE.
        SET currentThrust TO SHIP:AVAILABLETHRUSTAT(0).
      }
      SET threshold TO MIN(0,currentThrust - stageThreshold).
      PRESERVE.
    }
  }
  RETURN LEX("clearTrigger",{ SET keepStaging TO FALSE. PRINT "removed thrust delta threshold trigger". }).
}