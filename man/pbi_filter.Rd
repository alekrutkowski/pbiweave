\name{pbi_filter}
\alias{pbi_filter}
\title{Apply a static include or exclude filter at a chosen scope}
\description{Constructs a reusable typed filter or attaches that filter to a report, page or visual.}
\usage{
pbi_filter(..., field = NULL, values = NULL, table = NULL,
                       exclude = FALSE, x = NULL, page = NULL)
}
\arguments{
  \item{...}{Positional field, values, table, exclude, optionally preceded by a dashboard/visual. Do not supply unknown named arguments.}
  \item{field}{A column name or pbi_field() reference. Slicers and categorical filters require an unaggregated column.}
  \item{values}{Nonempty atomic values, including NA for blank. Values are validated against the column type.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{exclude}{FALSE includes the supplied values; TRUE excludes them.}
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{page}{The page name. Defaults to the last page for binding, all pages for flow inspection, and report scope for filtering.}
}
\details{
The original constructor remains pbi_filter(field, values, table, exclude). Its result can be reused with pbi_filters(), pbi_where() or pbi_page(filters = list(...)). The added modifier form is dashboard_or_visual \%>\% pbi_filter(field, values, ...). For a dashboard, page = NULL means report scope; use a page name or index for page scope. Named x is also accepted. NA represents a native blank, and values are normalized against the model type before compilation. Invalid numeric, integer, date, timestamp and currency values are rejected. These are static query constraints, not row-level security and not R callbacks. Slicers combine with these constraints, so excluded source rows cannot be made available by a slicer. This API implements inclusion/exclusion, not arbitrary DAX, Top N or range expressions.
}
\value{With no dashboard/visual supplied, a reusable pbi_filter object. Otherwise, the modified pbi_dashboard or pbi_visual.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
keep_east <- pbi_filter("region", "East")
d <- pbi_dashboard("Scoped filters", pbi_demo_data()) \%>\%
  pbi_filters(keep_east) \%>\%
  pbi_page("Overview", pbi_bar("product", "revenue"),
           pbi_card("cost") \%>\% pbi_filter("product", "Atlas"))
pbi_validate(d)$valid
}
