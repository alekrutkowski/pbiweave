\name{pbi_inspect}
\alias{pbi_inspect}
\title{Inspect snapshot sizes and report complexity}
\description{Summarizes data sizes, page geometry, model complexity and preflight diagnostics.}
\usage{
pbi_inspect(x)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
}
\details{
Use this before choosing a data grain or compiling a larger report. tables contains rows, columns and approximate in-memory bytes for each copied data.table; it is not a forecast of VertiPaq or encoded JSON size. pages contains visual counts, layout and page dimensions. Measures and relationships are counts, and diagnostics is the structured pbi_validate() result. Large snapshots and pages with many visuals can produce actionable warnings without invalidating the specification. This does not measure native refresh or interaction latency.
}
\value{A named list: tables, pages, measures, relationships and diagnostics.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
report <- pbi_example("showcase")
info <- pbi_inspect(report)
info$tables
info$pages
info$diagnostics
}
