module Workflows

using QuantumControlBase: optimize, set_atexit_save_optimization
export run_or_load, @optimize_or_load, save_optimization, load_optimization

using FileIO: FileIO, File, DataFormat
using JLD2: JLD2
using IOCapture

_is_jld2_filename(file) = (file isa String && endswith(file, ".jld2"))

"""
Run some code and write the result to file, or load from the file if it exists.

```julia
data = run_or_load(
    file;
    save=(endswith(file, ".jld2") ? JLD2.save_object : FileIO.save),
    load=(endswith(file, ".jld2") ? JLD2.load_object : FileIO.load),
    force=false,
    verbose=true,
    kwargs...
) do
    data = Dict()  # ...  # something that can be saved to / loaded from file
    return data
end
```

runs the code in the block and stores `data` in the given `file`.
If `file` already exists, skip running the code and instead return the data
in `file`.

If `force` is `True`, run the code whether or not `file` exists,
potentially overwriting it.

With `verbose=true`, information about the status of `file` will be shown
as `@info`.

The `data` returned by the code block must be compatible with the format of
`file` and the `save`/`load` functions. When using `JLD2.save_object` and
`JLD2.load_object`, almost any data can be written, so this should be
particularly safe. More generally, when using `FileIO.save` and `FileIO.load`,
see the [FileIO registry](https://juliaio.github.io/FileIO.jl/stable/registry/)
for details. A common examples would be a
[`DataFrame`](https://dataframes.juliadata.org/stable/) being written to a
`.csv` file.

# See also

* [`@optimize_or_load`](@ref) — for wrapping around [`optimize`](@ref)
* [`DrWatson.@produce_or_load`](https://juliadynamics.github.io/DrWatson.jl/stable/save/#DrWatson.@produce_or_load)
  — a similar but more opinionated function with automatic naming
"""
function run_or_load(
    f::Function,
    file;
    save::Function=(_is_jld2_filename(file) ? JLD2.save_object : FileIO.save),
    load::Function=(_is_jld2_filename(file) ? JLD2.load_object : FileIO.load),
    force=false,
    verbose=true,
    _else=nothing,   # undocumented function to run on data if loaded
    kwargs...
)
    # Using `JLD2.save_object` instead of `FileIO.save` is more flexible:
    # `FileIO.save` would require a Dict{String, Any}, whereas `save_object`
    # can save pretty much anything.
    if file isa AbstractString
        filename = file
    else
        filename = FileIO.filename(file)
    end
    if force || !isfile(filename)
        if verbose
            if force && isfile(filename)
                @info "Overwriting $filename (force=true)"
            else  # if !isfile(filename)
                @info "File $filename does not exist. Creating it now."
            end
        end
        dir, _ = splitdir(filename)
        # We want to make sure we can create the output dir *before* we run `f`
        mkpath(dir)
        data = f()
        try
            save(file, data; kwargs...)
        catch exc
            # This "emergency fallback" is undocumented on purpose: it's just
            # to be nice and try to preserve the results of long-running
            # calculations, but nothing is guaranteed and nobody should rely on
            # it.
            if exc isa CapturedException
                # `showerror` directly for a CapturedException includes the
                # backtrace, which we don't want.
                exc = exc.ex
            end
            exc_msg = sprint(showerror, exc)
            @error "Error saving data: $exc_msg"
            tmp = "$(tempname(; cleanup=false)).jld2"
            try
                JLD2.save_object(tmp, data)
            catch exc_inner
                exc_msg = sprint(showerror, exc_inner)
                error("Unable to recover by writing data to $tmp: $exc_msg")
            end
            # Julia < 1.8 doesn't have `else` for `try`
            error("""
            Recover data with:

                using JLD2: load_object
                data = load_object($(repr(tmp)))
            """)
        end
        return load(file)
    else
        data = load(file)
        verbose && @info "Loading data from $filename"
        if !isnothing(_else)
            _else(data)
        end
        return data
    end
end


mutable struct FirstLastBuffer
    first::Vector{UInt8}
    last::Vector{UInt8}
    N::Int64
    written::Int64
end


function FirstLastBuffer(N=1024)
    first = Vector{UInt8}(undef, N)
    last = Vector{UInt8}(undef, N)
    FirstLastBuffer(first, last, N, 0)
end


function Base.write(buffer::FirstLastBuffer, data)
    for byte in data
        if buffer.written < buffer.N
            i = buffer.written + 1
            buffer.first[i] = byte
        else
            i = mod((buffer.written - buffer.N), buffer.N) + 1
            buffer.last[i] = byte
        end
        buffer.written += 1
    end
