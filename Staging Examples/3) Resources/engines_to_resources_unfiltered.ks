//The function staging_check checks all engines for any engines that have a consumed resource amount below the passed in threshold
// A possible issue with the function is that if there are no active engines it will not stage
// The function expects one parameter which is the amount of units a given resource must be below to cause staging

FUNCTION staging_check {
  PARAMETER threshold IS 0.01.
  LOCAL shouldStage IS FALSE.
  LOCAL noActiveEngines IS TRUE.
  IF STAGE:READY {
    FOR eng IN SHIP:ENGINES {
      IF eng:IGNITION {
		SET noActiveEngines TO FALSE.
        LOCAL engRes IS eng:CONSUMEDRESOURCES.
        FOR res IN engRes:VALUES {
          IF res:AMOUNT < threshold {
            SET shouldStage TO TRUE.
            PRINT "Staging due to resource: " + res:NAME + " below threshold".
            BREAK.
          }
        }
        IF shouldStage {
          BREAK.
        }
      }
    }
    IF shouldStage OR noActiveEngines {
      IF noActiveEngines {
        PRINT "Staging due to no active engines".
      }
      STAGE.
    }
  }
  RETURN shouldStage.
}