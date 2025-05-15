# Howto

## How to deal with long-running calculations

For any calculation that runs for more than a couple of minutes, use the [`QuantumControl.run_or_load`](@ref) function. A particular case of a long-running calculation is a call to [`QuantumControl.optimize`](@ref) for a system of non-trivial size. For optimizations in particular, there is [`QuantumControl.@optimize_or_load`](@ref) that uses `run_or_load` around `optimize`, and stores the optimization result together with the (truncated) output from the optimization.

As an alternative to [`QuantumControl.run_or_load`](@ref), you might also consider the use of the [DrWatson package](@extref DrWatson :doc:`index`), which provides [`DrWatson.produce_or_load`](@extref). It has a slightly more opinionated approach to saving and uses automatic file names based on parameters in a `config` data structure. In contrast, [`QuantumControl.run_or_load`](@ref) gives more control over the filename and does not force you to organize parameters in a `config`.
