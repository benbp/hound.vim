if !exists('g:hound_base_url')
    let g:hound_base_url="http://127.0.0.1"
endif

if !exists('g:hound_port')
    let g:hound_port="6080"
endif

if !exists('g:hound_repos')
    let g:hound_repos="*"
endif

if !exists('g:hound_verbose')
    " defaults to true; 0 is falsy; vimscript has no booleans yay vimscript o_O
    let g:hound_verbose=1
endif

if !exists('g:hound_vertical_split')
    let g:hound_vertical_split=0
endif

function! hound#encodeUrl(string) abort
    let mask = "[ \\]'\!\#\$&(),\*\+\/:;=?@\[]"
    return substitute(a:string, mask, '\=printf("%%%x", char2nr(submatch(0)))', 'g')
endfunction

function! Hound(...) abort

    let a:query_string = join(a:000)
    let sanitized_query_string = hound#encodeUrl(a:query_string)

    let clean_repos = substitute(tolower(g:hound_repos), " ","","g")

    let s:api_full_url = g:hound_base_url
                \. ":" . g:hound_port
                \. '/api/v1/search?'
                \.'&repos=' . clean_repos
                \. '&q=' . sanitized_query_string

    let s:web_full_url = g:hound_base_url . ':' . g:hound_port
                \.'?repos=' . clean_repos
                \. '&q=' . sanitized_query_string

    let s:curl_response=system('curl -s "'.s:api_full_url.'"')

    try
        let s:response = webapi#json#decode(s:curl_response)
    catch
        echoerr "Hound could not connect to " . g:hound_base_url . ":" . g:hound_port
    endtry

    if (has_key(s:response, 'Error'))
        echoerr "Hound server says: " . s:response["Error"]
        return
    end

    let s:output = s:web_full_url

    let repos = []
    for tuple in items(s:response["Results"])
        let repos += [tuple[0]]
    endfor

    for repo in repos
        let s:output .= "\n\nRepo: " . repo . "\n================================================================================\n"
        for mymatch in s:response["Results"][repo]["Matches"]
            for mymatch2 in mymatch["Matches"]
                let s:output.="\n".mymatch["Filename"]
                            \.":".mymatch2["LineNumber"]
                            \."\n--------------------------------------------------------------------------------\n"
                if g:hound_verbose
                    let s:output.=join(mymatch2["Before"], "\n")
                                \. "\n" . mymatch2["Line"] . "\n"
                                \.join(mymatch2["After"], "\n")."\n"
                else
                    let s:output.=substitute(mymatch2["Line"], '^\s*\(.\{-}\)\s*$', '\1', '') . "\n"
                endif
                let s:output.="\n"
            endfor
        endfor
    endfor

    if (s:output == s:web_full_url)
        echo "Nothing for you, Dawg"
    else
        if g:hound_vertical_split
            execute ":vnew ". tempname() . sanitized_query_string
        else
            execute ":edit ". tempname() . sanitized_query_string
        endif

        normal! ggdG
        setlocal filetype=houndresults | setlocal nowrap | setlocal buftype=nofile
        call append(0, split(s:output, '\n'))
        normal! gg
        execute ":w "

        exec 'syntax match queryString "'.a:query_string.'"'
        highlight link queryString DiffAdd

        syntax match FilePath "^.*\(\n-----\)\@="
        highlight link FilePath Special

    endif
endfunction

command! -nargs=1 Hound call Hound(<f-args>)
