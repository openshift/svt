#!/bin/bash

yum install gcc libyaml python-virtualenv

virtualenv venv
source venv/bin/activate

pip install -r requirements.txt

# run test
python utils.py
