\name{pbi_bundle}
\alias{pbi_bundle}
\title{Bundle an existing project without recompiling it}
\description{Writes a ZIP of the complete project source, including intentional Desktop edits.}
\usage{
pbi_bundle(project, file = NULL, overwrite = FALSE)
}
\arguments{
  \item{project}{A pbi_project object, a generated project directory, or its .pbip entry-point path.}
  \item{file}{ZIP filename outside the source project. NULL chooses a sibling .zip.}
  \item{overwrite}{Replace an existing ZIP transactionally; does not recompile the project.}
}
\details{
Unlike pbi_compile(bundle = TRUE), this does not regenerate the model or report. It accepts an existing project object, folder or PBIP entry point, including legacy manifests. Structural checks are retained, but snapshot decoding and build-hash checks are skipped because intentional edits can invalidate the old manifest. cache.abf and localSettings.json are excluded; editor settings and other source files are retained. Destination paths must be outside the source folder. Symlinks escaping the project are rejected. The ZIP is not a PBIX; recipients must extract it and refresh. The original bundle is replaced transactionally when overwrite = TRUE.
}
\value{Invisibly, the absolute ZIP filename.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
p <- pbi_compile(pbi_example("quickstart"), tempfile("bundle-"))
z <- pbi_bundle(p)
stopifnot(file.exists(z))
unlink(c(p$path, z), recursive = TRUE)
}
