# pbiweave 0.3.1

## Windows path-guard hotfix

* Fix an erroneous `Project path escapes the project: .gitignore` failure
  in `pbi_compile()` and `pbi_check(verify_hashes = TRUE)`. Path containment
  now validates the canonical **containing directory** instead of relying on
  how Windows spells an individual filename during normalization.
* Continue rejecting absolute or parent-traversing paths, and symlinked
  project leaves on platforms where `Sys.readlink()` exposes them. Nested
  directory links that resolve outside the project are rejected.
* Add tests for dotfiles, nested paths, traversal, symlink escapes, and an
  end-to-end TMDL project compilation with a ZIP containing `.gitignore`.
* No intentional changes to dashboard constructors, visual serializers,
  TMDL/TMSL model output, or the embedded-data format.

# pbiweave 0.3.0

## Consolidated implementation

* Use the actual 0.1.0 implementation as baseline; preserve all 40 original exports and add the 10 useful exports introduced in 0.2.0. No original export is removed.
* Preserve original positional contracts and stable demo fixture. Support safe named aliases and document the deliberately ambiguous cases instead of guessing their meaning.
* Compile TMDL by default from the same validated intermediate model as optional TMSL. Preserve the original semantic compatibility and Microsoft report-schema profile.
* Restore exact decimal and Int64 normalization, typed blank filters, unique query references, text tooltip semantics, visual-role constraints, relationship graph checks, and rich column/sort metadata.
* Preserve accessible alternative text, modern multi-value cards, auto-visible tables, full theme controls, original layouts and hidden/background/header page controls.
* Add R-first preparation, per-column metadata, aggregation/ratio/calendar helpers, stable visual IDs and explicit Shiny-style interaction bindings with static flow inspection.
* Stage project and optional ZIP before committing; reject unsafe/symlink destinations, preserve previous output by default, and read both historical manifest formats.
* Clearly print first-open Home -> Refresh instructions and emit FIRST-OPEN.md in each project. Distinguish structural validation from native processing.
* Include two complete flights tutorials, the Shiny-developer guide, every-function README coverage and expanded help with examples.

## Acceptance

The regression suite retains the original tests and adds consolidation cases. Static checks and source-level evidence are recorded in VALIDATION.md; native R, TOM and Desktop gates are supplied separately and are not represented as completed runs.

Historical 0.1.0 release notes and evidence remain in validation/legacy-0.1.0/ in the repository. They describe the old release, not this one.
