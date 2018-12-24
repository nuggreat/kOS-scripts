FUNCTION sim_land_vac {//credit to dunbaratu for the orignal code
PARAMETER
ves,				//the craft to simulate for
isp,			//the isp of the active engines
t_deltaIn,		//time step for sim
coast.			//a coast time with no thrust in seconds

LOCAL t_delta IS MAX(t_deltaIn,0.02).	//making it so the t_delta can't go below 0.02s
LOCAL GM IS ves:BODY:MU.				//the MU of the body the ship is in orbit of
LOCAL b_pos IS ves:BODY:POSITION.	//the position of the body relative to the ship
LOCAL t_max IS ves:AVAILABLETHRUST * 0.95.	//the thrust available to the ship
LOCAL m IS ves:MASS.					//the ship's mass
LOCAL vel IS ves:VELOCITY:SURFACE.	//the ship's velocity relative to the surface
LOCAL prev_vel IS vel.
LOCAL deltaM IS t_max / (9.80665 * isp) * t_delta.

LOCAL pos IS V(0,0,0).
LOCAL t IS 0.
LOCAL cycles IS 0.

IF coast > 0 {
UNTIL t >= coast {	//advances the simulation of the craft with out burning for the amount of time defined by coast
	SET cycles TO cycles + 1.
	LOCAL up_vec IS (pos - b_pos).

//	LOCAL up_unit IS up_vec:NORMALIZED.//vector from craft pointing at craft from body you are around
//	LOCAL r_square IS up_vec:SQRMAGNITUDE.//needed for gravity calculation
//	LOCAL localGrav IS GM / r_square.//gravitational acceleration at current height
//	LOCAL a_vec IS - up_unit * localGrav.//gravatational acceleration as a vector
	LOCAL a_vec IS - up_vec:NORMALIZED * (GM / up_vec:SQRMAGNITUDE).
	// above commented math is merged to save on IPU during the sim

	SET prev_vel TO vel.//store previous velocity vector for averaging
	SET vel TO vel + a_vec * t_delta.//update velocity vector with calculated applied accelerations

	LOCAL avg_vel IS 0.5 * (vel + prev_vel).//average previous with current velocity vectors to smooth changes NOTE:might not be needed

	SET pos TO pos + avg_vel * t_delta.//change stored position by adding the velocity vector adjusted for time

	SET t TO t + t_delta.//increment clock
}
}

UNTIL FALSE {	//retroburn simulation
	SET cycles TO cycles + 1.
	LOCAL up_vec IS (pos - b_pos).

	IF VDOT(vel, prev_vel) < 0 { break. }	//ends sim when velocity reverses

//	LOCAL up_unit IS up_vec:NORMALIZED.//vector from craft pointing at craft from body you are around
//	LOCAL r_square IS up_vec:SQRMAGNITUDE.//needed for gravity calculation
//	LOCAL localGrav IS GM / r_square.//gravitational acceleration at current height
//  LOCAL g_vec IS - up_unit*localGrav.//gravatational acceleration as a vector
//	LOCAL eng_a_vec IS (t_max / m) * (- vel:NORMALIZED).//velocity vector imparted by engines calculated from thrust and mass along the negative of current velocity vector (retrograde)
//	LOCAL a_vec IS eng_a_vec + g_vec.//adding engine acceleration and grav acceleration vectors to create a vector for all acceleration acting on craft
	LOCAL a_vec IS ((t_max / m) * (- vel:NORMALIZED)) - ((GM / up_vec:SQRMAGNITUDE) * up_vec:NORMALIZED).
	// above commented math is merged to save on IPU during the sim

	SET prev_vel TO vel.//store previous velocity vector for averaging
	SET vel TO vel + a_vec * t_delta.//update velocity vector with calculated applied accelerations

	LOCAL avg_vel is 0.5 * (vel+prev_vel).//average previous with current velocity vectors to smooth changes NOTE:might not be needed

	SET pos TO pos + (avg_vel * t_delta).//change stored position by adding the velocity vector adjusted for time
	SET m TO m - deltaM.//change stored mass for craft based on pre calculated change in mass per tick of sim

	IF m <= 0 { BREAK. }
	SET t TO t + t_delta.//increment clock
}

RETURN LEX("pos", pos,"vel", vel,"seconds", t,"mass", m,"cycles", cycles).
}