;;;; OpenGL FLI for LispWorks
;;;;
;;;; Copyright (c) 2013 by Jeffrey Massung
;;;;
;;;; This file is provided to you under the Apache License,
;;;; Version 2.0 (the "License"); you may not use this file
;;;; except in compliance with the License.  You may obtain
;;;; a copy of the License at
;;;;
;;;;    http://www.apache.org/licenses/LICENSE-2.0
;;;;
;;;; Unless required by applicable law or agreed to in writing,
;;;; software distributed under the License is distributed on an
;;;; "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
;;;; KIND, either express or implied.  See the License for the
;;;; specific language governing permissions and limitations
;;;; under the License.
;;;;

(defpackage :opengl-texture
  (:use :cl :fli :opengl :opengl-context :opengl-pane)
  (:export
   #:opengl-texture
   #:opengl-texture-context
   #:opengl-texture-free
   #:opengl-texture-image
   #:opengl-texture-width
   #:opengl-texture-height))

(in-package :opengl-texture)

(defclass opengl-texture ()
  ((texture :initarg :texture :reader opengl-texture)
   (context :initarg :context :reader opengl-texture-context)
   (image   :initarg :image   :reader opengl-texture-image)
   (width   :initarg :width   :reader opengl-texture-width)
   (height  :initarg :height  :reader opengl-texture-height))
  (:documentation "An object representing an OpenGL texture resource for a specific context."))

(defmethod load-texture ((pane opengl-pane) image &key (filter +gl-linear+))
  "Load an image and create an OpenGL texture resource."
  (lw:when-let (image (gp:load-image pane image :editable :with-alpha))
    (let ((access (gp:make-image-access pane image)))
      (gp:image-access-transfer-from-image access)
        
      ;; upsize the texture to the next power of 2 for performance
      (let ((w (expt 2 (ceiling (log (gp:image-access-width access) 2))))
            (h (expt 2 (ceiling (log (gp:image-access-height access) 2)))))

        ;; create a memory buffer to write the image data into for OpenGL
        (with-dynamic-foreign-objects ((tex :unsigned-int :nelems 1)
                                       (data :unsigned-byte :nelems (* w h 4)))
          (dotimes (y (gp:image-access-height access))
            (dotimes (x (gp:image-access-width access))
              (let* ((p (gp:image-access-pixel access x y))
                     (c (color:unconvert-color pane p))
                     (r (color:color-red c))
                     (g (color:color-green c))
                     (b (color:color-blue c))
                     (a (color:color-alpha c)))

                ;; copy the pixel data into the buffer
                (setf (dereference data :index (+ (* y w 4) (* x 4) 0)) (truncate (* r 255))
                      (dereference data :index (+ (* y w 4) (* x 4) 1)) (truncate (* g 255))
                      (dereference data :index (+ (* y w 4) (* x 4) 2)) (truncate (* b 255))
                      (dereference data :index (+ (* y w 4) (* x 4) 3)) (truncate (* a 255))))))

          ;; create the texture resource
          (with-opengl-context (c (opengl-pane-context pane))
            (gl-gen-textures 1 tex)

            ;; bind the texture to what will be created
            (gl-bind-texture +gl-texture-2d+ (dereference tex))

            ;; pixel format options
            (gl-pixel-storei +gl-unpack-alignment+ 1)

            ;; texture parameters
            (gl-tex-parameteri +gl-texture-2d+ +gl-texture-min-filter+ filter)
            (gl-tex-parameteri +gl-texture-2d+ +gl-texture-mag-filter+ filter)
            
            ;; copy the pixel data into the texture
            (gl-tex-image2d +gl-texture-2d+ 0 +gl-rgba+ w h 0 +gl-rgba+ +gl-unsigned-byte+ data)

            ;; return the opengl resource
            (make-instance 'opengl-texture
                           :image image
                           :context c
                           :width w
                           :height h
                           :texture (dereference tex))))))))

(defmethod opengl-texture-free ((texture opengl-texture))
  "Release the memory used by a texture."
  (with-opengl-context (c (opengl-texture-context texture))
    (with-dynamic-foreign-objects ((tex :unsigned-int :initial-element (opengl-texture texture)))
      (gl-delete-textures 1 tex)))

  ;; clear the resource data
  (setf (slot-value texture 'texture) 0))