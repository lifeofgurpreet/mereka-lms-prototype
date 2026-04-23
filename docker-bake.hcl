variable "OPENEDX_CONTEXT" {
  default = "tutor_env/env/build/openedx"
}

variable "OPENEDX_DOCKERFILE" {
  default = "Dockerfile"
}

variable "OPENEDX_PROOF_TAG" {
  default = "docker.io/overhangio/openedx:21.0.0"
}

variable "OPENEDX_PROOF_TAGS" {
  default = "docker.io/overhangio/openedx:21.0.0"
}

variable "OPENEDX_FAST_TAG" {
  default = "docker.io/overhangio/openedx:21.0.0-fast"
}

variable "OPENEDX_FAST_TAGS" {
  default = "docker.io/overhangio/openedx:21.0.0-fast"
}

variable "OPENEDX_PRODUCER_TAG" {
  default = "docker.io/overhangio/openedx:21.0.0-producer"
}

variable "OPENEDX_PRODUCER_TAGS" {
  default = "docker.io/overhangio/openedx:21.0.0-producer"
}

variable "OPENEDX_CACHE_REF" {
  default = "docker.io/overhangio/openedx:21.0.0-cache"
}

variable "OPENEDX_PROOF_GHA_SCOPE" {
  default = "tutor-openedx-proof"
}

variable "OPENEDX_RENDERED_DOCKERFILE_SHA256" {
  default = ""
}

variable "OPENEDX_BUILD_CONTEXT_SHA256" {
  default = ""
}

// Shared GHCR registry cache refs (L2 — authoritative)
// See docs/ops/ci-cd/CACHE_AUTHORITY.md and ADR-024
variable "CACHE_TO_OPENEDX" {
  default = ""  // Empty = no cache export; set by workflow on trusted main only
}

variable "MFE_CONTEXT" {
  default = "tutor_env/env/plugins/mfe/build/mfe"
}

variable "MFE_DOCKERFILE" {
  default = "Dockerfile"
}

variable "MFE_RENDERED_CONTEXT" {
  default = "tutor_env/env/plugins/mfe/build/mfe"
}

variable "MFE_RENDERED_DOCKERFILE" {
  default = "Dockerfile"
}

variable "MFE_RENDERED_DOCKERFILE_SHA256" {
  default = ""
}

variable "MFE_BUILD_CONTEXT_SHA256" {
  default = ""
}

variable "MFE_PROOF_TAG" {
  default = "docker.io/overhangio/openedx-mfe:21.0.0"
}

variable "MFE_PROOF_TAGS" {
  default = "docker.io/overhangio/openedx-mfe:21.0.0"
}

variable "MFE_FAST_TAG" {
  default = "docker.io/overhangio/openedx-mfe:21.0.0-fast"
}

variable "MFE_FAST_TAGS" {
  default = "docker.io/overhangio/openedx-mfe:21.0.0-fast"
}

variable "MFE_PRODUCER_TAG" {
  default = "docker.io/overhangio/openedx-mfe:21.0.0-producer"
}

variable "MFE_PRODUCER_TAGS" {
  default = "docker.io/overhangio/openedx-mfe:21.0.0-producer"
}

variable "MFE_CACHE_REF" {
  default = "docker.io/overhangio/openedx-mfe:21.0.0-cache"
}

variable "MFE_PROOF_GHA_SCOPE" {
  default = "tutor-openedx-mfe-proof"
}

variable "CACHE_TO_MFE" {
  default = ""  // Empty = no cache export; set by workflow on trusted main only
}

group "default" {
  targets = ["openedx-proof"]
}

group "proof" {
  targets = ["openedx-proof", "mfe-proof"]
}

group "fast" {
  targets = ["openedx-fast", "mfe-fast"]
}

group "producer" {
  targets = ["openedx-producer", "mfe-producer"]
}

target "_openedx-common" {
  context = "${OPENEDX_CONTEXT}"
  dockerfile = "${OPENEDX_DOCKERFILE}"
  args = {
    MEREKA_BUILD_PROFILE           = "proof"
    BUILDKIT_INLINE_CACHE           = "1"
    MEREKA_CUSTOM_APP_INSTALL_MODE = "editable"
  }
  output = ["type=docker"]
  cache-from = [
    "type=registry,ref=${OPENEDX_CACHE_REF}",
  ]
}

