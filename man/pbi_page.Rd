\name{pbi_page}
\alias{pbi_page}
\title{Add a page of native visuals}
\description{Adds a named report page containing visual specifications and a layout.}
\usage{
pbi_page(x, name, ..., layout = pbi_layout(), size = "wide", filters = list(),
                     interactions = c("default", "filter", "none"), hidden = FALSE, background = NULL,
                     width = NULL, height = NULL)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{name}{A unique model, measure, page, or example name, as described above.}
  \item{...}{Additional visual specifications, transformation arguments, or print arguments, depending on the function.}
  \item{layout}{A pbi_layout() specification. The default is a two-column grid, except for pbi_screen().}
  \item{size}{Page-size preset or numeric c(width, height). For text, an alias for font_size; for scatter, the bubble field.}
  \item{filters}{A pbi_filter() object or list of such objects applied to this page.}
  \item{interactions}{"default" or "native" uses native rules; "filter" forces filtering; "none" disables same-page cross-visual selections.}
  \item{hidden}{Column names to hide in pbi_data(); a scalar logical for column/page visibility elsewhere. Hiding is never security.}
  \item{background}{Optional scalar #RRGGBB page background; on pbi_page(), overrides the report theme.}
  \item{width}{Optional page width or required visual width in report-canvas units.}
  \item{height}{Optional page height or required visual height in report-canvas units.}
}
\details{
Supply complete native visuals directly or in a list. Page names and visual IDs must be unique within their respective scopes. Original presets wide, standard, portrait and a4 are supported, as is a numeric width/height size vector. Named width and height override the preset; "custom" uses wide defaults for unspecified dimensions. Filters supplied here are page-scoped pbi_filter() specifications. Hidden pages are presentation metadata, not security. At least one page must be visible. The default interactions = "default" uses native selection rules; "native" is an alias, "filter" forces filtering and "none" disables cross-visual selections. Report/page filters and model relationships are separate from these interaction settings.
}
\value{The modified pbi_dashboard object.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_dashboard("Sales", pbi_demo_data()) \%>\%
  pbi_page("Summary", pbi_card("revenue"), pbi_bar("product", "cost")) \%>\%
  pbi_page("Detail", pbi_table(c("date", "region", "revenue")))
length(d$pages)
}
