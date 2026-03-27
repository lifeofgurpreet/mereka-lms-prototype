# Secret Manager Module (stub)

Responsible for provisioning Google Secret Manager entries used by Tutor (Django secret key, JWT private key, database passwords, SMTP credentials, etc.).

Populate the `secrets` variable via tfvars to avoid committing plaintext secrets.
