# Project writing is transactional: prepare, check, and bundle in a sibling
# staging directory, then rename. Never modify the old project in place.
pbi_compile <- function(x, path, overwrite = FALSE, bundle = FALSE,
                        compression = TRUE, open = FALSE,
                        model_format = c("tmdl", "tmsl"), keep_backup = TRUE) {
  assert_dashboard(x); scalar_string(path, "path")
  invisible(lapply(list(overwrite, bundle, compression, open, keep_backup),
                   scalar_flag, label = "Compilation flags"))
  model_format <- match.arg(model_format)
  if (grepl("\\.(pbix|pbit|pbip|zip)$", path, ignore.case = TRUE)) abort(
    "path must be a project directory. For PBIX, open the generated project in ",
    "Desktop, select Home > Refresh, then File > Save As. Use bundle=TRUE for a ZIP.")
  diagnostics <- pbi_validate(x, stop_on_error = TRUE)
  if (nrow(diagnostics)) warning(paste0("Report preflight: ", nrow(diagnostics),
    " warning(s). Inspect pbi_validate(x) for details."), call. = FALSE)
  path <- path.expand(path)
  if (basename(path) %in% c("", ".", "..") || identical(path, "/"))
    abort("Choose a dedicated project directory.")
  parent <- dirname(path)
  if (!dir.exists(parent) && !dir.create(parent, recursive = TRUE, showWarnings = FALSE))
    abort("Cannot create destination parent: ", parent)
  parent <- normalizePath(parent, winslash = "/", mustWork = TRUE)
  path <- file.path(parent, basename(path))
  if (identical(path, normalizePath(getwd(), winslash = "/", mustWork = TRUE)))
    abort("Choose a dedicated project directory, not the current working directory.")
  link <- Sys.readlink(path)
  if (!is.na(link) && nzchar(link)) abort("Refusing to replace a symlinked directory.")
  existing <- file.exists(path)
  if (existing && !dir.exists(path)) abort("Destination is an existing file.")
  if (existing && !overwrite) abort("Destination exists; choose another path or set overwrite=TRUE.")
  if (existing && length(list.files(path, all.files = TRUE, no.. = TRUE))) {
    marker <- tryCatch(read_project_manifest(path), error = function(e) NULL)
    if (is.null(marker) || !identical(marker$generator %||% marker$package, "pbiweave"))
      abort("Refusing to replace a non-pbiweave directory.")
  }
  zip_path <- paste0(path, ".zip")
  zip_link <- Sys.readlink(zip_path)
  if (bundle && !is.na(zip_link) && nzchar(zip_link)) abort("Refusing to replace a symlinked bundle.")
  if (bundle && dir.exists(zip_path)) abort("ZIP destination is a directory.")
  if (bundle && file.exists(zip_path) && !overwrite)
    abort("ZIP destination exists; set overwrite=TRUE or choose another path.")
  name <- substr(gsub("[^A-Za-z0-9_-]", "-", basename(path)), 1L, 64L)
  if (!nzchar(gsub("-", "", name, fixed = TRUE))) name <- "Report"
  stage <- tempfile(".pbiweave-build-", tmpdir = parent)
  if (!dir.create(stage)) abort("Cannot create build staging directory.")
  staged_zip <- tempfile(".pbiweave-build-", tmpdir = parent, fileext = ".zip")
  on.exit({ if (dir.exists(stage)) unlink(stage, recursive = TRUE); unlink(staged_zip) }, add = TRUE)
  model_folder <- paste0(name, ".SemanticModel"); report_folder <- paste0(name, ".Report")
  compile_model(x, file.path(stage, model_folder), compression = compression, model_format = model_format)
  compile_report(x, file.path(stage, report_folder), model_folder)
  write_json(list(`$schema` = "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",
    version = "1.0", artifacts = list(list(report = list(path = report_folder))),
    settings = list(enableAutoRecovery = TRUE)), file.path(stage, paste0(name, ".pbip")))
  write_utf8(c("**/.pbi/cache.abf", "**/.pbi/localSettings.json"), file.path(stage, ".gitignore"))
  first_open <- c(paste0("# ", x$title), "",
    "## FIRST OPEN: Home > Refresh is required", "",
    paste0("1. Extract the whole project and open `", name, ".pbip` in Power BI Desktop for Windows."),
    "2. Select **Home > Refresh**. Empty visuals and the incomplete-data banner before refresh are expected.",
    "3. Check totals, filters, interactions, labels, dates, and number formats.",
    "4. Select **File > Save As > Power BI Desktop file (.pbix)** to save the loaded data.",
    "5. Use Desktop Publish to publish after inspection, subject to your Power BI permissions.", "",
    paste0("Semantic-model format: **", toupper(model_format), "**. Do not keep model.bim and definition/ together."),
    "Close and reopen the project after rebuilding or changing files outside Desktop.", "",
    "The PBIP file is an entry point, not a standalone data file. Share the complete folder or its ZIP.",
    "The ZIP is a source archive, not a PBIX and not a Power BI import endpoint.",
    "The embedded snapshot has no CSV, database, credentials, or R-runtime dependency.",
    "Recipients can recover embedded data. Hidden columns and tables are not access control.", "",
    "Recompiling with overwrite=TRUE replaces the project, including Desktop edits. Keep backups or use a new path.",
    "By default pbiweave retains the previous project and bundle beside the output when overwriting.", "",
    "pbi_check() checks structure and embedded payloads, not execution, rendering, security, or publication.",
    "https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset")
  write_utf8(first_open, file.path(stage, "FIRST-OPEN.md"))
  write_utf8(first_open, file.path(stage, "START-HERE.txt"))
  source_files <- sort(list.files(stage, recursive = TRUE, full.names = TRUE, all.files = TRUE))
  files <- lapply(source_files, function(f) list(path = substring(f, nchar(stage) + 2L),
    bytes = unname(file.info(f)$size), md5 = unname(tools::md5sum(f))))
  manifest <- list(generator = "pbiweave", package = "pbiweave", packageVersion = "0.4.0",
    version = "0.4.0", title = x$title, format = paste0("PBIP/PBIR/", toupper(model_format)),
    model_format = model_format, schemaProfile = "2026-10-20", embeddedSourceData = TRUE,
    requiresDesktopRefresh = TRUE, requiresDesktopSaveForPBIX = TRUE,
    first_refresh_required = TRUE, runtime_checked = FALSE,
    compression = if (compression) "gzip" else "none", entryPoint = paste0(name, ".pbip"),
    project_file = paste0(name, ".pbip"), report_dir = report_folder, model_dir = model_folder,
    tables = unname(lapply(seq_along(x$tables), function(i) {
      t <- x$tables[[i]]
      list(name = t$name, rows = nrow(t$data), columns = ncol(t$data),
        columnNames = as.list(names(t$columns)),
        source = if (model_format == "tmdl") paste(model_folder, "definition", "tables",
          tmdl_table_file(t$name, i), sep = "/") else paste0(model_folder, "/model.bim"))
    })),
    pages = unname(lapply(x$pages, function(p) list(name = p$name, visuals = length(p$visuals)))),
    diagnostics = lapply(seq_len(nrow(diagnostics)), function(i) as.list(diagnostics[i])), files = files)
  write_json(manifest, file.path(stage, "pbiweave.json"))
  pbi_check(stage, stop_on_error = TRUE, verify_hashes = TRUE, check_data = TRUE)
  if (bundle) write_project_zip(stage, staged_zip)
  backup <- zip_backup <- NULL
  if (existing) {
    backup <- tempfile(paste0(basename(path), "-backup-"), tmpdir = parent)
    if (!file.rename(path, backup)) abort("Cannot replace destination. Close it in Desktop first.")
  }
  if (bundle && file.exists(zip_path)) {
    zip_backup <- tempfile(paste0(basename(path), "-bundle-backup-"), tmpdir = parent, fileext = ".zip")
    if (!file.rename(zip_path, zip_backup)) {
      if (!is.null(backup)) file.rename(backup, path)
      abort("Cannot replace bundle. Recovery was attempted; inspect the original path and retained backup.")
    }
  }
  if (!file.rename(stage, path)) {
    if (!is.null(backup)) file.rename(backup, path)
    if (!is.null(zip_backup)) file.rename(zip_backup, zip_path)
    abort("Cannot commit staged project. Recovery was attempted; inspect the original paths and retained backups.")
  }
  if (bundle && !file.rename(staged_zip, zip_path)) {
    unlink(path, recursive = TRUE)
    if (!is.null(backup)) file.rename(backup, path)
    if (!is.null(zip_backup)) file.rename(zip_backup, zip_path)
    abort("Cannot commit staged bundle. Recovery was attempted; inspect the original paths and retained backups.")
  }
  if (!keep_backup) {
    if (!is.null(backup)) unlink(backup, recursive = TRUE)
    if (!is.null(zip_backup)) unlink(zip_backup)
    backup <- zip_backup <- NULL
  }
  result <- structure(list(path = path, pbip = file.path(path, paste0(name, ".pbip")),
    project_file = file.path(path, paste0(name, ".pbip")), report = file.path(path, report_folder),
    model = file.path(path, model_folder), model_format = model_format,
    bundle = if (bundle) zip_path else NULL, diagnostics = diagnostics,
    backup = backup, bundle_backup = zip_backup), class = "pbi_project")
  refresh_notice()
  if (open) pbi_open(result)
  invisible(result)
}

