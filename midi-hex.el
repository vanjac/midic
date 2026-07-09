;; -*- lexical-binding: t; -*-

(defvar midi-hex-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?# "<\n" table)
    (modify-syntax-entry ?\n ">#" table)
    table))

(defvar-keymap midi-hex-mode-map
  "<tab>" #'move-to-tab-stop
  "<backtab>" #'move-to-prev-tab-stop
  "C-c TAB" #'tabify
  "C-M-S-<right>" #'increase-hex-number-at-point
  "C-M-S-<left>" #'decrease-hex-number-at-point)

(defun move-to-prev-tab-stop ()
  "Move point to previous defined tab-stop column."
  (interactive)
  (let ((prevtab (indent-next-tab-stop (current-column) t)))
    (when (wholenump prevtab)
      (move-to-column prevtab t))))

(defun increase-hex-number-at-point (&optional inc)
  "Increment hex value at point, clamped to the range of the available digits.
Based on org-increase-number-at-point"
  (interactive "p")
  (let* ((pos (point))
	 (beg (skip-chars-backward "0-9a-fA-F"))
	 (end (skip-chars-forward "0-9a-fA-F"))
	 (num-str (buffer-substring-no-properties (+ pos beg) (+ pos beg end)))
	 (num (string-to-number num-str 16))
	 (len (length num-str))
	 (new-num (max 0 (min (- (expt 16 len) 1) (+ num (or inc 1)))))
	 (new-num-str (format (concat "%0" (number-to-string len) "X") new-num)))
    (when (> len 0)
      (delete-region (+ pos beg) (+ pos beg end))
      (insert new-num-str))))

(defun decrease-hex-number-at-point (&optional inc)
  "Decrement hex value at point."
  (interactive "p")
  (increase-hex-number-at-point (- (or inc 1))))

(define-derived-mode midi-hex-mode prog-mode "MIDI"
  "Major mode for editing MIDI hex files."
  (setq-local comment-start "# "))

(provide 'midi-hex)
