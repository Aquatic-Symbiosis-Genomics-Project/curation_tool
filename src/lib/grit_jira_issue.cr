require "http/client"
require "html"
require "json"
require "yaml"
require "file_utils"

class GritJiraIssue
  @@url = "jira.sanger.ac.uk"
  @token : String?
  @yaml : (YAML::Any | Nil)

  getter merged

  def initialize(name : String, @merged : Bool = false)
    @id = name
    @token = self.get_token
  end

  def json
    @json ||= self.get_json
  end

  def yaml
    @yaml ||= self.get_yaml
  end

  def hic_read_dir
    self.yaml["hic_read_dir"].as_s
  end

  def pacbio_read_dir
    return nil unless self.yaml.as_h.has_key?("pacbio_read_dir")
    self.yaml["pacbio_read_dir"].as_s?
  end

  def ont_read_dir
    return nil unless self.yaml.as_h.has_key?("ont_read_dir")
    self.yaml["ont_read_dir"].as_s?
  end

  def projects
    self.yaml["projects"].as_a
  end

  def geval_db
    if self.json["fields"]["customfield_11643"].as_s?
      self.json["fields"]["customfield_11643"].as_s
    else
      ""
    end
  end

  def telomer
    if self.json["fields"]["customfield_11650"].as_s?
      self.json["fields"]["customfield_11650"].as_s
    else
      ""
    end
  end

  def decon_file
    self.json["fields"]["customfield_11677"].as_s
  end

  def release_version
    self.json["fields"]["customfield_11609"].as_f.to_i
  end

  def tol_id
    self.yaml["specimen"].as_s
  end

  def scientific_name
    self.yaml["species"].as_s
  end

  # in the form of tol_id _ version
  def sample_version
    "#{self.tol_id}_#{self.release_version}"
  end

  # in the form of tol_id . version
  def sample_dot_version
    "#{self.tol_id}.#{self.release_version}"
  end

  # curation working directory
  def working_dir
    # "/lustre/scratch123/tol/teams/grit/#{ENV["USER"]}/#{self.tol_id}_#{self.release_version}"
    dir = self.pacbio_read_dir || self.ont_read_dir
    dir.to_s.sub(/genomic_data\/.*/, "working/#{self.tol_id}_#{ENV["USER"]}_curation")
  end

  def pretext_dir
    prefix = self.tol_id[0]
    pretext_root = "/nfs/treeoflife-01/teams/grit/data/curated_pretext_maps"
    dir = Dir["#{pretext_root}/#{prefix}*"].select { |file| File.directory?(file) }
    if ['i', 'd', 'q', 't'].includes?(prefix)
      second = self.tol_id[1]
      dir = Dir["#{pretext_root}/#{prefix}_*/#{second}_*"].select { |file| File.directory?(file) }
    end
    dir[0]
  end

  # directory where the curated files go, based on the decon file  directory
  def curated_dir
    t = self.decon_file.split("/")[0..-4].join("/") + "/curated/" + self.tol_id

    if self.projects.map(&.as_s.downcase).includes? "genomeark"
      t += ".genomeark.#{self.release_version}"
    else
      t += ".#{self.release_version}"
    end
    t
  end

  def get_token : String
    File.each_line(Path["~/.netrc"].expand(home: true)) { |line|
      line = line.chomp
      columns = line.split
      return columns[-1].to_s if /\s+#{@@url}\s+login\s+token\s+password/.match(line)
    }
    raise "cannot get token for #{@@url}"
  end

  def get_json
    r = HTTP::Client.get("https://#{@@url}/rest/api/2/issue/#{@id}", headers: HTTP::Headers{"Accept" => "application/json", "Authorization" => "Bearer #{@token}"})
    raise "cannot get the ticket" unless r.success?
    @json = JSON.parse(r.body)
  end

  def get_yaml
    if self.json["fields"]["customfield_13408"].as_s?
      yaml_path = self.json["fields"]["customfield_13408"].as_s
      if File.exists?(yaml_path)
        yaml = YAML.parse(File.read(yaml_path))
      else
        file_name = File.basename(yaml_path)
        `scp tol22:#{yaml_path} /tmp/#{file_name}`
        if File.exists?("/tmp/#{file_name}")
          yaml = YAML.parse(File.read("/tmp/#{file_name}"))
          File.delete("/tmp/#{file_name}")
        end
      end
    end

    # if the file doesn't work, get it from Jira
    if yaml.nil?
      yaml_url = self.json["fields"]["attachment"].as_a.map { |e| e["content"] }.select { |elem| /.*\.(yaml|yml)/.match(elem.as_s) }[0]
      r = HTTP::Client.get("#{yaml_url}", headers: HTTP::Headers{"Authorization" => "Bearer #{@token}"})
      raise "cannot get the YAML from Jira" unless r.success?
      yaml = YAML.parse(r.body)
    end
    raise "cannot get the YAML data" if yaml.nil?
    @yaml = yaml
  end

  def curation_pretext(fasta, output, no_email = false)
    raise "input fasta file #{fasta} doesn't exist" unless File.exists?(fasta)

    telo = self.telomer.size > 1 ? "--teloseq #{self.telomer}" : ""
    reads = self.ont_read_dir || "#{self.pacbio_read_dir}/fasta"
    email = no_email ? "" : "-N #{ENV["USER"]}@sanger.ac.uk"
    <<-HERE
curationpretext.sh -profile sanger,singularity --input #{Path[fasta].expand} \
--sample #{self.sample_dot_version} \
--cram #{self.hic_read_dir} \
--reads #{reads} \
--outdir #{output} #{email} -c /nfs/users/nfs_m/mh6/clean.config #{telo}
HERE
  end

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
