;;; webkit-color-picker.el --- Insert and adjust colors using Webkit Widgets -*- lexical-binding: t -*-

;; Copyright (C) 2018 Ozan Sener

;; Author: Ozan Sener <hi@ozan.email>
;; URL: https://github.com/osener/emacs-webkit-color-picker
;; Maintainer: Ozan Sener <hi@ozan.email>
;; Version: 0.1.0
;; Keywords: tools
;; Package-Requires: ((emacs "26.0") (posframe "0.1.0"))

;; This file is NOT part of GNU Emacs.

;; The MIT License (MIT)

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Commentary:

;; #+OPTIONS: toc:nil title:nil timestamp:nil
;; * webkit-color-picker                                                :README:

;; Small experiment with embedded a Webkit widgets in a childframe. Requires Emacs 26 compiled with [[https://www.gnu.org/software/emacs/manual/html_node/emacs/Embedded-WebKit-Widgets.html][embedded Webkit Widget support]].

;; webkit-color-picker is available on [[https://melpa.org/][MELPA]]. Example configuration using [[https://github.com/jwiegley/use-package][use-package]]:

;; #+BEGIN_SRC emacs-lisp
;; (use-package webkit-color-picker
;;   :ensure t
;;   :bind (("C-c C-p" . webkit-color-picker-show)))
;; #+END_SRC

;; ** Screenshot
;; [[./screenshots/webkit-color-picker.gif]]

;;; Code:
;; * webkit-color-picker's code

(require 'xwidget)
(require 'posframe)
(require 'css-mode)
(eval-when-compile (require 'subr-x))
(eval-when-compile (require 'cl-lib))

(defvar webkit-color-picker--client-path
  (concat "file://"
          (file-name-directory (or load-file-name buffer-file-name))
          "color-picker.html"))

(defun webkit-color-picker--run-xwidget ()
  "Launch embedded Webkit instance."
  (with-current-buffer " *webkit-color-picker*"
    (let ((inhibit-read-only t))
      (goto-char 1)

      (let ((id (make-xwidget
                 'webkit
                 nil
                 (window-pixel-width)
                 (window-pixel-height)
                 nil
                 "*webkit-color-picker*")))
        (put-text-property (point) (+ 1 (point))
                           'display (list 'xwidget ':xwidget id))
        (xwidget-webkit-mode)
        (xwidget-webkit-goto-uri (xwidget-at 1)
                                 webkit-color-picker--client-path)))))

(defun webkit-color-picker--show ()
  "Make color picker childframe visible."
  (when-let* ((current-frame (selected-frame))
              (buffer (webkit-color-picker--get-buffer))
              (frame (webkit-color-picker--get-frame)))
    (progn
      (select-frame frame t)
      (switch-to-buffer buffer t t)
      (select-frame current-frame t)
      (make-frame-visible frame)
      (redraw-frame frame)

      (let*
          ((position (point))
           (parent-window (selected-window))
           (parent-frame (window-frame parent-window))
           (x-pixel-offset 0)
           (y-pixel-offset 0)
           (font-width (default-font-width))
           (font-height (posframe--get-font-height position))
           (frame-resize-pixelwise t)
           (position (posframe-poshandler-point-bottom-left-corner
                      `(;All poshandlers will get info from this plist.
                        :position ,position
                        :font-height ,font-height
                        :font-width ,font-width
                        :posframe ,frame
                        :posframe-buffer ,buffer
                        :parent-frame ,parent-frame
                        :parent-window ,parent-window
                        :x-pixel-offset ,x-pixel-offset
                        :y-pixel-offset ,y-pixel-offset))))

        (set-frame-position frame (car position) (cdr position))))))

(defun webkit-color-picker--create ()
  "Create a new posframe and launch Webkit."
  (let ((x-pointer-shape x-pointer-top-left-arrow))
    (posframe-show " *webkit-color-picker*"
                   :string " "
                   :position (point)))

  (define-key (current-global-map) [xwidget-event]
    (lambda ()
      (interactive)

      (let ((xwidget-event-type (nth 1 last-input-event)))
        (when (eq xwidget-event-type 'load-changed)
          (webkit-color-picker--resize)
          (webkit-color-picker--set-background))

        (when (eq xwidget-event-type 'javascript-callback)
          (let ((proc (nth 3 last-input-event))
                (arg  (nth 4 last-input-event)))
            (funcall proc arg))))))

  (webkit-color-picker--run-xwidget))

(defun webkit-color-picker--get-buffer ()
  "Return color picker buffer."
  (get-buffer " *webkit-color-picker*"))

(defun webkit-color-picker--get-frame ()
  "Return color picker frame."
  (when-let* ((buffer (webkit-color-picker--get-buffer)))
    (seq-find
     (lambda (frame)
       (let ((buffer-info (frame-parameter frame 'posframe-buffer)))
         (or (eq buffer (car buffer-info))
             (eq buffer (cdr buffer-info)))))
     (frame-list))))

(defun webkit-color-picker--set-background ()
  "Evaluate JS code in color picker Webkit instance."
  (webkit-color-picker--execute-script
   (format "document.body.style.background = '%s';"
           (face-attribute 'default :background))))

(defun webkit-color-picker--insert-color ()
  "Get the selected color from the widget and insert in the current buffer."
  (webkit-color-picker--execute-script
   "window.selectedColor;"
   `(lambda (color)
      (let ((color (kill-new (or color "")))
            (start (or (car webkit-color-picker--last-position) (point)))
            (end (or (cdr webkit-color-picker--last-position) (point))))
        (when (> (length color) 0)
          (delete-region start end)
          (goto-char start)
          (insert color)
          (webkit-color-picker-hide))))))

(defvar webkit-color-picker--emulation-alist '((t . nil)))

(defvar-local webkit-color-picker--my-keymap nil)
(defvar-local webkit-color-picker--last-position nil)

(defsubst webkit-color-picker--enable-overriding-keymap (keymap)
  "Enable color picker overriding KEYMAP."
  (webkit-color-picker--uninstall-map)
  (setq webkit-color-picker--my-keymap keymap))

(defun webkit-color-picker--ensure-emulation-alist ()
  "Append color picker emulation alist."
  (unless (eq 'webkit-color-picker--emulation-alist (car emulation-mode-map-alists))
    (setq emulation-mode-map-alists
          (cons 'webkit-color-picker--emulation-alist
                (delq 'webkit-color-picker--emulation-alist emulation-mode-map-alists)))))

;; TODO: Find a better way of preventing accidental keystrokes whether the
;; childframe is in focus or not
(defun webkit-color-picker--install-map ()
  "Install temporary color picker keymap."
  (unless (or (cdar webkit-color-picker--emulation-alist)
              (null webkit-color-picker--my-keymap))
    (setf (cdar webkit-color-picker--emulation-alist) webkit-color-picker--my-keymap)))

(defun webkit-color-picker--uninstall-map ()
  "Uninstall temporary color picker keymap."
  (setf (cdar webkit-color-picker--emulation-alist) nil))

(defvar webkit-color-picker--active-map
  (let ((keymap (make-sparse-keymap)))
    (define-key keymap "\e\e\e" 'webkit-color-picker-hide)
    (define-key keymap "\C-g" 'webkit-color-picker-hide)
    (define-key keymap [mouse-1] (lambda () (interactive) (webkit-color-picker--insert-color)))
    (define-key keymap (kbd "RET") (lambda () (interactive) (webkit-color-picker--insert-color)))
    keymap)
  "Keymap that is enabled during an active completion.")

(defvar webkit-color-picker--hex-color-regexp
  (concat
   ;; Short hex.  css-color-4 adds alpha.
   "\\(#[0-9a-fA-F]\\{3,4\\}\\b\\)"
   "\\|"
   ;; Long hex.  css-color-4 adds alpha.
   "\\(#\\(?:[0-9a-fA-F][0-9a-fA-F]\\)\\{3,4\\}\\b\\)"))

(defun webkit-color-picker--get-hex-color-at-point ()
  "Return hex color at point."
  (with-syntax-table (copy-syntax-table (syntax-table))
    (modify-syntax-entry ?# "w") ; Make `#' a word constituent.
    (when-let* ((word (thing-at-point 'word t))
                (bounds (bounds-of-thing-at-point 'word)))
      (when (string-match webkit-color-picker--hex-color-regexp word)
        (cons word bounds)))))

(defun webkit-color-picker--get-named-color-at-point ()
  "Return color name at point."
  (when-let* ((word (word-at-point))
              (color (assoc (downcase word) css--color-map)))
    (cons word (bounds-of-thing-at-point 'word))))

(defun webkit-color-picker--get-rgb-or-hsl-color-at-point ()
  "Return RGB or HSL formatted color at point."
  (save-excursion
    (when-let* ((open-paren-pos (nth 1 (syntax-ppss))))
      (when (save-excursion
              (goto-char open-paren-pos)
              (looking-back "\\(?:hsl\\|rgb\\)a?" (- (point) 4)))
        (goto-char (nth 1 (syntax-ppss)))))
    (when (eq (char-before) ?\))
      (backward-sexp))
    (skip-chars-backward "rgbhslaRGBHSLA")
    (when (looking-at "\\(\\_<\\(?:hsl\\|rgb\\)a?(\\)")
      (when-let* ((start (point))
                  (end (search-forward ")" nil t)))
        (cons (buffer-substring-no-properties start end) (cons start end))))))

(defun webkit-color-picker--color-at-point ()
  "Return recognized color at point."
  (or
   (webkit-color-picker--get-rgb-or-hsl-color-at-point)
   (webkit-color-picker--get-named-color-at-point)
   (webkit-color-picker--get-hex-color-at-point)))

(defun webkit-color-picker--get-xwidget ()
  "Return Xwidget instance."
  (with-current-buffer " *webkit-color-picker*"
    (xwidget-at 1)))

(defun webkit-color-picker--execute-script (script &optional fn)
  "Execute SCRIPT in embedded Xwidget and run optional callback FN."
  (when-let* ((xw (webkit-color-picker--get-xwidget)))
    (xwidget-webkit-execute-script xw script fn)))

(defun webkit-color-picker--resize ()
  "Resize color picker frame to widget boundaries."
  (webkit-color-picker--execute-script
   "[document.querySelector('.picker').offsetWidth, document.querySelector('.picker').offsetHeight];"
   (lambda (size)
     (when-let* ((frame (webkit-color-picker--get-frame)))
       (modify-frame-parameters
        frame
        `((width . (text-pixels . ,(+ 30 (aref size 0))))
          (height . (text-pixels . ,(+ 30 (aref size 1))))
          (inhibit-double-buffering . t)))))))

(defun webkit-color-picker--set-color (color)
  "Update color picker widget state with COLOR."
  (webkit-color-picker--execute-script
   (format
    "window.selectedColor = '%s';"
    (if (stringp color) color "#000000"))))

;;;###autoload
(defun webkit-color-picker-show ()
  "Activate color picker."
  (interactive)
  (unless (featurep 'xwidget-internal)
    (user-error "Your Emacs was not compiled with xwidgets support"))
  (unless (display-graphic-p)
    (user-error "webkit-color-picker only works in graphical displays"))
  (let ((color-at-point (webkit-color-picker--color-at-point)))
    (if (buffer-live-p (webkit-color-picker--get-buffer))
        (webkit-color-picker--show)
      (webkit-color-picker--create))

    (webkit-color-picker--set-color (car color-at-point))
    (webkit-color-picker--set-background)

    (setq-local webkit-color-picker--last-position
                (or (cdr color-at-point)
                    (cons (point) (point))))

    (webkit-color-picker--ensure-emulation-alist)
    (webkit-color-picker--enable-overriding-keymap webkit-color-picker--active-map)
    (webkit-color-picker--install-map)

    t))

;;;###autoload
(defun webkit-color-picker-hide ()
  "Hide color picker frame."
  (interactive)
  (when-let* ((frame (webkit-color-picker--get-frame)))
    (make-frame-invisible frame))
  (webkit-color-picker--enable-overriding-keymap nil))

;;;###autoload
(defun webkit-color-picker-cleanup ()
  "Destroy color picker buffer and frame."
  (interactive)
  (dolist (xwidget-view xwidget-view-list)
    (delete-xwidget-view xwidget-view))
  (posframe-delete-all)
  (kill-buffer " *webkit-color-picker*"))

(provide 'webkit-color-picker)

;; Local Variables:
;; coding: utf-8-unix
;; End:

;;; webkit-color-picker.el ends here