project_path <- function(project) {
  if (inherits(project, "pbi_project")) project <- project$path
  scalar_string(project, "project")
  path <- normalizePath(path.expand(project), winslash = "/", mustWork = TRUE)
  if (grepl("\\.pbip$", path, ignore.case = TRUE)) path <- dirname(path)
  if (!dir.exists(path)) abort("Expected a project directory or .pbip entry point.")
  path
}

read_project_manifest <- function(path) {
  candidates <- file.path(path, c("pbiweave.json", "pbiweave-manifest.json"))
  files <- candidates[file.exists(candidates)]
  if (!length(files)) abort("Missing pbiweave manifest (pbiweave.json or pbiweave-manifest.json).")
  if (length(files) != 1L) abort("Conflicting pbiweave manifests; keep only the matching version.")
  jsonlite::fromJSON(files[[1L]], simplifyVector = FALSE)
}

project_child <- function(root, relative) {
  scalar_string(relative, "Relative project path")
  # Reject absolute paths, Windows drives and backslashes, and every . or ..
  # component. Names such as .gitignore must remain valid project members.
  if (grepl("^(/|[A-Za-z]:)|\\\\|(^|/)\\.\\.?(/|$)", relative))
    abort("Unsafe relative project path: ", relative)

  # On Windows normalizePath() may express a *file* differently from its
  # containing directory (for example through drive, UNC or 8.3 aliases).
  # The old test compared a normalized leaf with a non-equivalent root path
  # and rejected ordinary files including .gitignore. Security depends on
  # validating the real parent directory, not its arbitrary leaf spelling.
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  if (!dir.exists(root)) abort("Expected an existing project directory.")
  child <- file.path(root, relative)
  if (!file.exists(child)) abort("Missing project path: ", relative)
  parent <- normalizePath(dirname(child), winslash = "/", mustWork = TRUE)
  prefix <- paste0(sub("/+$", "", root), "/")
  if (.Platform$OS.type == "windows") {
    parent <- tolower(parent)
    root <- tolower(root)
    prefix <- tolower(prefix)
  }
  if (!identical(parent, root) && !startsWith(parent, prefix))
    abort("Project path escapes the project: ", relative)

  # Reject symbolic-link leaves where readlink is supported. The resolved
  # parent check above also protects against nested directory links/junctions
  # that point outside the project root.
  link <- Sys.readlink(child)
  if (!is.na(link) && nzchar(link))
    abort("Refusing a symlinked project entry: ", relative)
  child
}

