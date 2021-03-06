;; -*- Gerbil -*-
;;;; hash-table utilities

(export
  hash-ensure-ref
  invert-hash invert-hash* invert-hash<-vector invert-hash*<-vector
  hash-restriction
  hash-value-map
  hash-filter
  hash-remove
  hash-remove-value
  hash-ensure-removed!
  hash-ensure-modify
  hash-empty?
  )

(import
  :std/iter
  :clan/utils/base)

(def (hash-empty? h)
  (zero? (hash-length h)))

;; *private* object (a vector) to mark absence of parameter given. NOT EXPORTED.
(def %none '#(none))

;; type (Table V K) ;; hash-tables mapping key K to values V (note that V comes before K)

;; Lookup a table for a
;; If the key is missing, compute a default value, and put it in the table.
;; : V <- (Table V K) K (V <-)
(def (hash-ensure-ref table key default)
  (let ((val (hash-ref table key %none)))
    (if (eq? val %none)
      (let ((value (default)))
        (hash-put! table key value)
        value)
      val)))

;; Given a hash-table to (a new equal? hash-table by default,
;; but e.g. an eqv? or eq? hash-table could be given instead), invert the hash-table from
;; by storing in the hash-table a map from vector value back to map key.
;; NB: Assumes the original table is injective and/or you only care to link back to
;; *one* possible key for each value.
;; : (Table K V) <- (Table V K) to: (Optional (Table K V))
(def (invert-hash from to: (to (make-hash-table)))
  (hash-for-each (λ (k v) (hash-put! to v k)) from)
  to)

;; Given a hash-table to (a new equal? hash-table by default,
;; but e.g. an eqv? or eq? hash-table could be given instead), invert the hash-table from
;; by storing in the hash-table a map from vector value back to list of map keys.
;; Instead of a list, any container (M V) of values of type V can be used,
;; by overriding the arguments nil and cons.
;; NB: If there are multiple indices, the order is not guaranteed.
;; : (Table (M K) V) <- (Vector V) \
;;     to: (Optional (Table (M K) V)) nil: (M V) cons: ((M V) <- V (M V))
(def (invert-hash* from to: (to (make-hash-table)) nil: (nil '()) cons: (cons cons))
  (hash-for-each (λ (k v) (hash-put! to v (cons k (hash-ref to v nil)))) from)
  to)

;; Given a vector and a hash-table (a new equal? hash-table by default,
;; but e.g. an eqv? or eq? hash-table could be given instead), compute a "right invert" (or section)
;; of the vector from by storing in the hash-table a map from vector value back to vector index.
;; NB: Assumes the original table is injective and/or you only care to link back to
;; *one* possible index for each value.
;; : (Table Nat V) <- (Vector V) to: (Optional (Table Nat V))
(def (invert-hash<-vector from to: (to (make-hash-table)))
  (for ((i (in-range 0 (vector-length from))))
    (hash-put! to (vector-ref from i) i))
  to)

;; Given a vector and a hash-table (a new equal? hash-table by default,
;; but e.g. an eqv? or eq? hash-table could be given instead), invert the vector from
;; by storing in the hash-table a map from vector value back to list of map keys.
;; Instead of a list, any container (M V) of values of type V can be used,
;; by overriding the arguments nil and cons.
;; NB: If there are multiple indices, the order is not guaranteed.
;; : (Table (M Nat) V) <- (Vector V) \
;;     to: (Optional (Table (List V) Nat)) nil: (M V) cons: ((M V) <- V (M V))
(def (invert-hash*<-vector from to: (to (make-hash-table)) nil: (nil '()) cons: (cons cons))
  (for ((i (in-range 0 (vector-length from))))
    (let ((val (vector-ref from i)))
      (hash-put! to val (cons i (hash-ref to val nil)))))
  to)

;; Create a new hash-table the keys of which are restricted to those specified (if any).
;; TODO: find a better name. subhash ?
;; : (Table V K) <- (Table V K) (List K)
(def hash-restriction
  (let ((marker '#(fresh)))
    (λ (h keys)
      (let ((table (make-hash-table)))
        (for-each
          (λ (k) (let ((v (hash-ref h k marker)))
                   (unless (eq? v marker) (hash-put! table k v))))
          keys)
        table))))

;;; Map a function f on all the values of a map
;; : (Table W K) <- (Table V K) (W <- V)
(def (hash-value-map h f)
  (list->hash-table
   (map (λ-match ([k . v] (cons k (f v))))
        (hash->list h))))


;;; Remove entries that satisfy a predicate
;; : (Table V K) <- (Table V K) (Bool <- K V) (Optional (Table V K))
(def (hash-filter from pred (to (make-hash-table)))
  (hash-for-each (λ (k v) (when (pred k v) (hash-put! to k v))) from)
  to)

;;; Remove entries that do not satisfy a predicate
;; : (Table V K) <- (Table V K) (Bool <- K V) (Optional (Table V K))
(def (hash-remove from pred (to (make-hash-table)))
  (hash-for-each (λ (k v) (unless (pred k v) (hash-put! to k v))) from)
  to)

;;; Remove entries that map some key to a given value (typically #f)
;; : (Table V K) <- (Table V K) (Optional V) (Optional (Table V K))
(def (hash-remove-value from (value #f) (to (make-hash-table)))
  (hash-remove from (λ (_ v) (equal? v value)) to))

;;; Remove entry from the table if it exists, return two values:
;; the value that was removed, if any, or #f if none was found,
;; and a boolean that tells if there was a value.
(def (hash-ensure-removed! table key)
  (let ((val (hash-ref table key %none)))
    (if (eq? val %none)
      (values #f #f)
      (values val #t))))

;; Modify an entry in a table. If no entry exists yet, call the provided default thunk.
;; Return the new value.
;; : V <- (Table V K) K (V <-) (V <- V)
(def (hash-ensure-modify table key default function)
  (let* ((val (hash-ensure-ref table key default))
         (new-val (function val)))
    (hash-put! table key new-val)
    new-val))
