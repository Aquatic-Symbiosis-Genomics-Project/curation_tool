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
end
