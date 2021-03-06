;;; oook-to-file.el --- Associate XQuery result with file.

;;; Commentary:

;;; Code:

(require 'oook)

(defgroup oook-to-file nil
  "XML results pretty printer."
  :group 'oook)

(defun oook-eval-to-file-handler (_id result &rest args)
  (let ((res (apply oook-eval-handler _id result args))
        (filename (plist-get args :filename))
        (eval-in-buffer (plist-get args :eval-in-buffer)))
    (when res
      (with-current-buffer res
        (setq buffer-file-name filename)
        (normal-mode t)
        (rename-buffer filename t)
        (set-buffer-modified-p nil)
        (run-hooks 'oook-after-display-hook)
        (view-mode -1) ;; disable view-mode even if viewmode is in ook-after-display-hook
        (when eval-in-buffer
          (eval eval-in-buffer))))
    res))

(defun oook-eval-buffer-to-file ()
  "Eval current buffer in cider."
  (interactive)
  (oook-eval
   (buffer-substring-no-properties (point-min) (point-max))
   #'oook-eval-to-file-handler
   nil
   (read-file-name "Result file: ")))

(defvar oook-to-file-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [remap oook-eval-buffer] 'oook-eval-buffer-to-file)
    map)
  "Keymap for `oook-to-file-mode'.")

;;;###autoload
(define-minor-mode oook-to-file-mode
  "XML results pretty printer."
  :group 'oook-to-file
  :lighter " To-File"
  :keymap oook-to-file-mode-map)

(provide 'oook-to-file)

;;; oook-to-file.el ends here
