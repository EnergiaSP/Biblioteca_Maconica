import copy
import json
import unittest
from pathlib import Path
from unittest.mock import patch

from comparar_estudos_acervo import compare


class StudyComparisonTest(unittest.TestCase):
    def setUp(self):
        self.rules = {"colecoes": [{"id": "collection"}], "trilhas": [{"id": "path"}],
                      "collectionLimit": 24, "pathLimit": 18}
        report = {"ruleIDs": ["collection", "path"], "selectedPages": [["work:1"], ["work:2"]],
                  "resultsPerRule": [1, 1], "pages": 69711, "maxBatch": 100, "milliseconds": 1}
        self.reports = {"ios": copy.deepcopy(report), "android": copy.deepcopy(report)}

    def errors(self):
        def read(path, *args, **kwargs):
            if path.name == "regras_estudo_v1.json":
                return json.dumps(self.rules)
            return json.dumps(self.reports["ios" if "-ios." in path.name else "android"])
        with patch.object(Path, "read_text", read):
            return compare(Path("fixture"))["errors"]

    def test_matching_reports_pass(self):
        self.assertEqual([], self.errors())

    def test_different_page_or_work_is_rejected(self):
        self.reports["android"]["selectedPages"][0] = ["another-work:1"]
        self.assertTrue(self.errors())

    def test_extra_rule_is_rejected_without_crashing(self):
        self.reports["android"]["selectedPages"].append(["work:3"])
        self.assertTrue(self.errors())

    def test_duplicate_and_invalid_pages_are_rejected(self):
        for pages in [["work:1", "work:1"], ["work:0"], ["work:Optional(1)"]]:
            with self.subTest(pages=pages):
                for report in self.reports.values():
                    report["selectedPages"][0] = pages
                    report["resultsPerRule"][0] = len(pages)
                self.assertTrue(self.errors())

    def test_partial_corpus_is_rejected_even_when_matching(self):
        for report in self.reports.values():
            report["pages"] = 365
        self.assertTrue(self.errors())


if __name__ == "__main__":
    unittest.main()
