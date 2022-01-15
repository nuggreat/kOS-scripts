## Thrust overview

These methods are based on checking the thrust of the vessel in some way.
Either looking for a lack of thrust or a change of thrust.

There are two different implementations of each method one employing function calls intended to be used in a loop and the other employing a single startup function call that sets up a trigger to handle staging.
My personal preference is for the loop based functions as I consider them more reliable and easier to work with but I included the trigger methods mostly to show how to properly do staging using triggers.

NOTE: These methods all use available thrust calls provided by kOS and some mods have been known to cause issues with this call which will intern cause issues with these methods.
The exact calls are `SHIP:AVAILABLETHRUST` and `SHIP:AVAILABLETHRUSTAT(0)`.

### Lack of Thrust

Loop:    [lib](loop%20form\lack_of_thrust.ks) / [example](loop%20form\lack_of_thrust_example.ks)

Trigger: [lib](trigger%20form\lack_of_thrust.ks) / [example](trigger%20form\lack_of_thrust_example.ks)

This methods simply checks the available thrust of the vessel and stages when the available thrust is zero.
This should only happen when no engines can generate thrust either by not having been activated yet or because they are out of fuel.
But some mods have been known to cause issues with the available thrust so there can be issues.

### thrust delta fraction

Loop:    [lib](loop%20form\thrust_delta_fraction.ks) / [example](loop%20form\thrust_delta_fraction_example.ks)

Trigger: [lib](trigger%20form\thrust_delta_fraction.ks) / [example](trigger%20form\thrust_delta_fraction_example.ks)

This method compares the previous available thrust against the current available thrust and should the current thrust be sufficiently lower than the previous thrust it will stage.
The change in thrust is calculated assuming the engine is in vacuum to avoid atmospheric issues as thrust can change due to atmosphere.
The amount the thrust needs to drop is not fixed and is instead some fraction of the previously stored thrust value.
The trigger form of this method is based on an `ON` trigger and it is looking for a change in `SHIP:AVAILABLETHRUSTAT(0)` before determine if staging should occur.

### thrust delta threshold

Loop:    [lib](loop%20form\thrust_delta_threshold.ks) / [example](loop%20form\thrust_delta_threshold_example.ks)

Trigger: [lib](trigger%20form\thrust_delta_threshold.ks) / [example](trigger%20form\thrust_delta_threshold_example.ks)

This method is the same as thrust delta fraction except that the threshold used is a fixed kN value as apposed to a fraction of the previous stored thrust value.
The lower bound is also capped at a thrust of 0 as negative thrust is not possible.
The trigger form of this method is based on an `ON` trigger and it is looking for a change in `SHIP:AVAILABLETHRUSTAT(0)` before determine if staging should occur.