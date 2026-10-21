\name{pbi_calendar}
\alias{pbi_calendar}
\title{Build a contiguous calendar in R}
\description{Creates a daily calendar table and relates it to a Date column in the fact table.}
\usage{
pbi_calendar(x, column, table = NULL, name = "Calendar", from = NULL, to = NULL)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{column}{An existing column name, supplied as a string. A calendar column must contain R Date values.}
  \item{table}{Model table name. NULL normally selects the first table; qualify dimension fields explicitly.}
  \item{name}{A unique model, measure, page, or example name, as described above.}
  \item{from}{Many-side fact table for pbi_relationship(); lower Date bound for pbi_calendar().}
  \item{to}{One-side dimension table for pbi_relationship(); upper Date bound for pbi_calendar().}
}
\details{
The source column must be a Date, not a timestamp. Bounds default to the nonmissing source range. This adds the same rich calendar as pbi_date_table(), including Date, Year, Quarter, Month, MonthName, YearMonth, Day, Weekday (Monday = 1) and WeekdayName, marks Date as the key and adds a many-to-one relationship. Both displayed month and weekday names have sort-by mappings. Bounds excluding fact dates produce unmatched-key diagnostics. For a standalone calendar or deliberate inactive relationship, use pbi_date_table() and pbi_relationship() separately.
}
\value{The modified pbi_dashboard object, with a calendar table and relationship.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_dashboard("Calendar", pbi_demo_data(), table = "Sales") \%>\%
  pbi_calendar("date", table = "Sales") \%>\%
  pbi_page("Monthly", pbi_slicer("Year", table = "Calendar"),
           pbi_bar(pbi_field("MonthName", "Calendar"), "revenue"))
pbi_validate(d)$valid
}
