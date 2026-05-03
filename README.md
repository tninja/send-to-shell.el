# send-to-shell.el

A unified Emacs package for sending code to shell buffers with support for multiple backends: eshell, shell, vterm, eat, and ghostel.

## Features

- **Multiple shell backends**: Support for eshell, shell, vterm, eat, and ghostel
- **Buffer-specific shell buffers**: Each source file gets its own dedicated shell buffer
- **Flexible code sending**: Send selected regions or current blocks to shell
- **Minimal dependencies**: Only depends on Emacs built-in packages for core functionality

## Installation

Clone the repository and add to your Emacs load path:

```emacs-lisp
(add-to-list 'load-path "~/.emacs.d/site-lisp/send-to-shell.el")
(require 'send-to-shell)
```

## Usage

### Core Functions

#### `send-to-shell-send-region (start end backend)`

Send a region of text to the specified shell backend.

```emacs-lisp
(send-to-shell-send-region (point-min) (point-max) 'eshell)
```

#### `send-to-shell-send-block (backend)`

Send the current paragraph/block to the specified shell backend.

```emacs-lisp
(send-to-shell-send-block 'vterm)
```

#### `send-to-shell-send-region-or-block (backend)`

Send the active region if one exists, otherwise send the current block.

```emacs-lisp
(send-to-shell-send-region-or-block 'shell)
```

### Backend Selection

List available backends:

```emacs-lisp
(send-to-shell-get-available-backends)
;; Returns: (eshell shell vterm eat ghostel) based on what's installed
```

### Configuration

Set the default backend:

```emacs-lisp
(setq send-to-shell-default-backend 'vterm)
```

Adjust sleep time for vterm (in milliseconds):

```emacs-lisp
(setq send-to-shell-vterm-sleep-ms 150)
```

## Buffer Naming

Each source buffer gets a dedicated shell buffer using the pattern `*<source-buffer-name>*`. For example:
- `script.sh` → shell buffer `*script.sh*`
- `Makefile` → shell buffer `*Makefile*`

## Backends

### eshell (Built-in)
Emacs shell implementation. No external dependencies.

### shell (Built-in)
Traditional comint-based shell. No external dependencies.

### vterm
Full terminal emulator. Requires `emacs-libvterm` package.

### eat
Eat is another terminal emulator implementation. Requires the `eat` package.

### ghostel
An alternative terminal backend. Requires the `ghostel` package.

## Testing

Run tests with:

```bash
cd send-to-shell.el
emacs --batch -L . -l ert -l send-to-shell.el -l send-to-shell-test.el -f ert-run-tests-batch-and-exit
```

## License

See LICENSE file in the repository.
