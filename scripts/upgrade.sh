#!/bin/sh -e

# Docker images upgrade tool
readonly TIMESTAMP=$(date +%s)
readonly BASEDIR="$(realpath $(dirname ${0}))"

[ ! -z "${1}" ] || readonly BACKUP_TYPE=dirty

readonly INSTALL_DIR='/opt/infra-wordpress'
[ -d "${INSTALL_DIR}" ] # check if dir exits
readonly BACKUPS_DIR="${INSTALL_DIR}/_backups/${TIMESTAMP}-${BACKUP_TYPE:-clean}" # add _backups to tar excludes!
mkdir -vp "${BACKUPS_DIR}"

XZ_OPT=${XZ_OPT:--9} # xz compression options

( set -x

: Mysqldump the DB
${BASEDIR}/backup-db | xz ${XZ_OPT} --verbose > "${BACKUPS_DIR}/mysqldump.sql.xz"

: Pull docker images
${BASEDIR}/dockerimages-pull dump-state

: Stop the service for INSTALL_DIR backup
[ "${BACKUP_TYPE:-clean}" '=' "dirty" ] || "${BASEDIR}/service-stop"

: Archive INSTALL_DIR
XZ_OPT=${XZ_OPT} tar cvJC "${INSTALL_DIR}"\
 -f "${BACKUPS_DIR}/installdir.tar.xz"\
 --checkpoint=5000 --checkpoint-action='echo="#%u: %T"'\
 --index-file="${BACKUPS_DIR}/installdir.tar.xz.index"\
 --exclude='_backups' .

: Start the service
[ "${BACKUP_TYPE:-clean}" '=' "dirty" ] || "${BASEDIR}/service-start"

echo 'INFO: Clean exit' >&2
) 2>&1 | tee --append "${BACKUPS_DIR}/backup.log"
