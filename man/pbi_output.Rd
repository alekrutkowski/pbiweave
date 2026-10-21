\name{pbi_output}
\alias{pbi_output}
\title{Give a native visual a stable output ID}
\description{Assigns an ID to an existing visual specification.}
\usage{
pbi_output(id, visual)
}
\arguments{
  \item{id}{Stable visual ID unique within its page; for pbi_example(), example name or index from 1 to 17.}
  \item{visual}{An already constructed pbi_visual object, not an R render function.}
}
\details{
The helper provides naming similar to output$plot in Shiny, but it does not register a render function. Pass a completed pbi_bar(), pbi_line(), or other visual, not an R function. IDs are unique per page. A native chart can also be a source of data-point selections, so bindings are not limited to slicer inputs.
}
\value{The same pbi_visual specification with its ID replaced.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
v <- pbi_output("trend", pbi_line("date", "revenue", title = "Revenue trend"))
print(v)
}
