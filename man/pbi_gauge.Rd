\name{pbi_gauge}
\alias{pbi_gauge}
\title{Compare a value with a target and bounded scale}
\description{Creates a native gauge with optional target, minimum, and maximum.}
\usage{
pbi_gauge(value, target = NULL, min = NULL, max = NULL,
                      table = NULL, title = NULL, alt = NULL, aggregate = "sum",
                     id = NULL, minimum = NULL, maximum = NULL)
}
\arguments{
  \item{value}{The value field, aggregate reference, or measure reference to display.}
  \item{target}{A fixed numeric target or a field/measure reference.}
  \item{min}{Gauge minimum: a fixed finite number or a model field/measure reference.}
  \item{max}{Gauge maximum: a fixed finite number or a model field/measure reference.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{title}{Static human-readable report or visual title. NULL chooses an informative default visual title.}
  \item{alt}{Optional scalar accessibility description stored as native alternative text.}
  \item{aggregate}{An explicit native aggregation, or NULL to choose according to the visual role.}
  \item{id}{Stable visual ID unique within its page; for pbi_example(), example name or index from 1 to 17.}
  \item{minimum}{A fixed numeric minimum or a field/measure reference.}
  \item{maximum}{A fixed numeric maximum or a field/measure reference.}
}
\details{
Bounds can be numeric constants or model field/measure references. Constants are fixed at compilation; fields are evaluated in the current selection. Use a coherent scale and a clearly documented target. Gauges are not selection sources for pbi_bind().
}
\value{A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
v <- pbi_gauge("revenue", target = 900000, minimum = 0, maximum = 1800000, title = "Revenue target")
d <- pbi_dashboard("Visual example", pbi_demo_data()) \%>\%
  pbi_page("Example", v)
pbi_validate(d)$valid
}
