if exists('g:loaded_logavim_plugin')
    finish
endif
let g:loaded_logavim_plugin = 1

function! s:splitNewBuf(bufname) abort
    setlocal noautoread
    execute 'aboveleft split ' . a:bufname
    setlocal buftype=nofile bufhidden=delete noswapfile nobuflisted
    setlocal modifiable noreadonly
    setlocal foldmethod=manual foldcolumn=0
endfunction

function! s:replaceCmd(args) abort
    if len(a:args) == 0 || len(a:args) > 2
        echoerr 'LogaVim: LGIgnorePat usage: <pattern> [<replacement]'
        return
    endif

    let [pat, replacement] = ['', '']
    if len(a:args) > 0
        let pat = a:args[0]
    endif
    if len(a:args) > 1
        let replacement = a:args[1]
    endif
    if len(pat) == 0
        echoerr 'LogaVim: LGIgnorePat <pattern> is empty!'
        return
    endif
    let b:logavim__replace_pats += [[pat, replacement]]
    call lgv#buf#RefreshFull(b:logavim__orig_bufnr, b:logavim__scheme_name,
                    \ b:logavim__nocolor_list, b:logavim__noargs, b:logavim__replace_pats)
endfunction

function! s:logalizeCmd(bufnr, bufname, args) abort
    let [nocolor_arg, scheme_arg] = ['', '']
    for arg in a:args
        if arg =~# '^-nocolor'
            let nocolor_arg = arg
        elseif arg =~# '^-'
            echoerr 'LogaVim: Logalize [<scheme>] [-nocolor[=*|COL0,COL1,..]]'
            return
        else
            let scheme_arg = arg
            unlet! b:logavim_scheme
        endif
    endfor

    if !exists('b:logavim_scheme')
        if scheme_arg ==# ''
            echoerr 'LogaVim: Logalize: Either b:logavim_scheme must be defined or
                        \ scheme argument passed!'
            return
        else
            let b:logavim_scheme = scheme_arg
        endif
    endif
    if !lgv#registry#Exists(b:logavim_scheme)
        echoerr 'LogaVim: Logalize: Scheme "' . b:logavim_scheme . '" not found'
        return
    endif

    if !exists('g:logavim_similarity_threshold')
        let g:logavim_similarity_threshold = 92.0
    endif
    if !exists('g:logavim_repetition_threshold')
        let g:logavim_repetition_threshold = 3
    endif

    call s:splitNewBuf('logalized_' . a:bufname)
    let b:logavim__noargs = !len(nocolor_arg)
    let nocolor_arg = nocolor_arg[8:]
    if nocolor_arg =~# '^='
        let nocolor_arg = nocolor_arg[1:]
    endif
    let b:logavim__nocolor_list = split(nocolor_arg, ',')
    let b:logavim__scheme_name = getbufvar(a:bufnr, 'logavim_scheme')
    let b:logavim__orig_bufnr = a:bufnr
    let b:logavim__replace_pats = exists('g:logavim_replacement_patterns') ?
                \ g:logavim_replacement_patterns : []

    let b:logavim__logalize_synclines = lgv#buf#PopulateUsingScheme(b:logavim__orig_bufnr,
                        \ lgv#registry#GetByName(b:logavim__scheme_name), b:logavim__nocolor_list,
                        \ b:logavim__noargs, 1, b:logavim__replace_pats)

    normal! ggddG
    setlocal nomodifiable readonly
    call setbufvar(a:bufnr, '&autoread', 1)
    execute "normal! \<C-w>_"
    command -buffer -nargs=* LGReplace call s:replaceCmd([<f-args>])
endfunction

function! s:cursorHold() abort
    try
        let linenr = line('.')
        let line = getbufline(b:logavim__orig_bufnr, linenr, linenr)
        let i = matchend(line[0], getbufvar(b:logavim__orig_bufnr, 'logavim_line_pattern'))
        if i > 0
            echomsg line[0]
        else
            echomsg ''
        endif
    catch /.*/
        echomsg 'LogaVim ERROR: ' . v:exception
    endtry
endfunction

function! s:bufEnterEvent() abort
    let [upd, length] = lgv#buf#CheckUpdated(b:logavim__logalize_synclines, b:logavim__orig_bufnr)
    if upd == 2
        call lgv#buf#RefreshFull(b:logavim__orig_bufnr, b:logavim__scheme_name,
                            \ b:logavim__nocolor_list, b:logavim__noargs, b:logavim__replace_pats)
    elseif upd == 1
        call lgv#buf#RefreshAppend(b:logavim__orig_bufnr, length, b:logavim__scheme_name,
                            \ b:logavim__nocolor_list, b:logavim__noargs, b:logavim__replace_pats)
    endif
endfunction

augroup LogaVim_Augroup
    au!
    au! CursorHold * if (exists('b:logavim__orig_bufnr'))| call s:cursorHold() |endif
    au! BufEnter   * if (exists('b:logavim__orig_bufnr'))| call s:bufEnterEvent() |endif
    au! FileChangedShellPost * if (exists('b:logavim__orig_bufnr'))| call s:bufEnterEvent() |endif
augroup END

function! s:completeLogalize(argLead, cmdLine, cursorPos) abort
    if !a:cmdLine || a:cursorPos
    endif
    let llall = lgv#registry#GetAllNames() + ['-nocolor']
    return filter(llall, 'v:val =~# "^' . a:argLead .'"')
endfunction

command! -nargs=* -complete=customlist,s:completeLogalize Logalize
            \ call s:logalizeCmd(bufnr("%"), fnamemodify(expand("%"), ":t"), [<f-args>])

silent do LogaVim_User User LogaVimLoaded

