//The function staging_start creates a trigger that will stage when there is no thrust
// The function will return a lexicon with a single function delegate in it that allows for removal of the staging trigger

FUNCTION staging_start {
  LOCAL clearStageing IS FALSE.
  WHEN clearStageing OR ((SHIP:AVAILABLETHRUST = 0) AND STAGE:READY) THEN {
    IF NOT clearStageing {
      PRINT "Staging due to no thrust".
      STAGE.
      PRESERVE.
    }
  }
  RETURN LEX("clearTrigger",{ SET clearStageing TO TRUE. PRINT "removed no thrust trigger". }).
}