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

function! s:filterOutPats(pats, line) abort
    let ret = a:line
    for p in a:pats
        let ret = substitute(ret, p[0], p[1], '')
    endfor
    return ret
endfunction

function! s:getSimilarity(lnnr, line) abort
    if a:lnnr == 0
        return 0.0
    endif
    let [cnt, length] = [0, len(a:line)]
    let line_prev = getline(a:lnnr, a:lnnr)[0]
    if len(line_prev) != length
        return 0.0
    endif
    for i in range(1, length)
        if a:line[i] ==# line_prev[i]
            let cnt += 1
        endif
    endfor
    return (cnt*1.0 / length*1.0) * 100.0
endfunction

function! s:populateLogsNoColor(bufnr, pat, shrink_maxlen, linenr,
            \ similarity_threshold, repetition_threshold) abort
    let lines = getbufline(a:bufnr, a:linenr, '$')
    let [line_num, diff_start] = [a:linenr - 1, a:linenr - 1]
    for line in lines
        let line_num = line_num + 1
        let i = matchend(line, a:pat)
        let cropped_line = line
        if i > 0
            let cropped_line = line[i:]
        endif
        let cropped_line = s:filterOutPats(b:logavim__replace_pats, cropped_line)
        if a:shrink_maxlen > 0 && len(cropped_line) > a:shrink_maxlen
            let cropped_line = cropped_line[0:a:shrink_maxlen] . '...'
        endif
        if s:getSimilarity(line_num-1, cropped_line) < a:similarity_threshold
            let diff_start = line_num - diff_start
            if diff_start > a:repetition_threshold
                execute 'normal! zf' . diff_start . 'kG'
            endif
            let diff_start = line_num
        endif
        put=cropped_line
    endfor
    let diff_start = line_num - diff_start + 1
    if diff_start > a:repetition_threshold
        execute 'normal! zf' . diff_start . 'kG'
    endif
    return [lines[0], lines[len(lines)-1]]
endfunction

function! s:populateLogsWithColor(bufnr, pat, color_map, shrink_maxlen,
            \ nocolor_list, linenr, similarity_threshold, repetition_threshold) abort
    let [line_num, diff_start] = [a:linenr - 1, a:linenr - 1]
    let lines = getbufline(a:bufnr, a:linenr, '$')
    for line in lines
        let line_num = line_num + 1
        let mm = matchlist(line, a:pat)
        let cropped_line = line
        if len(mm)
            let cropped_line = line[len(mm[0]):]
        endif
        let cropped_line = s:filterOutPats(b:logavim__replace_pats, cropped_line)
        if a:shrink_maxlen > 0 && len(cropped_line) > a:shrink_maxlen
            let cropped_line = cropped_line[0:a:shrink_maxlen] . '...'
        endif
        if s:getSimilarity(line_num-1, cropped_line) < a:similarity_threshold
            let diff_start = line_num - diff_start
            if diff_start > a:repetition_threshold
                execute 'normal! zf' . diff_start . 'kG'
            endif
            let diff_start = line_num
        endif
        put=cropped_line
        if len(mm) < 2
            continue
        endif
        let color_name = get(a:color_map, mm[1], '')
        if color_name ==# '' || index(a:nocolor_list, mm[1]) >= 0
            continue
        endif
        call matchaddpos(color_name, [line_num])
    endfor
    let diff_start = line_num - diff_start + 1
    if diff_start > a:repetition_threshold
        execute 'normal! zf' . diff_start . 'kG'
    endif
    return [lines[0], lines[len(lines)-1]]
endfunction

