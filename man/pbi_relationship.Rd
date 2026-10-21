\name{pbi_relationship}
\alias{pbi_relationship}
\title{Connect a fact table to a unique dimension key}
\description{Creates an active or inactive many-to-one relationship and checks key integrity.}
\usage{
pbi_relationship(x, from = NULL, from_column, to = NULL, to_column,
                             active = TRUE, bidirectional = FALSE,
                             from_table = NULL, to_table = NULL, direction = NULL,
                             unmatched = c("warn", "error", "allow"))
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{from}{Many-side fact table for pbi_relationship(); lower Date bound for pbi_calendar().}
  \item{from_column}{The fact-table foreign-key column.}
  \item{to}{One-side dimension table for pbi_relationship(); upper Date bound for pbi_calendar().}
  \item{to_column}{The unique, nonblank dimension key.}
  \item{active}{Whether the relationship participates in the default filter propagation.}
  \item{bidirectional}{Logical original relationship flag. FALSE propagates dimension filters to facts; TRUE allows both directions.}
  \item{from_table}{Named alias for from.}
  \item{to_table}{Named alias for to.}
  \item{direction}{For relationships: single (dimension to fact) or both. For visual sorting: ascending or descending.}
  \item{unmatched}{Policy for missing or unmatched fact keys: "warn" (original default), "error" or "allow".}
}
\details{
from/from_column name the many-side fact key and to/to_column name the one-side dimension key. With single-direction filtering, dimension selections filter fact rows, not the reverse. from_table and to_table are named aliases; direction = "single" or "both" aliases bidirectional. Dimension keys must be unique and nonmissing after typed normalization. Text comparisons fold case and remove trailing ASCII spaces but preserve leading spaces. Other locale-specific equivalences require native review. unmatched defaults to "warn" for original compatibility; choose "error" for strict coverage or "allow" for intentional unknown facts. Active undirected cycles and parallel routes are conservatively rejected by pbi_validate(), even though some more complex native models could resolve them. Make alternative relationships inactive rather than suppressing the diagnostics.
}
\value{The modified pbi_dashboard object.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
sales <- pbi_demo_data()
regions <- data.frame(region = unique(sales$region),
                      manager = c("Alex", "Sam", "Robin"))
d <- pbi_dashboard("Team sales", sales, table = "Sales") \%>\%
  pbi_data(regions, "Regions") \%>\%
  pbi_relationship("Sales", "region", "Regions", "region") \%>\%
  pbi_page("Teams", pbi_bar(pbi_field("manager", "Regions"), "revenue"))
pbi_validate(d)$valid
}
