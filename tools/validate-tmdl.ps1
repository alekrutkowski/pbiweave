<#
Use Microsoft's TOM parser, not a regular expression, for TMDL grammar acceptance.
PowerShell 7 example:
  ./tools/validate-tmdl.ps1 -DefinitionFolder 'C:/build/report.SemanticModel/definition' `
    -TabularAssembly 'C:/trusted/TOM/Microsoft.AnalysisServices.Tabular.dll'

Supply a compatible, trusted Microsoft TOM installation containing TmdlSerializer.
No assemblies are downloaded or bundled by this helper. Use the runtime matching
those assemblies. Microsoft documents DeserializeDatabaseFromFolder here:
https://learn.microsoft.com/en-us/analysis-services/tmdl/tmdl-overview
This checks deserialization, not M refresh, DAX execution, or report rendering.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$DefinitionFolder,
  [Parameter(Mandatory = $true)][string]$TabularAssembly,
  [string]$TmslFile
)
$ErrorActionPreference = 'Stop'
$folder = (Resolve-Path -LiteralPath $DefinitionFolder).Path
$assembly = (Resolve-Path -LiteralPath $TabularAssembly).Path
if (-not (Test-Path -LiteralPath (Join-Path $folder 'model.tmdl'))) {
  throw 'DefinitionFolder must contain model.tmdl.'
}
$core = Join-Path (Split-Path $assembly -Parent) 'Microsoft.AnalysisServices.Core.dll'
if (Test-Path -LiteralPath $core) { [void][Reflection.Assembly]::LoadFrom($core) }
[void][Reflection.Assembly]::LoadFrom($assembly)
$db = [Microsoft.AnalysisServices.Tabular.TmdlSerializer]::DeserializeDatabaseFromFolder($folder)
if ($null -eq $db.Model -or $db.Model.Tables.Count -eq 0) {
  throw 'Deserialization did not produce a nonempty model.'
}
# Optional semantic equivalence gate against the matching generated TMSL.
# Both definitions are deserialized by Microsoft TOM and reserialized with
# identical settings. The comparison ignores JSON object-key ordering only.
function Normalize-JsonValue($Value) {
  if ($Value -is [System.Collections.IDictionary]) {
    $result = [ordered]@{}
    foreach ($key in @($Value.Keys | Sort-Object)) {
      $result[$key] = Normalize-JsonValue $Value[$key]
    }
    return $result
  }
  if ($Value -is [System.Collections.IList]) {
    return ,@($Value | ForEach-Object { Normalize-JsonValue $_ })
  }
  return $Value
}
$equivalence = 'not-requested'
if ($TmslFile) {
  $json = Get-Content -LiteralPath (Resolve-Path -LiteralPath $TmslFile).Path -Raw
  $reference = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::DeserializeDatabase($json)
  $left = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::SerializeDatabase($db)
  $right = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::SerializeDatabase($reference)
  $a = Normalize-JsonValue ($left | ConvertFrom-Json -AsHashtable)
  $b = Normalize-JsonValue ($right | ConvertFrom-Json -AsHashtable)
  $a = ConvertTo-Json -InputObject $a -Depth 100 -Compress
  $b = ConvertTo-Json -InputObject $b -Depth 100 -Compress
  if ($a -cne $b) { throw 'Native TOM round-trip differs between TMDL and TMSL. Review the serialized models.' }
  $equivalence = 'passed'
}
[ordered]@{
  parser = 'Microsoft.AnalysisServices.Tabular.TmdlSerializer'
  deserialization = 'passed'
  tmslEquivalence = $equivalence
  tables = $db.Model.Tables.Count
  relationships = $db.Model.Relationships.Count
  nativeRefreshExecuted = $false
  daxExecuted = $false
  reportRendered = $false
} | ConvertTo-Json