# Read object names and M text for structural checking, NOT a TMDL parser.
# Fenced expressions are skipped when looking for object declarations.
read_tmdl_inventory <- function(definition) {
  if (!file.exists(file.path(definition, "database.tmdl")) ||
      !file.exists(file.path(definition, "model.tmdl"))) abort("Missing database.tmdl or model.tmdl.")
  files <- list.files(file.path(definition, "tables"), pattern = "\\.tmdl$", full.names = TRUE)
  if (!length(files)) abort("Missing TMDL table definitions.")
  unquote <- function(s) {
    s <- trimws(s)
    if (startsWith(s, "'") && endsWith(s, "'"))
      gsub("''", "'", substr(s, 2L, nchar(s) - 1L), fixed = TRUE) else s
  }
  tables <- lapply(files, function(file) {
    lines <- readLines(file, warn = FALSE, encoding = "UTF-8")
    inside <- FALSE
    keep <- vapply(lines, function(line) {
      if (inside) {
        if (grepl("^[[:space:]]*```[[:space:]]*$", line)) inside <<- FALSE
        return(FALSE)
      }
      if (grepl("=[[:space:]]*```[[:space:]]*$", line)) inside <<- TRUE
      TRUE
    }, logical(1))
    if (inside) abort("Unclosed TMDL expression fence in ", basename(file))
    declarations <- lines[keep]
    title <- grep("^table[[:space:]]+", declarations, value = TRUE)
    if (length(title) != 1L) abort("Expected one root table in ", basename(file))
    columns <- grep("^[\\t ]+column[[:space:]]+", declarations, value = TRUE, perl = TRUE)
    columns <- vapply(sub("^[\\t ]+column[[:space:]]+", "", columns, perl = TRUE), unquote, character(1))
    if (!length(columns)) abort("No stored columns in ", basename(file))
    list(name = unquote(sub("^table[[:space:]]+", "", title)), columns = columns,
         expression = paste(lines, collapse = "\n"), file = file)
  })
  names(tables) <- vapply(tables, `[[`, character(1), "name")
  if (anyDuplicated(tolower(names(tables)))) abort("Duplicate table names in TMDL.")
  tables
}

