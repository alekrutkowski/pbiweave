\name{pbi_measure}
\alias{pbi_measure}
\title{Define an optional DAX measure}
\description{Adds either a simple aggregation measure or an explicit DAX expression.}
\usage{
pbi_measure(x, name, expression = NULL, table = NULL, column = NULL,
                        aggregate = "sum", format = NULL, description = NULL)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{name}{A unique model, measure, page, or example name, as described above.}
  \item{expression}{A DAX expression string. It is passed through for evaluation by Power BI; R does not validate the DAX grammar.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{column}{An existing column name, supplied as a string. A calendar column must contain R Date values.}
  \item{aggregate}{An explicit native aggregation, or NULL to choose according to the visual role.}
  \item{format}{A Power BI format string, such as "#,0", "$#,0.00", or "0.0\%". It is not an R sprintf() pattern.}
  \item{description}{Optional explanatory metadata stored with the model object.}
}
\details{
Supply exactly one of column and expression. Prefer R for transformations and model-fitting; use a measure only when a value genuinely depends on a viewer's current selection. Free-form DAX is passed through, not evaluated or parsed by R. Its validity must be checked in Power BI. A sum measure is a convenient reusable label, not a requirement for using a numeric column in a visual.
}
\value{The modified pbi_dashboard object.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_dashboard("Profit", pbi_demo_data(), table = "Sales") \%>\%
  pbi_measure("Revenue total", column = "revenue", format = "$#,0") \%>\%
  pbi_measure("Cost total", column = "cost", format = "$#,0") \%>\%
  pbi_measure("Profit total", "[Revenue total] - [Cost total]", format = "$#,0") \%>\%
  pbi_page("Summary", pbi_card(pbi_ref("Profit total")))
pbi_validate(d)$valid
}
