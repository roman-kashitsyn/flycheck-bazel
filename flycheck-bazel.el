;;; flycheck-bazel.el --- Flycheck: bazel targets support -*- lexical-binding: t -*-

;; Copyright (C) 2023 Roman Kashitsyn <roman.kashitsyn@gmail.com>

;; Author: Roman Kashitsyn <roman.kashitsyn@gmail.com>
;; Maintainer: Roman Kashitsyn <roman.kashitsyn@gmail.com>
;; Package-Requires: ((emacs "27.2") (flycheck "30"))
;; Version: 0.0.1
;; Keywords: flycheck

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This Flycheck extension integrates the Bazel build system with the
;; Flycheck infrastructure.
;;
;; The checker tries to build the target associated with the file
;; being checked and extracts errors using patterns matching to the
;; major mode.

;;; Code:

(require 'flycheck)
(require 'cl-lib)

(flycheck-def-executable-var bazel "bazel")

(flycheck-def-args-var flycheck-bazel-flags bazel)

(defun flycheck-bazel--targets-for-current-buffer ()
  "Return the list of targets for the current buffer."
  (when-let ((path (buffer-file-name)))
    (flycheck-bazel--build-target (file-relative-name path))))

(defun flycheck-bazel--build-target (path)
  "Return the list of direct Bazel dependencies for the specified PATH."
  (process-lines-ignore-status
   (flycheck-checker-executable 'bazel)
   "query"
   "--ui_event_filters=-info,-debug,-warning,-error,-stderr"
   "--noshow_progress"
   (format "kind(\".* rule\", rdeps(//..., \"%s\", 1))" path)))

(defun flycheck-bazel--workspace-root-p (directory)
  "Return non-nil if DIRECTORY is a Bazel workspace root."
  (locate-file "WORKSPACE" (list directory) '(".bazel" "")))

(defun flycheck-bazel--workspace ()
  "Return the Bazel workspace to which the current directory belongs."
  (when-let ((file-name (buffer-file-name)))
    (locate-dominating-file (file-name-directory file-name)
                            #'flycheck-bazel--workspace-root-p)))

(defun flycheck-bazel--verify (_checker)
  "Verify the universal Bazel syntax checker."
   (let ((workspace (flycheck-bazel--workspace))
         (targets (flycheck-bazel--targets-for-current-buffer)))
    (list
     (flycheck-verification-result-new
      :label "Bazel workspace root"
      :message (if workspace (format "Found at %s" workspace) "Not found")
      :face (if workspace 'success '(bold error)))
     (flycheck-verification-result-new
      :label "Found Bazel targets"
      :message (if targets (format "Found: %s" (string-join targets)) "Not found")
      :face (if targets 'success '(bold warning))))))

(defun flycheck-bazel--working-directory (_checker)
  "Return the workspace directory for the Bazel checker."
  (flycheck-bazel--workspace))

(flycheck-define-checker bazel
  "A universal checker based on https://bazel.build."
  :command ("bazel"
            "build"
            "--ui_event_filters=-info,-debug,-warning,-stderr"
            "--noshow_progress"
            "--@rules_rust//:error_format=json"
            (eval (flycheck-bazel--targets-for-current-buffer)))
  :verify flycheck-bazel--verify
  :enabled flycheck-bazel--workspace
  :error-filter flycheck-rust-error-filter
  :error-parser flycheck-parse-rustc
  :error-explainer flycheck-rust-error-explainer
  :working-directory flycheck-bazel--working-directory
  :modes (rust-mode))

;;;###autoload
(defun flycheck-bazel-setup ()
  "Setup Flycheck-Bazel."
  (add-to-list 'flycheck-checkers 'bazel))

(provide 'flycheck-bazel)
;;; flycheck-bazel.el ends here
