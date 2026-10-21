\name{pbi_slicer}
\alias{pbi_slicer}
\title{Add a viewer-operated filter}
\description{Creates a native dropdown, list, or between-range slicer bound to one model column.}
\usage{
pbi_slicer(field, table = NULL, title = NULL, alt = NULL,
                       style = c("dropdown", "list", "between"), single_select = FALSE, sync = NULL,
                     id = NULL, single = NULL)
}
\arguments{
  \item{field}{A column name or pbi_field() reference. Slicers and categorical filters require an unaggregated column.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{title}{Static human-readable report or visual title. NULL chooses an informative default visual title.}
  \item{alt}{Optional scalar accessibility description stored as native alternative text.}
  \item{style}{Slicer presentation: dropdown, list, or between.}
  \item{single_select}{Restrict a slicer to a single selected value. Does not set an initial selection.}
  \item{sync}{Optional synchronization-group name for slicers on different pages using the same column.}
  \item{id}{Stable visual ID unique within its page; for pbi_example(), example name or index from 1 to 17.}
  \item{single}{Whether the slicer permits only a single selection. No initial selection is specified.}
}
\details{
The choices come from the embedded column rather than an R callback. between requires a numeric or date column. single affects selection behavior but does not specify an initial selected value. Giving slicers on multiple pages the same sync name synchronizes their selection state; they must refer to the same column. On explicit pbi_screen() pages use bindings to connect the slicer to outputs.
}
\value{A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
v <- pbi_slicer("region", title = "Choose regions", style = "list", sync = "region")
d <- pbi_dashboard("Visual example", pbi_demo_data()) \%>\%
  pbi_page("Example", v)
pbi_validate(d)$valid
}
