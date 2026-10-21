\name{pbi_data}
\alias{pbi_data}
\title{Embed another data frame in the model}
\description{Adds a copied, typed data snapshot under a unique model-table name.}
\usage{
pbi_data(x, name, data, types = NULL, formats = NULL, hidden = character(),
                     descriptions = NULL, sort_by = NULL, description = NULL, table_hidden = FALSE)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{name}{A unique model, measure, page, or example name, as described above.}
  \item{data}{A data.frame, data.table, or tibble. The package stores a copy rather than a live R data source.}
  \item{types}{Named per-column semantic type overrides; see pbi_column() for supported types.}
  \item{formats}{Named Power BI display-format strings for columns, such as c(revenue = "$#,0.00").}
  \item{hidden}{Original vector of column names to hide. A logical scalar is accepted as a table_hidden alias.}
  \item{descriptions}{Named explanatory descriptions for individual columns.}
  \item{sort_by}{Another column in the same table that provides a unique ordering for each displayed value.}
  \item{description}{Optional explanatory metadata stored with the model object.}
  \item{table_hidden}{Hide this table in the field list; data remain embedded and recoverable.}
}
\details{
Use one table for observation-level data and additional tables for dimensions. Adding tables does not join or relate them. Define a many-to-one relationship explicitly with pbi_relationship(). Data are embedded in the generated source; hidden tables are not a security boundary. Factors become text, Dates remain dates, and timestamps are serialized in UTC. Lists, complex vectors, and raw columns must be converted in R first. The canonical positional order is (x, name, data). The reversed 0.2.0 order (x, data, name) is accepted when argument types make it unambiguous. Prefer named arguments in shared code. types, formats, descriptions and sort_by are named column mappings. hidden is normally a vector of column names; table_hidden hides the table. A scalar logical hidden is also accepted as a table-hidden alias. Exact int64 and fixed-decimal strings are normalized before key validation.
}
\value{The modified pbi_dashboard object.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
sales <- pbi_demo_data()
regions <- data.frame(region = unique(sales$region), area = c("A", "B", "C"))
d <- pbi_dashboard("Regions", sales, table = "Sales") \%>\%
  pbi_data("Regions", regions) \%>\%
  pbi_relationship("Sales", "region", "Regions", "region")
length(d$tables)
}
