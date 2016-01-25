# jes-emacs
This an Emacs library to interact with Z/OS JES 
I have created a library to interact with JES2 and save time on my workflow by avoiding using TSO to execute a job or edit a dataset. This library has the following features:

Edit a dataset just using  running for example.                             
  * M-x mvs-get-file for ex: PDS(MEMBER) .

Uploads your current buffer into a PDS by using the following rules:
* If this file is a JCL it will be executed. 
* if the file has the extension proc or cntl it will be uploaded in a TSO-USER.PDS called CNTL or PROC.(it assumes you wish to save in there).

  M-x transfer-to-mvs  

* Check your spool (this will create a buffer called MVS-JOBS)
 

  M-x mvs-list-jobs


* You could automate a task like editing a PROC or CNTL member an associate a JCL to them so everytime you edit one of these files the job associated with this member executes.    
For ex: 
```elisp
 (add-hook 'after-save-hook  
'(lambda () (if (string-equal (first (last (split-string  (buffer-file-name (current-buffer))  "/")  ) )
                               "<your file>" )
   (progn
           (transfer-to-mvs)
           (with-current-buffer "<jcl job that uses the file>"
            (transfer-to-mvs))))))
```            