function! s:populateUsingScheme(bufnr, scheme, nocolor_list, show_colors, linenr) abort
    let logline = get(a:scheme, 'logline', '')
    let dict = get(a:scheme, 'dict', {})
    let color_section = get(a:scheme, 'color_section', '')
    let shrink_maxlen = get(a:scheme, 'shrink_maxlen', 0)
    let logpat = s:parseLoglineToPattern(logline, dict, color_section)
    call setbufvar(a:bufnr, 'logavim_line_pattern', logpat)
    if len(a:nocolor_list) || a:show_colors
        let color_map = get(a:scheme, 'color_map', {})
        let sync_lines = s:populateLogsWithColor(a:bufnr, logpat, color_map,
                            \ shrink_maxlen, a:nocolor_list, a:linenr,
                            \ g:logavim_similarity_threshold, g:logavim_repetition_threshold)
    else
        let sync_lines = s:populateLogsNoColor(a:bufnr, logpat, shrink_maxlen, a:linenr, 
                            \ g:logavim_similarity_threshold, g:logavim_repetition_threshold)

    endif
    let b:logavim__logalize_synclines = sync_lines
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
    call s:refreshFull()
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
    let b:logavim__nocolor_list = split(nocolor_arg[8:], ',')
    let b:logavim__noargs = !len(nocolor_arg)
    let b:logavim__scheme_name = getbufvar(a:bufnr, 'logavim_scheme')
    let b:logavim__orig_bufnr = a:bufnr
    let b:logavim__replace_pats = exists('g:logavim_replacement_patterns') ?
                \ g:logavim_replacement_patterns : []


    call s:populateUsingScheme(b:logavim__orig_bufnr,
                \ lgv#registry#GetByName(b:logavim__scheme_name),
                \ b:logavim__nocolor_list, b:logavim__noargs, 1)

    normal! ggddG
    setlocal nomodifiable readonly
    call setbufvar(a:bufnr, '&autoread', 1)
    execute "normal! \<C-w>_"
    command -buffer -nargs=* LGReplace call s:replaceCmd([<f-args>])
endfunction

function! s:refreshFull() abort
    setlocal modifiable noreadonly
    call clearmatches()
    normal! gg"_dG
    call s:populateUsingScheme(b:logavim__orig_bufnr,
                \ lgv#registry#GetByName(b:logavim__scheme_name),
                \ b:logavim__nocolor_list, b:logavim__noargs, 1)
    normal! ggddG
    setlocal nomodifiable readonly
endfunction

function! s:refreshAppend(linenr) abort
    normal! G
    setlocal modifiable noreadonly
    call s:populateUsingScheme(b:logavim__orig_bufnr,
            \ lgv#registry#GetByName(b:logavim__scheme_name),
            \ b:logavim__nocolor_list, b:logavim__noargs, a:linenr+1)
    setlocal nomodifiable readonly
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

function! s:checkUpdated(sync_lines, bufnr) abort
    let len_logalize = len(getbufline('%', 1, '$'))
    let len_orig = len(getbufline(a:bufnr, 1, '$'))
    if len_orig < len_logalize
        return [2, len_orig]
    endif
    if a:sync_lines[0] !=# getbufline(a:bufnr, 1, 1)[0]
            \ || a:sync_lines[1] !=# getbufline(a:bufnr, len_logalize, len_logalize)[0]
        return [2, len_orig]
    endif
    if len_orig == len_logalize
        return [0, 0]
    endif
    return [1, len_logalize]
endfunction

function! s:bufEnterEvent() abort
    let [upd, length] = s:checkUpdated(b:logavim__logalize_synclines,
            \ b:logavim__orig_bufnr)
    if upd == 2
        call s:refreshFull()
    elseif upd == 1
        call s:refreshAppend(length)
    endif
endfunction

augroup LogaVim_Augroup
    au!
    au! CursorHold * if (exists('b:logavim__orig_bufnr'))| call s:cursorHold() |endif
    au! BufEnter   * if (exists('b:logavim__orig_bufnr'))| call s:bufEnterEvent() |endif
    au! FileChangedShellPost * if (exists('b:logavim__orig_bufnr'))| call s:bufEnterEvent() |endif
augroup END

comm! -nargs=* Logalize call s:logalizeCmd(bufnr("%"), fnamemodify(expand("%"), ":t"), [<f-args>])

silent do LogaVim_User User LogaVimLoaded

