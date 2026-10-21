\name{pbi_ratio}
\alias{pbi_ratio}
\title{Combine R-precomputed sufficient statistics correctly}
\description{Defines a ratio of two native sums without requiring handwritten DAX.}
\usage{
pbi_ratio(x, name, numerator, denominator, table = NULL,
                      format = "0.0\%", description = NULL)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{name}{A unique model, measure, page, or example name, as described above.}
  \item{numerator}{An additive numeric column containing R-precomputed numerator totals.}
  \item{denominator}{An additive numeric column containing the matching eligible counts or denominator totals.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{format}{A Power BI format string, such as "#,0", "$#,0.00", or "0.0\%". It is not an R sprintf() pattern.}
  \item{description}{Optional explanatory metadata stored with the model object.}
}
\details{
The generated measure is DIVIDE(SUM(numerator), SUM(denominator)). Prepare both additive columns in R at the chosen data grain. For a rate, store event counts and eligible counts. For a mean, store a value sum and its nonmissing observation count. This preserves weighted results under arbitrary supported filtering; averaging cell means does not. A zero denominator produces a blank, not an invented zero. A ratio is still evaluated by Power BI at viewing time.
}
\value{The modified pbi_dashboard object with an additional measure.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
cells <- data.frame(group = c("small", "large"),
                    value_sum = c(0, 1000), observed = c(2L, 100L))
d <- pbi_dashboard("Weighted mean", cells) \%>\%
  pbi_ratio("Mean value", "value_sum", "observed", format = "0.00") \%>\%
  pbi_page("Summary", pbi_card(pbi_ref("Mean value")))
# The unfiltered result should be 1000 / 102, not mean(c(0, 10)).
pbi_validate(d)$valid
}
