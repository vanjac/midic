;; -*- lexical-binding: t; -*-

(require 'comint)

(defvar midi-hex-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?# "<\n" table)
    (modify-syntax-entry ?\n ">#" table)
    table))

(defvar-keymap midi-hex-mode-map
  "C-c TAB" #'midi-cleanup
  "M-<right>" #'midi-next-tab-stop
  "M-<left>" #'midi-prev-tab-stop
  "<tab>" #'midi-next-tab-stop
  "<backtab>" #'midi-prev-tab-stop
  "C-M-<right>" #'midi-increase-hex-at-point
  "C-M-<left>" #'midi-decrease-hex-at-point
  "C-c C-r" #'midi-comint
  "C-c C-o" #'midi-all-sound-off
  "C-c C-k" #'midi-stop
  "M-<return>" #'midi-play-line
  "M-S-<return>" #'midi-play-line-and-advance)

(defun midi-cleanup (start end)
  "Clean up whitespace in region."
  (interactive "r")
  (delete-trailing-whitespace start end)
  (tabify start end))

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

(defun midi--path-from-here (path)
  (concat (file-name-directory (or load-file-name (buffer-file-name))) path))

(defvar midi-comint-program
  (if (eq system-type 'windows-nt)
      (midi--path-from-here "playlive.cmd")
    (midi--path-from-here "playlive.sh")))

(defvar midi-comint-buffer-name "*midi*")

(defun midi-comint ()
  "(Re)start MIDI synth process for live playback."
  (interactive)
  (with-current-buffer (get-buffer-create midi-comint-buffer-name)
    (unless (derived-mode-p 'comint-mode)
      (comint-mode))
    (comint-exec (current-buffer) midi-comint-buffer-name midi-comint-program nil nil))
  (message "Started MIDI synth"))

(defun midi-stop ()
  "Stop MIDI synth process."
  (interactive)
  (delete-process (get-buffer-process midi-comint-buffer-name))
  (message "Stopped MIDI synth"))

(defun midi--send (str)
  (comint-send-string (get-buffer-process midi-comint-buffer-name) str))

(defun midi-play-line ()
  "Send current line to the MIDI synth."
  (interactive)
  (midi--send (thing-at-point 'line)))

(defun midi-play-line-and-advance ()
  "Send current line to the MIDI synth, and move to the next line."
  (interactive)
  (midi-play-line)
  (next-logical-line))

(defun midi-all-sound-off ()
  "Send all-sound-off command for each channel."
  (interactive)
  (dotimes (c 16)
    (midi--send (format ">B%X7800\n" c))))

(define-derived-mode midi-hex-mode prog-mode "MIDI"
  "Major mode for editing MIDI hex files."
  (setq-local comment-start "# ")
  (setq-local compilation-ask-about-save nil)
  (setq-local truncate-lines t))

(provide 'midi-hex)
