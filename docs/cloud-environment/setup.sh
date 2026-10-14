#!/bin/bash
# Cloud environment setup script for the psyduck repositories and the dev-team plugin.
#
# Paste this whole file into the "Setup script" field of a Claude Code cloud environment
# (claude.ai/code, environment selector, Edit). It runs as root on Ubuntu 24.04 before Claude
# Code starts, must exit 0, and must finish in about five minutes for the environment to be
# cached. Every step below is idempotent, so re-running it is safe.
#
# What it installs on top of the stock image:
#   - PostgreSQL ${PG_MAJOR} on port 5432, role postgres / postgres, database psyduck_db
#   - Node.js ${NODE_MAJOR} at /opt/node${NODE_MAJOR} (the frontend's .nvmrc); Node 22 stays the default
#     in the shell Claude runs commands in
#   - uv-managed Python ${PY_VERSION} for the backend
#   - AWS CLI v2 and the CDK CLI
#   - the dev-team plugin, installed from a copy of the my-dev-team checkout kept at
#     ${MARKETPLACE_DIR} so it survives in the environment snapshot
#
# When the repositories are already checked out under /home/user it also runs `uv sync` and
# `npm ci` in each one so the package caches are warm. Otherwise the per-repo install steps are
# skipped and each repo's README says how to run them.
#
# Postgres is a process, and the environment cache keeps files, not processes. Each session
# starts it with `psyduck-db start` (installed below).

set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
export PATH="/root/.local/bin:/usr/local/bin:/opt/node22/bin:${PATH}"

PG_MAJOR=18
NODE_MAJOR=24
PY_VERSION=3.14
MARKETPLACE_DIR=/opt/dev-team-marketplace
MARKETPLACE_NAME=ksco92
PLUGIN_NAME=dev-team
REPO_ROOTS=(/home/user "${PWD}" "${PWD}/..")

log() { echo "==> $*"; }
warn() { echo "WARNING: $*" >&2; }

# Returns the first directory named $1 under the candidate repo roots.
find_repo() {
    local name="$1" root
    for root in "${REPO_ROOTS[@]}"; do
        if [ -d "${root}/${name}/.git" ]; then
            (cd "${root}/${name}" && pwd -P)
            return 0
        fi
    done
    return 1
}

# ---------------------------------------------------------------- PostgreSQL
install_postgres() {
    if [ -x "/usr/lib/postgresql/${PG_MAJOR}/bin/postgres" ]; then
        log "PostgreSQL ${PG_MAJOR} already installed"
    else
        log "Installing PostgreSQL ${PG_MAJOR} from apt.postgresql.org"
        install -d /usr/share/postgresql-common/pgdg
        curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
            -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc || return 1
        echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt noble-pgdg main" \
            > /etc/apt/sources.list.d/pgdg.list
        # The stock image ships a stopped PostgreSQL 16 cluster on 5432. Drop it first so the
        # new major's cluster takes that port instead of 5433.
        if pg_lsclusters -h 2>/dev/null | grep -q "^16 "; then
            pg_dropcluster --stop 16 main || warn "could not drop the PostgreSQL 16 cluster"
        fi
        apt-get update -qq || return 1
        apt-get install -y -qq "postgresql-${PG_MAJOR}" "postgresql-client-${PG_MAJOR}" || return 1
    fi

    if ! pg_lsclusters -h | grep -q "^${PG_MAJOR} main"; then
        pg_createcluster --port 5432 "${PG_MAJOR}" main || return 1
    fi
    pg_ctlcluster "${PG_MAJOR}" main start || true
    for _ in $(seq 1 30); do
        su postgres -c "pg_isready -q" && break
        sleep 1
    done
    # Matches psyduck_backend/.env.example: postgres/postgres on 127.0.0.1:5432, db psyduck_db.
    su postgres -c "psql -q -c \"ALTER USER postgres PASSWORD 'postgres';\"" || return 1
    su postgres -c "psql -tAq -c \"SELECT 1 FROM pg_database WHERE datname='psyduck_db'\"" | grep -q 1 \
        || su postgres -c "createdb psyduck_db" || return 1

    cat > /usr/local/bin/psyduck-db <<HELPER
#!/bin/bash
# Start, stop, or check the local PostgreSQL ${PG_MAJOR} cluster the psyduck backend uses.
case "\${1:-status}" in
    start)  pg_ctlcluster ${PG_MAJOR} main start && pg_isready -h 127.0.0.1 -p 5432 ;;
    stop)   pg_ctlcluster ${PG_MAJOR} main stop ;;
    status) pg_lsclusters ;;
    *)      echo "usage: psyduck-db [start|stop|status]" >&2; exit 2 ;;