check_embedded_payload <- function(expression, expected_rows, expected_columns) {
  # Recognize a line-start initializer from either historical emitter. This
  # is a generated-snapshot check, not a parser for arbitrary M or DAX.
  pattern <- "(?ms)^[\\t ]*(?:Payload|Encoded)[[:space:]]*=[[:space:]]*Text\\.Combine\\(\\{([[:space:][:alnum:]+/=\",]*)\\}\\)"
  match <- regexec(pattern, expression, perl = TRUE)
  block <- regmatches(expression, match)[[1L]]
  if (length(block) != 2L) abort("Cannot recognize the embedded snapshot; use check_data=FALSE for intentionally edited queries.")
  chunks <- regmatches(block[[2L]], gregexpr('"[A-Za-z0-9+/=]*"', block[[2L]], perl = TRUE))[[1L]]
  payload <- paste0(sub('"$', "", sub('^"', "", chunks)), collapse = "")
  if (!nzchar(payload) || nchar(payload) %% 4L != 0L ||
      !grepl("^[A-Za-z0-9+/]+={0,2}$", payload)) abort("Invalid embedded Base64 payload.")
  bytes <- base64enc::base64decode(payload)
  if (grepl("Compression.GZip", expression, fixed = TRUE)) {
    if (length(bytes) < 2L || !identical(as.integer(bytes[1:2]), c(31L, 139L)))
      abort("Embedded payload is not a genuine gzip stream.")
    bytes <- memDecompress(bytes, type = "gzip")
  }
  rows <- jsonlite::fromJSON(rawToChar(bytes), simplifyVector = FALSE)
  if (!is.list(rows) || length(rows) != expected_rows) abort("Embedded row count does not match the manifest.")
  if (any(lengths(rows) != expected_columns)) abort("Embedded row width does not match the manifest.")
  invisible(TRUE)
}

