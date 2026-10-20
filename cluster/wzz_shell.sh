if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo 'Source your personal wzz_bashrc instead.' >&2; exit 2
fi
source /public/home/xiaohe2/zizhangw/chgnet-runtime-ci-20261020/env.sh || return $?
wzzcd() { cd "$LIS_PROJECT"; }
wzzscripts() { cd "$LIS_SCRIPTS"; }
wzzpython() { bash "$LIS_SCRIPTS/run-in-container.sh" "$LIS_PYTHON" "$@"; }
wzzuv() { bash "$LIS_SCRIPTS/run-in-container.sh" "$LIS_UV" "$@"; }
wzzqueue() {
    [[ $# == 1 && "$1" =~ ^[0-9]+$ ]] || { echo 'Usage: wzzqueue YOUR_JOB_ID' >&2; return 2; }
    squeue -j "$1" -o '%.18i %.25j %.9P %.10T %.10M %R'
}
