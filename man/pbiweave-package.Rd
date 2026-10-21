\name{pbiweave-package}
\alias{pbiweave}
\alias{pbiweave-package}
\docType{package}
\title{Declarative Power BI reports with portable embedded snapshots}
\description{Prepare data in R and generate native report definitions with a TMDL or TMSL semantic model.}
\details{On FIRST OPEN select Home -> Refresh in Power BI Desktop. Then inspect the report and Save As .pbix to include the loaded data. R performs build-time preparation; the report has native filtering and aggregation, not R callbacks. See the README for both complete flights tutorials and all function examples. Installed guides are in system.file("doc", package = "pbiweave").}
\seealso{\code{\link{pbi_example}}, \code{\link{pbi_compile}}, \code{\link{pbi_input}}}