target "openedx-proof" {
  inherits = ["_openedx-common"]
  tags = [for tag in split(",", OPENEDX_PROOF_TAGS) : trimspace(tag) if trimspace(tag) != ""]
  args = {
    MEREKA_BUILD_PROFILE           = "proof"
    MEREKA_CUSTOM_APP_INSTALL_MODE = "noneditable"
  }
  cache-from = [
    // L0 — platform-wide shared base-layer cache (ADR-025 §4). buildx
    // silently skips missing refs, so this is safe to reference before
    // the platform-bases.yml workflow has published its first images.
    "type=registry,ref=ghcr.io/biji-biji-initiative/platform/cache/python3.11-base:latest",
    "type=registry,ref=ghcr.io/biji-biji-initiative/platform/cache/debian-bookworm-base:latest",
    // L2 — shared GHCR registry cache (app-scoped, authoritative per ADR-024)
    "type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64",
    // L3 — final-image fallback (transitional, retire Phase 5)
    "type=registry,ref=${OPENEDX_CACHE_REF}",
  ]
  cache-to = [
    // Set via CACHE_TO_OPENEDX env; empty on non-main builds (RL-5)
    "${CACHE_TO_OPENEDX}",
  ]
  labels = {
    "io.mereka.build-profile"              = "proof"
    "io.mereka.build-scope"                = "openedx"
    "io.mereka.rendered-dockerfile-sha256" = "${OPENEDX_RENDERED_DOCKERFILE_SHA256}"
    "io.mereka.build-context-sha256"       = "${OPENEDX_BUILD_CONTEXT_SHA256}"
  }
}

target "openedx-proof-nocache" {
  context = "${OPENEDX_CONTEXT}"
  dockerfile = "${OPENEDX_DOCKERFILE}"
  args = {
    MEREKA_BUILD_PROFILE           = "proof"
    BUILDKIT_INLINE_CACHE           = "1"
    MEREKA_CUSTOM_APP_INSTALL_MODE = "noneditable"
  }
  output = ["type=docker"]
  tags = [for tag in split(",", OPENEDX_PROOF_TAGS) : trimspace(tag) if trimspace(tag) != ""]
  labels = {
    "io.mereka.build-profile"              = "proof"
    "io.mereka.build-scope"                = "openedx"
    "io.mereka.rendered-dockerfile-sha256" = "${OPENEDX_RENDERED_DOCKERFILE_SHA256}"
    "io.mereka.build-context-sha256"       = "${OPENEDX_BUILD_CONTEXT_SHA256}"
  }
}

target "openedx-fast" {
  inherits = ["_openedx-common"]
  tags = [for tag in split(",", OPENEDX_FAST_TAGS) : trimspace(tag) if trimspace(tag) != ""]
  args = {
    MEREKA_BUILD_PROFILE           = "fast"
    MEREKA_CUSTOM_APP_INSTALL_MODE = "editable"
  }
  // Local Open edX fast builds read registry fallback caches and keep rich reuse
  // in the persistent buildkitd worker cache. Do not add client-side local cache
  // imports or exports here: that creates stale .buildx-cache lanes after image
  // load and can make first-run setup look failed/noisy even when the artifact
  // is already valid.
  cache-to = []
  cache-from = [
    "type=registry,ref=${OPENEDX_CACHE_REF}",
  ]
  labels = {
    "io.mereka.build-profile"              = "fast"
    "io.mereka.build-scope"                = "openedx"
    "io.mereka.rendered-dockerfile-sha256" = "${OPENEDX_RENDERED_DOCKERFILE_SHA256}"
    "io.mereka.build-context-sha256"       = "${OPENEDX_BUILD_CONTEXT_SHA256}"
  }
}

target "openedx-producer" {
  inherits = ["_openedx-common"]
  tags = [for tag in split(",", OPENEDX_PRODUCER_TAGS) : trimspace(tag) if trimspace(tag) != ""]
  args = {
    MEREKA_BUILD_PROFILE           = "producer"
    MEREKA_CUSTOM_APP_INSTALL_MODE = "noneditable"
  }
  output = ["type=cacheonly"]
  labels = {
    "io.mereka.build-profile"              = "producer"
    "io.mereka.build-scope"                = "openedx"
    "io.mereka.rendered-dockerfile-sha256" = "${OPENEDX_RENDERED_DOCKERFILE_SHA256}"
    "io.mereka.build-context-sha256"       = "${OPENEDX_BUILD_CONTEXT_SHA256}"
  }
}

target "_mfe-common" {
  context = "${MFE_CONTEXT}"
  dockerfile = "${MFE_DOCKERFILE}"
  args = {
    BUILDKIT_INLINE_CACHE = "1"
  }
  output = ["type=docker"]
  cache-from = [
    "type=registry,ref=${MFE_CACHE_REF}",
  ]
}

