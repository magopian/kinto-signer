VIRTUALENV = virtualenv
VENV := $(shell echo $${VIRTUAL_ENV-$$PWD/.venv})
PYTHON = $(VENV)/bin/python
DEV_STAMP = $(VENV)/.dev_env_installed.stamp
INSTALL_STAMP = $(VENV)/.install.stamp
TEMPDIR := $(shell mktemp -d)

.IGNORE: clean
.PHONY: all install virtualenv tests install-dev tests-once

OBJECTS = .venv .coverage

all: install
install: $(INSTALL_STAMP)
$(INSTALL_STAMP): $(PYTHON) setup.py
	$(PYTHON) setup.py develop
	touch $(INSTALL_STAMP)

install-dev: $(INSTALL_STAMP) $(DEV_STAMP)
$(DEV_STAMP): $(PYTHON) dev-requirements.txt
	$(VENV)/bin/pip install -r dev-requirements.txt
	touch $(DEV_STAMP)

virtualenv: $(PYTHON)
$(PYTHON):
	virtualenv $(VENV)

build-requirements:
	$(VIRTUALENV) $(TEMPDIR)
	$(TEMPDIR)/bin/pip install -U pip
	$(TEMPDIR)/bin/pip install -Ue .
	$(TEMPDIR)/bin/pip freeze > requirements.txt

tests-once: install-dev
	$(VENV)/bin/py.test --cov-report term-missing --cov-fail-under 100 --cov kinto_signer

tests: install-dev
	$(VENV)/bin/py.test kinto_signer/tests --cov-report term-missing --cov-fail-under 100 --cov kinto_signer

clean:
	find . -name '*.pyc' -delete
	find . -name '__pycache__' -type d -exec rm -fr {} \;

$(VENV)/bin/kinto: install
	$(VENV)/bin/pip install kinto

run-signer: $(VENV)/bin/kinto
	$(VENV)/bin/kinto --ini kinto_signer/tests/config/signer.ini migrate
	$(VENV)/bin/kinto --ini kinto_signer/tests/config/signer.ini start

install-autograph: $(VENV)/bin/autograph

$(VENV)/bin/autograph:
	export GOPATH=$(VENV); export PATH="$$GOPATH/bin;$$PATH"; go get github.com/mozilla-services/autograph

run-autograph: $(VENV)/bin/autograph
	$(VENV)/bin/autograph -c kinto_signer/tests/config/autograph.yaml

need-kinto-running:
	@curl http://localhost:8888/v0/ 2>/dev/null 1>&2 || (echo "Run 'make run-signer' before starting tests." && exit 1)

functional: install-dev need-kinto-running
	$(VENV)/bin/py.test kinto_signer/tests/functional.py
