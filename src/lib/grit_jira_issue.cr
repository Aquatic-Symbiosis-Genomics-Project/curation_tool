require "http/client"
require "html"
require "json"
require "yaml"
require "file_utils"

# Represents a GRIT JIRA curation issue and provides access to all
# specimen metadata needed by the curation workflow tools.
#
# Authentication uses a Bearer token read from `~/.netrc` (entry for
# `jira.sanger.ac.uk`). Per-specimen metadata is loaded from a YAML file
# whose path is stored in JIRA custom field `customfield_13408`. If the
# file is not accessible locally it is fetched via `scp` from `tol22`, and
# as a last resort downloaded as a JIRA attachment.
#
# The `merged` flag indicates that both haplotypes should be treated as a
# single merged assembly (hap1/hap2 or maternal/paternal dual-output mode).
class GritJiraIssue
  @@url = "jira.sanger.ac.uk"
  @token : String?
  @yaml : (YAML::Any | Nil)

  getter merged

  # Creates a new issue handle for *name* (e.g. `"RC-1234"`).
  # Set *merged* to `true` for dual-haplotype assemblies.
  def initialize(name : String, @merged : Bool = false)
    @id = name
    @token = self.get_token
  end

  # Returns the parsed JIRA issue JSON, fetching it on first access.
  def json
    @json ||= self.get_json
  end

  # Returns the parsed per-specimen YAML, fetching it on first access.
  def yaml
    @yaml ||= self.get_yaml
  end

  # Returns the Hi-C read directory (or directories) as an array of strings.
  # Handles both scalar and list values in the YAML.
  def hic_read_dir
    if self.yaml["hic_read_dir"].as_a?
      self.yaml["hic_read_dir"].as_a
    else
      [self.yaml["hic_read_dir"].as_s]
    end
  end

  # Returns the PacBio read directory, or `nil` if not present in the YAML.
  def pacbio_read_dir
    return nil unless self.yaml.as_h.has_key?("pacbio_read_dir")
    self.yaml["pacbio_read_dir"].as_s?
  end

  # Returns the ONT read directory, or `nil` if not present in the YAML.
  def ont_read_dir
    return nil unless self.yaml.as_h.has_key?("ont_read_dir")
    self.yaml["ont_read_dir"].as_s?
  end

  # Returns the list of project names associated with this specimen (e.g. `["DToL", "GenomeArk"]`).
  def projects
    self.yaml["projects"].as_a
  end

  # Returns the geval database name from JIRA custom field `customfield_11643`,
  # or an empty string if not set.
  def geval_db
    if self.json["fields"]["customfield_11643"].as_s?
      self.json["fields"]["customfield_11643"].as_s
    else
      ""
    end
  end

  # Returns the telomere sequence from JIRA custom field `customfield_11650`,
  # or an empty string if not set.
  def telomer
    if self.json["fields"]["customfield_11650"].as_s?
      self.json["fields"]["customfield_11650"].as_s
    else
      ""
    end
  end

  # Returns the decontamination file path from JIRA custom field `customfield_11677`.
  # May be a `.bed` file (contamination intervals) or a `.fa.gz` decontaminated FASTA.
  def decon_file
    self.json["fields"]["customfield_11677"].as_s
  end

  # Returns the integer release version from JIRA custom field `customfield_11609`.
  def release_version
    self.json["fields"]["customfield_11609"].as_f.to_i
  end

  # Returns the ToL specimen ID (e.g. `"mMusMus1"`) from the YAML `specimen` key.
  def tol_id
    self.yaml["specimen"].as_s
  end

  # Returns the scientific name of the specimen from the YAML `species` key.
  def scientific_name
    self.yaml["species"].as_s
  end

  # Returns the specimen identifier in underscore form: `<tol_id>_<release_version>`.
  def sample_version
    "#{self.tol_id}_#{self.release_version}"
  end

  # Returns the specimen identifier in dot form: `<tol_id>.<release_version>`.
  def sample_dot_version
    "#{self.tol_id}.#{self.release_version}"
  end

  # Returns the curation working directory on the HPC.
  # Derived from `pacbio_read_dir` or `ont_read_dir` by replacing the
  # `genomic_data/...` suffix with `working/<tol_id>_<user>_curation`.
  def working_dir
    # "/lustre/scratch123/tol/teams/grit/#{ENV["USER"]}/#{self.tol_id}_#{self.release_version}"
    dir = self.pacbio_read_dir || self.ont_read_dir
    dir.to_s.sub(/genomic_data\/.*/, "working/#{self.tol_id}_#{ENV["USER"]}_curation")
  end

  # Returns the curated pretext map directory for this specimen under
  # `/nfs/treeoflife-01/teams/grit/data/curated_pretext_maps`.
  # For invertebrate/other prefixes (`i`, `d`, `q`, `t`, `c`) a two-level
  # subdirectory lookup is used. Raises if no matching directory is found.
  def pretext_dir
    prefix = self.tol_id[0]
    pretext_root = "/nfs/treeoflife-01/teams/grit/data/curated_pretext_maps"
    dir = Dir["#{pretext_root}/#{prefix}*"].select { |file| File.directory?(file) }
    if ['i', 'd', 'q', 't', 'c'].includes?(prefix)
      second = self.tol_id[1]
      dir = Dir["#{pretext_root}/#{prefix}_*/#{second}_*"].select { |file| File.directory?(file) }
    end
    raise "no pretext directory found for #{self.tol_id} under #{pretext_root}" if dir.empty?
    dir[0]
  end

  # Returns the target directory for curated output files.
  # Derived from the decon file path; appended with `.genomeark.<version>`
  # for GenomeArk specimens, or `.<version>` otherwise.
  def curated_dir
    t = self.decon_file.split("/")[0..-4].join("/") + "/curated/" + self.tol_id

    if self.projects.map(&.as_s.downcase).includes? "genomeark"
      t += ".genomeark.#{self.release_version}"
    else
      t += ".#{self.release_version}"
    end
    t
  end

  # Reads the Bearer token for `jira.sanger.ac.uk` from `~/.netrc`.
  # Raises if no matching entry is found.
  def get_token : String
    File.each_line(Path["~/.netrc"].expand(home: true)) { |line|
      line = line.chomp
      columns = line.split
      return columns[-1].to_s if /\s+#{@@url}\s+login\s+token\s+password/.match(line)
    }
    raise "cannot get token for #{@@url}"
  end

  # Fetches the JIRA issue JSON via the REST API (`/rest/api/2/issue/<id>`).
  # Raises if the request fails.
  def get_json
    r = HTTP::Client.get("https://#{@@url}/rest/api/2/issue/#{@id}", headers: HTTP::Headers{"Accept" => "application/json", "Authorization" => "Bearer #{@token}"})
    raise "cannot get the ticket" unless r.success?
    @json = JSON.parse(r.body)
  end

  # Loads and parses the per-specimen YAML.
  #
  # Resolution order:
  # 1. Path stored in JIRA custom field `customfield_13408`, read directly if it exists locally.
  # 2. Same path fetched via `scp` from `tol22` into `/tmp/`.
  # 3. YAML attachment downloaded directly from the JIRA issue.
  #
  # Raises if no YAML can be obtained.
  def get_yaml
    if self.json["fields"]["customfield_13408"].as_s?
      yaml_path = self.json["fields"]["customfield_13408"].as_s
      if File.exists?(yaml_path)
        yaml = YAML.parse(File.read(yaml_path))
      else
        file_name = File.basename(yaml_path)
        tmp_path = "/tmp/#{file_name}"
        STDERR.puts "WARNING: #{yaml_path} not found locally, trying scp from tol22"
        `scp tol22:#{yaml_path} #{tmp_path}`
        if $?.success? && File.exists?(tmp_path)
          yaml = YAML.parse(File.read(tmp_path))
          File.delete(tmp_path)
        else
          STDERR.puts "WARNING: scp of #{yaml_path} from tol22 failed, falling back to Jira attachment"
        end
      end
    end

    # if the file doesn't work, get it from Jira
    if yaml.nil?
      attachments = self.json["fields"]["attachment"].as_a
        .map(&.["content"].as_s)
        .select { |url| /\.(yaml|yml)$/.match(url) }
      raise "no YAML attachment found on Jira issue #{@id}" if attachments.empty?
      r = HTTP::Client.get(attachments[0], headers: HTTP::Headers{"Authorization" => "Bearer #{@token}"})
      raise "cannot fetch YAML attachment from Jira (HTTP #{r.status_code})" unless r.success?
      yaml = YAML.parse(r.body)
    end
    raise "cannot get the YAML data" if yaml.nil?
    @yaml = yaml
  end

  # Builds and returns the shell command string to invoke the `curationpretext.sh`
  # Nextflow pipeline for *fasta* (must exist), writing output to *output*.
  #
  # Writes a YAML params file next to *fasta* and assembles the command with
  # the correct read files, Hi-C CRAMs, telomere sequence, and email flag.
  # Pass `no_email: true` to suppress the LSF completion notification.
  def curation_pretext(fasta, output, no_email = false)
    raise "input fasta file #{fasta} doesn't exist" unless File.exists?(fasta)

    telo = self.telomer.size > 1 ? self.telomer : ""
    reads = self.ont_read_dir || "#{self.pacbio_read_dir}/fasta"
    crams = self.hic_read_dir
    email = no_email ? "" : "-N #{ENV["USER"]}@sanger.ac.uk"
    read_files = Dir.glob("#{reads}/*.fasta.gz")
    cram_files = crams.flat_map { |directory| Dir.glob("#{directory}/*.cram") }
    input_file = Path[fasta].expand
    yaml_file = "#{input_file}.yml"

    params = {
      :sample         => self.sample_dot_version,
      :teloseq        => telo,
      :all_output     => false,
      :skip_tracks    => "NONE",
      :run_hires      => true,
      :run_ultra      => "force",
      :split_telomere => true,
      :input          => input_file,
      :reads          => read_files,
      :cram           => cram_files,
    }

    File.write(yaml_file, params.to_yaml)
    "curationpretext.sh -profile sanger,singularity -params-file #{yaml_file} --outdir #{output} #{email} -c /nfs/users/nfs_m/mh6/clean.config"
  end

  # Looks up the NCBI taxonomy ID for this specimen via the EBI taxonomy REST API.
  # First tries an exact scientific-name lookup, then falls back to an any-name search.
  # Returns the taxon ID as a string. Raises if no result is found.
  def taxonomy
    common_name = self.scientific_name.gsub(/\s/, "%20")

    r = HTTP::Client.get("https://www.ebi.ac.uk/ena/taxonomy/rest/scientific-name/#{common_name}", headers: HTTP::Headers{"Accept" => "application/json"})
    raise "cannot get the taxonomy" unless r.success?

    json = JSON.parse(r.body)

    if json.as_a.size < 1
      r = HTTP::Client.get("https://www.ebi.ac.uk/ena/taxonomy/rest/any-name/#{common_name}", headers: HTTP::Headers{"Accept" => "application/json"})
      raise "cannot get the taxonomy" unless r.success?

      json = JSON.parse(r.body)
    end

    raise "cannot get the taxonomy" if json.as_a.size < 1

    json[0]["taxId"].as_s
  end
end
