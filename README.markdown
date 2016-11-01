> Oook -- is all the [Librarian](https://en.wikipedia.org/wiki/Unseen_University#Librarian)
> at the university of the Discworld ever utters. He is the sole staff
> member of the greatest database of knowledge, and as such offers a
> very versatile and helpful interface to it.

# Oook

Evaluate XQuery documents in a different ways.

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
