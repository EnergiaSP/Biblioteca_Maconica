import unittest

from validar_icloud import document_entitlement_errors


class DocumentEntitlementsTest(unittest.TestCase):
    def setUp(self):
        self.values = {
            "com.apple.developer.icloud-services": ["CloudDocuments"],
            "com.apple.developer.icloud-container-identifiers": ["iCloud.test.library"],
            "com.apple.developer.ubiquity-container-identifiers": ["iCloud.test.library"],
        }

    def test_configured_documents_pass(self):
        self.assertEqual(document_entitlement_errors(self.values), [])

    def test_invalid_plist_root_fails(self):
        self.assertTrue(document_entitlement_errors([]))

    def test_missing_documents_fail(self):
        del self.values["com.apple.developer.ubiquity-container-identifiers"]
        self.assertTrue(document_entitlement_errors(self.values))

    def test_mismatched_containers_fail(self):
        self.values["com.apple.developer.ubiquity-container-identifiers"] = ["iCloud.other"]
        self.assertTrue(document_entitlement_errors(self.values))

    def test_invalid_arrays_fail(self):
        for value in ([], "iCloud.test.library", ["*"], [None], [""]):
            with self.subTest(value=value):
                self.values["com.apple.developer.ubiquity-container-identifiers"] = value
                self.assertTrue(document_entitlement_errors(self.values))

    def test_cloudkit_only_does_not_require_documents(self):
        self.values["com.apple.developer.icloud-services"] = ["CloudKit"]
        del self.values["com.apple.developer.ubiquity-container-identifiers"]
        self.assertEqual(document_entitlement_errors(self.values), [])

    def test_missing_icloud_containers_fail(self):
        del self.values["com.apple.developer.icloud-container-identifiers"]
        self.assertTrue(document_entitlement_errors(self.values))

    def test_invalid_services_fail(self):
        self.values["com.apple.developer.icloud-services"] = "CloudDocuments"
        self.assertTrue(document_entitlement_errors(self.values))


if __name__ == "__main__":
    unittest.main()