end


function Base.take!(buffer::FirstLastBuffer)
    N = buffer.N
    if buffer.written <= N
        result = buffer.first[1:buffer.written]
    else
        written_last = buffer.written - N
        last = view(buffer.last, 1:min(written_last, N))
        if written_last <= N
            sep = Vector{UInt8}[]
            length_result = buffer.written
            shift = 0
        else
            sep = Vector{UInt8}("…\n…")
            length_result = 2 * N + length(sep)
            shift = -mod(buffer.written - buffer.N, buffer.N)
        end
        result = Vector{UInt8}(undef, length_result)
        result[1:N] .= buffer.first
        result[N+1:N+length(sep)] .= sep
        result[N+length(sep)+1:end] .= circshift(last, shift)
    end
    buffer.written = 0
    return result
end


function _redirect_to_file(f, logfile)
    open(logfile, "w") do io
        redirect_stdout(io) do
            redirect_stderr(io) do
                return f()
            end
        end
    end
end


function _print_loaded_output(data)
    if haskey(data, "output")
        for line in split(data["output"], "\n")
            if !startswith(line, "…")
                println(line)
            end
        end
    end
end


# See @optimize_or_load for documentation –
# Only the macro version should be public!
function optimize_or_load(
    _filter,
    file,
    problem;
    method,
    force=false,
    verbose=get(problem.kwargs, :verbose, false),
    metadata::Union{Nothing,Dict}=nothing,
    logfile=nothing,
    kwargs...
)

    # _filter is only for attaching metadata to the result

    save = FileIO.save
    load = FileIO.load
    JLD2_fmt = FileIO.DataFormat{:JLD2}
    if file isa AbstractString
        atexit_filename = file
    else
        atexit_filename = FileIO.filename(file)
    end
    data = run_or_load(
        File{JLD2_fmt}(file);
        save,
        load,
        force,
        verbose,
        _else=_print_loaded_output
    ) do
        color = get(stdout, :color, false)
        if haskey(ENV, "JULIA_CAPTURE_COLOR")
            # Undocumented feature. Literate.jl doesn't work well with captured
            # color. When doing an optimization in a Literate example, it's
            # best to evaluate it with JULIA_CAPTURE_COLOR=0
            color = (ENV["JULIA_CAPTURE_COLOR"] != "0")
        end
        if isnothing(logfile)
            c = IOCapture.capture(
                passthrough=true,
                capture_buffer=FirstLastBuffer(),
                color=color,
            ) do
                optimize(problem; method, verbose, atexit_filename, kwargs...)
            end
            result = c.value
            output = c.output
        else
            result = _redirect_to_file(logfile) do
                optimize(problem; method, verbose, atexit_filename, kwargs...)
            end
            output = ""
        end
        data = Dict{String,Any}("result" => result, "output" => output)
        if !isnothing(_filter)
            data = _filter(data)
        end
        if !isnothing(metadata)
            for (k, v) in metadata
                # This should convert pretty much any key to a string
                data[String(Symbol(k))] = v
            end
        end
        return data
    end
    return data["result"]

end

optimize_or_load(file, problem; kwargs...) =
    optimize_or_load(nothing, file, problem; kwargs...)


# Given a list of macro arguments, push all keyword parameters to the end.
#
# A macro will receive keyword arguments after ";" as either the first or
# second argument (depending on whether the macro is invoked together with
# `do`). The `reorder_macro_kw_params` function reorders the arguments to put
# the keyword arguments at the end or the argument list, as if they had been
# separated from the positional arguments by a comma instead of a semicolon.
#
# # Example
#
# With
#
# ```
# macro mymacro(exs...)
#     @show exs
#     exs = reorder_macro_kw_params(exs)
#     @show exs
# end
# ```
#
# the `exs` in e.g. `@mymacro(1, 2; a=3, b)` will end up as
#
# ```
# (1, 2, :($(Expr(:kw, :a, 3))), :($(Expr(:kw, :b, :b))))
# ```
#
# instead of the original
#
# ```
# (:($(Expr(:parameters, :($(Expr(:kw, :a, 3))), :b))), 1, 2)
# ```
function reorder_macro_kw_params(exs)
    exs = Any[exs...]
    i = findfirst([(ex isa Expr && ex.head == :parameters) for ex in exs])
    if !isnothing(i)
        extra_kw_def = exs[i].args
        for ex in extra_kw_def
            push!(exs, ex isa Symbol ? Expr(:kw, ex, ex) : ex)
        end
        deleteat!(exs, i)
    end
    return Tuple(exs)
