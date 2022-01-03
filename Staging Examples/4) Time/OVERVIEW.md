## Time overview

These methods staged based on the time since some event staging for one and when the startup function was called for the other.
Both methods require something else to supply the initial set of timing information as they can not generate it on there own.
Timing can be structured based on seconds from a zero point or seconds between staging events.
Each method's startup function can change the cast to the type they require.

There are two different implementations of each method one employing function calls intended to be used in a loop and the other employing a single startup function call that sets up a trigger to handle staging.
My personal preference is for the loop based functions as I consider them more reliable and easier to work with but I included the trigger methods mostly to show how to properly do staging using triggers.

### delta between staging

Loop form:    [lib](loop%20form/delta_between_staging.ks) / [example](loop%20form/delta_between_staging_example.ks)

Trigger form: [lib](trigger%20form/delta_between_staging.ks) / [example](trigger%20form/delta_between_staging_example.ks)

This method stages once sufficient time has passed since the last time the method staged.
Externally triggered staging by some other function or the user pressing the stage key will not be registered by the method.
There is a ghost staging event that gets included as part of the startup function to sync the timing to.

### elapsed since start

loop form:    [lib](loop%20form/elapsed_since_start.ks) / [example](loop%20form/elapsed_since_start_example.ks)

trigger form: [lib](trigger%20form/elapsed_since_start.ks) / [example](trigger%20form/elapsed_since_start_example.ks)

This method stages based on the time elapsed since the start up function was called.
