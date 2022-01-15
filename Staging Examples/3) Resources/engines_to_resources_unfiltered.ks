//The function staging_check checks all engines for any engines that have a consumed resource amount below the passed in threshold
// A possible issue with the function is that if there are no active engines it will not stage
// The function expects one parameter which is the amount of units a given resource must be below to cause staging

FUNCTION staging_check {
  PARAMETER threshold IS 0.01.
  LOCAL engList IS LIST().
  LIST ENGINES IN engList.
  LOCAL shouldStage IS FALSE.
  IF STAGE:READY {
    FOR eng IN engList {
      LOCAL engRes IS eng:CONSUMEDRESOURCES.
      FOR key IN engRes:KEYS {
        IF engRes[key]:AMOUNT < threshold {
          SET shouldStage TO TRUE.
          PRINT "staging due to resource: " + engRes[key]:NAME + " below threshold".
          STAGE.
          BREAK.
        }
      }
      IF shouldStage {
        BREAK.
      }
    }
  }
  RETURN shouldStage.
}