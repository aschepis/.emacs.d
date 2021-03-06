;;; backlog.el --- Functions for working with Backlog -*- lexical-binding: t -*-

;; Package-Requires: ((emacs "25") request thingatpt cl-lib ivy)

;;; Commentary:

;;; Code:

(require 'thingatpt)
(require 'request)
(require 'cl-lib)
(require 'ivy)

(defconst backlog-link-template "https://%s.backlog.jp/view/%s")
(defconst backlog-api-template "https://%s.backlog.jp/api/v2/%s")

(defcustom backlog-api-key nil
  "Backlog API key to use for API calls."
  :group 'backlog
  :type '(string))

(defcustom backlog-team nil
  "The Backlog team to use when opening links."
  :group 'backlog
  :type '(string))

;; Backlog REST API functions

(defun backlog-api-url (&optional action)
  "Get the Backlog API endpoint for an ACTION."
  (format backlog-api-template backlog-team (or action "")))

(defun backlog-recent-issues ()
  "Select from among recent issues.  Default action is to insert key+summary into buffer."
  (interactive)
  (backlog-recent-issues-async
   nil
   (lambda (issues)
     (let (ivy--actions-list ;; Set to nil temporarily to suppress default ivy actions
           (desc-kns-alist (mapcar (lambda (item)
                                     (let ((kns (backlog-issue-key-and-summary (alist-get 'issue item))))
                                       `(,(backlog-issue-short-desc kns) . ,kns)))
                                   issues)))
       (ivy-read "Issue:" desc-kns-alist
                 :action '(1 ("o" (lambda (x) (with-ivy-window (insert (car x)))) "insert key+summary")
                             ("i" (lambda (x) (with-ivy-window (insert (cadr x)))) "insert key")
                             ("b" (lambda (x) (browse-backlog-issue (cadr x))) "browse issue")))))))

(defun backlog-issue-key-and-summary (issue)
  "Extract a short description from a raw ISSUE, in the format `(KEY . SUMMARY)`."
  (let ((key (alist-get 'issueKey issue))
        (summary (alist-get 'summary issue)))
    `(,(decode-coding-string key 'utf-8) .  ,(decode-coding-string summary 'utf-8))))

(defun backlog-issue-short-desc (kns)
  "Format a key-and-summary cons KNS as a string."
  (format "%s %s" (car kns) (cdr kns)))

(defun backlog-request (url callback &rest args)
  "Forward URL to `request` while setting the result CALLBACKs \
and API key in addition to optional ARGS."
  (if backlog-api-key
      (let ((params (plist-get args :params)))
        (push `("apiKey" . ,backlog-api-key) params)
        (mapc (lambda (x) (setq args (plist-put args (car x) (cdr x))))
              `((:params . ,params)
                (:parser . json-read)
                (:success . ,(cl-function (lambda (&key data &allow-other-keys)
                                            (condition-case err
                                                (funcall callback data)
                                              (error (message "Callback error: %s" err))))))
                (:error . ,(cl-function (lambda (&key data &allow-other-keys)
                                          (error "Request error: %s" data))))))
        (apply #'request url args))
    (error "No value set for backlog-api-key")))

(defun backlog-recent-issues-async (user callback)
  "Retrieve USER's recently viewed issues asynchronously and \
process with CALLBACK.  If USER is nil, `myself` is used."
  (let* ((usr (or user "myself"))
         ;; https://developer.nulab-inc.com/ja/docs/backlog/api/2/get-list-of-recently-viewed-issues/
         (endpoint (format "users/%s/recentlyViewedIssues" usr))
         (url (backlog-api-url endpoint)))
    (backlog-request url callback)))

;; External browser functions

(defun backlog-browse-issue (issue)
  "Open Backlog issue with key ISSUE."
  (if issue
      (browse-url (backlog-make-link issue))
    (error "Issue was nil")))

(defun backlog-make-link (issue)
  "Create a Backlog URL for issue ISSUE."
  (format backlog-link-template backlog-team issue))

(defun backlog-issue-p (string)
  "Return t if STRING appears to be a Backlog issue key."
  (if (string-match-p "^[a-z]+-[1-9][0-9]*$" string) t))

(defun backlog-browse-issue-at-point ()
  "Browse the Backlog issue at point, if any."
  (interactive)
  (let ((sym (thing-at-point 'symbol t)))
    (if (backlog-issue-p sym)
        (browse-backlog-issue sym))))

(provide 'backlog)
;;; backlog.el ends here
