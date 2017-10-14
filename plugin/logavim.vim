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

function! s:populateFilterWithColor(bufnr, pat, color_map, shrink_maxlen,
              \ nocolor_list, linenr) abort
    let line_num = a:linenr - 1
    let lines = getbufline(a:bufnr, a:linenr, '$')
    for line in lines
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
        if color_name ==# '' || index(a:nocolor_list, mm[1]) >= 0
            continue
        endif
        call matchaddpos(color_name, [line_num])
    endfor
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
        let sync_lines = s:populateFilterWithColor(a:bufnr, logpat, color_map,
              \ shrink_maxlen, a:nocolor_list, a:linenr)
    else
        let sync_lines = s:populateFilteredLogs(a:bufnr, logpat, shrink_maxlen, a:linenr)
    endif
    let b:logavim__logalize_synclines = sync_lines
endfunction

function! s:populateFilteredLogs(bufnr, pat, shrink_maxlen, linenr) abort
    let lines = getbufline(a:bufnr, a:linenr, '$')
    for line in lines
        let i = matchend(line, a:pat)
        let cropped_line = line
        if i > 0
            let cropped_line = line[i:]
        endif
        if a:shrink_maxlen > 0 && len(cropped_line) > a:shrink_maxlen
            let cropped_line = cropped_line[0:a:shrink_maxlen] . '...'
        endif
        put=cropped_line
    endfor
    return [lines[0], lines[len(lines)-1]]
endfunction

function! Logalize(bufnr, bufname, args) abort
    if !exists('b:logavim_scheme')
        echoerr 'LogaVim: Logalize: b:logavim_scheme must be defined!'
        return
    endif
    if len(a:args) > 1
        echoerr 'LogaVim: Logalize accepts one argument: -nocolor[=*|COL0,COL1,..]'
        return
    endif
    if len(a:args) > 0 && a:args[0] !~# '^-nocolor'
        echoerr 'LogaVim: Logalize argument is: -nocolor[=*|COL0,COL1,..]'
        return
    endif

    let arg0 = ''
    if len(a:args) > 0
        let arg0 = a:args[0][8:]
        if arg0[0] ==# '='
            let arg0 = arg0[1:]
        endif
    endif

    call s:splitNewBuf('logalized_' . a:bufname)
    let b:logavim__nocolor_list = split(arg0, ',')
    let b:logavim__noargs = !len(a:args)
    let b:logavim__scheme_name = getbufvar(a:bufnr, 'logavim_scheme')
    let b:logavim__orig_bufnr = a:bufnr

    call s:populateUsingScheme(b:logavim__orig_bufnr,
          \ lgv#registry#GetByName(b:logavim__scheme_name),
          \ b:logavim__nocolor_list, b:logavim__noargs, 1)

    normal! ggddG
    setlocal nomodifiable readonly
    call setbufvar(a:bufnr, '&autoread', 1)
    execute "normal! \<C-w>_"
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

comm! -nargs=* Logalize call Logalize(bufnr("%"), fnamemodify(expand("%"), ":t"), [<f-args>])

silent do LogaVim_User User LogaVimLoaded

