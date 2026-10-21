# Run from the repository root after installing pbiweave.
readme <- paste(readLines("README.md", warn = FALSE, encoding = "UTF-8"), collapse = "\n")
blocks <- regmatches(readme, gregexpr("(?s)```r\\n.*?```", readme, perl = TRUE))[[1L]]
code <- lapply(blocks, function(block) sub("```$", "", sub("^```r\\n", "", block)))
exprs <- lapply(code, function(text) parse(text = text))
called <- unique(unlist(lapply(exprs, function(expr) all.names(expr, functions = TRUE))))
missing <- setdiff(getNamespaceExports("pbiweave"), called)
if (length(missing)) stop("Missing README examples: ", paste(missing, collapse = ", "))
cat(length(getNamespaceExports("pbiweave")), "exported functions covered in parsed README code.\n")
