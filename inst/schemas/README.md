# Microsoft Power BI schema snapshot

`registry.json` is an offline mapping from each published schema URL to its
complete JSON schema. It includes recursive external references, including
embedded variants, so validation does not need network access.

Source: <https://github.com/microsoft/json-schemas>

Retrieved: 20 October 2026. Upstream license: MIT, copyright Microsoft
Corporation. The full notice is retained in `LICENSE-MICROSOFT`.

Top-level schema versions used by pbiweave:

| Component | Version |
| --- | --- |
| PBIP properties | 1.0.0 |
| Report definition properties | 2.0.0 |
| Semantic model definition properties | 1.0.0 |
| Report | 3.3.0 |
| Page | 2.1.0 |
| Pages metadata | 1.1.0 |
| Visual container | 2.13.0 |
| Visual configuration | 2.8.0 |
| Version metadata | 1.0.0 |
| Theme schema (separate theme-schema.json) | 2.159 |

The separate theme schema is copied unchanged from Microsoft's
[Power BI Desktop samples](https://github.com/microsoft/powerbi-desktop-samples/tree/main/Report%20Theme%20JSON%20Schema)
and is loaded by the validator alongside the URL-keyed registry. Its upstream
MIT copyright notice is also retained in `LICENSE-MICROSOFT`.

The PBIR report format version is separate from JSON schema versions. The
snapshot is reproducible; it does not automatically track unreviewed future
schema changes. Schema conformance does not replace opening and refreshing the
project in Power BI Desktop to validate DAX, M, and visual rendering.
