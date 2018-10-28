RCS OFF.
CLEARSCREEN.
UNTIL RCS {
  WAIT 0.
  LOCAL shipMass IS SHIP:MASS.
  LOCAL shipAlt IS SHIP:ALTITUDE.
  LOCAL obtSpeed IS SHIP:VELOCITY:ORBIT:MAG.
  LOCAL ke IS 0.5 * shipMass * obtSpeed^2.
  LOCAL ke IS 0.5 * shipMass * obtSpeed^2.
  ke * 2 = shipMass * obtSpeed^2
  (ke * 2) / shipMass = obtSpeed^2
  SQRT((ke * 2) / shipMass)
//  LOCAL pe1 IS BODY:MU * shipMass / (shipAlt + BODY:RADIUS).

//shipAcc = SHIP:AVAILABLETHRUST / SHIP:MASS = m/s
//shipPE = (-BODY:MU * shipMass / (shipAlt + BODY:RADIUS) - (-BODY:MU * shipMass / BODY:RADIUS))
//shipPE + shipKE = totalEnergy 
//
//(BODY:MU * shipMass / (BODY:RADIUS + impactAlt)) = impactEnergy
//
//needToEmit = totalEnergy - impactEnergy
//
//energyEmissionRate = 0.5 * shipMass * shipAcc ^ 2
//energyEmissionRate = 0.5 * shipMass * (SHIP:AVAILABLETHRUST / shipMass) ^ 2

  LOCAL pe1 IS (-BODY:MU * shipMass / (shipAlt + BODY:RADIUS) - (-BODY:MU * shipMass / BODY:RADIUS)).
  LOCAL pe2 IS potential_energy(shipMass,shipAlt,0,SHIP:BODY).//calculating the potential energy using sea level as 0 potential energy
  
  PRINT "   kenitic Energy: " + ROUND(ke,2) + " kJ     " AT(0,0).
  PRINT "Potential Energy1: " + ROUND(pe1,2) + " kJ     " AT(0,1).
  PRINT "        ke + pe1 = " + ROUND(ke + pe1,2) + " kJ     " AT(0,2).
  
  PRINT "   kenitic Energy: " + ROUND(ke,2) + " kJ     " AT(0,4).
  PRINT "Potential Energy2: " + ROUND(pe2,2) + " kJ     " AT(0,5).
  PRINT "        ke + pe2 = " + ROUND(ke + pe2,2) + " kJ     " AT(0,6).
}

FUNCTION average_grav {
  PARAMETER highAlt IS SHIP:ALTITUDE,lowAlt IS 0,localBody IS SHIP:BODY.
  LOCAL altDiff IS highAlt - lowAlt.
  IF altDiff <= 0 {
    RETURN localBody:MU / localBody:RADIUS^2.
  } ELSE {
    RETURN ((localBody:MU / (localBody:RADIUS + lowAlt)) - (localBody:MU / (localBody:RADIUS + highAlt))) / altDiff.
  }
}

FUNCTION potential_energy {//in joules
  PARAMETER shipMass IS SHIP:MASS,highAlt IS SHIP:ALTITUDE,lowAlt IS 0,localBody IS SHIP:BODY.
  LOCAL avrGrav IS average_grav(highAlt,lowAlt,localBody).
  LOCAL altDiff IS highAlt - lowAlt.
  RETURN shipMass*avrGrav*altDiff.
}