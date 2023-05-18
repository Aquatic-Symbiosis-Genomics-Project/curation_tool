#!/bin/env crystal

# export MODULEPATH=/software/treeoflife/shpc/current/views/<team-name>:/software/treeoflife/custom-installs/modules:/software/modules
# module load nextflow/23.04.0-5857
# module load ISG/singularity/3.10.0
# module load ISG/python/

require "fileutils"
require "option_parser"
require "./lib/GritJiraIssue"

class BTKIssue < GritJiraIssue
  def get_files
    files = [] of String
    ["primary", "haplotigs"].each { |key|
      files << self.yaml[key].to_s if self.yaml.as_h.has_key?(key)
    }
    files
  end

  def decon_dir
    Path[self.get_files[0]].parent.to_s
  end

  def submit_to_lsf
    tolid = self.yaml["specimen"]

    ["primary", "haplotigs"].each { |key|
      if self.yaml.as_h.has_key?(key)
        f = self.yaml[key].to_s
        pacbio = Dir.glob("#{self.yaml["pacbio_read_dir"]}/fasta/*.filtered.fasta.gz")[0]
        puts "bsub -n1 -q basement -R\"span[hosts=1]\" -o #{f}_#{key}_ascc.out -e #{f}_#{key}_ascc.err -M5000 -R 'select[mem>5000] rusage[mem=5000]' \"/software/team311/ea10/20230505_ascc/cobiontcheck/ascc.py #{f} --static_config_path /software/team311/ea10/20230505_ascc/cobiontcheck/static_settings.config --pacbio_reads_path #{pacbio} --assembly_title #{tolid}_#{key} --sci_name '#{self.get_scientific_name}' --taxid #{self.get_taxonomy} --steps tiara coverage fcs-gx fcs-adaptor create_btk_dataset btk_busco autofilter_assembly --threads 24 --pipeline_run_folder #{self.decon_dir}/#{tolid}_#{key}_ascc_minimal\""
      end
    }
  end
end

issue = "GRIT-863"

OptionParser.parse do |parser|
  parser.banner = "Usage: submit_fcs --issue JIRA_ID "
  parser.on("-i JIRA_ID", "--issue JIRA_ID", "JIRA ID") { |i| issue = i }

  parser.on("-h", "--help", "show this help") do
    puts parser
    exit
  end

  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit(1)
  end

  parser.missing_option do |flag|
    STDERR.puts "ERROR: #{flag} needs an argument"
    STDERR.puts parser
    exit(1)
  end
end

y = BTKIssue.new(issue)
y.submit_to_lsf
