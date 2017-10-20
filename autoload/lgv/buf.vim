if exists('g:loaded_lgv_buf_autoload')
    finish
endif
let g:loaded_lgv_buf_autoload = 1

function! lgv#buf#PopulateUsingScheme(bufnr, scheme, nocolor_list, show_colors, linenr, replace_pats) abort
    let logline = get(a:scheme, 'logline', '')
    let dict = get(a:scheme, 'dict', {})
    let color_section = get(a:scheme, 'color_section', '')
    let shrink_maxlen = get(a:scheme, 'shrink_maxlen', 0)
    let logpat = s:parseLoglineToPattern(logline, dict, color_section)
    call setbufvar(a:bufnr, 'logavim_line_pattern', logpat)
    if len(a:nocolor_list) || a:show_colors
        let color_map = get(a:scheme, 'color_map', {})
        let sync_lines = lgv#buf#PopulateLogsWithColor(a:bufnr, logpat, color_map,
                                \ shrink_maxlen, a:nocolor_list, a:linenr, a:replace_pats,
                                \ g:logavim_similarity_threshold, g:logavim_repetition_threshold)
    else
        let sync_lines = lgv#buf#PopulateLogsNoColor(a:bufnr, logpat, shrink_maxlen, a:linenr,
                \ a:replace_pats, g:logavim_similarity_threshold, g:logavim_repetition_threshold)

    endif
    return sync_lines
endfunction

function! lgv#buf#CheckUpdated(sync_lines, bufnr) abort
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

function! lgv#buf#RefreshFull(orig_bufnr, scheme_name, nocolor_list, is_noargs, replace_pats) abort
    setlocal modifiable noreadonly
    call clearmatches()
    normal! gg"_dG
    call lgv#buf#PopulateUsingScheme(a:orig_bufnr, lgv#registry#GetByName(a:scheme_name),
                                    \ a:nocolor_list, a:is_noargs, 1, a:replace_pats)
    normal! ggddG
    setlocal nomodifiable readonly
endfunction

function! lgv#buf#RefreshAppend(orig_bufnr, linenr, scheme_name, nocolor_list, is_noargs, replace_pats) abort
    normal! G
    setlocal modifiable noreadonly
    call lgv#buf#PopulateUsingScheme(a:orig_bufnr, lgv#registry#GetByName(a:scheme_name),
                                    \ a:nocolor_list, a:is_noargs, a:linenr+1, a:replace_pats)
    setlocal nomodifiable readonly
endfunction

function! lgv#buf#FilterOutPats(pats, line) abort
    let ret = a:line
    for p in a:pats
        let ret = substitute(ret, p[0], p[1], '')
    endfor
    return ret
endfunction

function! lgv#buf#GetSimilarity(lnnr, line) abort
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

function! lgv#buf#PopulateLogsNoColor(bufnr, pat, shrink_maxlen, linenr, replace_pats,
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
        let cropped_line = lgv#buf#FilterOutPats(a:replace_pats, cropped_line)
        if a:shrink_maxlen > 0 && len(cropped_line) > a:shrink_maxlen
            let cropped_line = cropped_line[0:a:shrink_maxlen] . '...'
        endif
        if lgv#buf#GetSimilarity(line_num-1, cropped_line) < a:similarity_threshold
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

function! lgv#buf#PopulateLogsWithColor(bufnr, pat, color_map, shrink_maxlen, nocolor_list, linenr,
            \ replace_pats, similarity_threshold, repetition_threshold) abort
    let [line_num, diff_start] = [a:linenr - 1, a:linenr - 1]
    let lines = getbufline(a:bufnr, a:linenr, '$')
    for line in lines
        let line_num = line_num + 1
        let mm = matchlist(line, a:pat)
        let cropped_line = line
        if len(mm)
            let cropped_line = line[len(mm[0]):]
        endif
        let cropped_line = lgv#buf#FilterOutPats(a:replace_pats, cropped_line)
        if a:shrink_maxlen > 0 && len(cropped_line) > a:shrink_maxlen
            let cropped_line = cropped_line[0:a:shrink_maxlen] . '...'
        endif
        if lgv#buf#GetSimilarity(line_num-1, cropped_line) < a:similarity_threshold
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

