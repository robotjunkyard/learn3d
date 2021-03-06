;;;; cl-learn3d.lisp

(in-package #:cl-learn3d)

(defvar *model* nil)
(defparameter *delay* 1.0)  ;; actual FPS = this / 60.0
(defparameter *font* nil)
(defparameter *draw-frame* 0)

(defmacro with-main (&body body)
  "Enables REPL access via UPDATE-SWANK in the main loop using SDL2. Wrap this around the sdl2:with-init code."
  ;;TODO: understand this. Without this wrapping the sdl:with-init the sdl thread
  ;; is an "Anonymous thread" (tested using sb-thread:*current-thread*), while applying
  ;; this makes *current-thread* the same as the one one when queried directly from the
  ;; REPL thread: #<SB-THREAD:THREAD "repl-thread" RUNNING {adress...}>
  `(sdl2:make-this-thread-main
    (lambda ()
      ;; does work on linux+sbcl without the following line:
      #+sbcl (sb-int:with-float-traps-masked (:invalid) ,@body)
      #-sbcl ,@body)))

(defmacro continuable (&body body)
  `(restart-case
       (progn ,@body)
     (continue () :report "Continue")))

(defun update-swank ()
#-SWANK  nil
#+SWANK  (continuable
          (let ((connection (or swank::*emacs-connection*
                                (swank::default-connection))))
            (when connection
              (swank::handle-requests connection t)))))

(defparameter *axis-size* 4.0)
(defparameter *fov* 90.0)

(defparameter *x-res* 640)
(defparameter *y-res* 480)
(defparameter *x-res-float* (float *x-res*))
(defparameter *y-res-float* (float *y-res*))
(declaim (type uint16 *x-res* *y-res*)
	 (type single-float *x-res-float* *y-res-float*))

(defun setres (x y)
  (setf *x-res* x
	*y-res* y))

(defun reset-world-rotation ()
  (setf *rotation-matrix* (sb-cga:identity-matrix)))

(defun render-stuff (renderer)
  (sdl2:set-render-draw-color renderer 0 0 0 255)
  (sdl2:render-clear renderer)
  (sdl2:set-render-draw-color renderer 64 127 255 255)
  (when *model*
    (draw-axes renderer)
    (sort-mesh-face-draw-order *model* *world-matrix*)
    (sdl2:set-render-draw-color renderer 207 205 155 255)
    (draw-mesh *model* renderer))
  (sdl2:render-present renderer))

(defun set-camera (ex ey ez tx ty tz &key (fov *fov*))
  (declare (type single-float ex ey ez tx ty tz fov))
  (setf *vmat*
	(look-at 
	 (sb-cga:vec (+ ex) (+ ey) (+ ez))
	 (sb-cga:vec tx ty tz)
	 (sb-cga:vec 0.0 1.0 0.0))

	(aref *camera-eye* 0) ex
	(aref *camera-eye* 1) ey
	(aref *camera-eye* 2) ez

	(aref *camera-target* 0) tx
	(aref *camera-target* 1) ty
	(aref *camera-target* 2) tz

	;; umm... hmm
	;; *translation-matrix* (translate (- ex) (- ey) (- ez))

	;; *pmat* (perspective-projection fov 0.1 122.0)
	))

(defparameter *scale* 0.25)

(defun main-idle (renderer)
  (setf *vmat* (sb-cga:identity-matrix))
  ;; (setf *pmat* (sb-cga:identity-matrix))
  
  (set-camera 0.0 0.0 1.0 0.0 0.0 0.0 :fov *fov*)
  ;;(setf *pmat*
  ;;  (frustum-projection 0.2 -0.2 -0.5 0.5 0.2 120.0))
  (setf *pmat*
	(perspective-projection 120.0 0.01 100.0))
  (setf *scale-matrix*
	(scale *scale* *scale* *scale*))
  (setf *rotation-matrix* (sb-cga:identity-matrix))
  (setf *rotation-matrix*
	(rotate (mod (* 0.10 *draw-frame*) 360.0) 0.0 0.0 1.0))
  (setf *rotation-matrix*
	(sb-cga:matrix* *rotation-matrix*
			(rotate (mod (* 0.25 *draw-frame*) 360.0) 1.0 0.0 0.0)))
  (update-world-transformation-matrix)  ;; update world's Translate/Scale/Rotate matrix
  (update-world-matrix)                 ;; update world matrix to be P*V*M
  (render-stuff renderer)
  (incf *draw-frame*))

(defun main ()
  (sb-ext:gc :full t)
  (setf *x-res-float* (float *x-res*)
	*y-res-float* (float *y-res*))
  (with-main
    (set-camera 14.0 14.0 14.0
		0.0 0.0 0.0)
    (setq *model* (load-model "spaceship"))
    (setf *world-matrix* (sb-cga:identity-matrix))
    (sdl2:with-init (:video)
      (sdl2:with-window (win :title "Learn3D" :flags '(:shown)
			     :w *x-res* :h *y-res*)
	;; pffft, for some stupid reason, these two lines needed to display properly in Windows
#+win32	(sdl2:hide-window win)
#+win32	(sdl2:show-window win)
	(sdl2:with-renderer (renderer win #| :flags '(:accelerated :presentvsync) |#)
	  (sdl2:with-event-loop (:method :poll)
	    (:idle
	     ()
	     (sleep (/ *delay* 60))
	     (continuable
	       (main-idle renderer)
	       )
	     #+SWANK (update-swank))
	    (:quit ()
		   t)))))))