pbi_check <- function(project, stop_on_error = TRUE, verify_hashes = FALSE, check_data = TRUE) {
  invisible(lapply(list(stop_on_error, verify_hashes, check_data), scalar_flag, label = "Check flags"))
  errors <- character(); n <- 0L; format <- NA_character_; checked <- 0L; cache <- FALSE
  tryCatch({
    path <- project_path(project)
    entry <- list.files(path, pattern = "\\.pbip$", full.names = TRUE)
    if (length(entry) != 1L) abort("Expected exactly one PBIP entry point.")
    manifest <- read_project_manifest(path)
    if (!identical(manifest$generator %||% manifest$package, "pbiweave")) abort("Unrecognized project manifest.")
    files <- list.files(path, recursive = TRUE, full.names = TRUE, all.files = TRUE)
    files <- files[grepl("\\.(json|pbip|pbir|pbism|bim)$", files, ignore.case = TRUE)]
    parsed <- stats::setNames(lapply(files, function(f) tryCatch(jsonlite::fromJSON(f, simplifyVector = FALSE),
      error = function(e) abort("Invalid JSON in ", basename(f), ": ", conditionMessage(e)))), files)
    n <- length(files)
    pbip <- parsed[[entry]]
    report <- project_child(path, pbip$artifacts[[1L]]$report$path)
    pbir <- parsed[[file.path(report, "definition.pbir")]]
    if (is.null(pbir)) abort("Missing report definition.pbir.")
    model_rel <- pbir$datasetReference$byPath$path
    if (is.null(model_rel) || !grepl("^\\.\\./[^/\\\\]+$", model_rel)) abort("Expected a sibling embedded semantic model.")
    model <- project_child(path, sub("^\\.\\./", "", model_rel))
    if (!file.exists(file.path(model, "definition.pbism"))) abort("Missing definition.pbism.")
    bim <- file.exists(file.path(model, "model.bim")); tmdl <- dir.exists(file.path(model, "definition"))
    if (bim == tmdl) abort("Keep exactly one semantic model: model.bim OR definition/ (TMDL), never both.")
    format <- if (tmdl) "tmdl" else "tmsl"
    cache <- file.exists(file.path(model, ".pbi", "cache.abf"))
    inventory <- if (tmdl) read_tmdl_inventory(file.path(model, "definition")) else {
      tables <- parsed[[file.path(model, "model.bim")]]$model$tables
      out <- lapply(tables, function(t) list(name = t$name,
        columns = vapply(t$columns, `[[`, character(1), "name"),
        expression = paste(unlist(t$partitions[[1L]]$source$expression, use.names = FALSE), collapse = "\n")))
      stats::setNames(out, vapply(out, `[[`, character(1), "name"))
    }
    if (!length(inventory)) abort("No model tables.")
    if (check_data) invisible(lapply(manifest$tables, function(t) {
      item <- inventory[[t$name]]
      if (is.null(item)) abort("Manifest table is missing: ", t$name)
      nc <- if (is.numeric(t$columns)) t$columns else length(t$columns)
      if (length(item$columns) != nc) abort("Column count does not match manifest for ", t$name)
      check_embedded_payload(item$expression, t$rows, nc)
      checked <<- checked + 1L
    }))
    pages <- parsed[[file.path(report, "definition", "pages", "pages.json")]]
    if (!length(pages$pageOrder)) abort("Missing ordered report pages.")
    invisible(lapply(pages$pageOrder, function(id) {
      if (!is.character(id) || length(id) != 1L || grepl("[/\\\\]", id) || id %in% c(".", "..")) abort("Invalid page identifier.")
      project_child(path, paste(pbip$artifacts[[1L]]$report$path, "definition", "pages", id, "page.json", sep = "/"))
    }))
    if (verify_hashes) invisible(lapply(manifest$files, function(item) {
      file <- project_child(path, item$path)
      if (!identical(tolower(unname(tools::md5sum(file))), tolower(item$md5)))
        abort("File hash mismatch: ", item$path, ". Desktop edits intentionally change build hashes.")
    }))
  }, error = function(e) errors <<- c(errors, conditionMessage(e)))
  if (length(errors) && stop_on_error) abort(paste(errors, collapse = "\n"))
  invisible(list(valid = !length(errors), files = n, errors = errors, model_format = format,
    embedded_tables_checked = checked, hashes_checked = verify_hashes && !length(errors),
    data_loaded = NA, cache_present = cache, runtime_checked = FALSE))
}

