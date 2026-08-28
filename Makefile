PY := python
VENV := .venv
BIN := $(VENV)/Scripts
BOT ?= rookie
ROLE ?= all
ifeq ($(origin AS),command line)
ROLE := $(AS)
endif

SHELL := powershell.exe
.SHELLFLAGS := -NoProfile -NonInteractive -Command

.PHONY: install spar ui validate validate-bots qualify submit test clean check-no-key check-world check-referee doctor

install:
	if (!(Test-Path "$(VENV)")) { if (Get-Command uv -ErrorAction SilentlyContinue) { uv venv --python 3.12 --seed $(VENV) } else { $(PY) -m venv $(VENV) } }
	$(BIN)/python -m pip install -q --upgrade pip
	$(BIN)/python -m pip install -q pytest
	Write-Host "ready. no api key needed, ever."

spar:
	$(BIN)/python spar.py --bot $(BOT) --as $(ROLE)

ui:
	$(BIN)/python spar.py --bot $(BOT) --as $(ROLE) --ui
	$(BIN)/python -m kit.arena_ui.build_ui
	$(BIN)/python -m kit.arena_ui.serve

WORLD := $(firstword $(wildcard kit/world/*/manifest.json))

validate:
	if (-not "$(WORLD)") { Write-Error "no world exported - run 'make check-world'"; exit 1 }
	$(BIN)/python validate_deck.py deck/deck.json deck/lineup.json --world $(dir $(WORLD))

validate-bots:
	foreach ($$b in @("rookie","operator","adversary")) { Write-Host ("$$b".PadRight(12) + " ") -NoNewline; $(BIN)/python validate_deck.py bots/$$b/deck.json bots/$$b/lineup.json --world $(dir $(WORLD)) 2>&1 | Select-Object -Last 1 }

qualify:
	Write-Host "make qualify: retired - nothing consumed submissions/radar.json."; Write-Host "Your conformance check is 'make test' (the public suite)."; Write-Host "Then: make validate && make submit TEAM=<your-team>"; exit 1

submit: validate
	if (-not "$(TEAM)") { Write-Error "usage: make submit TEAM=<your-team-name>"; exit 1 }
	$(BIN)/python -m kit.submit --team $(TEAM)

test: check-no-key
	$(BIN)/python -m pytest tests/

check-referee:
	if (!(Test-Path "kit/referee")) { Write-Error "kit/referee missing - ask your instructor to run tools.sync_referee"; exit 1 }
	$(BIN)/python -c "from kit.referee.rubric import CLASSES; from kit.referee.adjudicate import LOCAL_ONLY; print(f'referee: {len(CLASSES)} classes, local_only={LOCAL_ONLY}')"

check-world:
	$$manifests = Get-ChildItem kit/world/*/manifest.json -ErrorAction SilentlyContinue; if (-not $$manifests) { Write-Error "no world in kit/world/ - ask your instructor for the world artifact"; exit 1 }
	$(BIN)/python -c "import json,glob; m=json.load(open(sorted(glob.glob('kit/world/*/manifest.json'))[-1])); print('world', m.get('world_id'), '-', sum(m.get('counts',{}).values()), 'pages')"
	if (Get-ChildItem kit/world/*/truth.json -ErrorAction SilentlyContinue) { Write-Error "FAIL: truth.json must never ship to students"; exit 1 }

doctor: check-no-key check-world check-referee validate
	Write-Host "ready to spar."

check-no-key:
	$(BIN)/python -m kit.gate_no_key

clean:
	Get-ChildItem -Recurse -Filter __pycache__ -Directory | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
	if (Test-Path .pytest_cache) { Remove-Item -Recurse -Force .pytest_cache }
