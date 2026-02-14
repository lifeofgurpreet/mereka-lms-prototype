"""
Verifiable Credentials issuer identity and DID document endpoint.

This Django app provides the DID (Decentralized Identifier) document endpoint
for the Credentials Service, enabling verifiers to resolve the issuer's public
key and verify signed verifiable credentials.

@covers AC-CRED-010, AC-CRED-011
@spec: verifiable-credentials-issuer_spec.md (CRED-020)
"""

__version__ = '1.0.0'
