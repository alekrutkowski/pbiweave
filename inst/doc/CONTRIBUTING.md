# Development and acceptance

The complete repository contains development tools intentionally excluded from the installable package. Runtime code has no compiled extension of its own. Install the Imports and suggested test/data packages; documentation generation uses Python's standard library.

```sh
python tools/make_docs.py
Rscript tools/export-themes.R
python tools/check-static.py
python -m pip install 'jsonschema>=4.18,<5'
python tools/test_static.py
R CMD build .
R CMD check --no-manual pbiweave_0.4.0.tar.gz
R CMD INSTALL pbiweave_0.4.0.tar.gz
Rscript tools/run-acceptance.R --flights
python tools/validate_project.py build/examples build/tutorials --json
```

Do not run roxygenise on the source comments: `tools/make_docs.py` maintains checked-in Rd and REFERENCE.md from explicit pedagogical prose plus actual function signatures. After revising docs copy the guides/reference into inst/doc, run the documentation coverage gate, and inspect help examples. The source comments retain historical explanations but are not a competing documentation generator.

The acceptance runner refuses pre-existing build/example and build/tutorial output to avoid confusing old generated files with a new pass. Preserve prior results elsewhere. All native gate results should record exact R, package, operating-system, TOM assembly and Desktop versions.

## Native TMDL gate

Use PowerShell 7 and an explicitly selected trusted Microsoft TOM assembly supporting TmdlSerializer. No assembly is downloaded or bundled. For the same specification generated in both formats:

```powershell
./tools/validate-tmdl.ps1 `
  -DefinitionFolder 'C:/build/examples/showcase-tmdl/showcase-tmdl.SemanticModel/definition' `
  -TabularAssembly 'C:/trusted/TOM/Microsoft.AnalysisServices.Tabular.dll' `
  -TmslFile 'C:/build/examples/showcase-tmsl/showcase-tmsl.SemanticModel/model.bim'
```

This performs native deserialization and an optional normalized JSON comparison after both definitions pass through TOM. It ignores JSON object-key order, not collection order or expression content. Any reported difference requires review. It does not execute M, evaluate DAX, process a cache or render a report.

## Desktop/publication gate

Use the intended Windows Power BI Desktop build and record its full version. Open, **Home -> Refresh**, compare expected unfiltered and selected totals, inspect all chart types and both theme contrasts, test multi-table propagation, blanks, exact decimals, Unicode, date/range controls, synchronization and disabled edges. Review label fit, alt text, fonts, hidden pages and heading behavior. Save to PBIX, close and reopen without the source project, and test publication under the actual workspace permissions. A metadata-only project or JSON-schema pass is not equivalent to this gate.

## Safe changes

Preserve exact numeric transport, copied snapshot ownership, relative paths, deterministic identifiers and transactional replacement. Add a focused regression before changing existing behavior. Do not weaken a Microsoft schema to make a generated file pass. Review schema changes explicitly, preserve upstream notices, and keep the compatibility profile accurate. Never relabel historical evidence as a pass for the current version.
