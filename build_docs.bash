#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# read the version from CurationTool::VERSION so the docs can't drift from the code
version=$(sed -n 's/^ *VERSION = "\(.*\)"/\1/p' src/lib/curation_tool.cr)
if [ -z "$version" ]; then
  echo "could not read VERSION from src/lib/curation_tool.cr" >&2
  exit 1
fi

crystal docs --project-version="$version" --source-url-pattern="https://github.com/Aquatic-Symbiosis-Genomics-Project/curation_tool/blob/%{refname}/%{path}#L%{line}" --source-refname=new_curation_pretext
