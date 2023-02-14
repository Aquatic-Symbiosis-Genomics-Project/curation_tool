#!/bin/env crystal

require "option_parser"
require "./lib/CurationTool"

include CurationTool

issue = "GRIT-736"
setup = false
qc = false
tol = false
qc_dir = ""
OptionParser.parse do |parser|
  parser.banner = "Usage: curation_tool --issue JIRA_ID [--setup_local | --copy_qc]"
  parser.on("-i JIRA_ID", "--issue JIRA_ID", "JIRA ID") { |i| issue = i }
  parser.on("-l", "--setup_local", "copy over pretext") { setup = true }
  parser.on("-t", "--setup_tol", "create initial RC files") { tol = true }
  parser.on("-q DIR", "--copy_qc DIR", "copy from DIR to curation for QC") { |q|
    qc = true
    qc_dir = q
  }

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

y = GritJiraIssue.new(issue)

if setup
  puts "copy pretext =>"
  setup_local(y.yaml)
end

if qc
  puts "stage for QC =>"
  copy_qc(y.json, qc_dir)
end

if tol
  puts "staging files for RC"
  setup_tol(y)
end
# puts y.json.to_pretty_json("  ")
