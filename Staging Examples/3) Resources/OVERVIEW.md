## Resource overview

These methods are based on checking resources in some way.
Either looking at global resource levels on the vessel, the resources in individual tanks, or engine derived resource data.

One method has two different implementations one based on a function called in a loop and the other on use of a trigger.
All other methods are based around functions called in a loop.
My personal preference is for the loop based functions as I consider them more reliable and easier to work with but I included the trigger methods mostly to show how to properly do staging using triggers.

### global thresholds

Loop form:    [lib](global_thresholds_loop.ks) / [example](global_thresholds_loop_example.ks)

Trigger form: [lib](global_thresholds_trigger.ks) / [example](global_thresholds_trigger_example.ks)

This method stages once the remaining amount of a resources is below a given threshold at which point it will check the next resource in the list.
The resources and thresholds will be processed one at a time in the order they are passed to function.
	   
### tagged tanks

[lib](tagged_tanks.ks) / [example](tagged_tanks_example.ks)

This method checks parts that have one tag or one of several tags for when any of the resources in those parts fall below a threshold.

### above engines

Filtered form:   [lib](tanks_above_engines_filtered.ks) / [example](tanks_above_engines_filtered_example.ks)

Unfiltered form: [lib](tanks_above_engines_unfiltered.ks) / [example](tanks_above_engines_unfiltered_example.ks)

This method starts from an engine and works up the part tree looking for a part that contains one of the resources that the engine consumes.
Once such a part is found the part is monitored for when the amount of the found resource falls below a threshold defined during the set up.

There are two forms to this method a filtered and unfiltered.
The filtered from only examines tanks above active engines.
The unfiltered form examines all tanks found regardless of engine status.

### engines to resource cast

Filtered form:   [lib](engines_to_resources_filtered.ks) / [example](engines_to_resources_filtered_example.ks)

Unfiltered form: [lib](engines_to_resources_unfiltered.ks) / [example](engines_to_resources_unfiltered_example.ks)

This method works by examines the resources available to an engine for use as propellants and checks for when the amounts of any of the resources for any of the engines fall below a threshold.

There are two forms of this method.
The filtered form only examines the resources of active engines.
The unfiltered form examines the resources of all engines regardless of engine status.