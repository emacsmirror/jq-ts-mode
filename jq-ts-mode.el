;;; jq-ts-mode.el --- Tree-sitter support for jq buffers -*- lexical-binding: t; -*-

;; This is free and unencumbered software released into the public domain.

;; Author: Noah Peart <noah.v.peart@gmail.com>
;; URL: https://github.com/nverno/jq-ts-mode
;; Package-Requires: ((emacs "29"))
;; Created: 26 August 2023
;; Keywords: jq languages tree-sitter

;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;;; Code:

(require 'treesit)

(defcustom jq-ts-mode-indent-level 2
  "Number of spaces for each indentation step in `jq-ts-mode'."
  :type 'integer
  :safe 'integerp
  :group 'jq)

(defcustom jq-ts-mode-align-pipelines t
  "When non-nil, indent \"|\" to same level in pipelines."
  :type 'booleanp
  :safe 'booleanp
  :group 'jq)

(defconst jq-ts-mode--keywords
  '("and" "as" "break" "catch" "def" "elif" "else" "end" "foreach"
    "if" "import" "include" "label" "module" "or" "reduce" "then" "try")
  "Jq keywords for tree-sitter font-locking.")

(defconst jq-ts-mode--operators
  '("=" "+=" "-=" "*=" "/=" "%=" "|=" "//="
    "!=" "==" "<" ">" "<=" ">="
    "+" "-" "*" "/" "%"
    "|" "?"
    "//" "?//")
  "Jq operators for tree-sitter font-locking.")

(defconst jq-ts-mode--builtin-variables
  (rx string-start (or "$__loc__" "$ARGS" "$ENV") string-end)
  "Jq builtin variables for tree-sitter font-locking.")

(defconst jq-ts-mode--builtin-functions
  (rx string-start
      (or "acos" "acosh" "add" "all" "any" "arrays" "ascii_downcase" "ascii_upcase"
          "asin" "asinh" "atan" "atan2" "atanh" "booleans" "bsearch" "builtins"
          "capture" "cbrt" "ceil" "combinations" "contains" "copysign" "cos" "cosh"
          "debug" "del" "delpaths" "drem" "empty" "endswith" "env" "erf" "erfc" "error"
          "exp" "exp10" "exp2" "explode" "expm1" "fabs" "fdim" "finites" "first"
          "flatten" "floor" "fma" "fmax" "fmin" "fmod" "format" "frexp" "from_entries"
          "fromdate" "fromdateiso8601" "fromjson" "fromstream" "gamma" "get_jq_origin"
          "get_prog_origin" "get_search_list" "getpath" "gmtime" "group_by"
          "gsub" "halt" "halt_error" "has" "hypot" "implode" "IN" "in" "INDEX"
          "index" "indices" "infinite" "input" "input_filename" "input_line_number"
          "inputs" "inside" "isempty" "isfinite" "isinfinite" "isnan"
          "isnormal" "iterables" "j0" "j1" "jn" "JOIN" "join" "keys" "keys_unsorted"
          "last" "ldexp" "leaf_paths" "length" "lgamma" "lgamma_r" "limit"
          "localtime" "log" "log10" "log1p" "log2" "logb" "ltrimstr" "map" "map_values"
          "match" "max" "max_by" "min" "min_by" "mktime" "modf" "modulemeta"
          "nan" "nearbyint" "nextafter" "nexttoward" "normals" "not" "now" "nth"
          "nulls" "numbers" "objects" "path" "paths" "pow" "pow10" "range" "recurse"
          "recurse_down" "remainder" "repeat" "reverse" "rindex" "rint" "round"
          "rtrimstr" "scalars" "scalb" "scalbln" "scan" "select"
          "setpath" "significand" "sin" "sinh" "sort" "sort_by" "split" "splits"
          "sqrt" "startswith" "stderr" "strflocaltime" "strftime" "strings" "strptime"
          "sub" "tan" "tanh" "test" "tgamma" "to_entries" "todate" "todateiso8601"
          "tojson" "tonumber" "tostream" "tostring" "transpose" "trunc" "truncate_stream"
          "type" "unique" "unique_by" "until" "utf8bytelength" "values"
          "walk" "while" "with_entries" "y0" "y1" "yn")
      string-end)
  "Jq builtin functions for tree-sitter font-locking.")

;;; Font-locking

(defvar jq-ts-mode--treesit-lhs-identifier-query
  (when (treesit-available-p)
    (treesit-query-compile 'jq '((identifier) @id
                                 (field_id) @id
                                 (variable) @id)))
  "Query that captures identifier, field identifier, and variable.")


(defun jq-ts-mode--treesit-fontify-assignment-lhs (node override start end &rest _)
  "Fontify the lhs NODE of an assignment_expression.
For OVERRIDE, START, END, see `treesit-font-lock-rules'."
  (dolist (node (treesit-query-capture
                 node jq-ts-mode--treesit-lhs-identifier-query nil nil t))
    (treesit-fontify-with-override
     (treesit-node-start node) (treesit-node-end node)
     (pcase (treesit-node-type node)
       ("identifier" 'font-lock-variable-use-face)
       ("variable" 'font-lock-variable-use-face)
       ("field_id" 'font-lock-property-use-face))
     override start end)))

(defvar jq-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'jq
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'jq
   :feature 'constant
   '([(true) (false) (null)] @font-lock-constant-face)
   
   :language 'jq
   :feature 'number
   '((number) @font-lock-number-face)

   :language 'jq
   :feature 'builtin-function
   `((format) @font-lock-builtin-face
     ((identifier) @var (:match ,jq-ts-mode--builtin-functions @var))
     @font-lock-builtin-face)

   :language 'jq
   :feature 'builtin-variable
   `(((variable) @var (:match ,jq-ts-mode--builtin-variables @var))
     @font-lock-builtin-face)

   :language 'jq
   :feature 'operator
   `([,@jq-ts-mode--operators] @font-lock-operator-face)
   
   :language 'jq
   :feature 'bracket
   '((["(" ")" "[" "]" "{" "}"]) @font-lock-bracket-face)
   
   :language 'jq
   :feature 'delimiter
   '((["," ";" ":"]) @font-lock-delimiter-face)

   :language 'jq
   :feature 'keyword
   `([,@jq-ts-mode--keywords] @font-lock-keyword-face
     [(recurse) (dot)] @font-lock-keyword-face)

   :language 'jq
   :feature 'string
   '((string_content) @font-lock-string-face
     (string "\"" @font-lock-string-face))

   :language 'jq
   :feature 'interpolation
   :override t
   '((interpolation ["\\(" ")"] @font-lock-misc-punctuation-face))
   
   :language 'jq
   :feature 'escape-sequence
   :override t
   '((escape_sequence) @font-lock-escape-face)

   :language 'jq
   :feature 'definition
   :override t
   '((function_definition (identifier) @font-lock-function-name-face)
     (function_definition
      parameters: (parameter_list (identifier) @font-lock-variable-name-face)))

   :language 'jq
   :feature 'assignment
   '((assignment_expression
      left: (_) @jq-ts-mode--treesit-fontify-assignment-lhs))
   
   :language 'jq
   :feature 'function
   '((call_expression
      function: [(identifier) @font-lock-function-call-face]))
   
   :language 'jq
   :feature 'property
   :override t                          ; override string face on keys
   '((field_id) @font-lock-property-name-face
     (field name: [(string) (identifier)] @font-lock-property-use-face)
     (pair key: [(string) (identifier)] @font-lock-property-use-face))
   
   :language 'jq
   :feature 'variable
   '((variable) @font-lock-variable-name-face
     (import_statement
      name: (_) @font-lock-variable-name-face)))
  "Tree-sitter font-lock settings.")


;;; Indentation

(defun jq-ts-mode--indent-pipeline (node parent _bol)
  "Determine indentation for nodes in pipelines.
When `jq-ts-mode-align-pipelines', align NODE with topmost PARENT in pipeline."
  (when jq-ts-mode-align-pipelines
    (setq parent (treesit-parent-while
                  parent (lambda (n) (treesit-node-match-p n "pipeline")))))
  (save-excursion
    (goto-char (treesit-node-start parent))
    (back-to-indentation)
    (point)))

;; (MATCHER ANCHOR OFFSET)
(defvar jq-ts-mode--indent-rules
  `((jq
     ((parent-is "program") parent-bol 0)
     ;; ((query "(ERROR (ERROR)) @indent") column-0 0)
     ((node-is "}") parent-bol 0)
     ((node-is ")") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((parent-is "parenthesized_expression") parent-bol jq-ts-mode-indent-level)
     ;; pipelines
     ((node-is "|") jq-ts-mode--indent-pipeline jq-ts-mode-indent-level)
     ((parent-is "pipeline") parent-bol jq-ts-mode-indent-level)
     ;; if then elif else end
     ((node-is "else") first-sibling 0)
     ((node-is "then") first-sibling 0)
     ((node-is "elif") first-sibling 0)
     ((node-is "end") first-sibling 0)
     ((parent-is "if_expression") first-sibling jq-ts-mode-indent-level)
     ((parent-is "else_expression") first-sibling jq-ts-mode-indent-level)
     ((parent-is "reduce_expression") first-sibling jq-ts-mode-indent-level)
     ((parent-is "foreach_expression") first-sibling jq-ts-mode-indent-level)
     ((node-is "catch") first-sibling 0)
     ((parent-is "try_expression") first-sibling jq-ts-mode-indent-level)
     ((parent-is "call_expression") parent-bol jq-ts-mode-indent-level)
     ((parent-is "argument_list") parent-bol jq-ts-mode-indent-level)
     ((parent-is "parameter_list") parent-bol jq-ts-mode-indent-level)
     ;; ';' comes after expressions where it should be indented more (eg. reduce,foreach)
     ((node-is ";") parent-bol 0)
     ((parent-is "include_statement") parent-bol jq-ts-mode-indent-level)
     ((parent-is "import_statement") parent-bol jq-ts-mode-indent-level)
     ((parent-is "module") parent-bol jq-ts-mode-indent-level)
     ((parent-is "function_definition") parent-bol jq-ts-mode-indent-level)
     ((parent-is "function_expression") parent-bol 0)
     ((parent-is "string") no-indent)
     ((parent-is "interpolation") parent-bol jq-ts-mode-indent-level)
     ((parent-is "sequence_expression") parent-bol jq-ts-mode-indent-level)
     ((parent-is "binary_expression") parent-bol jq-ts-mode-indent-level)
     ((parent-is "assignment_expression") parent-bol jq-ts-mode-indent-level)
     ((parent-is "binding_expression") first-sibling jq-ts-mode-indent-level)
     ((parent-is "alternative") parent-bol jq-ts-mode-indent-level)
     ((parent-is "object") parent-bol jq-ts-mode-indent-level)
     ((parent-is "object_pattern") parent-bol jq-ts-mode-indent-level)
     ((parent-is "pair") parent-bol jq-ts-mode-indent-level)
     ((parent-is "pair_pattern") parent-bol jq-ts-mode-indent-level)
     ((parent-is "array") parent-bol jq-ts-mode-indent-level)
     ((parent-is "array_pattern") parent-bol jq-ts-mode-indent-level)
     ((parent-is "subscript_expression") parent-bol jq-ts-mode-indent-level)
     ((parent-is "slice_expression") parent 0)
     ((parent-is "optional_expression") parent 0)
     ((parent-is "field") parent 0)
     (no-node parent-bol 0)))
  "Tree-sitter indentation rules for Jq.")

(defun jq-ts-mode--variable-imenu-p (node)
  "Return non-nil if NODE is a variable defined in a binding expression."
  (pcase (treesit-node-type node)
    ("variable"
     (treesit-parent-until
      node (lambda (n) (treesit-node-match-p n "\\`binding_expression\\'"))))
    (_ nil)))

