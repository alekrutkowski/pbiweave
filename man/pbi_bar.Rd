\name{pbi_bar}
\alias{pbi_bar}
\title{Compare categories with a bar or column chart}
\description{Plots an aggregated value by category, with optional series, stacking, or percent stacking.}
\usage{
pbi_bar(x, y, legend = NULL, table = NULL, title = NULL, alt = NULL,
                    aggregate = "sum", horizontal = FALSE, stacked = FALSE,
                    percent = FALSE, labels = FALSE, tooltip = NULL,
                     id = NULL, series = NULL)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{y}{The value field or list of value fields. Use pbi_aggregate() or pbi_ref() when the default summary is not appropriate.}
  \item{legend}{Optional unaggregated categorical series field; series is its named alias.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{title}{Static human-readable report or visual title. NULL chooses an informative default visual title.}
  \item{alt}{Optional scalar accessibility description stored as native alternative text.}
  \item{aggregate}{An explicit native aggregation, or NULL to choose according to the visual role.}
  \item{horizontal}{TRUE uses horizontal bars; FALSE uses vertical columns.}
  \item{stacked}{Whether additive series are stacked.}
  \item{percent}{Whether to use 100\% stacking; implies stacked = TRUE.}
  \item{labels}{Whether native data labels are displayed.}
  \item{tooltip}{Optional field references for the native tooltip role.}
  \item{id}{Stable visual ID unique within its page; for pbi_example(), example name or index from 1 to 17.}
  \item{series}{Optional grouping field used as a legend/series split.}
}
\details{
Horizontal bars are useful for long labels. Set horizontal = FALSE for columns. percent selects 100\% stacking. A numeric value defaults to a sum; use pbi_aggregate() for an average or pbi_ref() for a measure. A chart selection can filter other visuals when interactions permit it. Original horizontal = FALSE remains the default. legend and series are equivalent named spellings. A categorical legend cannot be combined with multiple numeric value fields. alt supplies the accessible description.
}
\value{A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
v <- pbi_bar("region", "revenue", series = "product", stacked = TRUE, title = "Revenue mix")
d <- pbi_dashboard("Visual example", pbi_demo_data()) \%>\%
  pbi_page("Example", v)
pbi_validate(d)$valid
}
