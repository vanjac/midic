;; -*- lexical-binding: t; -*-

(require 'compile)
(require 'python)
(require 'thingatpt)

(defvar midi-hex-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?# "<\n" table)
    (modify-syntax-entry ?\n ">#" table)
    table))

(defvar-keymap midi-hex-mode-map
  "C-c TAB" #'midi-cleanup
  "M-<right>" #'midi-next-tab-stop
  "M-<left>" #'midi-prev-tab-stop
  "C-M-<right>" #'midi-increase-hex-digit
  "C-M-<left>" #'midi-decrease-hex-digit
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

(defun midi--hex-char-value (c)
  (cond
   ((<= ?0 c ?9) (- c ?0))
   ((<= ?a c ?f) (+ 10 (- c ?a)))
   ((<= ?A c ?F) (+ 10 (- c ?A)))))

(defun midi--hex-char (v)
  (cond
   ((<= 0 v 9) (+ v ?0))
   ((<= 10 v 15) (+ ?A (- v 10)))))

(defun midi--adjust-hex-digit (inc)
  (when-let* ((c (char-after))
	      (val (midi--hex-char-value c))
	      (inc-val (+ val inc))
	      (wrapped-val (if (<= 0 inc-val 15)
			       inc-val
			     (backward-char)
			     (midi--adjust-hex-digit (ash inc-val -4))
			     (forward-char)
			     (mod inc-val 16)))
	      (nc (midi--hex-char wrapped-val)))
    (delete-char 1)
    (insert-char nc)
    (backward-char)))

(defun midi-increase-hex-digit (&optional inc)
  "Increment hex digit at point, carrying to the next digit(s)."
  (interactive "p")
  (if (not (memql (char-after) '(?\s ?\t ?\n)))
      (midi--adjust-hex-digit inc)
    (backward-char)
    (midi--adjust-hex-digit inc)
    (forward-char)))

(defun midi-decrease-hex-digit (&optional inc)
  "Decrement hex digit at point, carrying to the next digit(s)."
  (interactive "p")
  (midi-increase-hex-digit (- (or inc 1))))

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
    (midi--path-from-here "play.sh")))

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
  (midi--send (concat ">" (mapconcat (lambda (c) (format "B%X7800\n" c))
				     (number-sequence 0 15)))))

(define-derived-mode midi-hex-mode prog-mode "MIDI"
  "Major mode for editing MIDI-Hex files."
  (setq-local comment-start "# ")
  (setq-local truncate-lines t)
  (setq-local fill-column 300)
  (setq-local forward-sentence-function #'midi-forward-sentance)
  (setq-local font-lock-defaults
	      '(((":[^\n]*" . font-lock-preprocessor-face)
		 ("\\b8[0-9a-fA-F]+\\b" . font-lock-constant-face)
		 ("\\b[9k-rK-R][0-9a-fA-F]+\\b" . font-lock-function-name-face)
		 ("\\b[aA][0-9a-fA-F]+\\b" . font-lock-warning-face)
		 ("\\b[bB][0-9a-fA-F]+\\b" . font-lock-keyword-face)
		 ("\\b[cC][0-9a-fA-F]+\\b" . font-lock-type-face)
		 ("\\b[dD][0-9a-fA-F]+\\b" . font-lock-warning-face)
		 ("\\b[eE][0-9a-fA-F]+\\b" . font-lock-variable-name-face)
		 ("\\b[fF][0-9a-fA-F]+\\b" . font-lock-preprocessor-face)
		 ("[<>*-/]" . 'bold)
		 ("[g-jG-Js-zS-Z]" . 'error)))))

(provide 'midi-hex)