esac
HELPER
    chmod +x /usr/local/bin/psyduck-db
}

# ------------------------------------------------------------------- Node.js
install_node() {
    local prefix="/opt/node${NODE_MAJOR}" version tarball
    if [ -x "${prefix}/bin/node" ]; then
        log "Node.js ${NODE_MAJOR} already installed at ${prefix}"
    else
        log "Installing Node.js ${NODE_MAJOR} to ${prefix}"
        version="$(curl -fsSL "https://nodejs.org/dist/latest-v${NODE_MAJOR}.x/SHASUMS256.txt" \
            | grep -o "node-v${NODE_MAJOR}\.[0-9]*\.[0-9]*-linux-x64\.tar\.xz" | head -1)" || return 1
        [ -n "${version}" ] || return 1
        tarball="/tmp/${version}"
        curl -fsSL "https://nodejs.org/dist/latest-v${NODE_MAJOR}.x/${version}" -o "${tarball}" || return 1
        install -d "${prefix}"
        tar -xJf "${tarball}" -C "${prefix}" --strip-components=1 || return 1
        rm -f "${tarball}"
    fi
    # Login and interactive shells get Node ${NODE_MAJOR} first on PATH. The shell Claude runs
    # commands in does not read these files, so it keeps the image default, Node 22, which the
    # frontend's engines field accepts; prefix PATH=${prefix}/bin to a command that needs 24.
    echo "export PATH=\"${prefix}/bin:\$PATH\"" > /etc/profile.d/node24.sh
    grep -q "${prefix}/bin" /root/.bashrc 2>/dev/null \
        || echo "export PATH=\"${prefix}/bin:\$PATH\"" >> /root/.bashrc
    # The CDK CLI as a global command, per psyduck_cdk/README.md. The default npm installs it
    # into the global prefix that is on PATH in every session; `npx cdk` works regardless.
    npm install -g --no-fund --no-audit aws-cdk >/dev/null || return 1
}

# -------------------------------------------------------------------- Python
install_python() {
    if ! command -v uv >/dev/null; then
        log "Installing uv"
        curl -fsSL https://astral.sh/uv/install.sh | sh || return 1
    fi
    log "Installing Python ${PY_VERSION} with uv"
    uv python install "${PY_VERSION}" || return 1
}

# ------------------------------------------------------------------- AWS CLI
install_awscli() {
    if command -v aws >/dev/null; then
        log "AWS CLI already installed"
        return 0
    fi
    log "Installing AWS CLI v2"
    local tmp
    tmp="$(mktemp -d)"
    curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o "${tmp}/awscliv2.zip" || return 1
    unzip -q "${tmp}/awscliv2.zip" -d "${tmp}" || return 1
    "${tmp}/aws/install" --update >/dev/null || return 1
    rm -rf "${tmp}"
}

# --------------------------------------------------------- per-repo installs
prepare_backend() {
    local dir
    dir="$(find_repo psyduck_backend)" || { log "psyduck_backend not checked out, skipping uv sync"; return 0; }
    log "uv sync in ${dir}"
    (cd "${dir}" && uv sync && { [ -f .env ] || cp .env.example .env; }) || return 1
}

prepare_frontend() {
    local dir
    dir="$(find_repo psyduck_frontend)" || { log "psyduck_frontend not checked out, skipping npm ci"; return 0; }
    log "npm ci in ${dir}"
    (cd "${dir}" && PATH="/opt/node${NODE_MAJOR}/bin:${PATH}" npm ci --no-fund --no-audit) || return 1
}

