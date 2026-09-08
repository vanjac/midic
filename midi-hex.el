;; -*- lexical-binding: t; -*-

(defvar midi-hex-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?# "<\n" table)
    (modify-syntax-entry ?\n ">#" table)
    table))

(defvar-keymap midi-hex-mode-map
  "M-<right>" #'midi-next-tab-stop
  "M-<left>" #'midi-prev-tab-stop
  "<tab>" #'midi-next-tab-stop
  "<backtab>" #'midi-prev-tab-stop
  "C-c TAB" #'tabify
  "C-M-<right>" #'midi-increase-hex-at-point
  "C-M-<left>" #'midi-decrease-hex-at-point)

(defun midi-next-tab-stop ()
  "Move point to next defined tab-stop column."
  (interactive "^")
  (move-to-tab-stop))

(defun midi-prev-tab-stop ()
  "Move point to previous defined tab-stop column."
  (interactive "^")
  (let ((prevtab (indent-next-tab-stop (current-column) t)))
    (when (wholenump prevtab)
      (move-to-column prevtab t))))

(defun midi-increase-hex-at-point (&optional inc)
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

(defun midi-decrease-hex-at-point (&optional inc)
  "Decrement hex value at point."
  (interactive "p")
  (midi-increase-hex-at-point (- (or inc 1))))

(define-derived-mode midi-hex-mode prog-mode "MIDI"
  "Major mode for editing MIDI hex files."
  (setq-local comment-start "# ")
  (setq-local compilation-ask-about-save nil))

(provide 'midi-hex)
