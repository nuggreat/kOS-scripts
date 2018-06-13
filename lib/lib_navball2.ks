// A library of functions to calculate navball-based directions for vectors:
// All functions assume the vector originates from the vessel running the function for the sake of calculating the values
@LAZYGLOBAL OFF.

FUNCTION heading_of_vector { // heading_of_vector returns the heading of the vector (number range   0 to 360)
	PARAMETER vecT.

	LOCAL east IS VCRS(SHIP:UP:VECTOR, SHIP:NORTH:VECTOR).

	LOCAL trig_x IS VDOT(SHIP:NORTH:VECTOR, vecT).
	LOCAL trig_y IS VDOT(east, vecT).

	LOCAL result IS ARCTAN2(trig_y, trig_x).

	IF result < 0 {RETURN 360 + result.} ELSE {RETURN result.}
}

FUNCTION pitch_of_vector { // pitch_of_vector returns the pitch of the vector(number range -90 to  90)
	PARAMETER vecT.

	RETURN 90 - VANG(SHIP:UP:VECTOR, vecT).
}