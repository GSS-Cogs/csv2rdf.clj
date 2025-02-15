(ns csv2rdf.csvw.minimal
  (:require [csv2rdf.vocabulary :refer [rdf:nil rdf:first rdf:rest]]
            [csv2rdf.csvw.common :refer :all]
            [csv2rdf.util :refer [liberal-mapcat]]))

(defn minimal-cell-statements [table-url default-subject {:keys [aboutUrl] :as cell}]
  (let [subject (or aboutUrl default-subject)
        predicate (cell-predicate table-url cell)]
    (cell-value-statements subject predicate cell)))

(defn minimal-row-statements [table-url row]
  (let [default-subject (gen-blank-node)
        unsuppressed-cells (row-unsuppressed-cells row)]
    (mapcat (fn [cell]
              (minimal-cell-statements table-url default-subject cell))
            unsuppressed-cells)))

(defmethod table-group-context :minimal [mode _table-group]
  {:mode mode
   :statements []})

(defmethod table-statements :minimal [_context {:keys [url] :as table} annotated-rows]
  (liberal-mapcat (fn [row]
                    (minimal-row-statements url row))
                  annotated-rows))
