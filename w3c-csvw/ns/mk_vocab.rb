#! /usr/bin/env ruby
# Parse vocabulary definition in CSV to generate Context+Vocabulary in JSON-LD or Turtle

require 'getoptlong'
require 'csv'
require 'json'
require 'erubis'

class Vocab
  JSON_STATE = JSON::State.new(
    :indent       => "  ",
    :space        => " ",
    :space_before => "",
    :object_nl    => "\n",
    :array_nl     => "\n"
  )

  TITLE = "CSVW Namespace Vocabulary Terms".freeze
  DESCRIPTION = %(This document describes the RDFS vocabulary description used in the Metadata Vocabulary for Tabular Data [[tabular-metadata]] along with the default JSON-LD Context.).freeze
  attr_accessor :prefixes, :terms, :properties, :classes, :instances, :datatypes,
                :imports, :date, :commit, :seeAlso

  def initialize
    path = File.expand_path("../_vocab.csv", __FILE__)
    csv = CSV.new(File.open(path))
    @prefixes, @terms, @properties, @classes, @datatypes, @instances = {}, {}, {}, {}, {}, {}
    @imports, @seeAlso = [], []
    git_info = %x{git log -1 #{path}}.split("\n")
    @commit = "https://github.com/w3c/csvw/commit/" + git_info[0].split.last
    @date = Date.parse(git_info[2].split(":",2).last).strftime("%Y-%m-%d")

    columns = []
    csv.shift.each_with_index {|c, i| columns[i] = c.to_sym if c}

    csv.each do |line|
      entry = {}
      # Create entry as object indexed by symbolized column name
      line.each_with_index {|v, i| entry[columns[i]] = v ? v.gsub("\r", "\n").gsub("\\", "\\\\") : nil}

      case entry[:type]
      when 'prefix'         then @prefixes[entry[:id]] = entry
      when 'term'           then @terms[entry[:id]] = entry
      when 'rdf:Property'   then @properties[entry[:id]] = entry
      when 'rdfs:Class'     then @classes[entry[:id]] = entry
      when 'rdfs:Datatype'  then @datatypes[entry[:id]] = entry
      when 'owl:imports'    then @imports << entry[:subClassOf]
      when 'rdfs:seeAlso'   then @seeAlso << entry[:subClassOf]
      else                       @instances[entry[:id]] = entry
      end
    end

  end

  def namespaced(term)
    term.include?(":") ? term : "csvw:#{term}"
  end

  def to_jsonld
    context = {}
    rdfs_context = ::JSON.parse %({
      "id": "@id",
      "type": "@type",
      "dc:title": {"@container": "@language"},
      "dc:description": {"@container": "@language"},
      "dc:date": {"@type": "xsd:date"},
      "rdfs:comment": {"@container": "@language"},
      "rdfs:domain": {"@type": "@id"},
      "rdfs:label": {"@container": "@language"},
      "rdfs:range": {"@type": "@id"},
      "rdfs:seeAlso": {"@type": "@id"},
      "rdfs:subClassOf": {"@type": "@id"},
      "rdfs:subPropertyOf": {"@type": "@id"},
      "owl:equivalentClass": {"@type": "@vocab"},
      "owl:equivalentProperty": {"@type": "@vocab"},
      "owl:oneOf": {"@container": "@list", "@type": "@vocab"},
      "owl:imports": {"@type": "@id"},
      "owl:versionInfo": {"@type": "@id"},
      "owl:inverseOf": {"@type": "@vocab"},
      "owl:unionOf": {"@type": "@vocab", "@container": "@list"},
      "rdfs_classes": {"@reverse": "rdfs:isDefinedBy", "@type": "@id"},
      "rdfs_properties": {"@reverse": "rdfs:isDefinedBy", "@type": "@id"},
      "rdfs_datatypes": {"@reverse": "rdfs:isDefinedBy", "@type": "@id"},
      "rdfs_instances": {"@reverse": "rdfs:isDefinedBy", "@type": "@id"}
    })
    rdfs_classes, rdfs_properties, rdfs_datatypes, rdfs_instances = [], [], [], []

    prefixes.each do |id, entry|
      context[id] = entry[:subClassOf]
    end

    terms.each do |id, entry|
      context[id] = entry[:subClassOf]
    end

    classes.each  do |id, entry|
      term = entry[:term] || id
      context[term] = namespaced(id)

      # Class definition
      node = {
        '@id' => namespaced(id),
        '@type' => 'rdfs:Class',
        'rdfs:label' => {"en" => entry[:label].to_s},
        'rdfs:comment' => {"en" => entry[:comment].to_s},
      }
      node['rdfs:subClassOf'] = namespaced(entry[:subClassOf]) if entry[:subClassOf]
      rdfs_classes << node
    end

    properties.each do |id, entry|
      defn = {"@id" => namespaced(id)}
      case entry[:range]
      when "xsd:string" then defn['@language'] = nil
      when /xsd:/       then defn['@type'] = entry[:range]
      when nil          then ;
      else                   defn['@type'] = '@id'
      end

      defn['@container'] = entry[:@container] if entry[:@container]
      defn['@type'] = entry[:@type] if entry[:@type]

      term = entry[:term] || id
      context[term] = defn

      # Property definition
      node = {
        '@id' => namespaced(id),
        '@type' => 'rdf:Property',
        'rdfs:label' => {"en" => entry[:label].to_s},
        'rdfs:comment' => {"en" => entry[:comment].to_s},
      }
      node['rdfs:subPropertyOf'] = namespaced(entry[:subClassOf]) if entry[:subClassOf]

      domains = entry[:domain].to_s.split(',')
      case domains.length
      when 0  then ;
      when 1  then node['rdfs:domain'] = namespaced(domains.first)
      else         node['rdfs:domain'] = {'owl:unionOf' => domains.map {|d| namespaced(d)}}
      end

      ranges = entry[:range].to_s.split(',')
      case ranges.length
      when 0  then ;
      when 1  then node['rdfs:range'] = namespaced(ranges.first)
      else         node['rdfs:range'] = {'owl:unionOf' => ranges.map {|r| namespaced(r)}}
      end

      rdfs_properties << node
    end

    datatypes.each  do |id, entry|
      context[id] = namespaced(id)

      # Datatype definition
      node = {
        '@id' => namespaced(id),
        '@type' => 'rdfs:Datatype',
        'rdfs:label' => {"en" => entry[:label].to_s},
        'rdfs:comment' => {"en" => entry[:comment].to_s},
      }
      node['rdfs:subClassOf'] = namespaced(entry[:subClassOf]) if entry[:subClassOf]
      rdfs_datatypes << node
    end

    instances.each do |id, entry|
      # Instance definition
      rdfs_instances << {
        '@id' => namespaced(id),
        '@type' => entry[:type],
        'rdfs:label' => {"en" => entry[:label].to_s},
        'rdfs:comment' => {"en" => entry[:comment].to_s},
      }
    end

    # Use separate rdfs context so as not to polute the CSVW context.
    ontology = {
      "@context" => rdfs_context,
      "@id" => prefixes["csvw"][:subClassOf],
      "@type" => "owl:Ontology",
      "dc:title" => {"en" => TITLE},
      "dc:description" => {"en" => DESCRIPTION},
      "dc:date" => date,
      "owl:imports" => imports,
      "owl:versionInfo" => commit,
      "rdfs:seeAlso" => seeAlso,
      "rdfs_classes" => rdfs_classes,
      "rdfs_properties" => rdfs_properties,
      "rdfs_datatypes" => rdfs_datatypes,
      "rdfs_instances" => rdfs_instances
    }.delete_if {|k,v| Array(v).empty?}

    {
      "@context" => context,
      "@graph" => ontology
    }.to_json(JSON_STATE)
  end

  def to_html
    json = JSON.parse(to_jsonld)
    eruby = Erubis::Eruby.new(File.read("template.html"))
    eruby.result(ont: json['@graph'], context: json['@context'])
  end

  def to_ttl
    output = []

    @prefixes.each {|id, entry| output << "@prefix #{id}: <#{entry[:subClassOf]}> ."}

    output << "\n# CSVM Ontology definition"
    output << "csvw: a owl:Ontology;"
    output << %(  dc:title "#{TITLE}"@en;)
    output << %(  dc:description """#{DESCRIPTION}"""@en;)
    output << %(  dc:date "#{date}"^^xsd:date;)
    output << %(  dc:imports #{imports.map {|i| '<' + i + '>'}.join(", ")};)
    output << %(  owl:versionInfo <#{commit}>;)
    output << %(  rdfs:seeAlso #{seeAlso.map {|i| '<' + i + '>'}.join(", ")};)
    output << "  .\n"

    output << "\n# Class definitions"#{
    @classes.each do |id, entry|
      output << "csvw:#{id} a rdfs:Class;"
      output << %(  rdfs:label "#{entry[:label]}"@en;)
      output << %(  rdfs:comment """#{entry[:comment]}"""@en;)
      output << %(  rdfs:subClassOf #{namespaced(entry[:subClassOf])};) if entry[:subClassOf]
      output << %(  rdfs:isDefinedBy csvw: .)
    end

    output << "\n# Property definitions"
    @properties.each do |id, entry|
      output << "csvw:#{id} a rdf:Property;"
      output << %(  rdfs:label "#{entry[:label]}"@en;)
      output << %(  rdfs:comment """#{entry[:comment]}"""@en;)
      output << %(  rdfs:subPropertyOf #{namespaced(entry[:subClassOf])};) if entry[:subClassOf]
      domains = entry[:domain].to_s.split(',')
      case domains.length
      when 0  then ;
      when 1  then output << %(  rdfs:domain #{namespaced(entry[:domain])};)
      else
        output << %(  rdfs:domain [ owl:unionOf (#{domains.map {|d| namespaced(d)}.join(' ')})];)
      end

      ranges = entry[:range].to_s.split(',')
      case ranges.length
      when 0  then ;
      when 1  then output << %(  rdfs:range #{namespaced(entry[:range])};)
      else
        output << %(  rdfs:range [ owl:unionOf (#{ranges.map {|d| namespaced(d)}.join(' ')})];)
      end
      output << %(  rdfs:isDefinedBy csvw: .)
    end

    output << "\n# Datatype definitions"
    @datatypes.each do |id, entry|
      output << "csvw:#{id} a rdfs:Datatype;"
      output << %(  rdfs:label "#{entry[:label]}"@en;)
      output << %(  rdfs:comment """#{entry[:comment]}"""@en;)
      output << %(  rdfs:subClassOf #{namespaced(entry[:subClassOf])};) if entry[:subClassOf]
      output << %(  rdfs:isDefinedBy csvw: .)
    end

    output << "\n# Instance definitions"
    @instances.each do |id, entry|
      output << "csvw:#{id} a #{namespaced(entry[:type])};"
      output << %(  rdfs:label "#{entry[:label]}"@en;)
      output << %(  rdfs:comment """#{entry[:comment]}"""@en;)
      output << %(  rdfs:isDefinedBy csvw: .)
    end

    output.join("\n")
  end

end

options = {
  output: $stdout
}

OPT_ARGS = [
  ["--format", "-f",  GetoptLong::REQUIRED_ARGUMENT,"Output format, default #{options[:format].inspect}"],
  ["--output", "-o",  GetoptLong::REQUIRED_ARGUMENT,"Output to the specified file path"],
  ["--quiet",         GetoptLong::NO_ARGUMENT,      "Supress most output other than progress indicators"],
  ["--help", "-?",    GetoptLong::NO_ARGUMENT,      "This message"]
]
def usage
  STDERR.puts %{Usage: #{$0} [options] URL ...}
  width = OPT_ARGS.map do |o|
    l = o.first.length
    l += o[1].length + 2 if o[1].is_a?(String)
    l
  end.max
  OPT_ARGS.each do |o|
    s = "  %-*s  " % [width, (o[1].is_a?(String) ? "#{o[0,2].join(', ')}" : o[0])]
    s += o.last
    STDERR.puts s
  end
  exit(1)
end

opts = GetoptLong.new(*OPT_ARGS.map {|o| o[0..-2]})

opts.each do |opt, arg|
  case opt
  when '--format'       then options[:format] = arg.to_sym
  when '--output'       then options[:output] = File.open(arg, "w")
  when '--quiet'        then options[:quiet] = true
  when '--help'         then usage
  end
end

vocab = Vocab.new
case options[:format]
when :jsonld  then options[:output].puts(vocab.to_jsonld)
when :ttl     then options[:output].puts(vocab.to_ttl)
when :html    then options[:output].puts(vocab.to_html)
else
  %w(jsonld ttl html).each do |format|
    File.open(format == 'html' ? 'index.html' : "csvw.#{format}", "w") do |output|
      output.puts(vocab.send("to_#{format}".to_sym))
    end
  end
end
