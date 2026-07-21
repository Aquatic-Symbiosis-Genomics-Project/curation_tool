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

- You can also get binaries compiled using Github Actions from the [Release](https://github.com/Aquatic-Symbiosis-Genomics-Project/curation_tool/releases) page. They are statically linked on Alpine Linux/x86_64 binaries.

## Usage

### curation_tool
```
Usage: curation_tool --issue JIRA_ID [options]
    -i JIRA_ID, --issue JIRA_ID      JIRA ID
    -p, --copy_pretext               copy over pretext
    -w, --setup_working_dir          create initial curation files and directory
    -r, --build_release              create pretext and release files
    -q, --copy_qc                    copy from DIR to curation for QC
    -m, --merged                     build files based on a merged map
    -h, --help                       show this help
```

### submit_fcs
```
Usage: submit_fcs --issue JIRA_ID 
    -i JIRA_ID, --issue JIRA_ID      JIRA ID
    -h, --help                       show this help
```

### submit_btk
```
Usage: submit_btk --issue JIRA_ID
    -i JIRA_ID, --issue JIRA_ID      JIRA ID
    -h, --help                       show this help
```

Before running, load the required environment:

```
module load grit
```

### submit_curation_pretext
```
Usage: submit_curation_pretext --issue JIRA_ID --fasta FASTA --out OUTDIR
    -i JIRA_ID,   --issue JIRA_ID    JIRA ID
    -n,           --no_email         don't send an email
    -c,           --no_name_check    don't check the tolid against the fasta name
    -f FASTA,     --fasta FASTA      input fasta
    -o OUTDIR,    --out OUTDIR       output dir
    -h,           --help             show this help
```

### ascc_stats
```
Usage: ascc_stats JIRA_ID [JIRA_ID ...]
```

Compares FCS-GX `.contamination` calls against the BED-based calls for each
issue and prints a tab-separated stats table to stdout.


## Contributors

- [epaule](https://github.com/epaule) - creator and maintainer
