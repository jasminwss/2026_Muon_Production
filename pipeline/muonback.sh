#!/bin/bash
set -eo pipefail

# Step 1: muon background simulation + reconstruction.
# Arguments (see muonback.sub, filled in by ../prod):
#   $1 = FAIRSHIP       FairShip worktree of this production
#   $2 = MUONBACK_BASE  output base, each job writes to <base>/<cluster>/job_<proc>/
#   $3 = inputFile      muon background flux file to sample from
#   $4 = startEvent     first event to read from inputFile
#   $5 = nEvents        number of events to generate
#   $6 = ProcId         $(Process)
#   $7 = ClusterId      $(Cluster)

FAIRSHIP=$1
MUONBACK_BASE=$2
inputFile=$3
startEvent=$4
nEvents=$5
ProcId=$6
ClusterId=$7

RUN_ID="${ClusterId}_${ProcId}"
OUTPUT_DIR=$MUONBACK_BASE/$ClusterId/job_$ProcId

# prod creates the parent directory the jobs share, so normally only job_<n>/ is created here. If a job
# is still first: mkdir -p can race on EOS when all jobs of a cluster create the parent at once ("File exists"
# despite -p), and the parent can stay invisible to this node for a while, so the -d check misses it as well.
# 5 tries within 8 s were not enough (DIS clusters 13131080/81: 63 of 68 jobs failed their first attempt).
# Hence about 3 min of retries, spaced randomly so that the jobs do not retry in lockstep.
for attempt in {1..12}; do
    mkdir -p "$OUTPUT_DIR" && break
    [ -d "$OUTPUT_DIR" ] && break
    sleep $((RANDOM % 20 + 5))
done
[ -d "$OUTPUT_DIR" ] || { echo "ERROR: could not create $OUTPUT_DIR"; exit 1; }

[ -f "$inputFile" ] || { echo "ERROR: input file missing: $inputFile"; exit 1; }

export QT_QPA_PLATFORM=offscreen   # headless node: Geant4's Qt UI otherwise aborts with qFatal
# environment served from CVMFS (pixi cvmfs), the workspace must be given explicitly in a job
export PATH=/cvmfs/ship-nightlies.cern.ch/pixi/0.72.0-rattlerfs-layers-d5a7568/bin:$PATH
PIXI_RUN=(pixi cvmfs "$FAIRSHIP")
echo "Using FAIRSHIP=$FAIRSHIP (pixi cvmfs), branch $(git -C "$FAIRSHIP" branch --show-current), commit $(git -C "$FAIRSHIP" rev-parse --short HEAD)"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

echo
echo " Step 1: MuonBack simulation using run_simScript.py"
echo "=============================================================="
"${PIXI_RUN[@]}" python "$FAIRSHIP/macro/run_simScript.py" \
    --MuonBack \
    -f "$inputFile" \
    -i "$startEvent" \
    -n "$nEvents" \
    --shieldName TRY_2026 \
    --tag "$RUN_ID" \
    -o "$WORKDIR" | tee simRunOutput_1.txt

SIM_FILE="$WORKDIR/sim_${RUN_ID}.root"
GEO_FILE="$WORKDIR/geo_${RUN_ID}.root"
PARAMS_FILE="$WORKDIR/params_${RUN_ID}.root"
REC_FILE="$WORKDIR/sim_${RUN_ID}_rec.root"

for f in "$SIM_FILE" "$GEO_FILE" "$PARAMS_FILE"; do
    [ -f "$f" ] || { echo "ERROR: $f not produced"; ls -lh "$WORKDIR"; exit 1; }
done

echo
echo " Step 2: Reconstruction using ShipReco.py"
echo "=============================================================="
"${PIXI_RUN[@]}" python "$FAIRSHIP/macro/ShipReco.py" \
    -f "$SIM_FILE" \
    -g "$GEO_FILE" \
    --trackFitter acts \
    --caloScoringPlanePID "$FAIRSHIP/geometry/caloScoringPlane_pid_provided.yaml" | tee simRunOutput_2.txt

[ -f "$REC_FILE" ] || { echo "ERROR: reco output not produced"; ls -lh "$WORKDIR"; exit 1; }

cp "$SIM_FILE"        "$OUTPUT_DIR/sim_${RUN_ID}.root"
cp "$GEO_FILE"        "$OUTPUT_DIR/geo_${RUN_ID}.root"
cp "$PARAMS_FILE"     "$OUTPUT_DIR/params_${RUN_ID}.root"
cp "$REC_FILE"        "$OUTPUT_DIR/reco_${RUN_ID}.root"
cp simRunOutput_1.txt "$OUTPUT_DIR/"
cp simRunOutput_2.txt "$OUTPUT_DIR/"

echo "SUCCESS: $OUTPUT_DIR"
