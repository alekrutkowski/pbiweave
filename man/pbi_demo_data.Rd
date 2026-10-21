\name{pbi_demo_data}
\alias{pbi_demo_data}
\title{Create deterministic demonstration data without changing the RNG}
\description{Returns a small synthetic sales data.table used by the examples and help pages.}
\usage{
pbi_demo_data()
}
\details{
The original 0.1.0 fixture is intentionally unchanged: 288 synthetic observations cover January 2025 through December 2026, three regions (Central, East, West) and four products (Atlas, Beacon, Cedar, Delta). It contains exactly date, region, product, units, revenue and cost. No random-number generator is used. Compute additional profit, margin or row IDs in R. Unfiltered totals are revenue 929888, cost 576336.64 and units 18368. This is illustrative data, not observed company performance.
}
\value{A fresh six-column, 288-row data.table.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_demo_data()
head(d)
d[, .(revenue = sum(revenue), profit = sum(revenue - cost), units = sum(units))]
}
