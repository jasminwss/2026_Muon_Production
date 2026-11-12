# Muon-Produktionen 2026

Jede Produktion besteht aus MuonBack und dem darauf aufbauenden DIS. Sie hat ihren eigenen FairShip-Branch und ihren eigenen Ausgabeordner.

| Produktion | FairShip-Worktree | Branch | Geometrie |
|---|---|---|---|
| `full_SBT` | `FairShip_fork` | `muondis-fix` | volles SBT |
| `sides_SBT` | `FairShip_sides_only` | `sbt-sides` | nur Seitenwände |
| `first6_SBT` | `FairShip_first6` | `sbt-first6` | nur die ersten 37 Zellen |
| `last5_SBT` | `FairShip_last5` | `sbt-last5` | nur die letzten 30 Zellen |
| `support_structure` | `FairShip_support` | `support-structure` | nur Stahlstruktur, sensitiv |
| `no_SBT` | `FairShip_noSBT` | `no-SBT` | kein SBT |
| `no_SBT_no_balloon` | `FairShip_noSBTnoballoon` | `no-SBT-no-balloon` | kein SBT und kein He- Balloon |

In den vier SBT-Produktionen kommen Wand- und Rib-Dicke sowie das Material aus `geometry/veto_config_*.yaml` des jeweiligen Branches, nicht aus festen Werten in `veto.cxx`.

## DIS-Simulation: alle Befehle in der richtigen Reihenfolge

Eine DIS-Simulation baut immer auf einer fertigen MuonBack-Produktion auf: erst MuonBack, dann die Myon-Auswahl (nTuples), dann DIS. Jeder Schritt startet erst, wenn der vorherige fertig ist.

```bash
cd /afs/cern.ch/work/j/jaweiss/private/2026_Muon_Production
P=first6_SBT                          # gewünschte Produktion
```

**1. FairShip-Stand prüfen**

```bash
./prod status                         # Überblick über alle Produktionen
./prod $P check                       # alle Punkte müssen "ok" sein
```

**2. MuonBack: Simulation und Reco**

```bash
./prod $P muonback short              # erst testen: 5 Jobs
condor_q                              # warten, bis alle Jobs fertig sind
./prod $P muonback full               # danach alle 8256 Jobs (oder test500: 500 Jobs)
```

Die Ausgabe von `condor_submit` zeigt die Cluster-Nummer, sie steht auch in `$P/submissions.log`. Das ist das `<cluster>` für die nächsten Schritte.

**3. nTuples: Myonen auswählen, die SBT oder T1 treffen**

```bash
condor_q                              # MuonBack muss fertig sein, sonst bricht prod ab
./prod status                         # zeigt, wie viele MuonBack-Jobs fertig sind
./prod $P ntuple <cluster>
```

**4. DIS: Simulation und Reco**

```bash
condor_q                              # der nTuple-Job muss fertig sein
./prod $P dis <cluster> --dry-run     # zeigt Myonen und Jobzahl, submittet nichts
./prod $P dis <cluster>
```

`dis` berechnet die Jobzahl selbst und lässt Tr aus, wenn dort 0 Myonen sind. Pro Job laufen bei SBT 10 Myonen × 100 DIS, bei Tr 1 Myon × 1000 DIS.

**5. Ergebnis prüfen**

Die Condor-Logs erscheinen erst, wenn ein Job zu Ende ist. `<dis-cluster>` ist die Nummer, die `dis` beim Submit ausgibt und die auch in `$P/submissions.log` steht.

```bash
condor_q                              # noch laufende Jobs
./prod status                         # zum Beispiel: SBT 630 muons, reco 63/63 jobs

# keine Ausgabe = alle Jobs erfolgreich
grep -L SUCCESS $P/logs/dis/SBT_<dis-cluster>_*.out

# Calo-PID angewendet? Die Zahl muss der Jobzahl entsprechen
grep -l "CaloScoringPlanePID: 7 energy" $P/logs/dis/SBT_<dis-cluster>_*.out | wc -l
```

Für Tr gilt dasselbe mit `Tr_<dis-cluster>_*.out`. Die Ergebnisse liegen in `/eos/user/j/jaweiss/2026_Muon_Production/$P/MuonDIS/<cluster>/`.

**6. Fehlgeschlagene Jobs wiederholen**

```bash
./prod $P dis <cluster>               # erst submitten, wenn der alte Cluster fertig ist
```

Fertige Schritte werden dabei übersprungen, wiederholt wird nur, was noch fehlt.

**Wichtig:**
- `<cluster>` ist bei `ntuple` und `dis` immer die Nummer der MuonBack-Produktion, nicht die des nTuple-Jobs.
- Vor jedem Submit läuft `check`. Es bricht ab, wenn der Worktree auf dem falschen Branch ist, uncommitted Änderungen hat, `muondis-fix` oder die Calo-PID fehlen oder der Build älter als die Geometrie ist.
- Mit `--dry-run` zeigen `muonback`, `ntuple` und `dis` nur an, was submittet würde.

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
