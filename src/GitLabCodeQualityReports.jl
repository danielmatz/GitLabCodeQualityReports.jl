module GitLabCodeQualityReports

using SHA: sha256
import JSON

export Finding, warnings_findings, write_report, read_report

function get_in(data, keys)
    for key in keys
        data = get(data, key, nothing)
        if isnothing(data)
            return nothing
        end
    end
    return data
end

# A report is a JSON file containing an array of findings:
# https://docs.gitlab.com/ci/testing/code_quality/#code-quality-report-format

Base.@kwdef struct Finding
    description::String
    check_name::String
    fingerprint::String
    location_path::String
    location_lines_begin::Int
    severity::String
end

function JSON.lower(f::Finding)
    Dict(
        "description" => f.description,
        "check_name" => f.check_name,
        "fingerprint" => f.fingerprint,
        "location" => Dict(
            "path" => f.location_path,
            "lines" => Dict(
                "begin" => f.location_lines_begin,
            ),
        ),
        "severity" => f.severity,
    )
end

"""
    warnings_findings(io_or_path)

Return a `Vector` of [`Finding`](@ref)s for all warning messages in
`io_or_path`.
"""
function warnings_findings(io_or_path)
    pattern = r"(?m)^\s*┌ Warning:\s*(?<description>.*?)\s*└ @ (?<module>.*?) (?<path>.*?):(?<line>\d+)"
    contents = read(io_or_path, String)
    map(eachmatch(pattern, contents)) do m
        Finding(
            description = m[:description],
            check_name = "warnings",
            fingerprint = bytes2hex(sha256(string(m[:description], m[:module], m[:path], m[:line]))),
            severity = "minor",
            location_path = m[:path],
            location_lines_begin = parse(Int, m[:line]),
        )
    end
end

"""
    write_report(io_or_path, findings::Vector{Finding}; indent = nothing)

Write `findings` to `io_or_path` as a GitLab Code Quality report in JSON format.

The `indent` keyword argument is an integer specifying the number of spaces to
use for each level of indentation. It may also be set to `nothing` to not apply
any indentation or whitespace. The default value is `nothing`.
"""
function write_report(io::IO, findings::Vector{Finding}; indent = nothing)
    JSON.print(io, findings, indent)
end

function write_report(output_path::AbstractString, findings::Vector{Finding}; indent = nothing)
    open(output_path, "w") do io
        write_report(io, findings; indent = indent)
    end
end

"""
    read_report(io_or_path)

Read a GitLab Code Quality report from `io_or_path` and return the vector of
findings.
"""
function read_report(io_or_path)
    raw_findings = if io_or_path isa IO
        JSON.parse(io_or_path)
    else
        JSON.parsefile(io_or_path)
    end

    if !(raw_findings isa Vector)
        error("invalid report, expected an array")
    end

    map(raw_findings) do raw_finding
        if !(raw_finding isa Dict)
            error("invalid report, expected an array of objects")
        end
        
        raw_location = get(raw_finding, "location") do
            error("invalid report, missing location field")
        end

        location_lines_begin = @something(
            get_in(raw_location, ("lines", "begin")),
            get_in(raw_location, ("positions", "begin", "line")),
            error("invalid report, missing location.lines.begin field"),
        )

        Finding(
            ;
            description = get(raw_finding, "description") do
                error("invalid report, missing description field")
            end,
            check_name = get(raw_finding, "check_name") do
                error("invalid report, missing check_name field")
            end,
            fingerprint = get(raw_finding, "fingerprint") do
                error("invalid report, missing fingerprint field")
            end,
            severity = get(raw_finding, "severity") do
                error("invalid report, missing severity field")
            end,
            location_path = get(raw_location, "path") do
                error("invalid report, missing location.path field")
            end,
            location_lines_begin = location_lines_begin,
        )
    end
end

end
