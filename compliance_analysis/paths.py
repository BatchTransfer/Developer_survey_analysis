"""Repo-relative locations used by every script in compliance_analysis/. EVM_DATA (env var) points to the raw bytecode dataset
(not in the repo; see README) and to scratch census output; default ~/Downloads/evm_data."""
import os
ROOT = os.path.dirname(os.path.abspath(__file__))
CLASSIFIER, CENSUS, VALIDATION = ROOT + '/classifier', ROOT + '/census', ROOT + '/validation'
RESULTS, FIGURES = ROOT + '/results', ROOT + '/figures'
EVM_DATA = os.environ.get('EVM_DATA', os.path.expanduser('~/Downloads/evm_data')) + '/'
