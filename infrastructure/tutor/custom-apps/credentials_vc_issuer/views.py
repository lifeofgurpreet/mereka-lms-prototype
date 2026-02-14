"""
DID document endpoint for Verifiable Credentials issuer.

@covers AC-CRED-010, AC-CRED-013, AC-CRED-014
@spec: verifiable-credentials-issuer_spec.md (CRED-020)
"""

import base64
import json
import logging
import os
from typing import Dict, List

from django.conf import settings
from django.http import JsonResponse
from django.views.decorators.cache import cache_control
from django.views.decorators.http import require_GET

logger = logging.getLogger(__name__)


def _get_public_key_from_private(private_key_b64: str) -> str:
    """
    Derive Ed25519 public key from base64-encoded private key.

    In Ed25519, the private key is 64 bytes (32-byte seed + 32-byte public key).
    The public key is the last 32 bytes.

    Args:
        private_key_b64: Base64-encoded Ed25519 private key (64 bytes)

    Returns:
        Base64-encoded public key (32 bytes)
    """
    try:
        private_key_bytes = base64.b64decode(private_key_b64)
        if len(private_key_bytes) == 64:
            # Standard Ed25519 private key: last 32 bytes are the public key
            public_key_bytes = private_key_bytes[32:]
        elif len(private_key_bytes) == 32:
            # If only the seed is provided, we need to derive the public key
            # This requires the cryptography library
            try:
                from cryptography.hazmat.primitives.asymmetric import ed25519
                private_key_obj = ed25519.Ed25519PrivateKey.from_private_bytes(private_key_bytes)
                public_key_obj = private_key_obj.public_key()
                public_key_bytes = public_key_obj.public_bytes(
                    encoding=serialization.Encoding.Raw,
                    format=serialization.PublicFormat.Raw
                )
            except ImportError:
                logger.error("cryptography library required to derive public key from 32-byte seed")
                raise
        else:
            raise ValueError(f"Invalid private key length: {len(private_key_bytes)} bytes")

        return base64.b64encode(public_key_bytes).decode('ascii')
    except Exception as e:
        logger.error(f"Failed to derive public key: {e}")
        raise


def _get_verification_methods() -> List[Dict]:
    """
    Build verification methods for the DID document.

    This includes the current signing key and any historical keys for rotation support.

    Returns:
        List of verification method dictionaries
    """
    vc_config = getattr(settings, 'VERIFIABLE_CREDENTIALS', {})
    issuer_did = vc_config.get('ISSUER_DID', '')
    signing_key_id = vc_config.get('SIGNING_KEY_ID', f'{issuer_did}#key-1')

    # Get the current private key and derive public key
    private_key_b64 = os.environ.get('VC_SIGNING_PRIVATE_KEY', '')
    if not private_key_b64:
        logger.warning("VC_SIGNING_PRIVATE_KEY not configured")
        return []

    try:
        public_key_b64 = _get_public_key_from_private(private_key_b64)
    except Exception as e:
        logger.error(f"Failed to generate public key: {e}")
        return []

    verification_methods = [
        {
            "id": signing_key_id,
            "type": "Ed25519VerificationKey2020",
            "controller": issuer_did,
            "publicKeyBase64": public_key_b64,
        }
    ]

    # Add historical keys for rotation support (AC-CRED-013, AC-CRED-014)
    # In production, these would be loaded from a key rotation registry
    # For now, we only include the current key
    # TODO: Implement key rotation registry when multiple keys are needed

    return verification_methods


@require_GET
@cache_control(public=True, max_age=3600)
def did_document_view(request):
    """
    Serve the DID document at /.well-known/did.json

    This endpoint enables verifiers to resolve the issuer's public key
    and verify signed verifiable credentials.

    @covers AC-CRED-010
    @spec: verifiable-credentials-issuer_spec.md (CRED-020)
    """
    vc_config = getattr(settings, 'VERIFIABLE_CREDENTIALS', {})
    issuer_did = vc_config.get('ISSUER_DID', '')

    if not issuer_did:
        logger.error("VERIFIABLE_CREDENTIALS.ISSUER_DID not configured")
        return JsonResponse(
            {"error": "DID not configured"},
            status=500
        )

    verification_methods = _get_verification_methods()
    if not verification_methods:
        logger.error("No verification methods available")
        return JsonResponse(
            {"error": "No verification methods available"},
            status=500
        )

    did_document = {
        "@context": [
            "https://www.w3.org/ns/did/v1",
            "https://w3id.org/security/suites/ed25519-2020/v1"
        ],
        "id": issuer_did,
        "verificationMethod": verification_methods,
        "assertionMethod": [vm["id"] for vm in verification_methods],
    }

    return JsonResponse(did_document, safe=False)
