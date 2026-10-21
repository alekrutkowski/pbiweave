\name{pbi_text}
\alias{pbi_text}
\title{Add static explanatory text}
\description{Creates a native text box with a fixed string, size, and weight.}
\usage{
pbi_text(text, font_size = 18, color = NULL, title = NULL, alt = NULL,
                     id = NULL, size = NULL, bold = FALSE)
}
\arguments{
  \item{text}{Static text to embed. Newlines create paragraphs.}
  \item{font_size}{Base font size in points, or the static text size for pbi_text().}
  \item{color}{Optional scalar #RRGGBB static-text color.}
  \item{title}{Static human-readable report or visual title. NULL chooses an informative default visual title.}
  \item{alt}{Optional scalar accessibility description stored as native alternative text.}
  \item{id}{Stable visual ID unique within its page; for pbi_example(), example name or index from 1 to 17.}
  \item{size}{Page-size preset or numeric c(width, height). For text, an alias for font_size; for scatter, the bubble field.}
  \item{bold}{Whether static text is bold.}
}
\details{
Text is evaluated and embedded at build time. It does not become renderText() and cannot be a data-filtered output. Compute explanatory prose in R before compiling or use a numeric card for a selection-dependent value. Newline characters create separate paragraphs.
}
\value{A pbi_visual object. Add it to a page, optionally modifying it with layout, filter, or sort helpers.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_dashboard("Explanation", pbi_demo_data()) \%>\%
  pbi_page("Notes", pbi_text("Select a region. Data are synthetic.",
                           font_size = 15, bold = TRUE, alt = "Report instructions"))
pbi_validate(d)$valid
}
