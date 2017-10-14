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

As log files are usually analysed during a program execution, logs will be automatically reloaded when log file is changed by an external program. Both the original log buffer and LogaVim buffer will be reloaded.

The log-line pattern should be fed by the user, first by registering the scheme with it's name and then defining the buffer variable `b:logavim_scheme` the scheme name registered before. These variables better be defined in `vimrc` and `autocommand`s. As an example, let's say we have a boot.log file we need to `:Logalize`:

```vim
call lgv#registry#Add('bootlog', {
    \ 'logline': '^%TIME% %LOGLEVEL%: ',
    \ 'dict': {
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
  \ })

augroup LogaVim_Schemes_LocalDefs
  au!
  au BufRead boot.log let b:logavim_scheme = 'bootlog'
augroup END
```

Shrinking Long Lines
--------------------
If you want to shrink long lines you could add `'shrink_maxlen'` attribute to the scheme dictionary. This will crop long lines and append `...` to the end as a marker.

Disable Coloring
----------------
If you want to disable coloring of some log lines. You can provide `-nocolor` argument to `:Logalize` command. `-nocolor=` accepts comma separated values for field tags to disable. If no values are passed then all line coloring is disabled.

Let's say your coloring is based on loglevel and you don't want to colorize INFO logs:
```vim
:Logalize -nocolor=INFO
```

