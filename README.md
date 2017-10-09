# Log-a-Vim
#############

Plugin to filter out unnecessary repeated sections of a log file and make it more convenient to read by coloring.

How to Install
--------------

If you use a plugin manager like Plug:
```vim
Plug 'umitkablan/logavim'
```

How to Use and Configure
------------------------

Open a log file and type `:Logalize` to create a new filtered read-only buffer from the contents of the current log buffer.
The filtered-out characters of the cursor line will be shown on the command line so you'd have the dirty sections (like date and log level) both away from your eye and easy visible - if the coloring is not enough.

The log-line pattern should be fed by the user defining two variables: (1) the scheme with name `g:logavim_scheme_XXXX` and (2) `b:logavim_scheme = 'XXXX'`. These variables better be defined in `vimrc` and `autocommand`s. As an example, let's say we have a boot.log file we need to `:Logalize`:

```vim
let g:logavim_scheme_bootlog = {
    \ 'logline': '^%TIME% %LOGLEVEL%: ',
    \ 'dict': {
      \ 'DATE': '\d\d\d\d-\d\d-\d\d-\d\d',
      \ 'TIME': '\d\d:\d\d:\d\d',
      \ 'LOGLEVEL': '\S\+'
    \ },
    \ 'color_section': 'LOGLEVEL',
    \ 'color_map': {
      \ 'WARN':  'WarningMsg',
      \ 'ERROR': 'ErrorMsg',
      \ 'INFO':  'Todo',
      \ 'DEBUG': 'DiffChange'
    \ }
  \ }

augroup LogaVim_Schemes_LocalDefs
  au!
  au BufRead boot.log let b:logavim_scheme = 'bootlog'
augroup END
```

Shrinking Long Lines
--------------------
If you want to shrink long lines you could add `'shrink_maxlen'` attribute to the scheme dictionary. This will crop long lines and append `...` to the end as as marker.
