\name{pipe}
\alias{\%>\%}
\title{Pipe a specification into the next construction step}
\description{Reexports the magrittr forward pipe. This is ordinary R execution, not a runtime reactive operator.}
\usage{lhs \%>\% rhs}
\arguments{\item{lhs}{The value passed into the next call.}\item{rhs}{The next function call, using a dot placeholder where needed.}}
\details{Preparation and constructor calls execute when the R script runs. Report-viewer selections are handled later by Power BI, not by this pipe or an R server.}
\value{The result of the right-hand expression.}
\examples{
x <- pbi_dashboard("Piped", pbi_demo_data()) \%>\%
  pbi_page("Summary", pbi_card("revenue"))
pbi_validate(x)$valid
}
