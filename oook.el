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
(require 'subr-x)

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

(defcustom oook-error-handler 'oook-display-error
  "Error handle function."
  :type 'function
  :group 'oook)

(defcustom oook-eval-buffer-template "*XQuery-Result-%s*"
  "Base buffer name to show XQuery documents."
  :type 'string
  :group 'oook-eval)

(defcustom oook-error-buffer-template "*XQuery-Error-%s*"
  "Base buffer name to show XQuery errors."
  :type 'string
  :group 'oook)

(defcustom oook-marklogic-install-dir "/opt/MarkLogic/"
  "MarkLogic server installation path.")

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
   oook-eval-handler
   oook-error-handler))

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
   oook-eval-handler
   oook-error-handler))

(defun oook-eval-line ()
  "Eval current line in cider."
  (interactive)
  (oook-eval
   (buffer-substring-no-properties
    (line-beginning-position)
    (line-end-position))
   oook-eval-handler
   oook-error-handler))

(defun oook-eval-region ()
  "Eval current region in cider."
  (interactive)
  (oook-eval
   (if (not (region-active-p))
       (error "Region is not marked")
     (buffer-substring-no-properties
      (region-beginning)
      (region-end)))
   oook-eval-handler
   oook-error-handler))

(defun oook-eval-string ()
  "Eval string in cider."
  (interactive)
  (oook-eval (read-string "XQuery: ") oook-eval-handler oook-error-handler))

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

    (CALLBACK ID RESULT &rest ARGS)

