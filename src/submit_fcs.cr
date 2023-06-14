#!/bin/env crystal

require "option_parser"
require "./lib/GritJiraIssue"

class FCSIssue < GritJiraIssue
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
    cmd = "bsub -o /dev/null -M 500000 -n 16 -R'select[mem>500000, tmp>500G] rusage[mem=500000, tmp=600G]' bash  /lustre/scratch123/tol/teams/grit/mh6/ncbi-decon/gx_pipeline/gx_map_wrapper.bash -o #{self.decon_dir} -t #{self.get_taxonomy}"
    self.get_files.each { |f| cmd += " -f #{f}" if File.exists?(f) }
    puts `#{cmd}`
  end
end

issues = [] of String

OptionParser.parse do |parser|
  parser.banner = "Usage: submit_fcs --issue JIRA_ID "
  parser.on("-i JIRA_ID", "--issue JIRA_ID", "JIRA ID") { |i| issues << i }

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

issues.each { |issue|
  y = FCSIssue.new(issue)
  y.submit_to_lsf
}
