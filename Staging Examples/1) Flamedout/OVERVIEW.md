## Flamed out engine overview

These methods check the engines on a vessel for any that are flamed out and staging when any are found.

### unfiltered engine list

[lib](unfiltered_engine_list.ks) / [example](unfiltered_engine_list_example.ks)

This method simply checks the list of all engines on the vessel for any that are flamed out.
It also stage if there are no active engines.

### filtered engine list

[lib](filtered_engine_list.ks) / [example](filtered_engine_list_example.ks)

This method employs a pre filter on the engine list so that it only checks the active engines for any that are flamed out.
It will also stage if there are no active engines.
After each staging event the list of filtered engines needs to be rebuilt as it is presumed that after staging ether flamed out engines are dropped or new engines are active.
The filter would be easy to expand to include a black list of tags/names should you use mods that enforce ullage.