#!/bin/bash
crystal docs --project-version=v1.2.0 --source-url-pattern="https://github.com/Aquatic-Symbiosis-Genomics-Project/curation_tool/blob/%{refname}/%{path}#L%{line}" --source-refname=new_curation_pretext
