#!/bin/sh

# Set variables
PROG="$(basename -- "$0")"

THISDIR="$(cd -- "$(dirname -- "$0")" && pwd)"
ROOTDIR="$(cd -- "${ROOTDIR:-"${THISDIR}/.."}" && pwd)"

LIBDIR="${ROOTDIR}/lib"
OUTDIR="${ROOTDIR}/out"

SRCDIR="${THISDIR}"
MAIN_SHT="${SRCDIR}/main.sht"

OUTFILE="${OUTDIR}/hostlist.sh"

# Commands
PRESH="$(command -v presh)"

####

# Print error message
err () {
    ! printf "%s: error: %s\n" "${PROG}" "$*" >&2
}

# Main subroutine
main () {
    # Check executables
    test -n "${PRESH}" || err "can't find 'presh'" || return 1
    # Create output directory
    test -d "${OUTDIR}" || mkdir -p "${OUTDIR}" || return 1
    # Build output file
    "${PRESH}" -I "${LIBDIR}" -o "${OUTFILE}" "${MAIN_SHT}" || return 1
}

# Call main subroutine
main "$@"