ERRBACK if specified must have following signature:

    (ERRBACK ID ERROR &rest ARGS)"
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
             (require '[clojure.string :as string])
             (require '[uruk.core :as uruk])
             (try
               (do
                 (set! *print-length* nil)
                 (set! *print-level* nil)
                 (let [host \"%s\"
                       port %s
                       db %s]
                   (with-open [session (uruk/create-default-session (uruk/make-hosted-content-source host port db))]
                     (doall (map str (uruk/execute-xquery session \"%%s\"))))))
               (catch com.marklogic.xcc.exceptions.XQueryException error
                 (let [nl (System/getProperty \"line.separator\")
                       format-str (.getFormatString error)
                       code (.getCode error)
                       data (.getData error)
                       stack (.getStack error)
                       session (.. error (getRequest) (getSession) (toString))
                       version (com.marklogic.xcc.Version/getVersionString)
                       server-version (.. error (getRequest) (getSession) (getServerVersion))
                       stacktrace (.getStackTrace error)]
                   (throw (Exception.
                           (string/join
                            (concat
                             (list
                              (if format-str
                                format-str
                                (string/join \" \" (cons code data)))
                              nl)
                             (map (fn [frame]
                                    (let [uri (.getUri frame)
                                          line (.getLineNumber frame)
                                          operation (.getOperation frame)
                                          variables (.getVariables frame)
                                          context-item (.getContextItem frame)
                                          context-position (.getContextPosition frame)]
                                      (string/join
                                       (remove nil?
                                               (concat (when uri
                                                         (list \"in \" uri))
                                                       (when (not (zero? line))
                                                         (list (when uri \", \") \"on line \" (str line)))
                                                       (list nl)
                                                       (when operation
                                                         (list \"in \" operation nl))
                                                       (when variables
                                                         (concat
                                                          (map (fn [variable]
                                                                 (let [name (.. variable (getName) (getLocalname))
                                                                       value (.. variable (getValue) (asString))]
                                                                   (when (and name value)
                                                                     (string/join (list \"  $\" name \" = \" value nl)))))
                                                               variables)
                                                          (when context-item
                                                            (list \"  context-item() = \" context-item nl))
                                                          (when (not (zero? context-position))
                                                            (list \"  context-position() = \" context-position nl)))))))))
                                  stack)
                             (list \"[Session: \" session \"]\" nl)
                             (list \"[Client: XCC/\" version)
                             (when server-version
                               (list \", Server: XDBC/\" server-version))
                             (list \"]\" nl)
                             (list nl \"Stacktrace:\" nl nl (string/join nl (map str stacktrace)) nl)))))))))"
          (plist-get oook-connection :host)
          (plist-get oook-connection :port)
          (oook-plist-to-map oook-connection)))

(defun oook-make-nrepl-handler (callback errback &rest args)
  ;; This function mostly repeat `nrepl-make-response-handler' logic.
  ;; One significant difference here that we pass request id inside
  ;; value and error handlers to support streaming results.  In
  ;; purpose of large tracebacks.
  (let ((buffer (current-buffer)))
    (lambda (response)
      (nrepl-dbind-response response (value ns out err status id pprint-out)
        (when (buffer-live-p buffer)
          (with-current-buffer buffer
            (when (and ns (not (derived-mode-p 'clojure-mode)))
              (cider-set-buffer-ns ns))))
        (cond (value
               (with-current-buffer buffer
                 (apply callback id (and value (read value)) args)))
              (out
               (cider-emit-interactive-eval-output out))
              (pprint-out
               (cider-emit-interactive-eval-output pprint-out))
              (err
               (with-current-buffer buffer
                 (if errback
                     (apply errback id err args)
                   (cider-emit-interactive-eval-err-output err))))
              (status
               (when (member "interrupted" status)
                 (message "Evaluation interrupted."))
               (when (member "eval-error" status)
                 (funcall nrepl-err-handler))
               (when (member "namespace-not-found" status)
                 (message "Namespace not found."))
               (when (member "need-input" status)
                 (cider-need-input buffer))
               (when (member "done" status)
                 (nrepl--mark-id-completed id))))))))

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

(defun oook-display-buffer (_id result &rest args)
  "Show RESULT in the buffer."
  (let ((eval-in-buffer (plist-get args :eval-in-buffer))
        (buffer-name (plist-get args :buffer-name)))
    (if (not result)
        (prog1 nil
          (message "XQuery returned an empty sequence"))
      (pop-to-buffer
       (with-current-buffer
           (get-buffer-create (or buffer-name
                                  (format oook-eval-buffer-template (buffer-name))))
         (fundamental-mode)
         (view-mode -1)
         (erase-buffer)
         (oook-insert-result result)
         (normal-mode)
         (run-hooks 'oook-after-display-hook)
         (when eval-in-buffer
          (eval eval-in-buffer))
         (current-buffer))))))

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


;;; Error handling.

(defvar-local oook-origin-buffer nil)

(defvar-local oook-last-failed-request nil)

(defvar oook-compilation-regexp-alist
  `(("^\\(in \\(.*\\), \\)?on line \\([[:digit:]]+\\)"
     (,(lambda ()
         (if (match-string-no-properties 2)
             (concat "<<marklogic>>" (match-string-no-properties 2))
           oook-origin-buffer))
      "%s")
     3))
  "`compilation-error-regexp-alist' for uruk errors.")

(defun oook-display-error (id error &rest _args)
  "Show ERROR in the buffer."
  (pop-to-buffer
   (let ((origin (buffer-file-name)))
     (with-current-buffer
         (get-buffer-create (format oook-error-buffer-template (buffer-name)))
       (let ((failed-id oook-last-failed-request))
         (fundamental-mode)
         (read-only-mode -1)
         (if (equal failed-id id)
             (goto-char (point-max))
           (erase-buffer))
         (insert error)
         (goto-char (point-min))
         (compilation-mode)
         (set (make-local-variable 'compilation-error-regexp-alist)
              oook-compilation-regexp-alist)
         (setq oook-origin-buffer origin
               oook-last-failed-request id)
         (current-buffer))))))

(defun oook-document-get (document)
  "Execute document-get request on DOCUMENT using MarkLogic service."
  (car (oook-eval-sync (format "
xquery version \"1.0-ml\";
try {xdmp:filesystem-file(\"%sModules%s\")}
catch ($exception) {()};
if (xdmp:modules-database() = 0)
then
  try {xdmp:filesystem-file(fn:replace(fn:concat(xdmp:modules-root(), \"%s\"), \"/+\", \"/\"))}
  catch ($exception) {()}
else
  xdmp:eval('xquery version \"1.0-ml\";
             fn:doc(\"%s\")',
            (),
            <options xmlns=\"xdmp:eval\">
              <database>{xdmp:modules-database()}</database>
            </options>)
" (file-name-directory (file-name-as-directory oook-marklogic-install-dir)) document document document))))

(defun oook-file-name-handler (operation &rest args)
  "File handler for MarkLogic documents.

See `file-name-handler-alist' for OPERATION and ARGS meaning."
  (let ((filename (car args)))
    (cl-case operation
      ((expand-file-name file-truename) filename)
      ((file-exists-p file-remote-p file-regular-p) t)
      ((file-directory-p file-writable-p vc-registered) nil)
      (file-attributes (list nil 1 0 0 '(22095 15153 0 0) '(22095 15153 0 0) '(22095 15153 0 0) 197867 "-rw-r--r--" t (abs (random)) (abs (random))))
      (file-modes (file-modes (locate-library "files")))
      (insert-file-contents (let* ((document (string-remove-prefix "<<marklogic>>" filename))
                                   (result (or (oook-document-get document)
                                               (format "Unable to read %s document" document))))
                              (insert result)
                              (setq buffer-file-name filename)
                              (list filename (length result))))
      (t (let ((inhibit-file-name-handlers '(oook-file-name-handler))
               (inhibit-file-name-operation operation))
           (apply operation args))))))

(add-to-list 'file-name-handler-alist
             '("\\`<<marklogic>>" . oook-file-name-handler))

(provide 'oook)

;;; oook.el ends here
