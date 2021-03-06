if exists('g:loaded_lgv_registry_autoload')
    finish
endif
let g:loaded_lgv_registry_autoload = 1

let s:lgv_registry = {}

function! lgv#registry#Add(name, def) abort
    if has_key(s:lgv_registry, a:name)
        echoerr 'LogaVim: Registry: ' . a:name . ' is already registered!'
        return
    endif
    if !len(a:name)
        echoerr 'LogaVim: Registry: No empty name!'
        return
    endif
    let s:lgv_registry[a:name] = a:def
endfunction

function! lgv#registry#GetByName(name) abort
    return s:lgv_registry[a:name]
endfunction

function! lgv#registry#Exists(name) abort
    return has_key(s:lgv_registry, a:name)
endfunction

function! lgv#registry#GetAllNames() abort
    return keys(s:lgv_registry)
endfunction
