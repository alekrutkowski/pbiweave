\name{pbi_bind}
\alias{pbi_bind}
\title{Declare which visual selections affect which outputs}
\description{Sets directed Power BI interaction edges between visual IDs on one page.}
\usage{
pbi_bind(x, input, outputs, page = NULL, mode = c("filter", "none", "native"))
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{input}{The source visual ID on the chosen page. The source must support selection.}
  \item{outputs}{One or more target visual IDs on the same page.}
  \item{page}{The page name. Defaults to the last page for binding, all pages for flow inspection, and report scope for filtering.}
  \item{mode}{filter, none, or native, describing the directed visual interaction.}
}
\details{
filter translates to a native DataFilter interaction, none to NoFilter, and native leaves the choice to Power BI. Later bindings replace earlier bindings for the same source/target pair. Sources must support selections; static text, cards, and gauges are not input sources. pbi_text() is not a reactive text output. Bindings do not join tables: the semantic model must have the necessary relationships for a selected dimension to filter a fact visual. This is not bindEvent() and does not execute R code.
}
\value{The modified pbi_dashboard object.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_example("shiny") \%>\%
  pbi_bind("region", "trend", mode = "none")
pbi_flow(d, include_disabled = TRUE)
}
