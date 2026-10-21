#!/usr/bin/env python3
"""Executed development-tool tests. They do NOT execute any R compiler function."""
from pathlib import Path
import tempfile, unittest, json, re, hashlib, sys
from tmdl_inventory import inventory, declarations, unquote
from jsonschema.validators import validator_for
ROOT = Path(__file__).resolve().parents[1]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

class ToolTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.folder = Path(self.temp.name)
        (self.folder / "tables").mkdir()
        (self.folder / "database.tmdl").write_text("database Example\n\tcompatibilityLevel: 1702\n")
        (self.folder / "model.tmdl").write_text("model Model\nref table 'A.B'\n")
    def tearDown(self):
        self.temp.cleanup()
    def table(self, text):
        path = self.folder / "tables" / "001-fixture.tmdl"
        path.write_text(text)
        return path
    def test_generated_subset_inventory(self):
        self.table("table 'A.B'\n\tcolumn 'O''Brien'\n\t\tdataType: string\n\tmeasure 'Amount' = ```\n\t\t\t1 + 2\n\t\t\t```\n")
        t = inventory(self.folder)["model"]["tables"][0]
        self.assertEqual(t["name"], "A.B")
        self.assertEqual(t["columns"], [{"name": "O'Brien"}])
        self.assertEqual(t["measures"], [{"name": "Amount"}])
    def test_expressions_cannot_inject_inventory_declarations(self):
        self.table("table 'A.B'\n\tcolumn 'C'\n\tpartition 'A.B' = m\n\t\tsource = ```\ntable Fake\n\tcolumn Injected\n\t\t\t```\n")
        t = inventory(self.folder)["model"]["tables"]
        self.assertEqual(len(t), 1)
        self.assertEqual(t[0]["columns"], [{"name":"C"}])
    def test_unclosed_fence_rejected(self):
        self.table("table A\n\tcolumn C\n\tmeasure M = ```\n")
        with self.assertRaisesRegex(ValueError, 'unclosed'):
            inventory(self.folder)
    def test_missing_tables_rejected(self):
        with self.assertRaisesRegex(ValueError, 'missing TMDL table'):
            inventory(self.folder)
    def test_missing_database_rejected(self):
        (self.folder/'database.tmdl').unlink()
        with self.assertRaisesRegex(ValueError, 'database.tmdl'):
            inventory(self.folder)
    def test_multiple_tables_rejected_by_subset_inventory(self):
        self.table("table A\n\tcolumn C\ntable B\n\tcolumn D\n")
        with self.assertRaisesRegex(ValueError, 'multiple tables'):
            inventory(self.folder)
    def test_quoted_relationship_endpoints(self):
        self.table("table 'A.B'\n\tcolumn 'C.D'\n")
        (self.folder/'relationships.tmdl').write_text("relationship 'rel'\n\tfromColumn: 'A.B'.'C.D'\n\ttoColumn: 'O''Brien'.'K'\n")
        r = inventory(self.folder)['model']['relationships'][0]
        self.assertEqual(r['fromTable'],'A.B'); self.assertEqual(r['fromColumn'],'C.D')
        self.assertEqual(r['toTable'],"O'Brien"); self.assertEqual(r['toColumn'],'K')
    def test_name_unquoting(self):
        self.assertEqual(unquote("'Two '' names'"),"Two ' names")
        self.assertEqual(unquote('Plain'),'Plain')
    def test_bundled_schemas_are_valid_schema_documents(self):
        registry=json.loads((ROOT/'inst/schemas/registry.json').read_text())
        registry['theme']=json.loads((ROOT/'inst/schemas/theme-schema.json').read_text())
        for uri,schema in registry.items():
            with self.subTest(uri=uri):
                validator_for(schema).check_schema(schema)
    def test_original_schema_bytes_retained(self):
        evidence=json.loads((ROOT/'validation/provenance.json').read_text())
        for item in evidence['original_schemas']:
            self.assertEqual(digest(ROOT/item['path']),item['sha256'])
    def test_union_of_historical_exports(self):
        e=json.loads((ROOT/'validation/provenance.json').read_text())['exports']
        self.assertEqual(set(e['0.3.0']),set(e['0.1.0'])|set(e['0.2.0']))
        self.assertEqual(len(e['0.3.0']),50)
    def test_preserved_test_files_match_record(self):
        evidence=json.loads((ROOT/'validation/provenance.json').read_text())
        for item in evidence['original_tests']:
            self.assertEqual(digest(ROOT/item['path']),item['consolidated_sha256'])
        self.assertEqual(sum(not x['identical'] for x in evidence['original_tests']),1)
    def test_path_guard_hotfix_checks_real_parent_not_normalized_leaf(self):
        # This is a source-invariant regression, not execution of Windows R.
        source=(ROOT/'R/compile.R').read_text().split('project_child <- function',1)[1].split('\n# Read object names',1)[0]
        self.assertIn('normalizePath(dirname(child), winslash = "/", mustWork = TRUE)',source)
        self.assertIn('if (!identical(parent, root) && !startsWith(parent, prefix))',source)
        self.assertIn('Sys.readlink(child)',source)
        self.assertNotIn('normalizePath(file.path(root, relative)',source)
        regression=(ROOT/'tests/testthat/test-path-guards.R').read_text()
        for item in ('.gitignore','bundle = TRUE','verify_hashes = TRUE','otherdir/private.json','external.json'):
            self.assertIn(item,regression)

    def test_unmodified_original_examples_are_retained(self):
        evidence=json.loads((ROOT/'validation/provenance.json').read_text())
        legacy=ROOT/'tools/legacy-examples.R'
        self.assertEqual(digest(legacy),evidence['legacy_example_source_sha256'])
        original=legacy.read_text().split('.pbi_examples <- list(',1)[1].split('\nutils::globalVariables',1)[0].strip()
        self.assertIn(original,(ROOT/'R/examples.R').read_text())

if __name__=='__main__':
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(ToolTests)
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    report={'scope':'Python development-tool and source-provenance tests only; no R/TOM/Desktop execution',
            'tests_run':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'passed':result.wasSuccessful()}
    out=ROOT/'validation/python-tool-tests.json';out.parent.mkdir(exist_ok=True)
    out.write_text(json.dumps(report,indent=2)+'\n')
    sys.exit(0 if result.wasSuccessful() else 1)
