Below is a set of libraries for different methods of staging sorted by type.
Included in addition to each method is an example launch script making use of the method so one can see the intended use in code.
The example scripts presumes they are running on a mostly stock kerbalX (you will need to add a kOS core to the craft) that comes with KSP and that kOS is the only mod installed.
Most of the example scripts can likely work on other vessels though some are designed with explicit knowledge of the craft in question which makes them unusable on other craft.
Lastly it is possible with some effort to use different methods at the same time though you would need to modify the provided libraries to do so.

Click on the [OVERVIEW](README.md) links below in the list for the overview of that category and additional explanations of the staging methods in that category.

Click on the [lib](README.md) links below in the list to jump strait to the library of functions needed for that staging method.

Click on the [example](README.md) links below in the list to jump strait to the example launch script for that staging method. 

  1. flamed out engines           [OVERVIEW](1\)%20Flamedout/OVERVIEW.md)
     - filtered engine list       [lib](1\)%20Flamedout/filtered_engine_list.ks) / [example](1\)%20Flamedout/filtered_engine_list_example.ks)
     - unfiltered engine list     [lib](1\)%20Flamedout/unfiltered_engine_list.ks) / [example](1\)%20Flamedout/unfiltered_engine_list_example.ks)
  1. thrust                     [OVERVIEW](2\)%20Thrust/OVERVIEW.md)
     - loop form
       - lack of thrust         [lib](2\)%20Thrust/loop%20form/lack_of_thrust.ks) / [example](2\)%20Thrust/loop%20form/lack_of_thrust_example.ks)
       - thrust delta fraction  [lib](2\)%20Thrust/loop%20form/thrust_delta_fraction.ks) / [example](2\)%20Thrust/loop%20form/thrust_delta_fraction_example.ks)
       - thrust delta threshold [lib](2\)%20Thrust/loop%20form/thrust_delta_threshold.ks) / [example](2\)%20Thrust/loop%20form/thrust_delta_threshold_example.ks)
     - trigger form
       - lack of thrust         [lib](2\)%20Thrust/trigger%20form/lack_of_thrust.ks) / [example](2\)%20Thrust/trigger%20form/lack_of_thrust_example.ks)
       - thrust delta fraction  [lib](2\)%20Thrust/trigger%20form/thrust_delta_fraction.ks) / [example](2\)%20Thrust/trigger%20form/thrust_delta_fraction_example.ks)
       - thrust delta threshold [lib](2\)%20Thrust/trigger%20form/thrust_delta_threshold.ks) / [example](2\)%20Thrust/trigger%20form/thrust_delta_threshold_example.ks)
  1. resource                   [OVERVIEW](3\)%20Resources/OVERVIEW.md)
     - global thresholds
       - loop form              [lib](3\)%20Resources/global_thresholds_loop.ks) / [example](3\)%20Resources/global_thresholds_loop_example.ks)
       - trigger form           [lib](3\)%20Resources/global_thresholds_trigger.ks) / [example](3\)%20Resources/global_thresholds_trigger_example.ks)
     - tagged tanks             [lib](3\)%20Resources/tagged_tanks.ks) / [example](3\)%20Resources/tagged_tanks_example.ks)
     - above engines
       - filtered engine list   [lib](3\)%20Resources/tanks_above_engines_filtered.ks) / [example](3\)%20Resources/tanks_above_engines_filtered_example.ks)
       - unfiltered engine list [lib](3\)%20Resources/tanks_above_engines_unfiltered.ks) / [example](3\)%20Resources/tanks_above_engines_unfiltered_example.ks)
     - engines to resource cast
       - filtered engine list   [lib](3\)%20Resources/engines_to_resources_filtered.ks) / [example](3\)%20Resources/engines_to_resources_filtered_example.ks)
       - unfiltered engine list [lib](3\)%20Resources/engines_to_resources_unfiltered.ks) / [example](3\)%20Resources/engines_to_resources_unfiltered_example.ks)
  1. time                                  [OVERVIEW](4\)%20Time/OVERVIEW.md)
     - loop form
       - time delta between staging events [lib](4\)%20Time/loop%20form/delta_between_staging.ks) / [example](4\)%20Time/loop%20form/delta_between_staging_example.ks)
       - elapsed time since start          [lib](4\)%20Time/loop%20form/elapsed_since_start.ks) / [example](4\)%20Time/loop%20form/elapsed_since_start_example.ks)
     - trigger form
       - time delta between staging events [lib](4\)%20Time/trigger%20form/delta_between_staging.ks) / [example](4\)%20Time/trigger%20form/delta_between_staging_example.ks)
       - elapsed time since start          [lib](4\)%20Time/trigger%20form/elapsed_since_start.ks) / [example](4\)%20Time/trigger%20form/elapsed_since_start_example.ks)
  1. deltaV [OVERVIEW](5\)%20DeltaV/OVERVIEW.md) / [lib](5\)%20DeltaV/delta_v.ks) / [example](5\)%20DeltaV/delta_v_example.ks)
