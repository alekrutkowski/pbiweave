\name{pbi_table}
\alias{pbi_table}
\title{Show unaggregated detail fields or explicit summaries}
\description{Creates a native table visual from a vector or list of fields.}
\usage{
pbi_table(columns = NULL, table = NULL, title = NULL, alt = NULL,
                     id = NULL)
}
\arguments{
  \item{columns}{NULL selects visible columns; otherwise a character vector or list of column and measure references.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{title}{Static human-readable report or visual title. NULL chooses an informative default visual title.}
  \item{alt}{Optional scalar accessibility description stored as native alternative text.}
  \item{id}{Stable visual ID unique within its page; for pbi_example(), example name or index from 1 to 17.}
}
\details{
Plain column names are unaggregated in this visual. Explicit pbi_aggregate() and pbi_ref() values remain aggregated. Power BI can group identical combinations of unaggregated displayed fields, so include a unique row ID when every source record must be distinguishable. A visual is not a guaranteed full-data export; native query reduction can limit displayed rows. columns = NULL automatically selects the visible columns of the chosen table. Hidden columns may still be selected explicitly; hiding is not data security.
}
\value{A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_dashboard("Evidence", pbi_demo_data()) \%>\%
  pbi_page("Details", pbi_table(title = "Visible source columns"))
pbi_validate(d)$valid
}
