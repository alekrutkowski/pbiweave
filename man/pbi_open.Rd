\name{pbi_open}
\alias{pbi_open}
\title{Open the project and print the mandatory first-refresh instructions}
\description{Opens the generated .pbip entry point using the Windows file association, or returns its path on other systems.}
\usage{
pbi_open(project)
}
\arguments{
  \item{project}{A pbi_project object, a generated project directory, or its .pbip entry-point path.}
}
\details{
Home -> Refresh is required on the first Desktop opening because the generated project contains embedded source data but no processed data cache. pbi_open() never triggers a refresh, presses GUI buttons, or publishes a report. On Linux and WSL, use Power BI Desktop on Windows to open the returned path. After refreshing, compare totals with R, test selections, and save as .pbix to include the loaded cache.
}
\value{The .pbip filename, invisibly. A clear refresh notice is always printed.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
p <- pbi_compile(pbi_example("quickstart"), tempfile("open-"))
if (interactive() && .Platform$OS.type == "windows") {
  pbi_open(p)
} else {
  unlink(p$path, recursive = TRUE)
}
# In Desktop: Home -> Refresh, inspect, then Save As .pbix.
}
