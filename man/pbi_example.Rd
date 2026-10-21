\name{pbi_example}
\alias{pbi_example}
\title{Construct one of the teaching report specifications}
\description{Builds a complete example specification without writing files or opening Desktop.}
\usage{
pbi_example(id = "showcase", theme = NULL, name = NULL)
}
\arguments{
  \item{id}{Stable visual ID unique within its page; for pbi_example(), example name or index from 1 to 17.}
  \item{theme}{A named theme preset or an object returned by pbi_theme().}
  \item{name}{Named alias for id. Use one, not both.}
}
\details{
Names quickstart, typed, themes, grid, sidebar, focus, free, measures, star, time, filters, scatter, tables, gallery, types, showcase, and shiny are supported in that order. A numeric index selects the same sequence. The examples use deterministic fictional data. Select a theme, inspect the specification with pbi_validate(), and choose a new output directory when compiling. The flight tutorials are separate, fully annotated scripts under inst/examples. id is the original argument; name is an alias. The first sixteen declarations and their original six-column fixture are retained, with shiny added seventeenth. No data are downloaded by pbi_example().
}
\value{A pbi_dashboard object ready for pbi_compile().}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_example("showcase", theme = "midnight")
pbi_validate(d)$valid
print(pbi_example(1))
}
