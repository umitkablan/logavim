# Log-a-Vim
-----------

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

The log-line pattern should be fed by the user, first by registering the scheme with it's name and then defining the buffer variable `b:logavim_scheme` - the scheme name registered before. These better be done in `vimrc` and `autocommand`s. Hence, better use `LogaVimLoaded` signal in `LogaVim_User` augroup to #register - you will be able to lazy load the plugin.

As an example, let's say we have a boot.log file we need to `:Logalize`:

```vim
augroup LogaVim_User
    au LogaVim_User User LogaVimLoaded call lgv#registry#Add('bootlog', {
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
augroup END

augroup LogaVim_Schemes_LocalDefs
  au!
  au BufRead boot.log let b:logavim_scheme = 'bootlog'
augroup END
```

Feed Scheme Name Manually
-------------------------
At above example `b:logavim_scheme` is automatically filled with the scheme name to interpret the lines. However, it's also possible to pass scheme name manually with `:Logalize` command. For example to interpret a boot.log file differently - let's make a fiction scheme 'dblog':
```vim
:Logalize dblog
```
So, practically, you could define schemes with no automatic attachment to file-path pattern.

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

Further Crop Patterns
---------------------
Sometimes you want more to filter-out from log lines even after `:Logalize`ing. So `:LGReplace` command available on the logalized buffer will help crop unwanted patterns. `:LGReplace` accepts the pattern to chop and the replacement text as arguments. If no replacement is provided then the pattern will simply be erased at every occurring line. This command is designed to be a manual step and will take one pattern at each call. `:LGReplace` will filter/replace what you see - you can use `^` for the text on the screen and every step will be separate from previous.

If you have common patterns to be replaced on every `:Logalize` then define `g:logavim_replacement_patterns` pair list:
```vim
let g:logavim_replacement_patterns = [
        \ ['/opt/xmake/xmake', 'XMAK'],
        \ ['/usr/local/Cellar/python/2.7.13/Frameworks/Python.framework/Versions/2.7', 'PY2.7'],
        \ ['Dont want to see', '']
    \ ]
```

