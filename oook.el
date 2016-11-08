;;; oook.el --- Evaluate XQuery  -*- lexical-binding: t; -*-

;; Author: Artem Malyshev <proofit404@gmail.com>
;; URL: https://github.com/xquery-mode/Oook
;; Version: 0.0.1
;; Package-Requires: ((cider "0.13.0"))

;;; Commentary:

;;; Code:

(require 'cl-lib)
(require 'cider)
(require 'page-break-lines)

(defgroup oook nil
  "Evaluate any buffer in cider."
  :group 'cider)

(defcustom oook-connection '(:host nil :port nil :user nil :password nil :content-base nil)
  "Property list of :host :port :user :password :content-base for uruk session creation."
  :type 'plist
  :group 'oook)

(defcustom oook-eval-handler 'oook-display-buffer
  "Response handle function."
  :type 'function
  :group 'oook-eval)

(defcustom oook-eval-buffer-template "*XQuery-Result-%s*"
  "Base buffer name to show XQuery documents."
  :type 'string
  :group 'oook-eval)

(defvar oook-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-k") 'oook-eval-buffer)
    (define-key map (kbd "C-c C-c") 'oook-eval-function)
    (define-key map (kbd "C-c C-l") 'oook-eval-line)
    (define-key map (kbd "C-c C-r") 'oook-eval-region)
    (define-key map (kbd "C-c M-:") 'oook-eval-string)
    map)
  "Keymap for `oook-mode'.")

(defun oook-eval-buffer ()
  "Eval current buffer in cider."
  (interactive)
  (oook-eval
   (buffer-substring-no-properties (point-min) (point-max))
   oook-eval-handler))

(defun oook-eval-function ()
  "Eval current function in cider."
  (interactive)
  (oook-eval
   (buffer-substring-no-properties
    (save-excursion
      (beginning-of-defun)
      (point))
    (save-excursion
      (end-of-defun)
      (point)))
   oook-eval-handler))

(defun oook-eval-line ()
  "Eval current line in cider."
  (interactive)
  (oook-eval
   (buffer-substring-no-properties
    (line-beginning-position)
    (line-end-position))
   oook-eval-handler))

(defun oook-eval-region ()
  "Eval current region in cider."
  (interactive)
  (oook-eval
   (if (not (region-active-p))
       (error "Region is not marked")
     (buffer-substring-no-properties
      (region-beginning)
      (region-end)))
   oook-eval-handler))

(defun oook-eval-string ()
  "Eval string in cider."
  (interactive)
  (oook-eval (read-string "XQuery: ") oook-eval-handler))

;;;###autoload
(define-minor-mode oook-mode
  "Evaluate anything.

\\{oook-mode-map}"
  :group 'oook
  :lighter " Oook"
  :keymap oook-mode-map)


;;; Evaluate functions.

(defun oook-eval (xquery callback &optional errback &rest args)
  "Eval specified XQUERY string asynchronously.

CALLBACK function must have following signature:

    (CALLBACK RESULT &rest ARGS)

ERRBACK if specified must have following signature:

    (ERRBACK ERROR &rest ARGS)"
  (cider-ensure-connected)
  (let* ((arg (oook-escape xquery))
         (form (format (oook-get-form) arg))
         (nrepl-callback (apply #'oook-make-nrepl-handler callback errback args))
         (connection (cider-current-connection))
         (session oook-session))
    (nrepl-request:eval form nrepl-callback connection session)))

(defun oook-eval-sync (xquery)
  "Eval specified XQUERY string synchronously."
  (cider-ensure-connected)
  (let* ((arg (oook-escape xquery))
         (form (format (oook-get-form) arg))
         (connection (cider-current-connection))
         (session oook-session)
         (response (nrepl-sync-request:eval form connection session))
         (value (nrepl-dict-get response "value")))
    (and value (read value))))

(defun oook-escape (xquery)
  (replace-regexp-in-string "\\\"" "\\\\\"" xquery))

(defun oook-get-form ()
  "Clojure form for XQuery document evaluation."
  (format "(do
             (require '[uruk.core :as uruk])
             (set! *print-length* nil)
             (set! *print-level* nil)
             (let [host \"%s\"
                   port %s
                   db %s]
               (with-open [session (uruk/create-default-session (uruk/make-hosted-content-source host port db))]
                 (doall (map (fn [it]
                               (if (instance? (Class/forName \"[B\") it)
                                 (String. it)
                                 (str it)))
                             (uruk/execute-xquery session \"%%s\"))))))"
          (plist-get oook-connection :host)
          (plist-get oook-connection :port)
          (oook-plist-to-map oook-connection)))

(defun oook-make-nrepl-handler (callback errback &rest args)
  (nrepl-make-response-handler
   (current-buffer)
   (lambda (buffer value)
     (with-current-buffer buffer
       (apply callback (and value (read value)) args)))
   (lambda (_buffer out)
     (cider-emit-interactive-eval-output out))
   (lambda (buffer err)
     (with-current-buffer buffer
       (if errback
           (apply errback err args)
         (cider-emit-interactive-eval-err-output err))))
   '()))

(defun oook-plist-to-map (plist)
  "Convert Elisp PLIST into Clojure map."
  (concat "{"
          (mapconcat #'(lambda (element)
                         (if (eq element t)
                             "true"
                           (cl-case (type-of element)
                             (cons (oook-plist-to-map element))
                             (integer (number-to-string element))
                             (float (number-to-string element))
                             (string (concat "\"" element "\""))
                             (symbol (symbol-name element)))))
                     plist
                     " ")
          "}"))


;;; Interactive eval result handlers.

(defun oook-browse (result &rest _args)
  "Show RESULT in the browser."
  (mapc
   (lambda (result)
     (let ((filename (make-temp-file "oook-eval")))
       (with-temp-file filename
         (insert result))
       (browse-url (concat "file://" filename))))
   result))

(defvar oook-after-display-hook nil
  "Hook runs after result buffer shows up.")

(add-hook 'oook-after-display-hook 'view-mode)
(add-hook 'oook-after-display-hook 'page-break-lines-mode)

(defun oook-display-buffer (result &rest _args)
  "Show RESULT in the buffer."
  (if (not result)
      (prog1 nil
        (message "XQuery returned an empty sequence"))
    (pop-to-buffer
     (with-current-buffer
         (get-buffer-create (format oook-eval-buffer-template (buffer-name)))
       (fundamental-mode)
       (view-mode -1)
       (erase-buffer)
       (oook-insert-result result)
       (normal-mode)
       (run-hooks 'oook-after-display-hook)
       (current-buffer)))))

(defun oook-insert-result (result)
  (let ((old-position (point)))
    (insert (car result))
    (dolist (item (cdr result))
      (insert "\n")
      (insert (make-string 1 ?\))
      (insert "\n")
      (insert item))
    (goto-char old-position)))


;;; NREPL session management.

(defvar oook-session nil)

(defun oook-connected ()
  (let ((response (nrepl-sync-request:clone (current-buffer))))
    (nrepl-dbind-response response (new-session err)
      (if new-session
          (setq oook-session new-session)
        (error "Could not create new session (%s)" err)))))

(defun oook-disconnected ()
  (setq oook-session nil))

(add-hook 'nrepl-connected-hook 'oook-connected)
(add-hook 'nrepl-disconnected-hook 'oook-disconnected)

(provide 'oook)

;;; oook.el ends here
