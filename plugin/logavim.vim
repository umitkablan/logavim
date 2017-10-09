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

function! s:getLogKeyFromString(logline, firstidx) abort
    let [index_start, index_end] = [stridx(a:logline, '%', a:firstidx), -1]
    if index_start < 0
        return ['', index_start, index_end]
    endif
    let index_end = stridx(a:logline, '%', index_start+1)
    if index_end < 0
        return ['', index_start, index_end]
    endif
    return [a:logline[index_start+1:index_end-1], index_start, index_end]
endfunction

function! s:parseLoglineToPattern(logln, dict, color_section) abort
    let [index_start, logline] = [0, a:logln]
    while 1
        let [key, index_start, index_end] = s:getLogKeyFromString(logline, index_start)
        if key ==# ''
            break
        endif
        let pat = get(a:dict, key, '')
        if pat ==# ''
            let index_start = index_end + 1
            continue
        endif
        if key ==# a:color_section
            let pat = '\(' . pat . '\)'
        endif
        let diff = len(pat) - len(key) - 1 " -2
        let logline = logline[0:index_start-1] . pat . logline[index_end+1:]
        let index_start = index_end + diff " + 1
    endwhile
    return logline
endfunction

function! s:populateFilterWithColor(bufnr, pat, color_map, shrink_maxlen) abort
    let line_num = 0
    for line in getbufline(a:bufnr, 1, '$')
        let line_num = line_num + 1
        let mm = matchlist(line, a:pat)
        let cropped_line = line
        if len(mm)
            let cropped_line = line[len(mm[0]):]
        endif
        if a:shrink_maxlen > 0 && len(cropped_line) > a:shrink_maxlen
            let cropped_line = cropped_line[0:a:shrink_maxlen] . '...'
        endif
        put=cropped_line
        if len(mm) < 2
            continue
        endif
        let color_name = get(a:color_map, mm[1], '')
        if color_name ==# ''
            continue
        endif
        call matchaddpos(color_name, [line_num])
    endfor
    let b:logalized__orig_bufnr = a:bufnr
    execute 'normal! ggddG'
endfunction

function! s:populateUsingScheme(bufnr, scheme) abort
    let logline = get(a:scheme, 'logline', '')
    let dict = get(a:scheme, 'dict', {})
    let color_section = get(a:scheme, 'color_section', '')
    let color_map = get(a:scheme, 'color_map', {})
    let shrink_maxlen = get(a:scheme, 'shrink_maxlen', 0)
    let logpat = s:parseLoglineToPattern(logline, dict, color_section)
    call setbufvar(a:bufnr, 'logalize_line_pattern', logpat)
    call s:populateFilterWithColor(a:bufnr, logpat, color_map, shrink_maxlen)
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
    if exists('b:logavim_scheme') && exists('g:logavim_scheme_' . b:logavim_scheme)
        let scheme_varname = 'g:logavim_scheme_' . b:logavim_scheme
        call s:splitNewBuf('logalized_' . a:bufname)
        call s:populateUsingScheme(a:bufnr, eval(scheme_varname))
    elseif exists('b:logalize_line_pattern')
        call s:splitNewBuf('logalized_' . a:bufname)
        call s:populateFilteredLogs(a:bufnr, getbufvar(a:bufnr, 'logalize_line_pattern'))
    else
        echoerr 'Logalize: b:logavim_scheme must be defined!'
        return
    endif
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
