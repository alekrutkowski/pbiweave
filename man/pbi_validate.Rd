\name{pbi_validate}
\alias{pbi_validate}
\title{Preflight a report specification before writing files}
\description{Checks fields, measures, types, filters, layouts, sort metadata, and slicer synchronization.}
\usage{
pbi_validate(x, strict = FALSE, stop_on_error = FALSE)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{strict}{With stop_on_error = TRUE, treat warning diagnostics as failures too.}
  \item{stop_on_error}{Stop when errors are found instead of returning an invalid diagnostics result.}
}
\details{
Returns structured diagnostics by default without stopping. Each row has severity, code, location and message. stop_on_error = TRUE raises on errors; strict = TRUE also promotes warnings for that stop decision. Compatibility accessors $valid, $errors and $warnings do not replace the underlying data.table columns. Checks include typed filters, relationship keys and conservative path ambiguity, sort dependencies, grouping/value roles, projected sort expressions, synchronized slicer fields, layout bounds and complexity. DAX grammar, native TMDL deserialization, Power Query execution, Desktop rendering and publication permissions remain native acceptance steps.
}
\value{A pbi_diagnostics data.table with severity, code, location and message. $valid is TRUE when no error rows exist, independently of warnings.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_example("showcase")
check <- pbi_validate(d)
check
check$valid
pbi_inspect(d)$tables
}
