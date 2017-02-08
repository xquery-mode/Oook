;;; oook-pprint.el --- XML results pretty printer.

;;; Commentary:

;;; Code:

(require 'oook)

(defgroup oook-pprint nil
  "XML results pretty printer."
  :group 'oook)

(defcustom oook-pprint-indicator " •"
  "String for pretty print indication.")

(defvar oook-pprint-old-handler nil)

(defun oook-do-pprint (_id result &rest args)
  "Pretty print xml content first.

See `oook' callback definition for RESULT and ARGS
meaning."
  (let ((res (apply oook-pprint-old-handler
                    _id
                    (mapcar
                     (lambda (result)
                       (with-temp-buffer
                         (insert result)
                         (goto-char (point-min))
                         (if (and (looking-at-p "[[:space:]]*<")
                                  (zerop
                                   (shell-command-on-region
                                    (point-min)
                                    (point-max)
                                    "xmllint --format -"
                                    (current-buffer)
                                    t)))
                             (progn
                               (nxml-mode)
                               (indent-region (point-min) (point-max))
                               (buffer-substring-no-properties (point-min) (point-max)))
                           result)))
                     result)
                    args)))
    (when res
      (with-current-buffer res
        (setq mode-line-format
              (cons '(:propertize oook-pprint-indicator face bold)
                    mode-line-format))))
    res))

;;;###autoload
(define-minor-mode oook-pprint-mode
  "XML results pretty printer."
  :lighter nil
  :group 'oook-pprint
  :global t
  (if oook-pprint-mode
      (setq oook-pprint-old-handler oook-eval-handler
            oook-eval-handler #'oook-do-pprint)
    (setq oook-eval-handler oook-pprint-old-handler
          oook-pprint-old-handler nil)))

(provide 'oook-pprint)

;;; oook-pprint.el ends here
