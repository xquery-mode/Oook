# Oook

> Oook -- is all the [Librarian](https://en.wikipedia.org/wiki/Unseen_University#Librarian)
> at the university of the Discworld ever utters. He is the sole staff
> member of the greatest database of knowledge, and as such offers a
> very versatile and helpful interface to it.

Evaluate XQuery documents in a different ways.

## Successor of cider-any

Oook replaces [cider-any](https://github.com/xquery-mode/cider-any).
We decided to get rid of the backend design of cider-any and have a
simpler interface that just lets you evaluate XQuery documents.

# XQuery

## Installation

System requirements:

* Clojure
* Leiningen
* Cider
* Page break lines emacs lisp library
* Uruk clojure library
* MarkLogic server access

Load Emacs Lisp libraries in your configuration.

```lisp
(require 'oook)
```

Enable oook-mode in the xquery-mode buffers by default.

```lisp
(add-hook 'xquery-mode-hook 'oook-mode)
```

Grain access to the MarkLogic account.

```lisp
(setq oook-connection
      '(:host "localhost" :port "8889"
        :user "proofit404" :password "<secret>"
        :content-base nil))
```

## Recommendation of using Cider Stable

You are advised to use the most recent stable version of Cider.
If you are using melpa, you should pin Cider to melpa-stable,
which you can do with an Emacs configuration along the lines of:

```lisp
(require 'package)
(add-to-list 'package-archives
             '("melpa" . "http://melpa.org/packages/") t)
(add-to-list 'package-archives
             '("melpa-stable" . "http://stable.melpa.org/packages/") t)
(add-to-list 'package-pinned-packages '(cider . "melpa-stable") t)
(package-initialize)
```

If you want to use a more recent development version of Cider from
melpa or GitHub, notice that Cider introduced an incompatible change
on Jan 22, 2017. So if you want to use newer version of cider,
please switch Oook to the branch fix-nrepl-eval-for-recent-cider:

> git checkout fix-nrepl-eval-for-recent-cider

## Usage

Start cider repl in the leiningen project.  Uruk library must be
pinned in the project.clj in the dependencies section.  When you hit
`C-c C-c` XQuery buffer will be evaluated on MarkLogic server you
grain access earlier.  Result of this evaluation will be displayed in
the buffer with corresponding major mode.

If you want to open result document in the web browser you can
customize this behavior.

```lisp
(setq oook-eval-handler 'oook-browse)
```

## Extensions

### Associate result with file

Associate buffer evaluation result document with file on disk.

```lisp
(add-hook 'oook-mode-hook 'oook-to-file-mode)
```

### Pretty print XML

Applies pretty printer to XML parts of the result.

* Install xmllint program
* Enable oook-pprint-mode

```lisp
(oook-pprint-mode)
```
