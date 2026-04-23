#!/bin/env crystal

require "./lib/grit_jira_issue"
require "klib"

include Klib

# Extends `GritJiraIssue` to provide access to the decontamination directory
# for comparing FCS-GX contamination calls against BED-based calls.
class StatIssue < GritJiraIssue
  # Returns the parent directory of the decontamination file.
  def decon_dir : String
    Path[self.decon_file].parent.to_s
  end
end

# Parses a `.contamination` file and returns the sequence IDs marked as `REMOVE`.
def parse_decon_file(f) : Array(String)
  i = [] of String
  File.each_line(f) do |line|
    if /^REMOVE\s+(\S+)/i.match(line)
      i << $1
    end
  end
  i
end

# Parses a `.contamination.bed` file and returns the sequence IDs marked as `REMOVE`.
def parse_bed_file(f) : Array(String)
  i = [] of String
  File.each_line(f) do |line|
    if /^(\S+)\s.*REMOVE/i.match(line)
      i << $1
    end
  end
  i
end

# Computes per-sequence statistics from a gzipped FASTA file.
# Returns a tuple of hashes keyed by sequence name:
# - sequence length
# - GC content (fraction of G/C bases)
# - repeat fraction (fraction of lowercase/soft-masked bases)
# - stop codon density (occurrences of stop codons per base)
def length_and_gc(f) : Tuple(Hash(String, Int32), Hash(String, Float64), Hash(String, Float64), Hash(String, Float64))
  l = Hash(String, Int32).new
  g = Hash(String, Float64).new
  s = Hash(String, Float64).new
  r = Hash(String, Float64).new
  fp = GzipReader.new(f)
  fx = FastxReader.new(fp)
  fx.each { |e|
    l[e.name] = e.seq.size
    g[e.name] = e.seq.count("gcGC").to_f/e.seq.size
    s[e.name] = e.seq.scan(/TGA|TAG|TAA|TTA|CTA|TCA/i).size.to_f/e.seq.size
    r[e.name] = e.seq.count("acgtn").to_f/e.seq.size
  }
  return(l, g, r, s)
end

# Returns the arithmetic mean of a Float64 array.
def av(l : Array(Float64)) : Float64
  l.sum / l.size
end

# Returns the arithmetic mean of an Int32 array as Float64.
def av(l : Array(Int32)) : Float64
  l.sum(0.0) / l.size
end

# Returns the mean value from hash *h* for the keys in *l*.
def get_ave(h, l : Array(String)) : Float64
  av(l.map { |k| h[k] })
end

puts ["tolID", "fasta file", "average gc", "average length", "average repeat", "average stops",
      "true positives", "average gc tp", "average len tp", "average repeat tp", "average stops tp",
      "false positives", "average gc fp", "average len fp", "average repeat fp", "average stops fp",
      "false negatives", "average gc fn", "average len fn", "average repeat fn", "average stops fn"].join("\t")

ARGV.each { |jira_id|
  y = StatIssue.new(jira_id, false)

  Dir.glob("#{y.decon_dir}/*.contamination").each { |file|
    contamination_ids = parse_decon_file(file)
    bed_file = "#{file}.bed"
    next unless File.exists?(bed_file)
    bed_ids = parse_bed_file(bed_file)

    fasta_file = file.gsub(".contamination", ".fa")
    next unless File.exists?(fasta_file + ".gz")

    masked_file = fasta_file + ".masked.gz"
    unless File.exists?(masked_file)
      `zcat #{fasta_file}.gz | /software/grit/bin/ncbi-blast-2.10.0+/bin/dustmasker -outfmt fasta | gzip -9 -c > #{masked_file}`
      raise "couldn't create #{masked_file}" unless $?.success?
    end

    ln, gc, rep, stops = length_and_gc(masked_file)
    true_positives = contamination_ids & bed_ids
    false_positives = bed_ids - contamination_ids
    false_negatives = contamination_ids - bed_ids

    columns = [y.tol_id, File.basename(file), av(gc.values), av(ln.values), av(rep.values), av(stops.values)]

    [true_positives, false_positives, false_negatives].each { |number|
      columns << number.size.to_f
      columns << get_ave(gc, number)
      columns << get_ave(ln, number)
      columns << get_ave(rep, number)
      columns << get_ave(stops, number)
    }
    puts columns.join("\t")
  }
}
