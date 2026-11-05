# Muon-Produktionen 2026

Jede Produktion besteht aus MuonBack und dem darauf aufbauenden DIS. Sie hat ihren eigenen FairShip-Branch und ihren eigenen Ausgabeordner.

| Produktion | FairShip-Worktree | Branch | Geometrie |
|---|---|---|---|
| `full_SBT` | `FairShip_fork` | `muondis-fix` | volles SBT |
| `sides_SBT` | `FairShip_sides_only` | `sbt-sides` | nur Seitenwände |
| `first6_SBT` | `FairShip_first6` | `sbt-first6` | nur die ersten 37 Zellen |
| `last5_SBT` | `FairShip_last5` | `sbt-last5` | nur die letzten 30 Zellen |
| `support_structure` | `FairShip_support` | `support-structure` | nur Stahlstruktur, sensitiv |

In den vier SBT-Produktionen kommen Wand- und Rib-Dicke sowie das Material aus `geometry/veto_config_*.yaml` des jeweiligen Branches, nicht aus festen Werten in `veto.cxx`.

## Ablauf

```bash
cd /afs/cern.ch/work/j/jaweiss/private/2026_Muon_Production

./prod status                        # Überblick über alles
./prod first6_SBT check              # ist der FairShip-Stand bereit?

./prod first6_SBT muonback short     # Test: 5 Jobs
./prod first6_SBT muonback full      # 8256 Jobs (test500: 500 Jobs)
./prod first6_SBT ntuple <cluster>   # wenn MuonBack fertig ist
./prod first6_SBT dis <cluster>      # wenn die nTuples fertig sind
```

`<cluster>` ist immer die Cluster-Nummer der MuonBack-Produktion. `dis` berechnet die Jobzahl selbst aus den nTuple-Logs und lässt Tr aus, wenn dort 0 Myonen sind. Mit `--dry-run` wird nur angezeigt, was submittet würde.

Vor jedem Submit läuft `check`. Es bricht ab, wenn der Worktree auf dem falschen Branch ist, uncommitted Änderungen hat, `muondis-fix` oder die Calo-PID fehlen oder der Build älter als die Geometrie ist.

## Wo liegt was

```
2026_Muon_Production/
├── prod                  einziger Befehl, den du brauchst
├── pipeline/             der Ablauf, gilt für alle Produktionen
│   ├── muonback.sh/.sub  Schritt 1: Simulation + Reco
│   ├── ntuple.sh/.sub    Schritt 2: Myonen auswählen
│   ├── dis.sh/.sub       Schritt 3: DIS + Simulation + Reco
│   └── jobs/             Joblisten: short, test500, full
└── <produktion>/
    ├── config.sh         FairShip-Worktree, Branch, Ausgabeordner
    ├── submissions.log   welcher Cluster mit welchem Commit lief
    └── logs/             Condor-Logs, getrennt nach Schritt

/eos/user/j/jaweiss/2026_Muon_Production/<produktion>/
├── MuonBack/<cluster>/job_<n>/
└── MuonDIS/<cluster>/    gleiche Cluster-Nummer wie das zugehörige MuonBack
    ├── muonsProduction_wsoft_SBT.root, ..._Tr.root, ntuple_*.log
    ├── SBT/job_<n>/
    └── Tr/job_<n>/
```

Eine Änderung am Ablauf, etwa eine neue Reco-Option, kommt nur in `pipeline/` und gilt dann für alle Produktionen.

## Neue Produktion hinzufügen

Ordner mit einer `config.sh` anlegen, mehr braucht es nicht:

```bash
mkdir support_first6
cat > support_first6/config.sh <<'EOF'
# Stahlstruktur: nur die ersten Zellen
FAIRSHIP=/afs/cern.ch/work/j/jaweiss/FairShip_support_first6
BRANCH=support-first6
EOS_BASE=/eos/user/j/jaweiss/2026_Muon_Production/support_first6
EOF
```
