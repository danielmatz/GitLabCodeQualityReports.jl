using Test
using GitLabCodeQualityReports
import Aqua
import ExplicitImports
using Logging

@testset "GitLabCodeQualityReports" begin
    @testset "get_in" begin
        get_in = GitLabCodeQualityReports.get_in
        dict = Dict(
            "a" => Dict(
                "b" => 1,
            ),
        )

        @test get_in(dict, ("a", "b")) == 1
        @test isnothing(get_in(dict, ("c", "d")))
    end

    @testset "Read findings" begin
        # This is the example compliant report from the GitLab docs
        io = IOBuffer("""
[
  {
    "description": "'unused' is assigned a value but never used.",
    "check_name": "no-unused-vars",
    "fingerprint": "7815696ecbf1c96e6894b779456d330e",
    "severity": "minor",
    "location": {
      "path": "lib/index.js",
      "lines": {
        "begin": 42
      }
    }
  }
]
""")
        findings = read_report(io)
        @test findings isa Vector{Finding}
        @test length(findings) == 1
        @test findings[1] === Finding(
            description = "'unused' is assigned a value but never used.",
            check_name = "no-unused-vars",
            fingerprint = "7815696ecbf1c96e6894b779456d330e",
            severity = "minor",
            location_path = "lib/index.js",
            location_lines_begin = 42,
        )
    end

    @testset "Write findings" begin
        findings = [
            Finding(
                description = "a problem",
                check_name = "check-one",
                fingerprint = "abc123",
                severity = "major",
                location_path = "some/Package/src/Package.jl",
                location_lines_begin = 123,
            ),
            Finding(
                description = "another problem",
                check_name = "check-two",
                fingerprint = "def456",
                severity = "minor",
                location_path = "some/Package/src/Package.jl",
                location_lines_begin = 987,
            ),
        ]

        io = IOBuffer()
        write_report(io, findings)

        # I wanted to test the JSON itself, but the ordering of the fields was
        # unpredictable. I think we'd have to `JSON.lower` the `Finding` to an
        # `OrderedDict`, but that means we'd need the extra dependency on
        # DataStructures.

        # Go back to the beginning of the IOBuffer so we can read from it
        seek(io, 0)

        roundtrip_findings = read_report(io)

        @test findings == roundtrip_findings
    end

    @testset "warnings_findings" begin
        io = IOBuffer()
        with_logger(SimpleLogger(io)) do
            @warn "A warning"
        end
        seek(io, 0)
        findings = warnings_findings(io; root = dirname(@__DIR__))
        @test length(findings) == 1
        @test findings[1].location_path == "test/runtests.jl"
    end

    @testset "Aqua" begin
        Aqua.test_all(GitLabCodeQualityReports)
    end

    @testset "ExplicitImports" begin
        @test isnothing(ExplicitImports.check_no_implicit_imports(GitLabCodeQualityReports))
        @test isnothing(ExplicitImports.check_all_explicit_imports_via_owners(GitLabCodeQualityReports))
        @test isnothing(ExplicitImports.check_no_stale_explicit_imports(GitLabCodeQualityReports))
        @test isnothing(ExplicitImports.check_all_qualified_accesses_via_owners(GitLabCodeQualityReports))
    end
end
