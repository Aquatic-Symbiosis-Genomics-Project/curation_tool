#!/bin/env crystal

require "option_parser"
require "./lib/grit_jira_issue"

class FCSIssue < GritJiraIssue
  def files
    files = [] of String
    ["primary", "haplotigs", "hap1", "hap2"].each { |key|
      files << self.yaml[key].to_s if self.yaml.as_h.has_key?(key)
    }
    files
  end

  def decon_dir
    Path[self.files[0]].parent.to_s
  end

  def submit_to_lsf
    cmd = "bsub -o #{decon_dir}/fcs.log -M 500000 -n 16 -R'select[mem>500000, tmp>500G] rusage[mem=500000, tmp=600G]' bash  /data/tol/users/mh6/lustre/gx_pipeline/gx_map_wrapper.bash -o #{self.decon_dir} -t #{self.taxonomy}"
    self.files.each { |file| cmd += " -f #{file}" if File.exists?(file) }
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
  y = FCSIssue.new(issue, false)
  y.submit_to_lsf
}
