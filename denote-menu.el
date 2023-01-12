;;; denote-menu.el --- View denote files in a tabulated list. -*- lexical-binding: t -*-

;; Author: Mohamed Suliman <sulimanm@tcd.ie>
;; Version: 1.0.0
;; Package-Requires: ((emacs "28.1") (denote "1.2.0"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'tabulated-list)
(require 'denote)
(require 'dired)

(defgroup denote-menu ()
  "View Denote files"
  :group 'files)

(defcustom denote-menu-date-column-width 20
  "Width for the date column."
  :type 'number
  :group 'denote-menu)

(defcustom denote-menu-title-column-width 45
  "Width for the title column."
  :type 'number
  :group 'denote-menu)


(defcustom denote-menu-keywords-column-width 50
  "Width for the keywords column."
  :type 'number
  :group 'denote-menu)


(defcustom denote-menu-action (lambda (path) (find-file path))
  "Function to execute when a denote file button action is
invoked. Takes a single argument which is the path of the
denote file corresponding to the button."
  :type 'function
  :group 'denote-menu)

(defcustom denote-menu-initial-regex "."
  "Regex used to initially populate the buffer with matching denote files."
  :type 'string
  :group 'denote-menu)

(defvar denote-menu-current-regex denote-menu-initial-regex
  "The current regex used to match denote filenames.")

;;;###autoload
(defun denote-menu-list-notes ()
  "Display list of Denote files in variable `denote-directory'."

  (interactive)
  (let ((buffer (get-buffer-create "*Denote*")))
    (with-current-buffer buffer
      (setq buffer-file-coding-system 'utf-8)
      (setq denote-menu-current-regex denote-menu-initial-regex)
      (denote-menu-mode))
    
    (pop-to-buffer-same-window buffer)))

(defalias 'list-denotes 'denote-menu-list-notes
  "Alias of `denote-menu-list-notes' command.")

(defun denote-menu-update-entries ()
  "Sets `tabulated-list-entries' to a function that maps currently
displayed denote file names
matching the value of `denote-menu-current-regex' to a tabulated
list entry following the defined form. Then updates the buffer."
  (if tabulated-list-entries
      (progn
        (let
            ((current-entry-paths (denote-menu--entries-to-paths)))
          (setq tabulated-list-entries
                (lambda ()
                  (let ((matching-denote-files
                         (denote-menu-files-matching-regexp current-entry-paths denote-menu-current-regex)))
                    (mapcar #'denote-menu--path-to-entry matching-denote-files))))))
    (setq tabulated-list-entries
          (lambda ()
            (let ((matching-denote-files
                   (denote-directory-files-matching-regexp denote-menu-current-regex)))
              (mapcar #'denote-menu--path-to-entry matching-denote-files)))))

  (revert-buffer))

(defun denote-menu--entries-to-filenames ()
  "Return list of file names present in the *Denote* buffer."
  (mapcar (lambda (entry)
            (let ((id (car entry)))
              (file-name-nondirectory (denote-menu-get-path-by-id id))))
          (funcall tabulated-list-entries)))

(defun denote-menu--entries-to-paths ()
  "Return list of file paths present in the *Denote* buffer."
  (mapcar (lambda (entry)
            (let ((id (car entry)))
              (denote-menu-get-path-by-id id)))
          (funcall tabulated-list-entries)))

(defun denote-menu-get-path-by-id (id)
  "Return absolute path of ID string in `denote-directory-files'."
  (seq-find
   (lambda (f)
     (and (string-prefix-p id (file-name-nondirectory f))))
   (denote-directory-files)))


(defun denote-menu-files-matching-regexp (files regexp)
  "Return list of files matching REGEXP from FILES."
  (seq-filter (lambda (f) (string-match-p regexp f)) files))

(defun denote-menu--path-to-entry (path)
  "Convert PATH to an entry matching the form of `tabulated-list-entries'."
  `(,(denote-retrieve-filename-identifier path)
    [(,(denote-menu-date path) . (action ,(lambda (button) (funcall denote-menu-action path))))
     ,(denote-menu-title path)
     ,(propertize (format "%s" (denote-extract-keywords-from-path path)) 'face 'italic)]))
  
(defun denote-menu-date (path)
  (let* ((timestamp (split-string (denote-retrieve-filename-identifier path) "T"))
         (date (car timestamp))
         (year (substring date 0 4))
         (month (substring date 4 6))
         (day (substring date 6 8))
               
         (time (cadr timestamp))
         (hour (substring time 0 2))
         (seconds (substring time 2 4)))
                  
    (format "%s-%s-%s %s:%s" year month day hour seconds)))

(defun denote-menu-title (path)
  "Return title of PATH.
If the denote file PATH has no title, return the string \"(No
Title)\".  Otherwise return PATH's title.

Determine whether a denote file has a title based on the
following rule derived from the file naming scheme:

1. If the path does not have a \"--\", it has no title."
  (if (or (not (string-match-p "--" path)))
      (propertize "(No Title)" 'face 'font-lock-comment-face)
    (denote-retrieve-filename-title path)))

(defun denote-menu-filter (regexp)
  "Filter `tabulated-list-entries' matching REGEXP.
When called interactively, prompt for REGEXP.

Revert the *Denotes* buffer to include only the matching entries."
  (interactive (list (read-regexp "Filter regex: ")))
  (setq denote-menu-current-regex regexp)
  (denote-menu-update-entries))

(defun denote-menu-filter-by-keyword (keywords)
  "Prompt for KEYWORDS and filters the list accordingly.
When called from Lisp, KEYWORDS is a list of strings."
  (interactive (list (denote-keywords-prompt)))
  (let ((regex (concat "\\(" (mapconcat (lambda (keyword) (format "_%s" keyword)) keywords "\\|") "\\)")))
    (setq denote-menu-current-regex regex)
    (denote-menu-update-entries)))
    
(defun denote-menu-clear-filters ()
  "Reset filters to `denote-menu-initial-regex' and update buffer."
  (interactive)
  (setq denote-menu-current-regex denote-menu-initial-regex)
  (setq tabulated-list-entries nil)
  (denote-menu-update-entries) )

(defun denote-menu-export-to-dired ()
  "Switch to variable `denote-directory' and mark filtered *Denotes* files."
  (interactive)
  (let ((files-to-mark (denote-menu--entries-to-filenames)))
    (dired denote-directory)
    (revert-buffer)
    (dired-unmark-all-marks)
    (dired-mark-if
     (and (not (looking-at-p dired-re-dot))
	  (not (eolp))			; empty line
	  (let ((fn (dired-get-filename t t)))
            (and fn (member fn files-to-mark))))
     "matching file")))

(define-derived-mode denote-menu-mode tabulated-list-mode "Denote Menu"
  "Major mode for browsing a list of Denote files."
  :interactive nil
  (setq tabulated-list-format `[("Date" ,denote-menu-date-column-width t)
                                ("Title" ,denote-menu-title-column-width nil)
                                ("Keywords" ,denote-menu-keywords-column-width nil)])

  (denote-menu-update-entries)
  (setq tabulated-list-sort-key '("Date" . t))
  (tabulated-list-init-header)
  (tabulated-list-print))

;; trying to add subdirectories
(defun my/subdirectories ()
  (interactive)
  (setq denote-directory "~/Developer/capsule-tilde-pi")
  (denote-menu-update-entries))

(provide 'denote-menu)
;;; denote-menu.el ends here