target "mfe-proof" {
  inherits = ["_mfe-common"]
  tags = [for tag in split(",", MFE_PROOF_TAGS) : trimspace(tag) if trimspace(tag) != ""]
  cache-from = [
    // L0 — platform-wide shared base-layer cache (ADR-025 §4). MFE builds
    // use a Node toolchain, so pull the node20 + debian bases. Missing refs
    // are skipped silently by buildx.
    "type=registry,ref=ghcr.io/biji-biji-initiative/platform/cache/node20-base:latest",
    "type=registry,ref=ghcr.io/biji-biji-initiative/platform/cache/debian-bookworm-base:latest",
    // L2 — shared GHCR registry cache (app-scoped, authoritative per ADR-024)
    "type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/cache/mfe:main-amd64",
    // L3 — final-image fallback (transitional, retire Phase 5)
    "type=registry,ref=${MFE_CACHE_REF}",
  ]
  cache-to = [
    // Set via CACHE_TO_MFE env; empty on non-main builds (RL-5)
    "${CACHE_TO_MFE}",
  ]
  labels = {
    "io.mereka.build-profile"              = "proof"
    "io.mereka.build-scope"                = "mfe"
    "io.mereka.rendered-context"           = "${MFE_RENDERED_CONTEXT}"
    "io.mereka.rendered-dockerfile"        = "${MFE_RENDERED_DOCKERFILE}"
    "io.mereka.rendered-dockerfile-sha256" = "${MFE_RENDERED_DOCKERFILE_SHA256}"
    "io.mereka.build-context-sha256"       = "${MFE_BUILD_CONTEXT_SHA256}"
  }
}

target "mfe-proof-nocache" {
  context = "${MFE_CONTEXT}"
  dockerfile = "${MFE_DOCKERFILE}"
  args = {
    BUILDKIT_INLINE_CACHE = "1"
  }
  output = ["type=docker"]
  tags = [for tag in split(",", MFE_PROOF_TAGS) : trimspace(tag) if trimspace(tag) != ""]
  labels = {
    "io.mereka.build-profile"              = "proof"
    "io.mereka.build-scope"                = "mfe"
    "io.mereka.rendered-context"           = "${MFE_RENDERED_CONTEXT}"
    "io.mereka.rendered-dockerfile"        = "${MFE_RENDERED_DOCKERFILE}"
    "io.mereka.rendered-dockerfile-sha256" = "${MFE_RENDERED_DOCKERFILE_SHA256}"
    "io.mereka.build-context-sha256"       = "${MFE_BUILD_CONTEXT_SHA256}"
  }
}

target "mfe-fast" {
  inherits = ["_mfe-common"]
  tags = [for tag in split(",", MFE_FAST_TAGS) : trimspace(tag) if trimspace(tag) != ""]
  // Local MFE fast builds read registry fallback caches and keep rich reuse in
  // the persistent buildkitd worker cache. Do not add client-side local cache
  // imports or exports here: that creates stale .buildx-cache lanes after image
  // load and can make first-run setup look hung even when the artifact is already
  // valid.
  cache-to = []
  cache-from = [
    "type=registry,ref=${MFE_CACHE_REF}",
  ]
  labels = {
    "io.mereka.build-profile"              = "fast"
    "io.mereka.build-scope"                = "mfe"
    "io.mereka.rendered-context"           = "${MFE_RENDERED_CONTEXT}"
    "io.mereka.rendered-dockerfile"        = "${MFE_RENDERED_DOCKERFILE}"
    "io.mereka.rendered-dockerfile-sha256" = "${MFE_RENDERED_DOCKERFILE_SHA256}"
    "io.mereka.build-context-sha256"       = "${MFE_BUILD_CONTEXT_SHA256}"
  }
}

target "mfe-producer" {
  inherits = ["_mfe-common"]
  tags = [for tag in split(",", MFE_PRODUCER_TAGS) : trimspace(tag) if trimspace(tag) != ""]
  output = ["type=cacheonly"]
  labels = {
    "io.mereka.build-profile"              = "producer"
    "io.mereka.build-scope"                = "mfe"
    "io.mereka.rendered-context"           = "${MFE_RENDERED_CONTEXT}"
    "io.mereka.rendered-dockerfile"        = "${MFE_RENDERED_DOCKERFILE}"
    "io.mereka.rendered-dockerfile-sha256" = "${MFE_RENDERED_DOCKERFILE_SHA256}"
    "io.mereka.build-context-sha256"       = "${MFE_BUILD_CONTEXT_SHA256}"
  }
}
