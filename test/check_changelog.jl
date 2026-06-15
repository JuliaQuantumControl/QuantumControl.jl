# Validate (and optionally fix) the reference-style links in CHANGELOG.md.
#
# The default check mode is purely textual: it makes no network calls and
# inspects no git state. It verifies that every reference used in the prose
# (e.g. `[#97]`, `[v0.8.0]`) has a matching link definition, that no definition
# is unused or duplicated, that each version link points to its own release tag,
# and that the `[Unreleased]` link compares against the latest version heading
# in the file.
#
# The `--fix` mode (only) may make network calls: any missing `[#N]`
# issue/pull-request link target is added, consulting the GitHub API to decide
# whether `#N` is an issue or a pull request and to confirm it exists:
#
#   * If the API confirms `#N` exists, the correct `issues/` or `pull/` URL is
#     added.
#   * If the API definitively reports that `#N` does not exist (HTTP 404), it is
#     treated as a typo: no link is added and the reference is reported.
#   * If the API cannot be reached (offline, rate-limited), verification is
#     skipped and an `issues/` URL is added (GitHub redirects `issues/N` ↔
#     `pull/N`, so it still resolves).
#
# Reading issues/PRs of a public repository requires no special privileges, so
# this works for any contributor (including from a fork): it uses the `gh` CLI
# when available, and otherwise the unauthenticated public API via `curl`.
#
# The repository is derived from the existing link definitions, falling back to
# the `origin` git remote, so the script is not tied to a specific repository.
#
# Run with `julia test/check_changelog.jl [--fix] [path]` (no project
# dependencies), or via `make check-changelog` / `make changelog`. Exits
# non-zero on any remaining problem.

const FIX = "--fix" in ARGS
const positional = filter(a -> a != "--fix", ARGS)
const CHANGELOG =
    isempty(positional) ? joinpath(@__DIR__, "..", "CHANGELOG.md") : positional[1]

const DEFINITION = r"^\[([^\]]+)\]:[ \t]*(\S+)[ \t]*$"
const INLINE_LABEL = r"\[([^\[\]]+)\]\("   # `[text](url)` — not a reference
const REFERENCE = r"\[([^\[\]]+)\]"        # innermost `[label]`
const VERSION_HEADING = r"^##[ \t]+\[(v[0-9]+\.[0-9]+\.[0-9]+)\]"
const ISSUE_LABEL = r"^#([0-9]+)$"

# Parse the file into its link definitions (label => url), the order in which
# labels first appear, duplicated labels, the references used in the prose, and
# the latest version (topmost `## [vX.Y.Z]` heading).
function parse_changelog(lines)
    defs = Dict{String,String}()
    order = String[]
    dups = String[]
    body = IOBuffer()
    for line in lines
        m = match(DEFINITION, line)
        if m === nothing
            println(body, line)
        else
            label = m.captures[1]
            haskey(defs, label) ? push!(dups, label) : push!(order, label)
            defs[label] = m.captures[2]
        end
    end
    prose = String(take!(body))
    inline = Set(m.captures[1] for m in eachmatch(INLINE_LABEL, prose))
    used = Set(
        m.captures[1] for m in eachmatch(REFERENCE, prose) if !(m.captures[1] in inline)
    )
    latest = nothing
    for line in lines
        m = match(VERSION_HEADING, line)
        if m !== nothing
            latest = m.captures[1]
            break
        end
    end
    return (; defs, order, dups, used, latest)
end

# Run `cmd`, capturing (exitcode, stdout, stderr). exitcode is `nothing` if the
# command could not be launched at all (e.g. the tool is not installed).
function run_capture(cmd)
    out = Pipe()
    err = Pipe()
    proc = try
        run(pipeline(ignorestatus(cmd); stdout = out, stderr = err); wait = false)
    catch
        return (nothing, "", "")
    end
    close(out.in)
    close(err.in)
    sout = @async read(out, String)
    serr = @async read(err, String)
    wait(proc)
    return (proc.exitcode, fetch(sout), fetch(serr))
end

# The `https://github.com/owner/repo` base, derived from existing definitions,
# falling back to the `origin` git remote.
function github_base(defs)
    for url in values(defs)
        m = match(r"^(https://github\.com/[^/]+/[^/]+)", url)
        m === nothing || return m.captures[1]
    end
    code, out, _ = run_capture(`git -C $(dirname(CHANGELOG)) remote get-url origin`)
    if code == 0
        m = match(r"github\.com[:/](.+?)(?:\.git)?\s*$", out)
        m === nothing || return "https://github.com/" * strip(m.captures[1])
    end
    error(
        "could not determine the GitHub repository (no link definitions, no github.com `origin`)"
    )
end

# Classify `#n` via the `gh` CLI. Returns :pull, :issue, :missing, :network, or
# :unavailable (gh not installed or not authenticated → try another method).
function classify_gh(slug, n)
    jq = "if has(\"pull_request\") then \"pull\" else \"issue\" end"
    code, out, err = run_capture(`gh api repos/$slug/issues/$n --jq $jq`)
    code === nothing && return :unavailable
    if code == 0
        kind = strip(out)
        kind == "pull" && return :pull
        kind == "issue" && return :issue
        return :network
    end
    if occursin("HTTP 404", err) || occursin("Not Found", err)
        return :missing
    elseif occursin("HTTP 401", err) || occursin(r"auth"i, err)
        return :unavailable
    end
    return :network
