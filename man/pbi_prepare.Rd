\name{pbi_prepare}
\alias{pbi_prepare}
\title{Run a build-time R transformation on a private copy}
\description{Calls an ordinary R function once on a copy of a data frame and returns its resulting data.table.}
\usage{
pbi_prepare(data, transform = identity, ...)
}
\arguments{
  \item{data}{A data.frame, data.table, or tibble. The package stores a copy rather than a live R data source.}
  \item{transform}{An ordinary R function taking a private data.table copy and returning a data frame. It is called immediately, once.}
  \item{...}{Additional visual specifications, transformation arguments, or print arguments, depending on the function.}
}
\details{
This is deliberately not a reactive expression or callback registration. The supplied function runs immediately. It may clean values, join data, calculate features, or preaggregate, but must return a data frame. Copying prevents data.table := inside the function from modifying the caller's original object. Changing a slicer in the exported report will never rerun transform.
}
\value{A copied data.table containing the result.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
sales <- pbi_demo_data()
prepared <- pbi_prepare(sales, function(d) {
  d[, profit_per_unit := (revenue - cost) / units]
  d
})
stopifnot(!"profit_per_unit" \%in\% names(sales))
head(prepared)
}
