require "http/client"
require "html"
require "json"
require "yaml"
require "file_utils"

class GritJiraIssue
  @@url = "jira.sanger.ac.uk"
  @token : String?

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
    "/lustre/scratch123/tol/teams/grit/#{ENV["USER"]}/#{self.tol_id}_#{self.release_version}"
  end

  def pretext_dir
    prefix = self.tol_id[0]
    pretext_root = "/nfs/treeoflife-01/teams/grit/data/curated_pretext_maps"
    dir = Dir["#{pretext_root}/#{prefix}*"].select { |file| File.directory?(file) }
    if ['i','d'].includes?(prefix)
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
    r = HTTP::Client.get("https://jira.sanger.ac.uk/rest/api/2/issue/#{@id}", headers: HTTP::Headers{"Accept" => "application/json", "Authorization" => "Bearer #{@token}"})
    raise "cannot get the ticket" unless r.success?
    @json = JSON.parse(r.body)
  end

  def get_yaml
    yaml_url = self.json["fields"]["attachment"].as_a.map { |e| e["content"] }.select { |elem| /.*\.(yaml|yml)/.match(elem.as_s) }[0]
    r = HTTP::Client.get("#{yaml_url}", headers: HTTP::Headers{"Authorization" => "Bearer #{@token}"})
    raise "cannot get the yaml" unless r.success?
    @yaml = YAML.parse(r.body)
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
