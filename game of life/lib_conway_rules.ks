LOCAL charTypes IS LIST(
	"  ",
	"░░",
	"▒▒",
	"▓▓",
	"██"
).

FUNCTION conways_game_of_life_init {
	PARAMETER randomFraction IS 1/3.
	LOCAL conways_game_of_life_scanList IS LIST(//list is ordered x,list of y
		LIST(-1, 1),LIST( 0, 1),LIST( 1, 1),
		LIST(-1, 0)            ,LIST( 1, 0),
		LIST(-1,-1),LIST( 0,-1),LIST( 1,-1)
		// LIST( 1, LIST(-1, 0, 1)),
		// LIST( 0, LIST(-1,    1)),
		// LIST(-1, LIST(-1, 0, 1))
	).
	LOCAL aliveCell IS charTypes[4].
	LOCAL deadCell IS charTypes[0].
	LOCAL dyingProgression IS LEXICON(
		charTypes[4],charTypes[3],
		charTypes[3],charTypes[2],
		charTypes[2],charTypes[1],
		charTypes[1],charTypes[0],
		charTypes[0],charTypes[0]
	).
	LOCAL aliveProgression IS LEXICON(
		charTypes[0],charTypes[4],
		charTypes[4],charTypes[3],
		charTypes[3],charTypes[2],
		charTypes[2],charTypes[1],
		charTypes[1],charTypes[1]
	).
	RETURN LEXICON(
	"rules", {
		PARAMETER frameQuery.
		// Any live cell with fewer than two live neighbors dies, as if by under population.
		// Any live cell with two or three live neighbors lives on to the next generation.
		// Any live cell with more than three live neighbors dies, as if by overpopulation.
		// Any dead cell with exactly three live neighbors becomes a live cell, as if by reproduction.
		LOCAL neighborCount IS 8 - frameQuery(conways_game_of_life_scanList,deadCell,"count").
		
		IF neighborCount < 2 OR neighborCount > 3 {
			// RETURN dyingProgression[frameQuery(0,0,"point")].
			RETURN deadCell.
		} ELSE {
			// LOCAL currentCell IS frameQuery(0,0,"point").
			IF (neighborCount = 3) OR (frameQuery(0,0,"point") = aliveCell) {
			// IF (neighborCount = 3) OR (currentCell <> deadCell) {
				RETURN aliveCell.
				// RETURN aliveProgression[currentCell].
			} ELSE {
				// RETURN dyingProgression[frameQuery(0,0,"point")].
				RETURN deadCell.
			}
		}
	},
	"randomState", {
		PARAMETER frameQuery.
		RETURN CHOOSE aliveCell IF RANDOM() <= randomFraction ELSE dyingProgression[aliveCell].
	} 
	).
}