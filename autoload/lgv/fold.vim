if exists('g:loaded_lgv_fold_autoload')
    finish
endif
let g:loaded_lgv_fold_autoload = 1

function! lgv#fold#ScanFull(linenr, similarity_threshold, repetition_threshold,
                        \ similars_arr, re_arr, fold_regions) abort
    if a:linenr < 2
        normal! zE
    endif
    let lines = getline(a:linenr, '$')

    call lgv#fold#ScanLines(a:linenr, lines, a:similarity_threshold, a:repetition_threshold)
    call lgv#fold#ScanBlocks(a:linenr, lines, a:similars_arr)
    call lgv#fold#ScanRegexpGroups(a:linenr, lines, a:re_arr)
    call lgv#fold#ScanRegions(a:linenr, lines, a:fold_regions)
endfunction

function! lgv#fold#ScanLines(linenr, lines, similarity_threshold, repetition_threshold) abort
    let [line_num, diff_start] = [a:linenr-1, a:linenr]
    for line in a:lines
        if line_num < 1 ||
                    \ s:calcSimilarity(line, a:lines[line_num-a:linenr], 0) < a:similarity_threshold
            let diff_start = line_num - diff_start
            if diff_start > a:repetition_threshold
                execute 'keepjumps normal! ' . line_num . 'Gzf' . diff_start . 'kj'
            endif
            let diff_start = line_num + 1
        endif
        let line_num = line_num + 1
    endfor
    let diff_start = line_num - diff_start
    if diff_start > a:repetition_threshold
        execute 'keepjumps normal! Gzf' . diff_start . 'kG'
    endif
endfunction

function! lgv#fold#ScanRegexpGroups(linenr, lines, re_groups) abort
    for re_arr in values(a:re_groups)
        call lgv#fold#ScanRegexpArr(a:linenr, a:lines, re_arr)
    endfor
endfunction

function! lgv#fold#ScanRegexpArr(linenr, lines, re_arr) abort
    let [line_num, diff_start] = [a:linenr, a:linenr]
    for line in a:lines
        if s:isLineNotIn(line, a:re_arr)
            let diff_start = line_num - diff_start - 1
            if diff_start > 0
                execute 'keepjumps normal! ' . (line_num-1) . 'Gzf' . diff_start . 'kj'
            endif
            let diff_start = line_num + 1
        endif
        let line_num = line_num + 1
    endfor
    let diff_start = line_num - diff_start - 1
    if diff_start > 0
        execute 'keepjumps normal! Gzf' . diff_start . 'kG'
    endif
endfunction

function! lgv#fold#ScanRegions(linenr, lines, fold_regions) abort
    for rgn in a:fold_regions
        for [ln0,ln1] in s:getFoldsForRegion(rgn, a:lines)
            if ln1-ln0 > 1
                execute 'keepjumps normal! ' . (a:linenr+ln0) . 'Gzf' . (ln1-ln0) . 'j'
            endif
        endfor
    endfor
endfunction

function! lgv#fold#ScanBlocks(linenr, lines, similars_arr) abort
    for [sim_lines, threshold] in a:similars_arr
        let [leng, ln, all_length] = [len(sim_lines)-1, 0, len(a:lines)]
        while 1
            if ln + leng >= all_length
                break
            endif
            if s:isLinesSimilar(sim_lines, a:lines[ln : ln+leng], threshold)
                execute 'keepjumps normal! ' . (ln+a:linenr) . 'Gzf' . leng . 'jj'
                let ln += leng
            endif
            let ln += 1
        endwhile
    endfor
endfunction

function! lgv#fold#CountMatchingBlocks(sim_lines, lines, threshold) abort
    let [leng, ln, all_length, ret] = [len(a:sim_lines)-1, 0, len(a:lines), 0]
    while 1
        if ln + leng >= all_length
            break
        endif
        if s:isLinesSimilar(a:sim_lines, a:lines[ln : ln+leng], a:threshold)
            let ret += 1
            let ln += leng
        endif
        let ln += 1
    endwhile
    return ret
endfunction

function! s:isLineNotIn(line, re_arr) abort
    for re in a:re_arr
        if matchend(a:line, re) > 0
            return 0
        endif
    endfor
    return 1
endfunction

function! s:calcSimilarity(ln0, ln1, is_len) abort
    let [minn, maxx] = [len(a:ln0), len(a:ln1)]
    if !a:is_len && minn != maxx
        return 0.0
    endif
    if minn > maxx
        let [minn, maxx] = [maxx, minn]
    endif
    let cnt = 0
    for i in range(minn)
        if a:ln0[i] ==# a:ln1[i]
            let cnt += 1
        endif
    endfor
    return (cnt*1.0 / maxx*1.0) * 100.0
endfunction

function! s:isLinesSimilar(lines0, lines1, threshold) abort
    let [cnt, length] = [0, len(a:lines0)]
    if length != len(a:lines1)
        return 0
    endif
    for i in range(length)
        if s:calcSimilarity(a:lines0[i], a:lines1[i], 1) < a:threshold
            break
        endif
        let cnt += 1
    endfor
    return cnt == length
endfunction

function! s:getFoldsForRegion(region, lines) abort
    let [pair, firstfound, ret] = [[0,0], 0, []]
    for i in range(len(a:lines))
        if matchend(a:lines[i], a:region[firstfound]) > 0
            let pair[firstfound] = i
            let firstfound += 1
        endif
        if firstfound > 1
            let ret += [[pair[0], pair[1]+a:region[2]]]
            let firstfound = 0
        endif
    endfor
    return ret
endfunction
