if exists('g:loaded_logavim_plugin')
    finish
endif
let g:loaded_logavim_plugin = 1

if !exists('g:logavim_similarity_threshold')
    let g:logavim_similarity_threshold = 92.0
endif
if !exists('g:logavim_repetition_threshold')
    let g:logavim_repetition_threshold = 3
endif

function! s:splitNewBuf(bufname) abort
    setlocal noautoread
    execute 'aboveleft split ' . a:bufname
    setlocal buftype=nofile bufhidden=delete noswapfile nobuflisted
    setlocal modifiable noreadonly
    setlocal foldmethod=manual foldcolumn=0
    setlocal nospell
endfunction

function! s:replaceCmd(args) abort
    if len(a:args) == 0 || len(a:args) > 2
        echoerr 'LogaVim: LGReplace usage: <pattern> [<replacement]'
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
        echoerr 'LogaVim: LGReplace <pattern> is empty!'
        return
    endif

    let b:logavim__replace_pats += [[pat, replacement]]
    let b:logavim__logalize_synclines =
        \ lgv#buf#RefreshFull(b:logavim__orig_bufnr, b:logavim__scheme_name,
            \ b:logavim__nocolor_list, b:logavim__noargs, b:logavim__replace_pats)
endfunction

function! s:foldSimilarCmd(ln1, ln2) abort
    if a:ln2 - a:ln1 < 1
        echoerr 'LogaVim: LGFoldSimilar must fold more than 1 line'
        return
    endif
    let lines = getline(a:ln1, a:ln2)
    let b:logavim__fold_similars += [[lines, g:logavim_similarity_threshold]]
    call lgv#fold#ScanFull(1, g:logavim_similarity_threshold,
                \ g:logavim_repetition_threshold, b:logavim__fold_similars,
                \ b:logavim__fold_groups, b:logavim__fold_regions)
endfunction

function! s:foldRegexpCmd(args) abort
    if len(a:args) < 1
        echoerr 'LogaVim: LGFoldRegexp expects at least regexp as argument!'
        return
    endif
    let [regexp, group_name] = [a:args[0], get(a:args, 1, '_default_')]

    if has_key(b:logavim__fold_groups, group_name)
        let b:logavim__fold_groups[group_name] += [regexp]
    else
        let b:logavim__fold_groups[group_name] = [regexp]
    endif

    call lgv#fold#ScanFull(1, g:logavim_similarity_threshold,
                \ g:logavim_repetition_threshold, b:logavim__fold_similars,
                \ b:logavim__fold_groups, b:logavim__fold_regions)
endfunction

function! s:logalizeCmd(args) abort
    let [nocolor_arg, scheme_arg, bufnum] = ['', '', bufnr('%')]
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

    call s:splitNewBuf('logalized_' . fnamemodify(expand('%'), ':t'))
    let b:logavim__noargs = !len(nocolor_arg)
    let nocolor_arg = nocolor_arg[8:]
    if nocolor_arg =~# '^='
        let nocolor_arg = nocolor_arg[1:]
    endif
    let b:logavim__nocolor_list = split(nocolor_arg, ',')
    let b:logavim__scheme_name = getbufvar(bufnum, 'logavim_scheme')
    let b:logavim__orig_bufnr = bufnum
    let b:logavim__replace_pats = exists('g:logavim_replacement_patterns') ?
                \ g:logavim_replacement_patterns : []
    let b:logavim__fold_similars = []
    let scheme_def = lgv#registry#GetByName(b:logavim__scheme_name)
    let b:logavim__fold_groups = get(scheme_def, 'fold_groups', {})
    let b:logavim__fold_regions = get(scheme_def, 'fold_regions', [])

    let tm = reltime()
    let b:logavim__logalize_synclines =
                \ lgv#buf#Populate(b:logavim__orig_bufnr, b:logavim__scheme_name,
                                \ b:logavim__nocolor_list, b:logavim__noargs,
                                \ b:logavim__replace_pats)
    call lgv#fold#ScanFull(1, g:logavim_similarity_threshold,
                    \ g:logavim_repetition_threshold, b:logavim__fold_similars,
                    \ b:logavim__fold_groups, b:logavim__fold_regions)
    echomsg 'LogaVim: It took ' . reltimestr(reltime(tm, reltime())) . ' secs to prepare.'

    call setbufvar(b:logavim__orig_bufnr, '&autoread', 1)
    execute "normal! \<C-w>_"

    command -buffer -nargs=* LGReplace call s:replaceCmd([<f-args>])
    command -buffer -range   LGFoldSimilar call s:foldSimilarCmd(<line1>, <line2>)
    command -buffer -nargs=* LGFoldRegexp call s:foldRegexpCmd([<f-args>])

    vmap <silent> <buffer> / :call LogalizedCountSelected()<CR>
endfunction

function! LogalizedCountSelected() range
    echomsg 'Matched #' .
            \ lgv#fold#CountMatchingBlocks(getline(a:firstline, a:lastline),
            \ g:logavim_similarity_threshold)
    normal! gv
endfunction

function! s:cursorHold() abort
    try
        let linenr = line('.')
        let line = getbufline(b:logavim__orig_bufnr, linenr, linenr)
        let i = matchend(line[0], getbufvar(b:logavim__orig_bufnr, 'logavim_line_pattern'))
        if i > 0
            echo line[0]
        else
            echo ''
        endif
    catch /.*/
        echomsg 'LogaVim ERROR: ' . v:exception
    endtry
endfunction

function! s:bufEnterEvent() abort
    let [upd, length] = lgv#buf#CheckUpdated(b:logavim__logalize_synclines,
                                        \ b:logavim__orig_bufnr)
    if upd == 2
        let b:logavim__logalize_synclines =
                    \ lgv#buf#RefreshFull(b:logavim__orig_bufnr,
                            \ b:logavim__scheme_name, b:logavim__nocolor_list,
                            \ b:logavim__noargs, b:logavim__replace_pats)
        call lgv#fold#ScanFull(1, g:logavim_similarity_threshold,
                    \ g:logavim_repetition_threshold, b:logavim__fold_similars,
                    \ b:logavim__fold_groups, b:logavim__fold_regions)
    elseif upd == 1
        let b:logavim__logalize_synclines =
                    \ lgv#buf#RefreshAppend(b:logavim__orig_bufnr, length,
                            \ b:logavim__scheme_name, b:logavim__nocolor_list,
                            \ b:logavim__noargs, b:logavim__replace_pats)
        call lgv#fold#ScanFull(length, g:logavim_similarity_threshold,
                    \ g:logavim_repetition_threshold, b:logavim__fold_similars,
                    \ b::logavim__fold_groups, b:logavim__fold_regions)
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
                                            \ call s:logalizeCmd([<f-args>])

silent do LogaVim_User User LogaVimLoaded

