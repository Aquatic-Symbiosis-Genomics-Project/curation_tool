require "spec"
require "../src/lib/grit_jira_issue"
require "../src/lib/curation_tool"

# Subclass that stubs all external I/O (network, ~/.netrc, scp) so that
# GritJiraIssue methods can be tested with in-memory fixture data.
class TestJiraIssue < GritJiraIssue
  @test_json : JSON::Any
  @test_yaml : YAML::Any

  def initialize(name : String, @merged : Bool = false,
                 json_str : String = FIXTURE_JSON,
                 yaml_str : String = FIXTURE_YAML)
    @id = name
    @token = "fake-token"
    @test_json = JSON.parse(json_str)
    @test_yaml = YAML.parse(yaml_str)
    @yaml = nil
  end

  def get_token : String
    "fake-token"
  end

  def get_json : JSON::Any
    @test_json
  end

  def get_yaml : YAML::Any
    @test_yaml
  end
end

FIXTURE_JSON = <<-JSON
{
  "fields": {
    "customfield_13408": "/lustre/scratch123/tol/resources/treeval/yaml/mMusMus1.yaml",
    "customfield_11677": "/lustre/scratch123/tol/species/Mus_musculus/mMusMus1/assembly/draft/treeval/hap1/contamination/mMusMus1.hap1.contamination.bed",
    "customfield_11609": 3.0,
    "customfield_11650": "TTAGGG",
    "customfield_11643": "mMusMus1_geval",
    "attachment": [
      {"content": "https://jira.sanger.ac.uk/secure/attachment/12345/mMusMus1.yaml"},
      {"content": "https://jira.sanger.ac.uk/secure/attachment/12346/screenshot.png"}
    ]
  }
}
JSON

FIXTURE_YAML = <<-YAML
specimen: mMusMus1
species: Mus musculus
hic_read_dir: /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/hic
pacbio_read_dir: /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/pacbio
projects:
  - DToL
  - GenomeArk
YAML

FIXTURE_YAML_MULTI_HIC = <<-YAML
specimen: mMusMus1
species: Mus musculus
hic_read_dir:
  - /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/hic/run1
  - /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/hic/run2
pacbio_read_dir: /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/pacbio
projects:
  - DToL
YAML

FIXTURE_YAML_ONT = <<-YAML
specimen: mMusMus1
species: Mus musculus
hic_read_dir: /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/hic
ont_read_dir: /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/ont
projects:
  - DToL
YAML

FIXTURE_YAML_MERGED_HAP = <<-YAML
specimen: mMusMus1
species: Mus musculus
hic_read_dir: /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/hic
pacbio_read_dir: /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/pacbio
hap1: /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/assembly/draft/treeval/hap1/mMusMus1.hap1.fa.gz
hap2: /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/assembly/draft/treeval/hap2/mMusMus1.hap2.fa.gz
projects:
  - DToL
YAML

FIXTURE_YAML_MERGED_MAT = <<-YAML
specimen: mMusMus1
species: Mus musculus
hic_read_dir: /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/hic
pacbio_read_dir: /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/pacbio
maternal: /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/assembly/draft/treeval/maternal/mMusMus1.maternal.fa.gz
paternal: /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/assembly/draft/treeval/paternal/mMusMus1.paternal.fa.gz
projects:
  - DToL
YAML

FIXTURE_YAML_MERGED_PRI = <<-YAML
specimen: mMusMus1
species: Mus musculus
hic_read_dir: /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/hic
pacbio_read_dir: /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/genomic_data/pacbio
primary: /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/assembly/draft/treeval/primary/mMusMus1.primary.fa.gz
haplotigs: /lustre/scratch123/tol/species/Mus_musculus/mMusMus1/assembly/draft/treeval/haplotigs/mMusMus1.haplotigs.fa.gz
projects:
  - DToL
YAML

FIXTURE_JSON_EMPTY_CUSTOM = <<-JSON
{
  "fields": {
    "customfield_13408": null,
    "customfield_11677": "/lustre/scratch123/tol/species/Mus_musculus/mMusMus1/assembly/draft/treeval/hap1/contamination/mMusMus1.hap1.contamination.bed",
    "customfield_11609": 1.0,
    "customfield_11650": null,
    "customfield_11643": null,
    "attachment": []
  }
}
JSON
