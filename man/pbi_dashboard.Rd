\name{pbi_dashboard}
\alias{pbi_dashboard}
\title{Start a declarative report specification}
\description{Creates an in-memory report specification and optionally snapshots a first data frame. Nothing is published and no Power BI process is started.}
\usage{
pbi_dashboard(title, data = NULL, table = "data", theme = "linen", locale = "en-US")
}
\arguments{
  \item{title}{Static human-readable report or visual title. NULL chooses an informative default visual title.}
  \item{data}{A data.frame, data.table, or tibble. The package stores a copy rather than a live R data source.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{theme}{A named theme preset or an object returned by pbi_theme().}
  \item{locale}{Model culture such as "en-US". Typed embedded values are parsed using an explicit en-US source culture.}
}
\details{
Build a report by piping this object through data, measure, and page constructors, then call pbi_compile(). Incoming data.tables are copied, so later by-reference edits to the original do not alter the snapshot. A specification is not a running application. R calculations finish before compilation; native Power BI filtering starts after opening and refreshing the generated project. A single table defaults to the name "data", as in 0.1.0. A named list of data frames creates several independent tables; add relationships explicitly. locale controls model culture, not the typed source-data parsing culture.
}
\value{A pbi_dashboard object. Most model and page helpers return a modified object of this class.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_dashboard("Revenue", pbi_demo_data(), table = "Sales") \%>\%
  pbi_page("Overview", pbi_card("revenue"), pbi_bar("region", "cost"))
pbi_validate(d)$valid
}
