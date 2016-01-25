;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;; Author: Carlos Neira  <cneirabustos@gmail.com>
;; Version: 1.0
;; Keywords: jes,mainframe, z/os
;; URL: https://github.com/cneira/jes-emacs

;;; Commentary:

;; MVS functions to avoid login to tso on Z/OS and work remotely from emacs
;; TODO: this functions assume that you have cygwin installed, use lftp and your remote host uses tls encryption
;; This is work in progress as it was a quick hack to speed up my workflow on the mainframe
;; assumes the visited datasets are created in windows under c:/mvs/visited
;; Buffers created :
;; MVS-JOBS it will have your current JES spool
;; lftp-transfer this will only have the result of the lftp transfer to the mainframe
;; MVS-JOBS-LOGS this will have the last job executed spool files
;; For example to execute a job everytime a control file is edited and saved you could
;; define this hook
;; (add-hook 'after-save-hook  '(lambda () (if (string-equal (first (last (split-string  (buffer-file-name (current-buffer))  "/")  ) )
;; 							  "<your file>" )
;; 					    (progn
;; 					      (transfer-to-mvs)
;; 					      (with-current-buffer "<jcl job that uses the file>"
;; 						(transfer-to-mvs))))))

;;; Code:

(defvar host "your host" )
(defvar user "your ftp account")
(defvar password "ditto")


;Where the files will be stored when visiting a dataset uses the cygwin path
(defvar mvs-repo "/cygdrive/c/mvs/visited/")



;; aux functions to construct the script being passed to lftp  
(defun create-transfer-string (host user pass remotedir currentbuf &optional quote )
  (if quote
      
      (list   "  open -e \"set ftps:initial-prot \"\"; set ftp:ssl-force true;set ftp:ssl-protect-data true; set ssl:verify-certificate no  \" -u " user "," pass " " host
	      "  ;" (if  (string-equal remotedir "JCL")  (jes-transfer remotedir)   (non-jes-transfer remotedir) ) )
    
    (shell-quote-argument (concat  "  open -e \"set ftps:initial-prot \"\"; set ftp:ssl-force true;set ftp:ssl-protect-data true; set ssl:verify-certificate no  \" -u " user "," pass " " host
				   "  ;" (if  (string-equal remotedir "JCL")  (jes-transfer remotedir)   (non-jes-transfer remotedir))))))


(defun connect (host user pass)
  (concat  "  open -e \"set ftps:initial-prot \"\"; set ftp:ssl-force true;set ftp:ssl-protect-data true; set ssl:verify-certificate no;set xfer:clobber on  \" -u " user "," pass " " host
	   "  ;" ))


(defun non-jes-transfer (remotedir)
  (concat  " cd "  remotedir
	   " ; put  -a     "
	   (replace-regexp-in-string   "c:/"   "/cygdrive/c/"
				       (buffer-file-name (with-current-buffer (current-buffer))))
	   "  -o  "
	   (file-name-nondirectory (replace-regexp-in-string   "c:/"   "/cygdrive/c/"
							       (file-name-sans-extension (buffer-file-name (with-current-buffer (current-buffer) )) ))) 
	   "  " "  ; bye"))

(defun jes-transfer (remotedir)
  (concat ";site filetype=jes;"
          "; put -a  "
	  (replace-regexp-in-string   "c:/"   "/cygdrive/c/"
				      (buffer-file-name (with-current-buffer (current-buffer) )))
          "  -o "
	  (file-name-nondirectory  (replace-regexp-in-string   "c:/"   "/cygdrive/c/"
							       (file-name-sans-extension (buffer-file-name (with-current-buffer (current-buffer) )) )  " ; ls ;"
							       ))))

(defun visit-string ()
  (concat  " cd "  (upcase (file-name-extension (buffer-file-name (current-buffer)))) 
	   " ; get  -a     "
	   (file-name-sans-extension (file-name-nondirectory (replace-regexp-in-string   "c:/"   "/cygdrive/c/"
											 (buffer-file-name (with-current-buffer (current-buffer))))))  
	   "  -o  "
	   (replace-regexp-in-string   "c:/"   "/cygdrive/c/"
				       (buffer-file-name (with-current-buffer (current-buffer))))
	   "  " "  ; bye"))


(defun mvs-hlq (hlq )
  (concat  " cd  "   (first  (split-string hlq "(\\|)") )   
	   " ; get  -a     "
	   (second  (split-string hlq "(\\|)") ) 
	   "  -o  /cygdrive/c/mvs/visited/ ;  bye;"))