(defun jq-ts-mode--defun-name (node)
  "Return name for NODE."
  (treesit-node-text
   (treesit-search-subtree
    node
    (rx string-start (or "identifier" "variable") string-end)
    nil t)
   t))

;;; Syntax
(defvar jq-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?$  "_" table)
    (modify-syntax-entry ?_  "w" table)
    (modify-syntax-entry ?\\ "\\" table)
    (modify-syntax-entry ?#  "<" table)
    (modify-syntax-entry ?\n ">" table)
    (modify-syntax-entry ?+  "." table)
    (modify-syntax-entry ?-  "." table)
    (modify-syntax-entry ?=  "." table)
    (modify-syntax-entry ?%  "." table)
    (modify-syntax-entry ?<  "." table)
    (modify-syntax-entry ?>  "." table)
    (modify-syntax-entry ?&  "." table)
    (modify-syntax-entry ?|  "." table)
    (modify-syntax-entry ?*  "." table)
    (modify-syntax-entry ?/  "." table)
    table)
  "Syntax table for `jq-ts-mode'.")

;;; Navigation

(defvar jq-ts-mode--treesit-sentence-nodes
  '("module"
    "import_statement"
    "include_statement"
    "if_expression"
    "try_expression"
    "binding_expression"
    "reduce_expression"
    "foreach_expression"
    "label_expression"
    "break_expression")
  "Nodes that designate sentences in Jq.")

