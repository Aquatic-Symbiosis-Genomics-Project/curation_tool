require "./spec_helper"

class CurationToolTest
  include CurationTool
end

describe CurationTool do
  describe "VERSION" do
    it "is set" do
      CurationTool::VERSION.should eq("v1.2.0")
    end
  end

  describe "#latest_file" do
    it "raises a descriptive error when nothing matches" do
      tmpdir = Dir.tempdir
      testdir = "#{tmpdir}/ct_test_latest_empty_#{Random.rand(100000)}"
      Dir.mkdir_p(testdir)

      ct = CurationToolTest.new
      expect_raises(Exception, /no widget found/) do
        ct.latest_file("#{testdir}/*.widget", "widget")
      end

      FileUtils.rm_rf(testdir)
    end

    it "returns the most recently modified matching file" do
      tmpdir = Dir.tempdir
      testdir = "#{tmpdir}/ct_test_latest_newest_#{Random.rand(100000)}"
      Dir.mkdir_p(testdir)

      File.write("#{testdir}/old.widget", "old")
      File.write("#{testdir}/new.widget", "new")
      # Force a distinct, later modification time on the expected winner.
      File.touch("#{testdir}/new.widget", Time.utc + 10.seconds)

      ct = CurationToolTest.new
      ct.latest_file("#{testdir}/*.widget", "widget").should eq("#{testdir}/new.widget")

      FileUtils.rm_rf(testdir)
    end
  end

  describe "#setup_tol" do
    it "raises when scaffolds.tpf already exists" do
      tmpdir = Dir.tempdir
      testdir = "#{tmpdir}/ct_test_guard_#{Random.rand(100000)}"
      Dir.mkdir_p(testdir)

      yaml_str = <<-YAML
      specimen: mMusMus1
      species: Mus musculus
      hic_read_dir: #{testdir}/genomic_data/hic
      pacbio_read_dir: #{testdir}/genomic_data/pacbio
      projects:
        - DToL
      YAML

      y = TestJiraIssue.new("RC-1234", yaml_str: yaml_str)
      wd = y.working_dir

      Dir.mkdir_p(wd)
      File.write("#{wd}/scaffolds.tpf", "dummy")

      ct = CurationToolTest.new
      expect_raises(Exception, /scaffolds.tpf/) do
        ct.setup_tol(y)
      end

      FileUtils.rm_rf(testdir)
    end

    it "creates working directory and decompresses fasta" do
      tmpdir = Dir.tempdir
      testdir = "#{tmpdir}/ct_test_decomp_#{Random.rand(100000)}"
      genomic_dir = "#{testdir}/genomic_data/pacbio"
      Dir.mkdir_p(genomic_dir)

      # Create a gzipped fasta to decompress
      fasta_content = ">seq1\nACGT\n"
      File.write("#{testdir}/decontaminated.fa", fasta_content)
      `gzip #{testdir}/decontaminated.fa`

      yaml_str = <<-YAML
      specimen: mMusMus1
      species: Mus musculus
      hic_read_dir: #{testdir}/genomic_data/hic
      pacbio_read_dir: #{testdir}/genomic_data/pacbio
      projects:
        - DToL
      YAML

      json_str = <<-JSON
      {
        "fields": {
          "customfield_13408": null,
          "customfield_11677": "#{testdir}/contamination/something.contamination.bed",
          "customfield_11609": 3.0,
          "customfield_11650": "TTAGGG",
          "customfield_11643": null,
          "attachment": []
        }
      }
      JSON

      y = TestJiraIssue.new("RC-1234", json_str: json_str, yaml_str: yaml_str)
      wd = y.working_dir

      ct = CurationToolTest.new
      ct.setup_tol(y)

      Dir.exists?(wd).should be_true
      File.exists?("#{wd}/original.fa").should be_true
      File.read("#{wd}/original.fa").should contain(">seq1")

      FileUtils.rm_rf(testdir)
    end

    it "concatenates hap1 and hap2 fastas when merged with hap keys" do
      tmpdir = Dir.tempdir
      testdir = "#{tmpdir}/ct_test_merged_#{Random.rand(100000)}"
      genomic_dir = "#{testdir}/genomic_data/pacbio"
      Dir.mkdir_p(genomic_dir)

      hap1_dir = "#{testdir}/assembly/hap1"
      hap2_dir = "#{testdir}/assembly/hap2"
      Dir.mkdir_p(hap1_dir)
      Dir.mkdir_p(hap2_dir)

      File.write("#{hap1_dir}/mMusMus1.hap1.decontaminated.fa", ">hap1_seq\nAAAA\n")
      `gzip #{hap1_dir}/mMusMus1.hap1.decontaminated.fa`
      File.write("#{hap2_dir}/mMusMus1.hap2.decontaminated.fa", ">hap2_seq\nTTTT\n")
      `gzip #{hap2_dir}/mMusMus1.hap2.decontaminated.fa`

      yaml_str = <<-YAML
      specimen: mMusMus1
      species: Mus musculus
      hic_read_dir: #{testdir}/genomic_data/hic
      pacbio_read_dir: #{testdir}/genomic_data/pacbio
      hap1: #{hap1_dir}/mMusMus1.hap1.fa.gz
      hap2: #{hap2_dir}/mMusMus1.hap2.fa.gz
      projects:
        - DToL
      YAML

      json_str = <<-JSON
      {
        "fields": {
          "customfield_13408": null,
          "customfield_11677": "#{testdir}/contamination/something.contamination.bed",
          "customfield_11609": 3.0,
          "customfield_11650": "TTAGGG",
          "customfield_11643": null,
          "attachment": []
        }
      }
      JSON

      y = TestJiraIssue.new("RC-1234", merged: true, json_str: json_str, yaml_str: yaml_str)
      wd = y.working_dir

      ct = CurationToolTest.new
      ct.setup_tol(y)

      File.exists?("#{wd}/original.fa").should be_true
      content = File.read("#{wd}/original.fa")
      content.should contain(">hap1_seq")
      content.should contain(">hap2_seq")

      FileUtils.rm_rf(testdir)
    end
  end
end
