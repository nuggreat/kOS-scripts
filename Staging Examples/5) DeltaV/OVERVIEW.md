## DeltaV overview

There is only one method for this catagory.

[lib](delta_v.ks) / [example](delta_v_example.ks)

This method staged once the stock deltaV information for the current stage reads below a threshold for sufficient time and enough time has passed since the method last staged.
Externally triggered staging by some other function or the user pressing the stage key will not be registered and thus will reset delay.
The reason for the delays both since last staging and requiring the stages DeltaV value to be blow the threshold for a period of time are all an attempt to mitigate against issues with the stock DeltaV system.
For more information on these issues read the [warnings](https://ksp-kos.github.io/KOS_DOC/structures/vessels/deltav.html#warning-stock-numbers-aren-t-totally-reliable) in the kOS documentation on the deltaV structure
