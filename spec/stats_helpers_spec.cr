require "./spec_helper"

# These functions are defined as top-level methods in src/get_assc_stats.cr.
# That file has top-level ARGV code that runs on require, so we redefine the
# pure functions here to test their logic in isolation.

def parse_decon_file(f) : Array(String)
  i = [] of String
  File.each_line(f) do |line|
    if /^REMOVE\s+(\S+)/i.match(line)
      i << $1
    end
  end
  i
end

def parse_bed_file(f) : Array(String)
  i = [] of String
  File.each_line(f) do |line|
    if /^(\S+)\s.*REMOVE/i.match(line)
      i << $1
    end
  end
  i
end

def av(l : Array(Float64)) : Float64
  l.sum / l.size
end

def av(l : Array(Int32)) : Float64
  l.sum(0.0) / l.size
end

def get_ave(h, l : Array(String)) : Float64
  av(l.map { |k| h[k] })
end

describe "parse_decon_file" do
  it "extracts sequence IDs from REMOVE lines" do
    tmpdir = Dir.tempdir
    path = "#{tmpdir}/test.contamination"
    File.write(path, "REMOVE seq1 some_reason\nKEEP seq2\nREMOVE seq3 another_reason\n# comment line\n")
    result = parse_decon_file(path)
    result.should eq(["seq1", "seq3"])
    File.delete(path)
  end

  it "returns empty array for file with no REMOVE lines" do
    tmpdir = Dir.tempdir
    path = "#{tmpdir}/clean.contamination"
    File.write(path, "KEEP seq1\nKEEP seq2\n")
    result = parse_decon_file(path)
    result.should be_empty
    File.delete(path)
  end

  it "handles case-insensitive REMOVE" do
    tmpdir = Dir.tempdir
    path = "#{tmpdir}/mixed.contamination"
    File.write(path, "remove seq1 reason\nRemove seq2 reason\nREMOVE seq3 reason\n")
    result = parse_decon_file(path)
    result.should eq(["seq1", "seq2", "seq3"])
    File.delete(path)
  end
end

describe "parse_bed_file" do
  it "extracts sequence IDs from lines containing REMOVE" do
    tmpdir = Dir.tempdir
    path = "#{tmpdir}/test.contamination.bed"
    File.write(path, "scaffold_1\t100\t200\tREMOVE\nscaffold_2\t300\t400\tKEEP\nscaffold_3\t500\t600\tREMOVE\n")
    result = parse_bed_file(path)
    result.should eq(["scaffold_1", "scaffold_3"])
    File.delete(path)
  end

  it "returns empty array when no REMOVE lines exist" do
    tmpdir = Dir.tempdir
    path = "#{tmpdir}/clean.bed"
    File.write(path, "scaffold_1\t100\t200\tKEEP\n")
    result = parse_bed_file(path)
    result.should be_empty
    File.delete(path)
  end
end

describe "av" do
  it "computes mean of Float64 array" do
    av([1.0, 2.0, 3.0]).should eq(2.0)
  end

  it "computes mean of Int32 array" do
    av([10, 20, 30]).should eq(20.0)
  end

  it "handles single-element arrays" do
    av([42.0]).should eq(42.0)
  end
end

describe "get_ave" do
  it "returns the mean of values for given keys" do
    h = {"a" => 10.0, "b" => 20.0, "c" => 30.0}
    get_ave(h, ["a", "c"]).should eq(20.0)
  end

  it "works with a single key" do
    h = {"x" => 5.0}
    get_ave(h, ["x"]).should eq(5.0)
  end
end
