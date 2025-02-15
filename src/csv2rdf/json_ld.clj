(ns csv2rdf.json-ld
  "Implementation of any parts of the JSON-LD specification required for expanding URIs in metadata documents.
   Defines the prefixes required to support compact URIs in common properties.

   RDFa initial context spec: https://www.w3.org/2011/rdfa-context/rdfa-1.1
   JSON-LD spec: https://www.w3.org/TR/json-ld/
   JSON-LD API spec: https://www.w3.org/TR/json-ld-api/")

(def ^{:metadata-spec "5.8.1"
       :rdfa-context-spec "vocabulary prefixes"} prefixes
  {"as" "https://www.w3.org/ns/activitystreams#"
   "csvw" "http://www.w3.org/ns/csvw#"
   "dcat" "http://www.w3.org/ns/dcat#"
   "dqv" "http://www.w3.org/ns/dqv#"
   "duv" "https://www.w3.org/TR/vocab-duv#"
   "grddl" "http://www.w3.org/2003/g/data-view#"
   "ldp" "http://www.w3.org/ns/ldp#"
   "ma" "http://www.w3.org/ns/ma-ont#"
   "oa" "http://www.w3.org/ns/oa#"
   "org" "http://www.w3.org/ns/org#"
   "owl" "http://www.w3.org/2002/07/owl#"
   "prov" "http://www.w3.org/ns/prov#"
   "qb" "http://purl.org/linked-data/cube#"
   "rdf" "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   "rdfa" "http://www.w3.org/ns/rdfa#"
   "rdfs" "http://www.w3.org/2000/01/rdf-schema#"
   "rif" "http://www.w3.org/2007/rif#"
   "rr" "http://www.w3.org/ns/r2rml#"
   "sd" "http://www.w3.org/ns/sparql-service-description#"
   "skos" "http://www.w3.org/2004/02/skos/core#"
   "skosxl" "http://www.w3.org/2008/05/skos-xl#"
   "ssn" "http://www.w3.org/ns/ssn/"
   "sosa" "http://www.w3.org/ns/sosa/"
   "time" "http://www.w3.org/2006/time#"
   "void" "http://rdfs.org/ns/void#"
   "wdr" "http://www.w3.org/2007/05/powder#"
   "wdrs" "http://www.w3.org/2007/05/powder-s#"
   "xhv" "http://www.w3.org/1999/xhtml/vocab#"
   "xml" "http://www.w3.org/XML/1998/namespace"
   "xsd" "http://www.w3.org/2001/XMLSchema#"
   "earl" "http://www.w3.org/ns/earl#"
   "odrl" "http://www.w3.org/ns/odrl/2/"
   "cc" "http://creativecommons.org/ns#"
   "ctag" "http://commontag.org/ns#"
   "dc" "http://purl.org/dc/terms/"
   "dcterms" "http://purl.org/dc/terms/"
   "dc11" "http://purl.org/dc/elements/1.1/"
   "foaf" "http://xmlns.com/foaf/0.1/"
   "gr" "http://purl.org/goodrelations/v1#"
   "ical" "http://www.w3.org/2002/12/cal/icaltzd#"
   "og" "http://ogp.me/ns#"
   "rev" "http://purl.org/stuff/rev#"
   "sioc" "http://rdfs.org/sioc/ns#"
   "v" "http://rdf.data-vocabulary.org/#"
   "vcard" "http://www.w3.org/2006/vcard/ns#"
   "schema" "http://schema.org/"
   "describedby" "http://www.w3.org/2007/05/powder-s#describedby"
   "license" "http://www.w3.org/1999/xhtml/vocab#license"
   "role" "http://www.w3.org/1999/xhtml/vocab#role"})

(def ^{:jsonld-spec "1.7"} keywords
  #{"@base" "@container" "@context" "@graph" "@id" "@index" "@language" "@list" "@nest" "@none" "@prefix"
    "@reverse" "@set" "@type" "@value" "@version" "@vocab"})

(defn is-keyword? [^String s]
  (contains? keywords s))

(defn- split-colon [^String s]
  (let [idx (.indexOf s ":")]
    (if (= -1 idx)
      [s ""]
      [(.substring s 0 idx) (.substring s (inc idx))])))

(defn ^String ^{:jsonld-api-spec "6.3"} expand-uri-string
  "Expands a string containing a URI or prefixed URI into a string containing the full URI. String which
   do not contain a URI are unaffected by the expansion."
  [^String uri-str]
  (if (is-keyword? uri-str)
    uri-str
    (let [[^String prefix ^String suffix] (split-colon uri-str)]
      (if (or (= "_" prefix) (.startsWith suffix "//"))
        uri-str
        (if-let [prefix-uri (get prefixes prefix)]
          (str prefix-uri suffix)
          uri-str)))))