end

# Classify `#n` via the unauthenticated public REST API using `curl`.
function classify_curl(slug, n)
    url = "https://api.github.com/repos/$slug/issues/$n"
    code, out, _ = run_capture(
        `curl -sS -H "Accept: application/vnd.github+json" -w $("\n%{http_code}") $url`,
    )
    code === nothing && return :unavailable
    code == 0 || return :network
    nl = findlast('\n', out)
    status = nl === nothing ? "" : strip(out[nextind(out, nl):end])
    payload = nl === nothing ? out : out[1:prevind(out, nl)]
    status == "200" && return occursin("\"pull_request\"", payload) ? :pull : :issue
    status == "404" && return :missing
    return :network
end

# Determine whether `#n` is an issue or pull request (or is missing / unknown).
function classify_issue(slug, n)
    result = classify_gh(slug, n)
    result === :unavailable || return result
    result = classify_curl(slug, n)
    result === :unavailable ? :network : result
end

# Append missing `[#N]` link targets. Returns (modified::Bool, problems::Vector).
function fix_missing!(lines)
    parsed = parse_changelog(lines)
    missing = sort!([
        parse(Int, match(ISSUE_LABEL, ref).captures[1]) for
        ref in parsed.used if occursin(ISSUE_LABEL, ref) && !haskey(parsed.defs, ref)
    ])
    isempty(missing) && return (false, String[])

    base = github_base(parsed.defs)
    slug = replace(base, "https://github.com/" => "")
    nonissue = Tuple{String,String}[]
    issues = Dict{Int,String}()
    for label in parsed.order
        m = match(ISSUE_LABEL, label)
        if m === nothing
            push!(nonissue, (label, parsed.defs[label]))
        else
            issues[parse(Int, m.captures[1])] = parsed.defs[label]
        end
    end

    problems = String[]
    added = 0
    for n in missing
        kind = classify_issue(slug, n)
        if kind === :missing
            push!(
                problems,
                "reference [#$n] does not exist on GitHub (typo?); no link added",
            )
            continue
        end
        issues[n] = kind === :pull ? "$base/pull/$n" : "$base/issues/$n"
        note = kind === :network ? " (could not verify via GitHub; assuming issue)" : ""
        println("Added link target [#$n]: $(issues[n])$note")
        added += 1
    end
    added == 0 && return (false, problems)

    # Rebuild: prose (trailing blanks trimmed), one blank separator, then all
    # definitions — non-issue defs in original order, then `#N` defs sorted.
    prose_lines = [line for line in lines if !occursin(DEFINITION, line)]
    while !isempty(prose_lines) && isempty(strip(prose_lines[end]))
        pop!(prose_lines)
    end
    out = copy(prose_lines)
    push!(out, "")
    for (label, url) in nonissue
        push!(out, "[$label]: $url")
    end
    for n in sort(collect(keys(issues)))
        push!(out, "[#$n]: $(issues[n])")
    end
    write(CHANGELOG, join(out, "\n") * "\n")
    return (true, problems)
end

function validate(lines)
    parsed = parse_changelog(lines)
    (; defs, dups, used, latest) = parsed
    errors = String[]

    for u in sort(collect(used))
        haskey(defs, u) ||
            push!(errors, "reference [$u] is used but has no link definition")
    end
    for d in sort(collect(keys(defs)))
        # `[Unreleased]` is structural and may be defined without a corresponding
        # heading on a `release-*` branch, where the heading is temporarily removed.
        d == "Unreleased" && continue
        d in used || push!(errors, "link definition [$d] is never used")
    end
    for d in sort(unique(dups))
        push!(errors, "link definition [$d] is duplicated")
    end

    # Each version link should point to its own release tag.
    for (label, url) in defs
        startswith(label, "v") || continue
        endswith(url, "/releases/tag/$label") ||
            push!(errors, "[$label] should point to `…/releases/tag/$label`, not `$url`")
    end

    # The `[Unreleased]` link should compare the latest version against HEAD.
    if !haskey(defs, "Unreleased")
        push!(errors, "missing the [Unreleased] link definition")
    elseif latest === nothing
        push!(
            errors,
            "no `## [vX.Y.Z]` version heading found to anchor the [Unreleased] link",
        )
    elseif !endswith(defs["Unreleased"], "/compare/$latest..HEAD")
        push!(
            errors,
            "[Unreleased] should compare against the latest version `$latest` " *
            "(expected `…/compare/$latest..HEAD`), not `$(defs["Unreleased"])`",
        )
    end

    return errors
end

function main()
    isfile(CHANGELOG) || (@error "Not found: $CHANGELOG"; exit(1))
    lines = readlines(CHANGELOG)

    if FIX
        _, problems = fix_missing!(lines)
        for p in problems
            @warn p
        end
        lines = readlines(CHANGELOG)
    end

    errors = validate(lines)
    if isempty(errors)
        n = count(line -> occursin(DEFINITION, line), lines)
        println("CHANGELOG.md: OK ($n link definitions)")
        exit(0)
    else
        @error "CHANGELOG.md has $(length(errors)) problem(s):\n  " * join(errors, "\n  ")
        exit(1)
    end
end

main()
