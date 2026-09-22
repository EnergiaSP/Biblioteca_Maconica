"""Validate document-container entitlements without accessing a user's cloud."""

from collections.abc import Mapping


def document_entitlement_errors(entitlements: Mapping) -> list[str]:
    if not isinstance(entitlements, Mapping):
        return ["entitlements must be a dictionary"]
    services = entitlements.get("com.apple.developer.icloud-services", [])
    if not isinstance(services, list):
        return ["iCloud services must be an array"]
    if "CloudDocuments" not in services:
        return []
    containers = entitlements.get("com.apple.developer.icloud-container-identifiers")
    documents = entitlements.get("com.apple.developer.ubiquity-container-identifiers")
    for label, values in (("iCloud containers", containers), ("document containers", documents)):
        if not isinstance(values, list) or not values or any(
            not isinstance(value, str) or not value.strip() or "*" in value for value in values
        ):
            return [f"{label} must be a nonempty array of explicit identifiers"]
    if not set(documents).issubset(containers):
        return ["document containers must belong to the configured iCloud containers"]
    return []
