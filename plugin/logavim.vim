if exists('g:loaded_logalize_plugin')
    finish
endif
let g:loaded_logalize_plugin = 1

function! s:splitNewBuf(bufname) abort
    execute 'aboveleft split ' . a:bufname
    setlocal buftype=nofile bufhidden=delete noswapfile nobuflisted
    setlocal modifiable noreadonly
    setlocal foldmethod=manual foldcolumn=0
endfunction

function! s:populateFilteredLogs(bufnr, pat) abort
    let lines = getbufline(a:bufnr, 1, '$')
    for line in lines
        let i = matchend(line, a:pat)
        if i > 0
            put=line[i:]
        else
            put=line
        endif
    endfor
    let b:logalized__orig_bufnr = a:bufnr
    execute 'normal! ggddG'
endfunction

function! Logalize(bufnr, bufname) abort
    if !exists('b:logalize_line_pattern')
        echoerr 'Logalize: b:logalize_line_pattern must be defined!'
        return
    endif
    call s:splitNewBuf('logalized_' . a:bufname)
    call s:populateFilteredLogs(a:bufnr, getbufvar(a:bufnr, 'logalize_line_pattern'))
    setlocal nomodifiable readonly
endfunction

function! s:cursorHold() abort
    let linenr = line('.')
    let line = getbufline(b:logalized__orig_bufnr, linenr, linenr)
    let i = matchend(line[0], getbufvar(b:logalized__orig_bufnr, 'logalize_line_pattern'))
    if i > 0
        echomsg line[0][0:i-1]
    else
        echomsg ''
    endif
endfunction

augroup Logalize_Augroup
    autocmd!
    autocmd! CursorHold * if (exists('b:logalized__orig_bufnr')) | call s:cursorHold() |endif
augroup END

comm! -nargs=0 Logalize call Logalize(bufnr("%"), fnamemodify(expand("%"), ":t"))
