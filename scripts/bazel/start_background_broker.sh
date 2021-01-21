#!/usr/bin/env bash
set -exuo pipefail

# pwd
# /usr/local/bin/tree

TEST_TMPDIR=${TEST_TMPDIR:=${TMPDIR}/rabbitmq-test-instances}
RABBITMQ_SCRIPTS_DIR=${PWD}/sbin
RABBITMQ_PLUGINS=${RABBITMQ_SCRIPTS_DIR}/rabbitmq-plugins
RABBITMQ_SERVER=${RABBITMQ_SCRIPTS_DIR}/rabbitmq-server
RABBITMQCTL=${RABBITMQ_SCRIPTS_DIR}/rabbitmqctl

export RABBITMQ_SCRIPTS_DIR RABBITMQCTL RABBITMQ_PLUGINS RABBITMQ_SERVER

HOSTNAME="$(hostname -s)"

RABBITMQ_NODENAME=rabbit@${HOSTNAME}
RABBITMQ_NODENAME_FOR_PATHS=${RABBITMQ_NODENAME}
NODE_TMPDIR=${TEST_TMPDIR}/${RABBITMQ_NODENAME_FOR_PATHS}

RABBITMQ_BASE=${NODE_TMPDIR}
RABBITMQ_PID_FILE=${NODE_TMPDIR}/${RABBITMQ_NODENAME_FOR_PATHS}.pid
RABBITMQ_LOG_BASE=${NODE_TMPDIR}/log
RABBITMQ_MNESIA_BASE=${NODE_TMPDIR}/mnesia
RABBITMQ_MNESIA_DIR=${RABBITMQ_MNESIA_BASE}/${RABBITMQ_NODENAME_FOR_PATHS}
RABBITMQ_QUORUM_DIR=${RABBITMQ_MNESIA_DIR}/quorum
RABBITMQ_STREAM_DIR=${RABBITMQ_MNESIA_DIR}/stream
RABBITMQ_PLUGINS_DIR=${PWD}/plugins
RABBITMQ_PLUGINS_EXPAND_DIR=${NODE_TMPDIR}/plugins
RABBITMQ_FEATURE_FLAGS_FILE=${NODE_TMPDIR}/feature_flags
RABBITMQ_ENABLED_PLUGINS_FILE=${NODE_TMPDIR}/enabled_plugins

# Enable colourful debug logging by default
# To change this, set RABBITMQ_LOG to info, notice, warning etc.
RABBITMQ_LOG='debug,+color'
export RABBITMQ_LOG

RABBITMQ_ENABLED_PLUGINS=ALL

mkdir -p ${TEST_TMPDIR}

mkdir -p ${RABBITMQ_LOG_BASE}
mkdir -p ${RABBITMQ_MNESIA_BASE}
mkdir -p ${RABBITMQ_PLUGINS_EXPAND_DIR}

export \
    RABBITMQ_NODENAME \
    RABBITMQ_NODE_IP_ADDRESS \
    RABBITMQ_BASE \
    RABBITMQ_PID_FILE \
    RABBITMQ_LOG_BASE \
    RABBITMQ_MNESIA_BASE \
    RABBITMQ_MNESIA_DIR \
    RABBITMQ_QUORUM_DIR \
    RABBITMQ_STREAM_DIR \
    RABBITMQ_FEATURE_FLAGS_FILE \
    RABBITMQ_PLUGINS_DIR \
    RABBITMQ_PLUGINS_EXPAND_DIR \
    RABBITMQ_SERVER_START_ARGS="-ra wal_sync_method sync" \
    RABBITMQ_ENABLED_PLUGINS \
    RABBITMQ_ENABLED_PLUGINS_FILE

# =============================================================

RMQCTL_WAIT_TIMEOUT=60

export ERL_LIBS={ERL_LIBS}

./sbin/rabbitmq-server $@ \
    > ${RABBITMQ_LOG_BASE}/startup_log \
    2> ${RABBITMQ_LOG_BASE}/startup_err &

# rabbitmqctl wait shells out to 'ps', which is broken in the bazel macOS
# sandbox (https://github.com/bazelbuild/bazel/issues/7448)
# adding "--spawn_strategy=local" to the invocation is a workaround
./sbin/rabbitmqctl \
    -n ${RABBITMQ_NODENAME} \
    wait \
    --timeout ${RMQCTL_WAIT_TIMEOUT} \
    ${RABBITMQ_PID_FILE}

{ERLANG_HOME}/bin/erl \
    -noinput \
    -eval "true = rpc:call('${RABBITMQ_NODENAME}', rabbit, is_running, []), halt()." \
    -sname {SNAME} \
    -hidden