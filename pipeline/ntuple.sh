#!/bin/bash
set -eo pipefail

# Step 2: collect the muons hitting the SBT / Tracking Station 1 from a MuonBack cluster.
# In the support-structure productions the "SBT" is the sensitive steel support.
# Arguments (see ntuple.sub, filled in by ../prod):
#   $1 = FAIRSHIP      FairShip worktree of this production
#   $2 = MUONBACK_DIR  MuonBack cluster dir containing job_*/sim_*.root
#   $3 = OUTDIR        where the muon nTuples are written
#   $4 = NFOLDERS      only use the first N job_* folders (0 = all, >0 for testing)

FAIRSHIP=$1
MUONBACK_DIR=$2
OUTDIR=$3
NFOLDERS=${4:-0}

compgen -G "$MUONBACK_DIR/job_*" > /dev/null || { echo "ERROR: no job_* folders in '$MUONBACK_DIR'"; exit 1; }

SCRIPTS=$FAIRSHIP/muonDIS
export QT_QPA_PLATFORM=offscreen   # headless node: Geant4's Qt UI otherwise aborts with qFatal
# environment served from CVMFS (pixi cvmfs), the workspace must be given explicitly in a job
export PATH=/cvmfs/ship-nightlies.cern.ch/pixi/0.72.0-rattlerfs-layers-d5a7568/bin:$PATH
PIXI_RUN=(pixi cvmfs "$FAIRSHIP")
echo "Using FAIRSHIP=$FAIRSHIP (pixi cvmfs), branch $(git -C "$FAIRSHIP" branch --show-current), commit $(git -C "$FAIRSHIP" rev-parse --short HEAD)"

mkdir -p "$OUTDIR"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

# make_nTuple_*.py expect <path>/<folder>/ship.conical.MuonBack-TGeant4.root,
# the production names the file sim_<cluster>_<proc>.root -> symlink it.
n=0
for sim in "$MUONBACK_DIR"/job_*/sim_*.root; do
    [ -f "$sim" ] || continue
    job=$(basename "$(dirname "$sim")")
    mkdir -p "links/$job"
    ln -s "$sim" "links/$job/ship.conical.MuonBack-TGeant4.root"
    n=$((n + 1))
    if [ "$NFOLDERS" -gt 0 ] && [ "$n" -ge "$NFOLDERS" ]; then break; fi
done
echo "Linked $n MuonBack files from $MUONBACK_DIR"
[ "$n" -gt 0 ] || { echo "ERROR: no sim_*.root found in $MUONBACK_DIR/job_*"; exit 1; }

echo
echo " Muons hitting the SBT"
echo "=============================================================="
"${PIXI_RUN[@]}" python "$SCRIPTS/make_nTuple_SBT.py" -p "$WORKDIR/links" 2>&1 | grep -v "LoadPCM" | tee ntuple_SBT.log

echo
echo " Muons hitting Tracking Station 1 (and not the SBT)"
echo "=============================================================="
"${PIXI_RUN[@]}" python "$SCRIPTS/make_nTuple_Tr.py" -p "$WORKDIR/links" 2>&1 | grep -v "LoadPCM" | tee ntuple_Tr.log

cp muonsProduction_wsoft_SBT.root SelectedMuonsSBT.txt ntuple_SBT.log "$OUTDIR"/
cp muonsProduction_wsoft_Tr.root  SelectedMuonsTr.txt  ntuple_Tr.log  "$OUTDIR"/

echo
for t in SBT Tr; do
    echo "$t: $(grep -m1 'Total number of entries' ntuple_$t.log)"
done
echo "SUCCESS: $OUTDIR"