end


"""
Run [`optimize`](@ref) and store the result, or load the result if it exists.

```julia
result = @optimize_or_load(
    file,
    problem;
    method,
    force=false,
    verbose=true,
    metadata=nothing,
    logfile=nothing,
    kwargs...
)
```

runs `result = optimize(problem; method, kwargs...)` and stores
`result` in `file` in the JLD2 format. Note that the `method` keyword argument
is mandatory.

In addition to the `result`, the data in the output `file`
can also contain metadata. By default, this is "script" with the file
name and line number of where `@optimize_or_load` was called, as well as data
from the dict `metadata` mapping arbitrary (string) keys to values.
Lastly, the data contains truncated captured output (up to 1kB of both the
beginning and end of the output) from the optmization.

If `logfile` is given as the path to a file, both `stdout` and `stderr` from
`optimize` are redirected into the given file.

If `file` already exists (and `force=false`), load the `result` from that file
instead of running the optimization, and print any (truncated) captured output.

All other `kwargs` are passed directly to [`optimize`](@ref).

For methods that support this, `@optimize_or_load` will set up a callback to
dump the optimization result to `file` in case of an unexpected program
shutdown, see [`set_atexit_save_optimization`](@ref).

## Related Functions

* [`run_or_load`](@ref)  — a function for more general long-running
  calculations.
* [`load_optimization`](@ref): Function to load a file produced by
  `@optimize_or_load`
"""
macro optimize_or_load(exs...)
    exs = reorder_macro_kw_params(exs)
    exs = Any[exs...]
    _isa_kw = arg -> (arg isa Expr && (arg.head == :kw || arg.head == :(=)))
    if (length(exs) < 2) || _isa_kw(exs[1]) || _isa_kw(exs[2])
        @show exs
        error(
            "@optimize_or_load macro must receive `file` and `problem` as positional arguments"
        )
    end
    if (length(exs) > 2) && !_isa_kw(exs[3])
        @show exs
        error(
            "@optimize_or_load macro only takes two positional arguments (`file` and `problem`)"
        )
    end
    file = popfirst!(exs)
    problem = popfirst!(exs)
    s = QuoteNode(__source__)  # source file and line number of calling line
    return quote
        optimize_or_load($(esc(file)), $(esc(problem)); $(esc.(exs)...)) do data # _filter
            data["script"] = relpath(_sourcename($(esc(s))), $(esc(file)))
            return data
        end
    end
end

_sourcename(s) = string(s)
_sourcename(s::LineNumberNode) = string(s.file) * "#" * string(s.line)


"""Write an optimization result to file.

```julia
save_optimization(file, result; metadata=nothing)
```

writes the result obtained from a call to `optimize` to the given `file` in
JLD2 format. If given, `metadata` is a dict of additional data that will be
stored with the result. The `metadata` dict should use strings as keys.

# See also

* [`load_optimization`](@ref): Function to load a file produced by
  [`@optimize_or_load`](@ref) or [`save_optimization`](@ref)
* [`@optimize_or_load`](@ref): Run [`optimize`](@ref) and
  [`save_optimization`](@ref) in one go.
"""
function save_optimization(file, result; metadata=nothing)
    JLD2_fmt = FileIO.DataFormat{:JLD2}
    data = Dict{String,Any}("result" => result)
    if !isnothing(metadata)
        for (k, v) in metadata
            # This should convert pretty much any key to a string
            data[String(Symbol(k))] = v
        end
    end
    FileIO.save(File{JLD2_fmt}(file), data)
end


"""Load a previously stored optimization.

```julia
result = load_optimization(file; verbose=false, kwargs...)
```

recovers a `result` previously stored by [`@optimize_or_load`](@ref) or
[`save_optimization`](@ref).

```julia
result, metadata = load_optimization(file; return_metadata=true, kwargs...)
```

also obtains a metadata dict, see [`@optimize_or_load`](@ref). This dict maps
string keys to values.

Calling `load_optimization` with `verbose=true` will `@info` the
metadata after loading the file
"""
function load_optimization(file; return_metadata=false, verbose=false, kwargs...)
    data = FileIO.load(file)
    result = data["result"]
    metadata = filter(kv -> (kv[1] != "result"), data)
    if verbose
        metadata_str = join(["  $key: $val" for (key, val) ∈ metadata], "\n")
        @info ("Loaded optimization result from $file\n" * metadata_str)
    end
    if return_metadata
        return result, metadata
    else
        return result
    end
end

end
