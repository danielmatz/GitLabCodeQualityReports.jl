# GitLabCodeQualityReports.jl

This package reads and writes [GitLab Code Quality reports](https://docs.gitlab.com/ci/testing/code_quality/#code-quality-report-format). It also provides a function for scanning a log file for Julia warning messages and creating associated creating GitLab Code Quality report findings.

## Usage

Run your tests or script and redirect stderr to a file.

Then use the following Julia code to create a GitLab Code Quality report:

```julia
findings = warnings_findings("path/to/stderr.log")
write_report("path/to/report.json", findings)
```
You can then provide the `report.json` file as a [GitLab code quality artifact](https://docs.gitlab.com/ci/yaml/artifacts_reports/#artifactsreportscodequality).
