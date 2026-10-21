\name{pbi_ref}
\alias{pbi_ref}
\title{Refer to an explicitly defined model measure}
\description{Creates a measure reference for use in a card, chart, table, or matrix.}
\usage{
pbi_ref(name, table = NULL, label = NULL, format = NULL)
}
\arguments{
  \item{name}{A unique model, measure, page, or example name, as described above.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{label}{Optional user-facing field or input label. It does not change the underlying column name.}
  \item{format}{A Power BI format string, such as "#,0", "$#,0.00", or "0.0\%". It is not an R sprintf() pattern.}
}
\details{
Use pbi_ref() rather than a bare name for measures created by pbi_measure() or pbi_ratio(). A measure is evaluated against the current Power BI filter context. The name must exist when the report is validated or compiled. An explicit table can disambiguate a reference, although this implementation requires measure names to be globally unique.
}
\value{A pbi_field reference with kind = "measure".}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_dashboard("Revenue", pbi_demo_data()) \%>\%
  pbi_measure("Total revenue", column = "revenue") \%>\%
  pbi_page("Summary", pbi_card(pbi_ref("Total revenue")))
pbi_validate(d)$valid
}
