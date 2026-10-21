\name{pbi_card}
\alias{pbi_card}
\title{Present one or several selection-dependent values}
\description{Creates the native modern cardVisual, supporting one or several value fields.}
\usage{
pbi_card(value, table = NULL, title = NULL, alt = NULL, aggregate = "sum",
                     id = NULL)
}
\arguments{
  \item{value}{The value field, aggregate reference, or measure reference to display.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{title}{Static human-readable report or visual title. NULL chooses an informative default visual title.}
  \item{alt}{Optional scalar accessibility description stored as native alternative text.}
  \item{aggregate}{An explicit native aggregation, or NULL to choose according to the visual role.}
  \item{id}{Stable visual ID unique within its page; for pbi_example(), example name or index from 1 to 17.}
}
\details{
Numeric columns default to sums; explicit aggregate references and measures override that. Pass a list of fields for several cards inside one visual, or create individual pbi_card() visuals for separate layout control. Titles are static; numbers are queried under current filters. Empty or zero-denominator measures can display blank. Cards are not selectable binding sources. alt supplies an accessible description.
}
\value{A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_dashboard("Summary", pbi_demo_data()) \%>\%
  pbi_page("KPIs", pbi_card(c("revenue", "cost"), title = "Revenue and cost"))
pbi_validate(d)$valid
}
