\name{pbi_date_table}
\alias{pbi_date_table}
\title{Add a standalone, richly described calendar dimension}
\description{Creates a contiguous calendar in R from explicit inclusive start and end bounds.}
\usage{
pbi_date_table(x, start, end, name = "Calendar")
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{start}{Inclusive first calendar date, as Date or an ISO YYYY-MM-DD string.}
  \item{end}{Inclusive last calendar date, as Date or an ISO YYYY-MM-DD string.}
  \item{name}{A unique model, measure, page, or example name, as described above.}
}
\details{
The table contains Date, Year, Quarter, Month, MonthName, YearMonth, Day, Weekday and WeekdayName. Weekday is Monday = 1. Month and weekday labels have sort-by metadata; Date is the model key and the table is marked as a time dimension. This helper deliberately adds no relationship. Relate the correct fact Date column explicitly, or use pbi_calendar() to infer bounds and add that relationship together. Timestamps should first be converted to Date in R at the desired timezone/grain. Date bounds must be valid and ordered; ranges greater than approximately 1000 years are rejected.
}
\value{The modified dashboard, with a new embedded calendar table.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_dashboard("Calendar", data.frame(day = as.Date("2025-01-01"), value = 1)) \%>\%
  pbi_date_table("2025-01-01", "2025-12-31") \%>\%
  pbi_relationship("data", "day", "Calendar", "Date") \%>\%
  pbi_page("Months", pbi_bar(pbi_field("MonthName", "Calendar"), "value"))
pbi_validate(d)$valid
}
