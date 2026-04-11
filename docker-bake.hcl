variable "OPENEDX_CONTEXT" {
  default = "tutor_env/env/build/openedx"
}

variable "OPENEDX_DOCKERFILE" {
  default = "tutor_env/env/build/openedx/Dockerfile"
}

variable "OPENEDX_PROOF_TAG" {
  default = "docker.io/overhangio/openedx:21.0.0-indigo"
}

variable "OPENEDX_FAST_TAG" {
  default = "docker.io/overhangio/openedx:21.0.0-indigo-fast"
}

variable "OPENEDX_CACHE_REF" {
  default = "docker.io/overhangio/openedx:21.0.0-indigo-cache"
}

variable "MFE_CONTEXT" {
  default = "tutor_env/env/plugins/mfe/build/mfe"
}

variable "MFE_DOCKERFILE" {
  default = "tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
}

variable "MFE_PROOF_TAG" {
  default = "docker.io/overhangio/openedx-mfe:21.0.0-indigo"
}

variable "MFE_FAST_TAG" {
  default = "docker.io/overhangio/openedx-mfe:21.0.0-indigo-fast"
}

variable "MFE_COMPAT_TAG" {
  default = "docker.io/overhangio/openedx-mfe:21.0.0-indigo-compat"
}

variable "MFE_CACHE_REF" {
  default = "docker.io/overhangio/openedx-mfe:21.0.0-indigo-cache"
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

group "compat" {
  targets = ["mfe-compat"]
}

target "_openedx-common" {
  context = "${OPENEDX_CONTEXT}"
  dockerfile = "${OPENEDX_DOCKERFILE}"
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
  tags = ["${OPENEDX_PROOF_TAG}"]
  labels = {
    "io.mereka.build-profile" = "proof"
    "io.mereka.build-scope"   = "openedx"
  }
}

target "openedx-fast" {
  inherits = ["_openedx-common"]
  tags = ["${OPENEDX_FAST_TAG}"]
  cache-to = [
    "type=local,dest=${LOCAL_CACHE_DIR}/openedx-fast,mode=max",
    "type=registry,ref=${OPENEDX_CACHE_REF},mode=max",
  ]
  labels = {
    "io.mereka.build-profile" = "fast"
    "io.mereka.build-scope"   = "openedx"
  }
}

target "_mfe-common" {
  context = "${MFE_CONTEXT}"
  dockerfile = "${MFE_DOCKERFILE}"
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
  tags = ["${MFE_PROOF_TAG}"]
  labels = {
    "io.mereka.build-profile" = "proof"
    "io.mereka.build-scope"   = "mfe"
  }
}

target "mfe-fast" {
  inherits = ["_mfe-common"]
  tags = ["${MFE_FAST_TAG}"]
  cache-to = [
    "type=local,dest=${LOCAL_CACHE_DIR}/mfe-fast,mode=max",
    "type=registry,ref=${MFE_CACHE_REF},mode=max",
  ]
  labels = {
    "io.mereka.build-profile" = "fast"
    "io.mereka.build-scope"   = "mfe"
  }
}

target "mfe-compat" {
  inherits = ["mfe-proof"]
  tags = ["${MFE_COMPAT_TAG}"]
  labels = {
    "io.mereka.build-profile" = "compat"
    "io.mereka.build-scope"   = "mfe"
  }
}
