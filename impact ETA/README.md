calculated_impact_eta is an example script showing the use of several functions to used to calculate the time a craft will impact a body

## Functions

### impact_UTs

  will calculate several things about when the ship impacts a body including the UT of said impact

**Parameter(s) and return value(s)**

  One optional parameter

    1) For setting the minimum change in terrain height between runs that will make the ["converged"] return true

  Returns a lexicon of 3 items

    ["time"] is the UT in seconds of when the SHIP will impact the body
    ["terrainHeight"] is the terrain height where the SHIP will impact the body
    ["converged"] is true when the changes to the terrainHeight from one run of the function to the next is less than the error as set by the parameter

**Notes about function**

  When the function first runs it assumes the terrain height is the same as the body radius, this value gets refined over further calls of the function improving the accuracy of the returned time as well as the terrain height.  Any changes to the impact location due to changing the craft's ballistic trajectory will disturbed the accuracy of the impact time until the function has been call a few more times and is able to refine it's terrain height.

### alt_to_ta

  Calculates the possible two true anomalies of a given altitude

**Parameter(s) and return value(s)**

  Four required parameters

    1) The semi-major axis of the craft's orbit
    2) The eccentricity of the craft's orbit
    3) The body the craft is in orbit around
    4) The altitude to calculate the true anomalies for

  Returns a list of 2 tiems

    [0] Will be the true anomaly when the craft rises through the passed in altitude (craft going from PE to AP)
    [1] Will be the true anomaly when the craft descends through the passed in altitude (craft going from AP to PE)

**Notes about function**

  There is no protection coded into the function for if you pass in a altitude not between the AP and PE.  The function be tested with hyperbolic orbit and i don't believe the math works for said hyperbolic orbits

  function derived from this equation:

    r   = distance from center of body
    sma = semi-major axis
    ecc = eccentricity
    ta  = true anomaly
    r = sma * ((1-ecc^2) / (1 + ecc * cos(ta)))

### time_betwene_two_ta

  Calculates the time it between 2 true anomaly

**Parameter(s) and return value(s)**

  Four required parameters

    1) The eccentricity of the orbit
    2) The period of the orbit
    3) The starting true anomaly(in degrees)
    4) The ending true anomaly(in degrees)

  Returns the number of seconds it takes to for the passed in orbit to travel from the starting true anomaly to the ending true anomaly

**Notes about function**

  Does not work for hyperbolic orbits, nor is there any protection in the function against passing a hyperbolic orbit

### ta_to_ma

  Calculates mean anomaly from true anomaly

**Parameter(s) and return value(s)**

  Two required parameters

    1) The eccentricity of the orbit
    2) The true anomaly

  Returns the mean anomaly of the passed in true anomaly

**Notes about function**

  Does not work for hyperbolic orbits

### ground_track

  For accounting for the rotation of a body.

**Parameter(s) and return value(s)**

  Calculates the location of a position at a given time

    1) a position vector
    2) the UT seconds
    3) the body to to adjust for

  returns the altitude longitude chordates of the passed in position vector adjusted for the rotation of the passed in body.

**Notes about function**

  expected use is with the POSITIONAT function inbuilt into kOS, EXAMPLE: ```ground_track(POSITIONAT(SHIP,someTime),someTime)```
