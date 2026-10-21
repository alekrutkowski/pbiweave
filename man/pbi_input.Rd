\name{pbi_input}
\alias{pbi_input}
\title{Declare a Shiny-style input ID backed by a native slicer}
\description{Creates a native slicer with an explicit ID for subsequent interaction bindings.}
\usage{
pbi_input(id, field, table = NULL, label = NULL,
                      style = c("dropdown", "list", "between"), single = FALSE,
                      sync = NULL, alt = NULL)
}
\arguments{
  \item{id}{Stable visual ID unique within its page; for pbi_example(), example name or index from 1 to 17.}
  \item{field}{A column name or pbi_field() reference. Slicers and categorical filters require an unaggregated column.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{label}{Optional user-facing field or input label. It does not change the underlying column name.}
  \item{style}{Slicer presentation: dropdown, list, or between.}
  \item{single}{Whether the slicer permits only a single selection. No initial selection is specified.}
  \item{sync}{Optional synchronization-group name for slicers on different pages using the same column.}
  \item{alt}{Optional scalar accessibility description stored as native alternative text.}
}
\details{
This is a convenience wrapper around pbi_slicer(), not a Shiny input object. The ID is a compile-time visual identifier; there is no input$id value available to R while the exported report runs. Fields must be model columns. With pbi_screen()'s default disabled interactions, use pbi_bind() to name the outputs affected by this input. single controls selection behavior but does not supply an initial selected value.
}
\value{A pbi_visual object representing a slicer.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_dashboard("Input example", pbi_demo_data()) \%>\%
  pbi_screen("Explore", pbi_input("region", "region", label = "Region"),
             pbi_output("sales", pbi_card("revenue"))) \%>\%
  pbi_bind("region", "sales")
pbi_flow(d)
}
