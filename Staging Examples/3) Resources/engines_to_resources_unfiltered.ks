FUNCTION staging_check {
  PARAMETER threshold IS 0.01.
  LOCAL engList IS LIST().
  LIST ENGINES IN engList.
  LOCAL shouldStage IS FALSE.
  IF STAGE:READY {
    FOR eng IN engList {
      IF eng:IGNITION {
        LOCAL engRes IS eng:CONSUMEDRESOURCES.
        FOR key IN engRes:KEYS {
          IF engRes[key]:AMOUNT < threshold {
            SET shouldStage TO TRUE.
            PRINT "staging due to resource: " + engRes[key]:NAME + " below threshold".
            STAGE.
            BREAK.
          }
        }
      }
      IF shouldStage {
        BREAK.
      }
    }
  }
  RETURN shouldStage.
}