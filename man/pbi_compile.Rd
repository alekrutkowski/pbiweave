\name{pbi_compile}
\alias{pbi_compile}
\title{Compile a portable project using TMDL by default}
\description{Writes report definitions, embedded data, and a TMDL or legacy TMSL semantic model to a project directory.}
\usage{
pbi_compile(x, path, overwrite = FALSE, bundle = FALSE,
                        compression = TRUE, open = FALSE,
                        model_format = c("tmdl", "tmsl"), keep_backup = TRUE)
}
\arguments{
  \item{x}{An existing report specification or visual to modify. For chart constructors, the horizontal/category field; see Details.}
  \item{path}{A project directory to create, not a .pbix, .pbip, or .zip filename.}
  \item{overwrite}{Whether to replace an existing pbiweave-generated directory, preserving its old contents in a sibling backup.}
  \item{bundle}{Whether also to create a ZIP alongside the generated directory.}
  \item{compression}{Embed data as genuine gzip-compressed Base64 JSON; FALSE embeds uncompressed Base64 JSON.}
  \item{open}{Open the completed project using pbi_open(); this never automates the Desktop refresh.}
  \item{model_format}{"tmdl" (default) or "tmsl". Exactly one semantic-model representation is written.}
  \item{keep_backup}{Retain the previous project and requested ZIP after a successful overwrite. Defaults TRUE.}
}
\details{
The default model_format = "tmdl" writes a definition/ folder and never a model.bim file. Explicit "tmsl" writes model.bim instead. Both formats use the same internal model and embedded data source. Compilation stages files before committing them. overwrite = TRUE only replaces a directory bearing a pbiweave manifest and retains the old project in a sibling backup directory. Close Desktop before replacing an open project. A bundle ZIP contains all source definitions, not a processed Power BI cache. On first opening select Home -> Refresh, review the visuals, and use Save As .pbix. There is no supported headless PBIX build step implemented here. The original positional sequence (x, path, overwrite, bundle, compression, open) is unchanged. Name the newer options, especially model_format. keep_backup = TRUE retains prior output; FALSE discards it after a successful commit. Compression uses genuine gzip framing, not R memCompress() zlib framing. Both project and requested ZIP are prepared before old output is moved. Output is still source definitions plus embedded data, not a headlessly generated PBIX.
}
\value{Invisibly, a pbi_project with original path, pbip, report, model, bundle and diagnostics fields, plus project_file, model_format, backup and bundle_backup.}
\seealso{\code{\link{pbi_dashboard}}, \code{\link{pbi_compile}}, \code{\link{pbi_check}}}
\examples{
d <- pbi_example("quickstart")
p <- pbi_compile(d, tempfile("pbiweave-example-"))
p$model_format
pbi_check(p)$valid
# For legacy output, use model_format = "tmsl" in a different directory.
unlink(p$path, recursive = TRUE)
}
