#!/bin/env crystal

require "./lib/GritJiraIssue"

def parse_decon_file(f)
  i = [] of String
  File.each_line(f) do |line|
    if /^REMOVE\s+(\S+)/i.match(line)
      i << $1
    end
  end
  i
end

def parse_bed_file(f)
  i = [] of String
  File.each_line(f) do |line|
    if /^(\S+)\s.*REMOVE/i.match(line)
      i << $1
    end
  end
  i
end

ARGV.each { |jira_id|
  y = GritJiraIssue.new(jira_id)

  contamination_ids = parse_decon_file(y.decon_file)
  bed_file = "#{y.decon_file}.bed"
  next unless File.exists?(bed_file)
  bed_ids = parse_bed_file(bed_file)

  puts [y.tol_id, contamination_ids & bed_ids, puts contamination_ids - bed_ids, bed_ids - contamination_ids].join("\t")
}
