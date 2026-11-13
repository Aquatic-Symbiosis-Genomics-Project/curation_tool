require "./spec_helper"

describe GritJiraIssue do
  describe "#tol_id" do
    it "returns the specimen field from YAML" do
      y = TestJiraIssue.new("RC-1234")
      y.tol_id.should eq("mMusMus1")
    end
  end

  describe "#scientific_name" do
    it "returns the species field from YAML" do
      y = TestJiraIssue.new("RC-1234")
      y.scientific_name.should eq("Mus musculus")
    end
  end

  describe "#release_version" do
    it "returns the integer release version from JSON" do
      y = TestJiraIssue.new("RC-1234")
      y.release_version.should eq(3)
    end
  end

  describe "#curated_chromosomes" do
    it "returns the curated chromosome count from a JIRA select option" do
      y = TestJiraIssue.new("RC-1234")
      y.curated_chromosomes.should eq(21)
    end

    it "accepts a plain integer, float or numeric string" do
      ["21", "21.0", %("21")].each do |value|
        y = TestJiraIssue.new("RC-1234", json_str: %({"fields": {"customfield_13210": #{value}}}))
        y.curated_chromosomes.should eq(21)
      end
    end

    it "returns nil when not set" do
      y = TestJiraIssue.new("RC-1234", json_str: FIXTURE_JSON_EMPTY_CUSTOM)
      y.curated_chromosomes.should be_nil
    end
  end

  describe "#sample_version" do
    it "returns tolid_version with underscore" do
      y = TestJiraIssue.new("RC-1234")
      y.sample_version.should eq("mMusMus1_3")
    end
  end

  describe "#sample_dot_version" do
    it "returns tolid.version with dot" do
      y = TestJiraIssue.new("RC-1234")
      y.sample_dot_version.should eq("mMusMus1.3")
    end
  end

  describe "#geval_db" do
    it "returns the geval database name when set" do
      y = TestJiraIssue.new("RC-1234")
      y.geval_db.should eq("mMusMus1_geval")
    end

    it "returns empty string when not set" do
      y = TestJiraIssue.new("RC-1234", json_str: FIXTURE_JSON_EMPTY_CUSTOM)
      y.geval_db.should eq("")
    end
  end

  describe "#telomer" do
    it "returns the telomere sequence when set" do
      y = TestJiraIssue.new("RC-1234")
      y.telomer.should eq("TTAGGG")
    end

    it "returns empty string when not set" do
      y = TestJiraIssue.new("RC-1234", json_str: FIXTURE_JSON_EMPTY_CUSTOM)
      y.telomer.should eq("")
    end
  end

  describe "#decon_file" do
    it "returns the decontamination file path" do
      y = TestJiraIssue.new("RC-1234")
      y.decon_file.should eq("/lustre/scratch123/tol/species/Mus_musculus/mMusMus1/assembly/draft/treeval/hap1/contamination/mMusMus1.hap1.contamination.bed")
    end
  end

  describe "#merged" do
    it "defaults to false" do
      y = TestJiraIssue.new("RC-1234")
      y.merged.should be_false
    end

    it "can be set to true" do
      y = TestJiraIssue.new("RC-1234", merged: true)
      y.merged.should be_true
    end
  end

  describe "#hic_read_dir" do
    it "returns a single-element array for a scalar value" do
      y = TestJiraIssue.new("RC-1234")
      dirs = y.hic_read_dir
      dirs.size.should eq(1)
      dirs[0].to_s.should eq("/lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/hic")
    end

    it "returns multiple elements for an array value" do
      y = TestJiraIssue.new("RC-1234", yaml_str: FIXTURE_YAML_MULTI_HIC)
      dirs = y.hic_read_dir
      dirs.size.should eq(2)
      dirs[0].to_s.should contain("run1")
      dirs[1].to_s.should contain("run2")
    end
  end

  describe "#pacbio_read_dir" do
    it "returns the pacbio read directory when present" do
      y = TestJiraIssue.new("RC-1234")
      y.pacbio_read_dir.should eq("/lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/pacbio")
    end

    it "returns nil when not present" do
      y = TestJiraIssue.new("RC-1234", yaml_str: FIXTURE_YAML_ONT)
      y.pacbio_read_dir.should be_nil
    end
  end

  describe "#ont_read_dir" do
    it "returns the ONT read directory when present" do
      y = TestJiraIssue.new("RC-1234", yaml_str: FIXTURE_YAML_ONT)
      y.ont_read_dir.should eq("/lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/ont")
    end

    it "returns nil when not present" do
      y = TestJiraIssue.new("RC-1234")
      y.ont_read_dir.should be_nil
    end
  end

  describe "#hic_read_files" do
    it "returns the Hi-C read file paths when present" do
      y = TestJiraIssue.new("RC-1234", yaml_str: FIXTURE_YAML_READ_FILES)
      y.hic_read_files.should eq([
        "/lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/hic/mMusMus1.hic.1.cram",
        "/lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/hic/mMusMus1.hic.2.cram",
      ])
    end

    it "returns nil when not present" do
      y = TestJiraIssue.new("RC-1234")
      y.hic_read_files.should be_nil
    end

    it "returns nil when the list is empty" do
      y = TestJiraIssue.new("RC-1234", yaml_str: "hic_read_files: []")
      y.hic_read_files.should be_nil
    end

    it "returns nil when the key is blank" do
      y = TestJiraIssue.new("RC-1234", yaml_str: "hic_read_files:")
      y.hic_read_files.should be_nil
    end
  end

  describe "#pacbio_read_files" do
    it "returns the PacBio read file paths when present" do
      y = TestJiraIssue.new("RC-1234", yaml_str: FIXTURE_YAML_READ_FILES)
      y.pacbio_read_files.should eq([
        "/lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/pacbio/mMusMus1.pacbio.1.fasta.gz",
        "/lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/pacbio/mMusMus1.pacbio.2.fasta.gz",
      ])
    end

    it "returns nil when not present" do
      y = TestJiraIssue.new("RC-1234")
      y.pacbio_read_files.should be_nil
    end

    it "returns nil when the list is empty" do
      y = TestJiraIssue.new("RC-1234", yaml_str: "pacbio_read_files: []")
      y.pacbio_read_files.should be_nil
    end
  end

  describe "#ont_read_files" do
    it "returns the ONT read file paths when present" do
      y = TestJiraIssue.new("RC-1234", yaml_str: FIXTURE_YAML_READ_FILES)
      y.ont_read_files.should eq([
        "/lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/ont/mMusMus1.ont.1.fasta.gz",
        "/lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/ont/mMusMus1.ont.2.fasta.gz",
      ])
    end

    it "returns nil when not present" do
      y = TestJiraIssue.new("RC-1234")
      y.ont_read_files.should be_nil
    end

    it "returns nil when the list is empty" do
      y = TestJiraIssue.new("RC-1234", yaml_str: "ont_read_files: []")
      y.ont_read_files.should be_nil
    end
  end

  describe "#curation_pretext" do
    it "prefers ONT reads and uses explicit Hi-C files" do
      testdir = "#{Dir.tempdir}/grit_jira_curation_pretext_#{Random.rand(UInt64)}"
      Dir.mkdir_p(testdir)
      fasta = "#{testdir}/input.fa"
      File.write(fasta, ">sample\nACGT\n")

      begin
        issue = TestJiraIssue.new("RC-1234", yaml_str: FIXTURE_YAML_READ_FILES)
        yaml_path = "#{Path[fasta].expand}.yml"
        issue.curation_pretext(fasta, "#{testdir}/output", no_email: true)
        params = YAML.parse(File.read(yaml_path))
        params["reads"].as_a.map(&.as_s).should eq(issue.ont_read_files)
        params["cram"].as_a.map(&.as_s).should eq(issue.hic_read_files)
      ensure
        FileUtils.rm_rf(testdir)
      end
    end

    it "uses PacBio reads when ONT files are absent" do
      testdir = "#{Dir.tempdir}/grit_jira_curation_pretext_#{Random.rand(UInt64)}"
      Dir.mkdir_p(testdir)
      fasta = "#{testdir}/input.fa"
      File.write(fasta, ">sample\nACGT\n")
      yaml = <<-YAML
        specimen: mMusMus1
        species: Mus musculus
        projects:
          - DToL
        pacbio_read_files:
          - /reads/pacbio.1.fasta.gz
          - /reads/pacbio.2.fasta.gz
        hic_read_files:
          - /reads/hic.1.cram
        YAML

      begin
        issue = TestJiraIssue.new("RC-1234", yaml_str: yaml)
        yaml_path = "#{Path[fasta].expand}.yml"
        issue.curation_pretext(fasta, "#{testdir}/output", no_email: true)
        params = YAML.parse(File.read(yaml_path))
        params["reads"].as_a.map(&.as_s).should eq(issue.pacbio_read_files)
      ensure
        FileUtils.rm_rf(testdir)
      end
    end

    it "uses explicit Hi-C files without requiring a Hi-C directory" do
      testdir = "#{Dir.tempdir}/grit_jira_curation_pretext_#{Random.rand(UInt64)}"
      Dir.mkdir_p(testdir)
      fasta = "#{testdir}/input.fa"
      File.write(fasta, ">sample\nACGT\n")
      yaml = <<-YAML
        specimen: mMusMus1
        species: Mus musculus
        projects:
          - DToL
        hic_read_files:
          - /reads/hic.1.cram
          - /reads/hic.2.cram
        YAML

      begin
        issue = TestJiraIssue.new("RC-1234", yaml_str: yaml)
        yaml_path = "#{Path[fasta].expand}.yml"
        issue.curation_pretext(fasta, "#{testdir}/output", no_email: true).should_not be_empty
        params = YAML.parse(File.read(yaml_path))
        params["cram"].as_a.map(&.as_s).should eq(issue.hic_read_files)
      ensure
        FileUtils.rm_rf(testdir)
      end
    end

    it "globs read and CRAM files from their directories" do
      testdir = "#{Dir.tempdir}/grit_jira_curation_pretext_#{Random.rand(UInt64)}"
      ont_dir = "#{testdir}/ont"
      hic_dir = "#{testdir}/hic"
      Dir.mkdir_p(ont_dir)
      Dir.mkdir_p(hic_dir)
      fasta = "#{testdir}/input.fa"
      File.write(fasta, ">sample\nACGT\n")
      ["reads.1.fasta.gz", "reads.2.fasta.gz", "ignore.txt"].each do |name|
        File.write("#{ont_dir}/#{name}", "file")
      end
      ["reads.1.cram", "reads.2.cram", "ignore.txt"].each do |name|
        File.write("#{hic_dir}/#{name}", "file")
      end
      yaml = <<-YAML
        specimen: mMusMus1
        species: Mus musculus
        projects:
          - DToL
        ont_read_dir: #{ont_dir}
        hic_read_dir: #{hic_dir}
        YAML

      begin
        issue = TestJiraIssue.new("RC-1234", yaml_str: yaml)
        yaml_path = "#{Path[fasta].expand}.yml"
        issue.curation_pretext(fasta, "#{testdir}/output", no_email: true)
        params = YAML.parse(File.read(yaml_path))
        params["reads"].as_a.map(&.as_s).sort!.should eq(Dir.glob("#{ont_dir}/*.fasta.gz").sort)
        params["cram"].as_a.map(&.as_s).sort!.should eq(Dir.glob("#{hic_dir}/*.cram").sort)
      ensure
        FileUtils.rm_rf(testdir)
      end
    end

    it "globs read and CRAM files when the YAML lists are empty" do
      testdir = "#{Dir.tempdir}/grit_jira_curation_pretext_#{Random.rand(UInt64)}"
      ont_dir = "#{testdir}/ont"
      hic_dir = "#{testdir}/hic"
      Dir.mkdir_p(ont_dir)
      Dir.mkdir_p(hic_dir)
      fasta = "#{testdir}/input.fa"
      File.write(fasta, ">sample\nACGT\n")
      ["reads.1.fasta.gz", "reads.2.fasta.gz", "ignore.txt"].each do |name|
        File.write("#{ont_dir}/#{name}", "file")
      end
      ["reads.1.cram", "reads.2.cram", "ignore.txt"].each do |name|
        File.write("#{hic_dir}/#{name}", "file")
      end
      yaml = <<-YAML
        specimen: mMusMus1
        species: Mus musculus
        projects:
          - DToL
        ont_read_files: []
        hic_read_files: []
        ont_read_dir: #{ont_dir}
        hic_read_dir: #{hic_dir}
        YAML

      begin
        issue = TestJiraIssue.new("RC-1234", yaml_str: yaml)
        yaml_path = "#{Path[fasta].expand}.yml"
        issue.curation_pretext(fasta, "#{testdir}/output", no_email: true)
        params = YAML.parse(File.read(yaml_path))
        params["reads"].as_a.map(&.as_s).sort!.should eq(Dir.glob("#{ont_dir}/*.fasta.gz").sort)
        params["cram"].as_a.map(&.as_s).sort!.should eq(Dir.glob("#{hic_dir}/*.cram").sort)
      ensure
        FileUtils.rm_rf(testdir)
      end
    end

    it "returns a command with the params file and output directory" do
      testdir = "#{Dir.tempdir}/grit_jira_curation_pretext_#{Random.rand(UInt64)}"
      Dir.mkdir_p(testdir)
      fasta = "#{testdir}/input.fa"
      output = "#{testdir}/output"
      File.write(fasta, ">sample\nACGT\n")

      begin
        issue = TestJiraIssue.new("RC-1234", yaml_str: FIXTURE_YAML_READ_FILES)
        yaml_path = "#{Path[fasta].expand}.yml"
        command = issue.curation_pretext(fasta, output, no_email: true)
        command.should contain("-params-file #{yaml_path}")
        command.should contain("--outdir #{output}")
      ensure
        FileUtils.rm_rf(testdir)
      end
    end
  end

  describe "#projects" do
    it "returns the list of projects" do
      y = TestJiraIssue.new("RC-1234")
      projects = y.projects.map(&.as_s)
      projects.should eq(["DToL", "GenomeArk"])
    end
  end

  describe "#working_dir" do
    it "derives working dir from pacbio_read_dir" do
      y = TestJiraIssue.new("RC-1234")
      wd = y.working_dir
      wd.should contain("working/mMusMus1_")
      wd.should contain("_curation")
      wd.should_not contain("genomic_data")
    end

    it "falls back to ont_read_dir when no pacbio" do
      y = TestJiraIssue.new("RC-1234", yaml_str: FIXTURE_YAML_ONT)
      wd = y.working_dir
      wd.should contain("working/mMusMus1_")
      wd.should contain("_curation")
    end
  end

  describe "#curated_dir" do
    it "includes genomeark suffix when GenomeArk is in projects" do
      y = TestJiraIssue.new("RC-1234")
      dir = y.curated_dir
      dir.should contain("curated/mMusMus1.genomeark.3")
    end

    it "uses simple version suffix when GenomeArk is not in projects" do
      y = TestJiraIssue.new("RC-1234", yaml_str: FIXTURE_YAML_MULTI_HIC)
      dir = y.curated_dir
      dir.should contain("curated/mMusMus1.3")
      dir.should_not contain("genomeark")
    end

    it "derives base path from decon_file" do
      y = TestJiraIssue.new("RC-1234")
      dir = y.curated_dir
      dir.should start_with("/lustre/scratch123/tol/species/Mus_musculus/mMusMus1/assembly/draft/treeval")
    end
  end

  describe "#files" do
    it "returns primary and haplotigs assembly paths when present" do
      y = TestJiraIssue.new("RC-1234", yaml_str: FIXTURE_YAML_MERGED_PRI)
      files = y.files
      files.size.should eq(2)
      files[0].should contain("mMusMus1.primary.fa.gz")
      files[1].should contain("mMusMus1.haplotigs.fa.gz")
    end

    it "returns hap1 and hap2 assembly paths when present" do
      y = TestJiraIssue.new("RC-1234", yaml_str: FIXTURE_YAML_MERGED_HAP)
      files = y.files
      files.size.should eq(2)
      files[0].should contain("mMusMus1.hap1.fa.gz")
      files[1].should contain("mMusMus1.hap2.fa.gz")
    end

    it "returns an empty array when no assembly keys are present" do
      y = TestJiraIssue.new("RC-1234")
      y.files.should be_empty
    end
  end

  describe "#assembly_files" do
    it "returns only the requested keys, in the requested order" do
      y = TestJiraIssue.new("RC-1234", yaml_str: FIXTURE_YAML_MERGED_PRI)
      selected = y.assembly_files(["primary"])
      selected.size.should eq(1)
      selected[0].should contain("mMusMus1.primary.fa.gz")
    end

    it "skips keys that are absent from the YAML" do
      y = TestJiraIssue.new("RC-1234", yaml_str: FIXTURE_YAML_MERGED_PRI)
      y.assembly_files(["hap1", "hap2"]).should be_empty
    end
  end

  describe "#decon_dir" do
    it "returns the parent directory of the first assembly file" do
      y = TestJiraIssue.new("RC-1234", yaml_str: FIXTURE_YAML_MERGED_PRI)
      y.decon_dir.should eq("/lustre/scratch123/tol/species/Mus_musculus/mMusMus1/assembly/draft/treeval/primary")
    end

    it "raises when the YAML contains no assembly files" do
      y = TestJiraIssue.new("RC-1234")
      expect_raises(Exception, /no assembly FASTA/) do
        y.decon_dir
      end
    end
  end

  describe "#user" do
    it "returns the USER environment variable" do
      saved = ENV["USER"]?
      ENV["USER"] = "testuser"
      begin
        TestJiraIssue.new("RC-1234").user.should eq("testuser")
      ensure
        saved ? (ENV["USER"] = saved) : ENV.delete("USER")
      end
    end

    it "raises a clear error when USER is not set" do
      saved = ENV["USER"]?
      ENV.delete("USER")
      begin
        expect_raises(Exception, /USER is not set/) do
          TestJiraIssue.new("RC-1234").user
        end
      ensure
        ENV["USER"] = saved if saved
      end
    end
  end
end
