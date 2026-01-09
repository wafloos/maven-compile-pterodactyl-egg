#!/bin/ash
set -euo pipefail

log() { printf '%s\n' "$*"; }

REEXEC_FLAG_VAR=REEXEC_DONE

if [ "${!REEXEC_FLAG_VAR:-}" != "1" ] && [ "$(id -u)" = "0" ] && [ -n "${PUID:-}" ]; then
  PGID=${PGID:-${PUID}}
  log "PUID/PGID provided; creating/ensuring user with UID=${PUID}, GID=${PGID} and re-execing as that user"
  addgroup -g "${PGID}" container 2>/dev/null || true
  adduser -D -u "${PUID}" -G container -h /home/container container 2>/dev/null || true
  chown -R "${PUID}:${PGID}" /home/container || true
  export ${REEXEC_FLAG_VAR}=1
  exec su-exec "${PUID}:${PGID}" "$0" "$@"
fi

: "${HOME:=/home/container}"
: "${PLUGIN_PATHS:=/home/container/*}"
: "${MAVEN_OPTS:=-Xmx512m}"
: "${MAVEN_SETTINGS:=}"
: "${OUT_DIR:=}"
: "${PLUGIN_DIR:=}"
: "${KEEP_ALIVE:=false}"

export HOME MAVEN_OPTS MAVEN_SETTINGS OUT_DIR KEEP_ALIVE

INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2);exit}' || true)
export INTERNAL_IP

log "HOME=${HOME}"
[ -n "${PLUGIN_DIR}" ] && log "PLUGIN_DIR set to ${PLUGIN_DIR}" || log "PLUGIN_PATHS=${PLUGIN_PATHS}"
[ -n "${MAVEN_SETTINGS}" ] && log "MAVEN_SETTINGS=${MAVEN_SETTINGS}"
log "MAVEN_OPTS=${MAVEN_OPTS}"
[ -n "${OUT_DIR}" ] && { log "OUT_DIR=${OUT_DIR} (artifacts will be copied there)"; mkdir -p "${OUT_DIR}"; }

if [ -n "${PLUGIN_DIR}" ]; then
  case "${PLUGIN_DIR}" in
    /*) primary_paths="${PLUGIN_DIR}" ;;
    *) primary_paths="${HOME%/}/${PLUGIN_DIR}" ;;
  esac
else
  primary_paths="${PLUGIN_PATHS}"
fi

paths_clean=$(printf '%s' "${primary_paths}" | tr ';:' ',')

OLDIFS=$IFS
IFS=,
for entry in $paths_clean; do
  entry=$(printf '%s' "$entry" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//' -e 's/^"//' -e 's/"$//')
  [ -z "$entry" ] && continue

  case "$entry" in
    /*) expanded="$entry" ;;
    *)   expanded="${HOME%/}/$entry" ;;
  esac

  set -- $expanded
  if [ $# -eq 1 ] && [ "$1" = "$expanded" ] && [ ! -e "$1" ]; then
    log "No match for: $expanded — skipping"
    set --
    continue
  fi

  for candidate in "$@"; do
    if [ -f "$candidate" ]; then
      candidate_dir=$(dirname "$candidate")
    else
      candidate_dir="$candidate"
    fi

    [ -d "$candidate_dir" ] || { log "Skipping non-directory: $candidate_dir"; continue; }

    if [ -f "${candidate_dir%/}/pom.xml" ]; then
      proj_list="${candidate_dir%/}"
    else
      proj_list=$(find "${candidate_dir%/}" -name 'pom.xml' 2>/dev/null | xargs -r -n1 dirname || true)
      [ -z "$proj_list" ] && { log "No pom.xml under ${candidate_dir}; skipping"; continue; }
    fi

    printf '%s\n' "${proj_list}" | while IFS= read -r proj || [ -n "$proj" ]; do
      [ -z "$proj" ] && continue
      proj_dir="${proj%/}"
      log "Building: ${proj_dir}"

      if [ -x "${proj_dir}/mvnw" ]; then
        mvn_cmd="${proj_dir}/mvnw"
      else
        mvn_cmd="mvn"
      fi

      if [ -n "${MAVEN_SETTINGS}" ]; then
        (cd "${proj_dir}" && MAVEN_OPTS="${MAVEN_OPTS}" "${mvn_cmd}" -f "${proj_dir}/pom.xml" -s "${MAVEN_SETTINGS}" -DskipTests package -T 1C)
      else
        (cd "${proj_dir}" && MAVEN_OPTS="${MAVEN_OPTS}" "${mvn_cmd}" -f "${proj_dir}/pom.xml" -DskipTests package -T 1C)
      fi

      # Copy artifacts if OUT_DIR is set
      if [ -n "${OUT_DIR}" ]; then
        copied=false
        for art in "${proj_dir}"/target/*.jar "${proj_dir}"/target/*.war; do
          if [ -f "$art" ]; then
            cp -v "$art" "${OUT_DIR}/"
            copied=true
          fi
        done
        [ "$copied" = true ] || log "No artifacts in ${proj_dir}/target to copy"
      else
        log "Leaving artifact(s) in ${proj_dir}/target"
      fi
    done
  done
  set --
done
IFS=$OLDIFS

log "Build(s) finished."

if [ "${KEEP_ALIVE}" = "true" ] || [ "${KEEP_ALIVE}" = "1" ]; then
  log "KEEP_ALIVE is true; keeping container alive (tail -f /dev/null)"
  tail -f /dev/null
fi

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

exit 0