prepare_cdk() {
    local dir
    dir="$(find_repo psyduck_cdk)" || { log "psyduck_cdk not checked out, skipping npm ci"; return 0; }
    log "npm ci in ${dir}"
    (cd "${dir}" && PATH="/opt/node${NODE_MAJOR}/bin:${PATH}" npm ci --no-fund --no-audit) || return 1
}

# -------------------------------------------------------------------- plugin
install_plugin() {
    local checkout claude_bin
    claude_bin="$(command -v claude || echo /opt/node22/bin/claude)"
    [ -x "${claude_bin}" ] || { warn "claude CLI not found, skipping plugin install"; return 1; }

    # Keep a copy of the marketplace outside the session's clones: the plugin is read from the
    # marketplace directory on every session, including sessions that don't check out
    # my-dev-team. The copy is refreshed from a checkout when one is present, or cloned.
    if checkout="$(find_repo my-dev-team)"; then
        log "Copying ${checkout} to ${MARKETPLACE_DIR}"
        rm -rf "${MARKETPLACE_DIR}"
        cp -a "${checkout}" "${MARKETPLACE_DIR}" || return 1
    elif [ -d "${MARKETPLACE_DIR}/.git" ]; then
        log "Refreshing ${MARKETPLACE_DIR}"
        git -C "${MARKETPLACE_DIR}" pull --ff-only -q || warn "could not refresh ${MARKETPLACE_DIR}, keeping the cached copy"
    else
        log "Cloning ksco92/my-dev-team to ${MARKETPLACE_DIR}"
        git clone --depth 1 -q https://github.com/ksco92/my-dev-team "${MARKETPLACE_DIR}" || {
            warn "could not clone ksco92/my-dev-team (private repository and no checkout present); plugin not installed"
            return 1
        }
    fi

    log "Installing ${PLUGIN_NAME}@${MARKETPLACE_NAME}"
    "${claude_bin}" plugin marketplace remove "${MARKETPLACE_NAME}" >/dev/null 2>&1 || true
    "${claude_bin}" plugin marketplace add "${MARKETPLACE_DIR}" || return 1
    "${claude_bin}" plugin install "${PLUGIN_NAME}@${MARKETPLACE_NAME}" || return 1
    "${claude_bin}" plugin list | grep -A3 "${PLUGIN_NAME}@${MARKETPLACE_NAME}" || true
}

# ---------------------------------------------------------------------- main
start=$(date +%s)
status=0

# Toolchains download independently; run them side by side to stay under the cache limit.
install_postgres & pid_pg=$!
install_node     & pid_node=$!
install_python   & pid_py=$!
install_awscli   & pid_aws=$!
wait "${pid_pg}"   || { warn "PostgreSQL setup failed"; status=1; }
wait "${pid_node}" || { warn "Node.js setup failed"; status=1; }
wait "${pid_py}"   || { warn "Python setup failed"; status=1; }
wait "${pid_aws}"  || { warn "AWS CLI setup failed"; status=1; }

prepare_backend  & pid_be=$!
prepare_frontend & pid_fe=$!
prepare_cdk      & pid_cdk=$!
wait "${pid_be}"  || { warn "backend dependency install failed"; status=1; }
wait "${pid_fe}"  || { warn "frontend dependency install failed"; status=1; }
wait "${pid_cdk}" || { warn "cdk dependency install failed"; status=1; }

install_plugin || status=1

log "Setup finished in $(( $(date +%s) - start ))s with status ${status}"
log "node: $(/opt/node${NODE_MAJOR}/bin/node --version 2>/dev/null || echo missing)," \
    "python: $(uv python find "${PY_VERSION}" 2>/dev/null || echo missing)," \
    "postgres: $(pg_lsclusters -h 2>/dev/null | awk '{print $1" "$4}' | head -1)," \
    "aws: $(aws --version 2>/dev/null || echo missing)"

# A failed optional step must not block the session from starting; it is reported above.
exit 0