(defvar jq-ts-mode--treesit-sexp-nodes
  '("expression"
    "pattern"
    "array"
    "object"
    "string"
    "number"
    "identifier"
    "variable"
    "dot"
    "recurse"
    "true"
    "false"
    "null"
    "argument_list"
    "parameter_list"
    "pair")
  "Nodes that designate sexps in Jq.")


;;;###autoload
(define-derived-mode jq-ts-mode prog-mode "Jq"
  "Major mode for editing jq buffers.

\\<jq-ts-mode-map>"
  :group 'jq
  :syntax-table jq-ts-mode--syntax-table
  (when (treesit-ready-p 'jq)
    (treesit-parser-create 'jq)

    (setq-local comment-start "# ")
    (setq-local comment-end "")
    (setq-local comment-start-skip (rx "#" (* (syntax whitespace))))
        
    ;; Indentation
    (setq-local treesit-simple-indent-rules jq-ts-mode--indent-rules)

    ;; Font-Locking
    (setq-local treesit-font-lock-settings jq-ts-mode--font-lock-settings)
    (setq-local treesit-font-lock-feature-list
                '(( comment definition)
                  ( keyword variable string)
                  ( builtin-variable builtin-function
                    assignment constant number delimiter
                    escape-sequence interpolation property)
                  ( bracket operator function)))
    
    ;; Imenu
    (setq-local treesit-simple-imenu-settings
                `(("Function" "\\`function_definition\\'" nil nil)
                  ("Variable" "\\`variable\\'"
                   jq-ts-mode--variable-imenu-p nil )))

    ;; Navigation
    (setq-local treesit-defun-type-regexp
                (rx string-start (or "function_definition") string-end))
    (setq-local treesit-defun-name-function #'jq-ts-mode--defun-name)
    (setq-local treesit-text-type-regexp (regexp-opt '("comment" "string_content")))
    (setq-local treesit-sentence-type-regexp
                (regexp-opt jq-ts-mode--treesit-sentence-nodes))
    (setq-local treesit-sexp-type-regexp (regexp-opt jq-ts-mode--treesit-sexp-nodes))
    (setq-local treesit-defun-prefer-top-level t)
    
    (treesit-major-mode-setup)))

(if (treesit-ready-p 'jq)
    (add-to-list 'auto-mode-alist '("\\.jq\\'" . jq-ts-mode)))

(provide 'jq-ts-mode)
;; Local Variables:
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:
;;; jq-ts-mode.el ends here