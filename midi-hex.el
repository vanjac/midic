;; -*- lexical-binding: t; -*-

(require 'compile)
(require 'python)

(defvar midi-hex-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?# "<\n" table)
    (modify-syntax-entry ?\n ">#" table)
    table))

(defvar-keymap midi-hex-mode-map
  "C-c TAB" #'midi-cleanup
  "M-<right>" #'midi-next-tab-stop
  "M-<left>" #'midi-prev-tab-stop
  "C-M-<right>" #'midi-increase-hex-at-point
  "C-M-<left>" #'midi-decrease-hex-at-point
  "C-c C-p" #'midi-build
  "C-c C-r" #'midi-comint
  "C-c C-o" #'midi-all-sound-off
  "C-c C-k" #'midi-stop
  "M-RET" #'midi-play-line
  "M-S-RET" #'midi-play-line-and-advance
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

(defun midi-forward-sentance (arg)
  (if (>= arg 0)
      (dotimes (i arg)
	(if (= (char-after) ?\t)
	    (forward-char))
	(skip-chars-forward "^\t\n"))
    (dotimes (i (- arg))
      (if (= (char-before) ?\t)
	  (backward-char))
      (skip-chars-backward "^\t\n"))))

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

(defvar midi-build-script
  (midi--path-from-here "midic.py"))

(defun midi-build (no-play)
  "Build and (optionally) play a MIDI file from MIDI-Hex"
  (interactive "P")
  (if (not (derived-mode-p 'midi-hex-mode))
      (error "Not in midi-hex mode"))
  (save-buffer)
  (let* ((infile (buffer-file-name))
	 (outfile (file-name-with-extension infile "mid"))
	 (cmd (format "%s %s -f smf -i %s -o %s"
		      (shell-quote-argument python-interpreter)
		      (shell-quote-argument midi-build-script)
		      (shell-quote-argument infile)
		      (shell-quote-argument outfile))))
    (delete-file outfile)
    (with-current-buffer (compilation-start cmd)
      (if (not no-play)
	  (setq-local compilation-finish-functions
		      (list (lambda (buf msg)
			      (if (numberp (string-match-p "finished" msg))
				  (midi-play-file outfile)))))))))

(defvar midi-play-program
  (if (eq system-type 'windows-nt)
      (midi--path-from-here "play.cmd")
    "fluidsynth"))

(defvar midi-play-buffer-name "*midi-play*")

(defun midi-play-file (file)
  "Play a MIDI file with the configured program."
  (interactive "f")
  (when-let* ((proc (get-buffer-process midi-play-buffer-name)))
    (delete-process proc))
  (start-process midi-play-buffer-name midi-play-buffer-name midi-play-program file)
  (with-current-buffer midi-play-buffer-name
    (special-mode)
    (goto-char (point-max)))
  (display-buffer midi-play-buffer-name))

(defvar midi-comint-program
  (if (eq system-type 'windows-nt)
      (midi--path-from-here "playlive.cmd")
    (midi--path-from-here "playlive.sh")))

(defvar midi-comint-buffer-name "*midi-synth*")

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
  (delete-process midi-comint-buffer-name)
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
  "Major mode for editing MIDI-Hex files."
  (setq-local comment-start "# ")
  (setq-local truncate-lines t)
  (setq-local fill-column 240)
  (setq-local forward-sentence-function #'midi-forward-sentance)
  (setq-local font-lock-defaults
	      '(((":[^\n]+" . font-lock-preprocessor-face)
		 ("\\b8[0-9a-fA-F]+\\b" . font-lock-constant-face)
		 ("\\b9[0-9a-fA-F]+\\b" . font-lock-function-name-face)
		 ("\\b[aA][0-9a-fA-F]+\\b" . font-lock-warning-face)
		 ("\\b[bB][0-9a-fA-F]+\\b" . font-lock-keyword-face)
		 ("\\b[cC][0-9a-fA-F]+\\b" . font-lock-type-face)
		 ("\\b[dD][0-9a-fA-F]+\\b" . font-lock-warning-face)
		 ("\\b[eE][0-9a-fA-F]+\\b" . font-lock-variable-name-face)
		 ("\\b[fF][0-9a-fA-F]+\\b" . font-lock-preprocessor-face)
		 ("[g-zG-Z]" . 'error)))))

(provide 'midi-hex)
