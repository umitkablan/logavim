if exists('g:loaded_lgv_fold_autoload')
    finish
endif
let g:loaded_lgv_fold_autoload = 1

function! lgv#fold#ScanFull(linenr, similarity_threshold, repetition_threshold,
                            \ similars_arr) abort
    if a:linenr < 2
        normal! zE
    endif
    call lgv#fold#ScanLines(a:linenr, a:similarity_threshold, a:repetition_threshold)
    call lgv#fold#ScanBlocks(a:linenr, a:similars_arr)
endfunction

function! lgv#fold#ScanLines(linenr, similarity_threshold, repetition_threshold) abort
    let [line_num, diff_start] = [a:linenr-1, a:linenr]
    let lines = getline(a:linenr, '$')
    for line in lines
        if line_num < 1 ||
        \ s:calcSimilarity(line, lines[line_num-a:linenr]) < a:similarity_threshold
            let diff_start = line_num - diff_start
            if diff_start > a:repetition_threshold
                execute 'normal! ' . line_num . 'Gzf' . diff_start . 'kj'
            endif
            let diff_start = line_num + 1
        endif
        let line_num = line_num + 1
    endfor
    let diff_start = line_num - diff_start
    if diff_start > a:repetition_threshold
        execute 'normal! Gzf' . diff_start . 'kG'
    endif
endfunction

function! lgv#fold#ScanBlocks(linenr, similars_arr) abort
    let lines = getline(a:linenr, '$')
    for [sim_lines, threshold] in a:similars_arr
        let [leng, ln, all_length] = [len(sim_lines)-1, 0, len(lines)]
        while 1
            if ln + leng >= all_length
                break
            endif
            if s:isLinesSimilar(sim_lines, lines[ln : ln+leng], threshold)
                execute 'normal! ' . (ln+a:linenr) . 'Gzf' . leng . 'jj'
                let ln += leng
            endif
            let ln += 1
        endwhile
    endfor
endfunction

function! s:calcSimilarity(ln0, ln1) abort
    let [cnt, length] = [0, len(a:ln0)]
    if len(a:ln1) != length
        return 0.0
    endif
    for i in range(length)
        if a:ln0[i] ==# a:ln1[i]
            let cnt += 1
        endif
    endfor
    return (cnt*1.0 / length*1.0) * 100.0
endfunction

function! s:isLinesSimilar(lines0, lines1, threshold) abort
    let [cnt, length] = [0, len(a:lines0)]
    if length != len(a:lines1)
        return 0
    endif
    for i in range(length)
        if s:calcSimilarity(a:lines0[i], a:lines1[i]) < a:threshold
            break
        endif
        let cnt += 1
    endfor
    return cnt == length
endfunction