write_project_zip <- function(path, file) {
  files <- sort(list.files(path, recursive = TRUE, full.names = FALSE, all.files = TRUE))
  files <- files[!grepl("(^|/)\\.pbi/(cache\\.abf|localSettings\\.json)$", files)]
  invisible(lapply(files, function(f) project_child(path, f)))
  zip::zipr(file, files = files, root = path, include_directories = FALSE, mode = "mirror")
  invisible(file)
}

pbi_bundle <- function(project, file = NULL, overwrite = FALSE) {
  path <- project_path(project); pbi_check(path, check_data = FALSE); scalar_flag(overwrite, "overwrite")
  file <- file %||% paste0(path, ".zip"); scalar_string(file, "file")
  if (!grepl("\\.zip$", file, ignore.case = TRUE)) abort("Bundle destination must end in .zip.")
  if (!dir.exists(dirname(file))) dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  file <- file.path(normalizePath(dirname(file), winslash = "/", mustWork = TRUE), basename(file))
  if (startsWith(file, paste0(path, "/"))) abort("Save the bundle outside its source project.")
  link <- Sys.readlink(file)
  if (!is.na(link) && nzchar(link)) abort("Refusing to replace a symlinked bundle.")
  if (file.exists(file) && !overwrite) abort("Bundle exists; choose another file or set overwrite=TRUE.")
  if (dir.exists(file)) abort("Bundle destination is a directory.")
  stage <- tempfile(".pbiweave-zip-", tmpdir = dirname(file), fileext = ".zip")
  on.exit(unlink(stage), add = TRUE)
  write_project_zip(path, stage)
  if (file.exists(file)) {
    backup <- tempfile(".pbiweave-zip-backup-", tmpdir = dirname(file))
    if (!file.rename(file, backup)) abort("Cannot replace existing bundle.")
    if (!file.rename(stage, file)) { file.rename(backup, file); abort("Cannot commit bundle; previous bundle was restored.") }
    unlink(backup)
  } else if (!file.rename(stage, file)) abort("Cannot commit bundle.")
  invisible(file)
}

pbi_open <- function(project) {
  path <- project_path(project); pbi_check(path, check_data = FALSE)
  entry <- list.files(path, pattern = "\\.pbip$", full.names = TRUE)[[1L]]
  refresh_notice()
  if (.Platform$OS.type == "windows") shell.exec(normalizePath(entry, winslash = "\\"))
  else message("Open ", entry, " in Windows Power BI Desktop.")
  invisible(entry)
}

print.pbi_project <- function(x, ...) {
  cat("<pbiweave project>\n", x$pbip %||% x$project_file, "\n", sep = "")
  if (!is.null(x$model_format)) cat("Model: ", toupper(x$model_format), "\n", sep = "")
  if (!is.null(x$bundle)) cat("Bundle: ", x$bundle, "\n", sep = "")
  if (!is.null(x$backup)) cat("Previous project retained at: ", x$backup, "\n", sep = "")
  cat("FIRST OPEN: Home > Refresh, inspect, then File > Save As > .pbix\n")
  invisible(x)
}
