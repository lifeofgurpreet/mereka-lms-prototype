variable "OPENEDX_CONTEXT" {
  default = "tutor_env/env/build/openedx"
}

variable "OPENEDX_DOCKERFILE" {
  default = "Dockerfile"
}

variable "OPENEDX_PROOF_TAG" {
  default = "docker.io/overhangio/openedx:21.0.0-indigo"
}

variable "OPENEDX_PROOF_TAGS" {
  type    = list(string)
  default = ["docker.io/overhangio/openedx:21.0.0-indigo"]
}

variable "OPENEDX_FAST_TAG" {
  default = "docker.io/overhangio/openedx:21.0.0-indigo-fast"
}

variable "OPENEDX_FAST_TAGS" {
  type    = list(string)
  default = ["docker.io/overhangio/openedx:21.0.0-indigo-fast"]
}

variable "OPENEDX_PRODUCER_TAG" {
  default = "docker.io/overhangio/openedx:21.0.0-indigo-producer"
}

variable "OPENEDX_PRODUCER_TAGS" {
  type    = list(string)
  default = ["docker.io/overhangio/openedx:21.0.0-indigo-producer"]
}

variable "OPENEDX_CACHE_REF" {
  default = "docker.io/overhangio/openedx:21.0.0-indigo-cache"
}

variable "OPENEDX_PROOF_GHA_SCOPE" {
  default = "tutor-openedx-proof"
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

variable "MFE_PROOF_TAG" {
  default = "docker.io/overhangio/openedx-mfe:21.0.0-indigo"
}

variable "MFE_PROOF_TAGS" {
  type    = list(string)
  default = ["docker.io/overhangio/openedx-mfe:21.0.0-indigo"]
}

variable "MFE_FAST_TAG" {
  default = "docker.io/overhangio/openedx-mfe:21.0.0-indigo-fast"
}

variable "MFE_FAST_TAGS" {
  type    = list(string)
  default = ["docker.io/overhangio/openedx-mfe:21.0.0-indigo-fast"]
}

variable "MFE_PRODUCER_TAG" {
  default = "docker.io/overhangio/openedx-mfe:21.0.0-indigo-producer"
}

variable "MFE_PRODUCER_TAGS" {
  type    = list(string)
  default = ["docker.io/overhangio/openedx-mfe:21.0.0-indigo-producer"]
}

variable "MFE_CACHE_REF" {
  default = "docker.io/overhangio/openedx-mfe:21.0.0-indigo-cache"
}

variable "MFE_PROOF_GHA_SCOPE" {
  default = "tutor-openedx-mfe-proof"
}

variable "LOCAL_CACHE_DIR" {
  default = ".buildx-cache"
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
    "type=local,src=${LOCAL_CACHE_DIR}/openedx",
  ]
  cache-to = [
    "type=local,dest=${LOCAL_CACHE_DIR}/openedx,mode=max",
  ]
}

target "openedx-proof" {
  inherits = ["_openedx-common"]
  tags = OPENEDX_PROOF_TAGS
  args = {
    MEREKA_BUILD_PROFILE           = "proof"
    MEREKA_CUSTOM_APP_INSTALL_MODE = "noneditable"
  }
  cache-from = [
    "type=gha,scope=${OPENEDX_PROOF_GHA_SCOPE}",
    "type=registry,ref=${OPENEDX_CACHE_REF}",
  ]
  cache-to = [
    "type=gha,mode=max,scope=${OPENEDX_PROOF_GHA_SCOPE}",
  ]
  labels = {
    "io.mereka.build-profile" = "proof"
    "io.mereka.build-scope"   = "openedx"
  }
}

target "openedx-fast" {
  inherits = ["_openedx-common"]
  tags = OPENEDX_FAST_TAGS
  args = {
    MEREKA_BUILD_PROFILE           = "fast"
    MEREKA_CUSTOM_APP_INSTALL_MODE = "editable"
  }
  cache-to = [
    "type=local,dest=${LOCAL_CACHE_DIR}/openedx-fast,mode=max",
  ]
  labels = {
    "io.mereka.build-profile" = "fast"
    "io.mereka.build-scope"   = "openedx"
  }
}

target "openedx-producer" {
  inherits = ["_openedx-common"]
  tags = OPENEDX_PRODUCER_TAGS
  args = {
    MEREKA_BUILD_PROFILE           = "producer"
    MEREKA_CUSTOM_APP_INSTALL_MODE = "noneditable"
  }
  output = ["type=cacheonly"]
  labels = {
    "io.mereka.build-profile" = "producer"
    "io.mereka.build-scope"   = "openedx"
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
    "type=local,src=${LOCAL_CACHE_DIR}/mfe",
  ]
  cache-to = [
    "type=local,dest=${LOCAL_CACHE_DIR}/mfe,mode=max",
  ]
}

target "mfe-proof" {
  inherits = ["_mfe-common"]
  tags = MFE_PROOF_TAGS
  cache-from = [
    "type=gha,scope=${MFE_PROOF_GHA_SCOPE}",
    "type=registry,ref=${MFE_CACHE_REF}",
  ]
  cache-to = [
    "type=gha,mode=max,scope=${MFE_PROOF_GHA_SCOPE}",
  ]
  labels = {
    "io.mereka.build-profile"              = "proof"
    "io.mereka.build-scope"                = "mfe"
    "io.mereka.rendered-context"           = "${MFE_RENDERED_CONTEXT}"
    "io.mereka.rendered-dockerfile"        = "${MFE_RENDERED_DOCKERFILE}"
    "io.mereka.rendered-dockerfile-sha256" = "${MFE_RENDERED_DOCKERFILE_SHA256}"
  }
}

target "mfe-fast" {
  inherits = ["_mfe-common"]
  tags = MFE_FAST_TAGS
  cache-to = [
    "type=local,dest=${LOCAL_CACHE_DIR}/mfe-fast,mode=max",
  ]
  labels = {
    "io.mereka.build-profile"              = "fast"
    "io.mereka.build-scope"                = "mfe"
    "io.mereka.rendered-context"           = "${MFE_RENDERED_CONTEXT}"
    "io.mereka.rendered-dockerfile"        = "${MFE_RENDERED_DOCKERFILE}"
    "io.mereka.rendered-dockerfile-sha256" = "${MFE_RENDERED_DOCKERFILE_SHA256}"
  }
}

target "mfe-producer" {
  inherits = ["_mfe-common"]
  tags = MFE_PRODUCER_TAGS
  output = ["type=cacheonly"]
  labels = {
    "io.mereka.build-profile"              = "producer"
    "io.mereka.build-scope"                = "mfe"
    "io.mereka.rendered-context"           = "${MFE_RENDERED_CONTEXT}"
    "io.mereka.rendered-dockerfile"        = "${MFE_RENDERED_DOCKERFILE}"
    "io.mereka.rendered-dockerfile-sha256" = "${MFE_RENDERED_DOCKERFILE_SHA256}"
  }
}
