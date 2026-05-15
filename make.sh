#!/bin/sh

# Set variables
PROG="$(basename -- "$0")"

ROOTDIR="$(cd -- "$(dirname -- "$0")" && pwd)"

LIBDIR="${ROOTDIR}/lib"
HLIBDIR="${ROOTDIR}/hostlist"
OUTDIR="${ROOTDIR}/out"

TARGETS="
hostlist
mkdeploy
sysexec
"

# Commands
PRESH="$(command -v presh)"

####

# Print error message
err () {
    ! printf "%s: error: %s\n" "${PROG}" "$*" >&2
}

# Build subroutine
build () {
    target="$1"
    src_dir="${ROOTDIR}/${target}"
    main_sht="${src_dir}/main.sht"
    out_file="${OUTDIR}/${target}.sh"
    # Build output file
    "${PRESH}" -I "${LIBDIR}" -I "${HLIBDIR}" -o "${out_file}" "${main_sht}"
}

# Build all targets
build_all () {
    for t in ${TARGETS} ; do
	build "${t}"
    done
}

# Check target
check_target () {
    case " ${TARGETS} " in
	( *[[:space:]]"$1"[[:space:]]* ) ;;
	( * ) err "Unknown target '$1'" ;;
    esac
}

# Show usage information
usage () {
    cat << EOF
Usage: ${PROG} target
    'target' is one of the following ('all' if missed):
    all		build all targets
EOF
    exit 1
}

# Main subroutine
main () {
    # Check command line arguments
    test $# -le 1 || usage
    test $# -gt 0 && target="$1" || target="all"
    # Check executables
    test -n "${PRESH}" || err "can't find 'presh'" || return 1
    # Create output directory
    test -d "${OUTDIR}" || mkdir -p "${OUTDIR}" || return 1
    # Build targets
    case "${target}" in
	( "all" ) build_all ;;
	( * ) check_target "${target}" || usage ; build "${target}" ;;
    esac
}

# Call main subroutine
main "$@"
