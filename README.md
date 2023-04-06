[![Built with Crystal](https://img.shields.io/badge/built%20with-crystal-000000.svg?style=flat-square)](https://crystal-lang.org/)
[![CI](https://github.com/Aquatic-Symbiosis-Genomics-Project/curation_tool/actions/workflows/ci.yml/badge.svg)](https://github.com/Aquatic-Symbiosis-Genomics-Project/curation_tool/actions?query=workflow%3ACI)
[![Latest Release](https://img.shields.io/github/v/release/Aquatic-Symbiosis-Genomics-Project/curation_tool.svg)](https://github.com/Aquatic-Symbiosis-Genomics-Project/curation_tool/releases)
# curation_tool

simple commandline tool to organise curation files using the GRIT JIRA

## Installation

if you got crystal installed:
shards build
will create a curation_tool binary in bin/

## Usage

Usage: curation_tool --issue JIRA_ID [--setup_local | --copy_qc]
    -i JIRA_ID, --issue JIRA_ID      JIRA ID
    -p, --copy_pretext               copy over pretext
    -w, --setup_working_dir          create initial curation files and directory
    -r, --build_release              create pretext and release files
    -q, --copy_qc                    copy from DIR to curation for QC
    -h, --help                       show this help

## Contributors

- [epaule](https://github.com/epaule) - creator and maintainer
