;; -*- lexical-binding: t; -*-

(defvar midi-hex-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?# "<\n" table)
    (modify-syntax-entry ?\n ">#" table)
    table))

(defvar-keymap midi-hex-mode-map
  "<tab>" #'move-to-tab-stop
  "<backtab>" #'move-to-prev-tab-stop
  "C-c TAB" #'tabify)

(defun move-to-prev-tab-stop ()
  "Move point to previous defined tab-stop column."
  (interactive)
  (let ((prevtab (indent-next-tab-stop (current-column) t)))
    (when (wholenump prevtab)
      (move-to-column prevtab t))))

(define-derived-mode midi-hex-mode prog-mode "MIDI"
  "Major mode for editing MIDI hex files."
  (setq-local comment-start "# "))

(provide 'midi-hex)
