# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Crystal-language CLI toolset for the GRIT team at the Sanger Institute to automate genome curation workflows. Tools interact with the GRIT JIRA instance (`jira.sanger.ac.uk`) and operate on files stored in Sanger HPC infrastructure (LSF cluster, lustre filesystems, `/nfs/treeoflife-01`).

## Build & Development Commands

```bash
# Install dependencies
shards install

# Build all binaries (output to bin/)
shards build

# Production static build (as used in CI/releases)
shards build --production --release --static --no-debug

# Run tests
crystal spec

# Check formatting
crystal tool format --check

# Auto-fix formatting
crystal tool format

# Run linter (Ameba — installed separately, e.g. `brew install ameba`; not a shard dependency)
ameba
```

## Architecture

### Entry Points (shard.yml targets → src/)

| Binary | Source | Purpose |
|--------|--------|---------|
| `curation_tool` | `src/curation_tool.cr` | Main curation workflow orchestrator |
| `fcs_submit` | `src/submit_fcs.cr` | Submit contamination screening (FCS/GX) jobs to LSF |
| `btk_submit` | `src/submit_btk.cr` | Submit BlobToolKit/ASCC jobs to LSF |
| `ascc_stats` | `src/get_assc_stats.cr` | Compare contamination detection stats |
| `submit_curation_pretext` | `src/submit_curation_pretext.cr` | Submit curation pretext pipeline |

### Core Library (`src/lib/`)

**`GritJiraIssue`** (`src/lib/grit_jira_issue.cr`) — central class used by all tools. It:
- Authenticates to JIRA via Bearer token read from `~/.netrc` (entry for `jira.sanger.ac.uk`)
- Fetches issue JSON from JIRA REST API (`/rest/api/2/issue/<ID>`)
- Reads per-specimen YAML (from a path in JIRA custom field `customfield_13408`, falling back to JIRA attachment, or via `scp` from `tol22:`)
- Derives all file paths (working dir, curated dir, pretext dir, decon files) from YAML and JIRA fields
- Exposes shared assembly-file accessors (`files`, `assembly_files`, `decon_dir`) used by the FCS/BTK subclasses
- Wraps the `curationpretext.sh` Nextflow pipeline invocation

**`CurationTool` module** (`src/lib/curation_tool.cr`) — workflow functions:
- `setup_tol`: Creates working directory and decompresses fasta
- `build_release`: Runs `pretext-to-asm`, optionally trims contamination via `remove_contamination_bed`, submits `curationpretext.sh` via LSF
- `copy_qc`: Copies curated fasta/chromosome lists to the curated dir, copies pretext map
- `setup_local`: Copies pretext files from `tol` server to local workstation

### Specialised subclasses
- `FCSIssue` (`submit_fcs.cr`) — adds `submit_to_lsf` for FCS-GX contamination pipeline
- `BTKIssue` (`submit_btk.cr`) — adds `submit_to_lsf` for ASCC/BTK pipeline
- `StatIssue` (`get_assc_stats.cr`) — adds stats computation using the `klib` shard for FASTA parsing

### Assembly type handling
The codebase distinguishes three assembly layouts (detected from YAML keys):
- **Haploid/primary+haplotigs**: `primary` + `haplotigs` keys
- **Fully phased**: `hap1` + `hap2` keys
- **Partially phased**: `maternal` + `paternal` keys

The `merged` boolean flag on `GritJiraIssue` controls whether hap1/hap2 dual-output mode is active.

## Key Conventions

- JIRA custom fields: `customfield_13408` = YAML path, `customfield_11677` = decon file, `customfield_11609` = release version, `customfield_11650` = telomere sequence, `customfield_11643` = geval DB
- Working directory pattern: derived from `pacbio_read_dir` or `ont_read_dir` by replacing `genomic_data/...` with `working/<tolid>_<user>_curation`
- HPC jobs use LSF (`bsub -K` for synchronous execution in release builds)
- All entry-point binaries require `--issue`/`-i`; they exit with an error if it is missing (no default issue ID)
- The `src/lib/_path` file (untracked) appears to be a local path override for development
