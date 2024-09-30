#!/bin/env crystal

require "option_parser"
require "./lib/grit_jira_issue"

class BTKIssue < GritJiraIssue
  def files
    files = [] of String
    ["primary", "haplotigs"].each { |key|
      files << self.yaml[key].to_s if self.yaml.as_h.has_key?(key)
    }
    files
  end

  def decon_dir
    Path[self.files[0]].parent.to_s
  end

  def submit_to_lsf
    tolid = self.yaml["specimen"]

    ["primary", "haplotigs"].each { |key|
      if self.yaml.as_h.has_key?(key)
        f = self.yaml[key].to_s
        ascc = "/software/team311/ea10/20240128_ascc/cobiontcheck"
        steps = "tiara coverage fcs-gx fcs-adaptor create_btk_dataset btk_busco nt_blast nr_diamond uniprot_diamond autofilter_assembly"
        pacbio = Dir.glob("#{self.yaml["pacbio_read_dir"]}/fasta/*.filtered.fasta.gz")[0]
        puts `bsub -n1 -q basement -R"span[hosts=1]" -o #{f}_#{key}_ascc.out -e #{f}_#{key}_ascc.err -M5000 -R 'select[mem>5000] rusage[mem=5000]' "#{ascc}/ascc.py #{f} --static_config_path #{ascc}/static_settings.config --pacbio_reads_path #{pacbio} --assembly_title #{tolid}_#{key} --sci_name '#{self.scientific_name}' --taxid #{self.taxonomy} --steps #{steps} --threads 24 --pipeline_run_folder #{self.decon_dir}/#{tolid}_#{key}_ascc_minimal --btk_busco_run_mode mandatory"`
      end
    }
  end
end

issue = "GRIT-863"

OptionParser.parse do |parser|
  parser.banner = <<-__HERE__
Usage: submit_fcs --issue JIRA_ID

don't forget to setup your environment:

export MODULEPATH=/software/treeoflife/shpc/current/views/grit:/software/treeoflife/custom-installs/modules:/software/modules
module load nextflow/23.10.0-5889
module load ISG/singularity/3.11.4
module load ISG/python/3.11.4

the options are:
__HERE__

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

y = BTKIssue.new(issue, false)
y.submit_to_lsf
