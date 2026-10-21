\name{pbi_flow}
\alias{pbi_flow}
\title{Inspect declared visual-interaction dependencies}
\description{Returns a table of potential directed selection flows in a report specification.}
\usage{
pbi_flow(x, page = NULL, include_disabled = FALSE)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{page}{The page name. Defaults to the last page for binding, all pages for flow inspection, and report scope for filtering.}
  \item{include_disabled}{Whether pbi_flow() should include edges with mode = "none".}
}
\details{
Each row identifies page, source ID, target ID, mode, and whether an explicit binding overrides the page default. Disabled edges are omitted unless requested. This is a static inspection tool, not a live reactlog and not proof that data can propagate through the semantic model. It does not include DAX dependency inference, relationship paths, or cross-page slicer synchronization. Native chart interactions may form cycles; they are not a Shiny reactive dependency DAG.
}
\value{A data.table with page, source, target, mode, and explicit columns.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_example("shiny")
pbi_flow(d)
pbi_flow(d, page = "Explore", include_disabled = TRUE)
}