(defun mvs-get-file (hlq)
  (progn
    (let ( (c (shell-quote-argument (concat  (connect host user password)
					     " ; " (mvs-hlq hlq) ))))
      (start-process-shell-command "lftp2.exe --verbose  -c " 
				   ( get-buffer-create  "lftp-transfer" ) 
				   "lftp2.exe --verbose  -c  "  c ))
    (sleep-for 5)
    (find-file (concat "c:/mvs/visited/"  (second (split-string hlq "(\\|)"))))))


(defun mvs-logs-from-job (jobid)
  (let (   (c   (shell-quote-argument (concat  (connect host user password)
					       "  ; site filetype=jes; "  " ; get -a " (concat jobid ".x") " -o /cygdrive/c/mvs/jobs/; ")    ) )   )
    (start-process-shell-command "lftp2.exe --verbose  -c " 
				 (get-buffer-create  "MVS-JOBS-LOGS") 
				 "lftp2.exe --verbose  -c  "  c )))


(defun read-log-from-job (jobid)
  (progn
    (mvs-logs-from-job jobid)
    (sleep-for 5)
    (find-file-read-only  (concat "c:/mvs/jobs/"  (concat jobid ".x")) )))



(defun get-buffer-as-list (buffname)
  (with-current-buffer buffname
    (progn
      (sleep-for 4 )
      (beginning-of-buffer)
      (delete-matching-lines "^\\(200 SITE\\|Process\\|JOBNAME \\)")
      (beginning-of-buffer)
      (split-string (buffer-string) "\n" t))))


;; these ones will allow you to retrieve a dataset and open a buffer with its contents
;;;###autoload
(defun mvs-visit-file ()
  (interactive)
  (progn
    (let ((c  (shell-quote-argument (concat  (connect host user password) " ; " (visit-string)))))
      (start-process-shell-command "lftp2.exe --verbose  -c " 
				   (get-buffer-create  "lftp-transfer") 
				   "lftp2.exe --verbose  -c  "  c ))
    (sleep-for 6 )
    (find-file (buffer-file-name (current-buffer ) ))))

;;;###autoload
(defun clean-buff (buff-to-kill)
  (interactive)
  (with-current-buffer buff-to-kill
    (erase-buffer)  ) )


;;;###autoload
(defun mvs-get-last-job ()
  (interactive)
  (get-buffer-as-list "MVS-JOBS"))

;;;###autoload
(defun mvs-list-jobs ()
  (interactive)
  "this will list jobs on remote server using jes facilities"
  (let ((c   (shell-quote-argument (concat  (connect host user password)  "  ; site filetype=jes; "  " ls ;  ; "))))
    (progn
      (start-process-shell-command "lftp2.exe --verbose  -c " 
				   (get-buffer-create  "MVS-JOBS") 
				   "lftp2.exe --verbose  -c  "  c ))))
;;;###autoload
(defun mvs-last-job-log ()
  (interactive)
  "this will retrieve the log from the job and show it"
  (progn
    (clean-buff "MVS-JOBS")
    (mvs-list-jobs)
    (sleep-for 4) 
    (get-buffer-as-list "MVS-JOBS")
    (read-log-from-job
     (with-current-buffer "MVS-JOBS" (second (split-string (first (split-string (buffer-string) "\n" t))))))))


;;;###autoload
(defun transfer-to-mvs ()
  (interactive)
  "this will transfer a file to the ftp dir"
  (let ( (s (upcase (file-name-extension (buffer-file-name (current-buffer))))))
    (if  (or (string-equal s "JCL")  (string-equal s "CNTL") (string-equal s "PROC"))
	(progn
	  (let (   (c  (create-transfer-string host user password
					       (upcase (file-name-extension (buffer-file-name (current-buffer)  ) ) ) 
					       (buffer-file-name (with-current-buffer (current-buffer ))))))
	    (start-process-shell-command "lftp2.exe --verbose  -c " 
					 (get-buffer-create  "lftp-transfer") 
					 "lftp2.exe --verbose  -c  "
					 c ))
	  (sleep-for 2)
	  (message "transfer finished!!"))
      ; I don't care what happens to other files
      ;(message "not a valid mvs file!!")
      )))



;; hooks
;; this one will transfer the dataset to the mainframe and start the job associated with this file

(add-hook 'after-save-hook  '(lambda () (if (string-equal (first (last (split-string  (buffer-file-name (current-buffer))  "/")  ) )
							  "your file" )
					    (progn
					      (transfer-to-mvs)
					      (with-current-buffer "jcl job that uses the file"
						(transfer-to-mvs))))))

(provide 'jes-zos)
