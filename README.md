# curation_tool

[![Built with Crystal](https://img.shields.io/badge/built%20with-crystal-000000.svg?style=flat-square)](https://crystal-lang.org/)
[![CI](https://github.com/Aquatic-Symbiosis-Genomics-Project/curation_tool/actions/workflows/ci.yml/badge.svg)](https://github.com/Aquatic-Symbiosis-Genomics-Project/curation_tool/actions?query=workflow%3ACI)
[![Latest Release](https://img.shields.io/github/v/release/Aquatic-Symbiosis-Genomics-Project/curation_tool.svg)](https://github.com/Aquatic-Symbiosis-Genomics-Project/curation_tool/releases)

simple commandline tools to organise curation files using the GRIT JIRA

## Installation

1. Install [Crystal](https://github.com/crystal-lang/crystal)

2. Build the project:

```
git clone git@github.com:Aquatic-Symbiosis-Genomics-Project/curation_tool.git
cd curation_tool
shards build
```

- You can also get binaries compiled using Github Actions from the [Release](https://github.com/Aquatic-Symbiosis-Genomics-Project/curation_tool/releases) page. They are statically linked.

## Usage

### curation_tool
```
Usage: curation_tool --issue JIRA_ID [options]
    -i JIRA_ID, --issue JIRA_ID      JIRA ID
    -p, --copy_pretext               copy over pretext
    -w, --setup_working_dir          create initial curation files and directory
    -r, --build_release              create pretext and release files
    -q, --copy_qc                    copy from DIR to curation for QC
    -m, --merged                     work on a merged curation & pretext
    -h, --help                       show this help
```

### submit_fcs
```
Usage: submit_fcs --issue JIRA_ID 
    -i JIRA_ID, --issue JIRA_ID      JIRA ID
    -h, --help                       show this help
```

### submit_curation_pretext
```
Usage: submit_fcs --issue JIRA_ID 
    -i JIRA_ID,   --issue JIRA_ID    JIRA ID
    -n,           --no_email         don't send an email
    -f FASTA,     --fasta FASTA      input fasta
    -o OUTDIR,    --out OUTDIR       output dir
    -h,           --help             show this help
```


## Contributors

- [epaule](https://github.com/epaule) - creator and maintainer
