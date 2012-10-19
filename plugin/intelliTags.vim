" integration with tagList?
    " * I don't think it should integrate perse, but instead I could modify
        " tagList to simply use all of the tag files found in the tags option
" Use the sandbox for inex?
" if a:depth == 0, have a setting for local tags generation?
    " Have a default that enables the --<LANGTYPE>-kinds=+l flag

" NEED TO FIND A WAY TO SPEED UP WHEN ALL FILES HAVE ALREADY BEEN CREATED!!!!
    " 1: SLOW WHEN OPENING THE FILE
    " 2: SLOW WHEN SEARCHING FOR A TAG
    " for example: open BioSigRZ/mainfrm.cpp and behold the delay!
" +1: In iTagMain, test to see if a 'master include' file is older than the buffer
    " file before deciding to run.  This file will contain ALL includes for
    " the current file, not just the immediate ones.  After a successful run,
    " create this file
    " - what about checking for changes in the include files?
        " + run handleFileTags with depth = g:Itags_Depth for each include
    " - what would this save me?
" +2: Create a 'master tags' file instead of all the little tags files?
    " + This could take the place of the 'local' tags file...
    " + Is it easy to just combine a bunch of existing tags files?
    " - what to do in the case where:
        " * file is opened, and an included file has been updated since the
            " last tag generation, so intelliTags runs and updates that include
            " file along with the 'master tags' file for the opened buffer
        " * later, another file that includes that same included file is
            " opened.  The include file will no longer appear to be out of
            " date, so the 'master tags' file for the current buffer won't be
            " updated.  However, it will still include the old, outdated
            " information!
        " * Does this mean I would have to compare the modified date of the
            " 'master tags' file to each of the individual tags files?  That
            " would only add to problem #1!
" Currently, were searching on header files in every handleFileTags pass
    " instead of storing the information in the incl file.  The reason for
    " this?  The handleFileTags depth for these files should be equal to whatever
    " Itags_Depth is set to, while the 'normal' include files' depth should be
    " calculated based on how 'deep' it is in the call stack.  I can't think
    " of a good way of storing this information in the incl files...
        " * I could just do file_name\tfile_Itags_Depth, where I can just
        " evaluate file_Itags_Depth.  That way it can be either a number, or
        " g:Itags_Depth itself.
            " depth would then be: g:Itags_Depth-


" find a way to do all of this in the background
    " it's more in the background right now, the user just can't do anything
    " until it's finished
" find a way to not generate tags for temp files?

" I would like to list all includes in the .incl file, even those that can't
" be found on the path.  That would mean needing to check files during
" handleFileTags in case we don't have the full path in the .incl file.
    " * maybe start a new version of .incl files:
        " If file is found, store the full path in the file
        " If file is not found, store the include name, and follow that with
        " some kind of identifier (eg, "file_name\tNF").
        " If a previously not found file is found, we'll need to set some flag
        " to overwrite the existing .incl file with the found path(s)
        " * I'm thinking I should somehow use "[^\f]" to delimit the file...
    " * another option is to only store the raw includes themselves, and only
        " search for the file in handleFileTags itself:
        " - slower (have to search every time)
        " + all includes are always listed, and they are all consistent
        " + if the filesystem changes somehow, such that an include changes
        "   directory but is still on the path, this will catch that.

    " * Or, do both?  As in:
        " include_string    file_found(if any)
        " * On every run, if handleFileTags gets -1 on the getftime, it will
        " return with some kind of error code.  In that case, try to find the
        " file and run again.  If the file is found, update the .incl file.
        " *
    " .incl File format:
    " include_string	file_found	depth	type(local, header, normal?)
if exists('g:Itags_loaded')
    finish
endif
let g:Itags_loaded = 1

function s:handleFileTags(name, depth)
    call s:WideMsg("echo ", "Generating tags file for:\t" . a:name)
    let b:processedFiles[a:name] = 1

    " if isdirectory(a:name)
        " let dirName = fnamemodify(a:name, ":p:h:h")
        " let fName = fnamemodify(fnamemodify(a:name, ":p:h"), ":t")
    " else
        let dirName = fnamemodify(a:name, ":h")
        let fName = fnamemodify(a:name, ":t")
    " endif
    execute "let tName = " . g:Itags_dir_name . ".'.tags'"
    execute "let iName = " . g:Itags_dir_name . ".'.incl'"

    if !isdirectory(fnamemodify(tName, ":h"))
        call mkdir(fnamemodify(tName, ":h"))
    endif

    let file_mod_time = getftime(a:name)
    if file_mod_time > getftime(iName) || s:forceIncl
        call s:createInclFile(a:name, iName)
    endif

    if file_mod_time > getftime(tName) || s:forceTags
        silent! call system('"' . s:cmdString . tName . '" "' . a:name . '""')
    endif
    " Why the triple escape? See :h option-backslash
    " execute 'setl tags+=' . fnameescape(fnameescape(fnameescape(findfile(tName))))
    let b:tags .= fnameescape(fnameescape(fnameescape(findfile(tName)))) . ','

    if a:depth - g:Itags_Depth == 0
        return
    endif

    let fIncList = []
    while 1
        try
            let file_mod = 0
            if filereadable(iName)
                let lines = readfile(iName)
            else
                let lines = []
            endif

            for line_num in range(len(lines))
                let line = split(lines[line_num], "\t")
                " Catch empty lines
                if len(line) == 0
                    continue
                endif
                if !len(line[1])
                    execute "cd! " . fnamemodify(a:name, ":p:h")
                    let incl_path = findfile(line[0])
                    cd! -
                    if !len(incl_path)
                        continue
                    endif
                    let line[1] = incl_path
                    let lines[line_num] = join(line, "\t")
                    let file_mod = 1
                endif
                execute "call add(fIncList, [line[1], " . line[2] . "])"
            endfor
            break
        catch /E684/
            " Catch list index out of range error (previous version)
            call s:createInclFile(a:name, iName)
        endtry
    endwhile
    if file_mod == 1
        call writefile(lines, iName)
    endif

    " for fileName in readfile(iName)
        " if len(fileName)
            " call add(fIncList, [fileName, a:depth+1])
        " endif
    " endfor
    for [inc, depth] in fIncList
        if !has_key(b:processedFiles, inc)
            call s:handleFileTags(inc, depth)
        endif
    endfor
endfunction

function s:createInclList(name)
    let fIncList = []
    let fIncTemp = []
    let matchIndex = 0
    let mName = ""
    if isdirectory(a:name)
        for child in split(glob(a:name."*.*"), "\n")
            let fIncList += s:createInclList(child)
        endfor
    else
        execute "cd! " . fnamemodify(a:name, ":p:h")
        for line in readfile(findfile(a:name))
           if line =~ &include
               if &include =~ '\\zs'
                   let mName = matchstr(line, &include)
               else
                   let matchIndex = matchend(line, &include)
                   let mName = matchstr(line, '\f\+', matchIndex)
               endif
               if len(&inex)
                   silent! execute 'let mName = ' . &inex
               endif
               let fIncTemp = s:findIncl(mName)
               if !len(fIncTemp)
                   call s:WideMsg('echomsg ', 'Unable to find include file: ' . mName . ' referrenced to in ' . a:name)
               else
                   let fIncList += fIncTemp
               endif
           endif
        endfor
        cd! -
    endif
    return fIncList
endfunction

function s:findIncl(name)
    let fIncList = []
    let incl_line = [a:name]
    let mFileName = findfile(a:name)

    if !len(mFileName)
        let mFileName = finddir(a:name)
    endif
    if len(mFileName)
        call add(incl_line, fnamemodify(mFileName, ":p"))
    else
        call add(incl_line, "")
    endif
    " Set depth
    call add(incl_line, 'a:depth+1')
    call add(incl_line, '.tags')
    call add(fIncList, join(incl_line, "\t"))

    let fExt = fnamemodify(a:name, ":e")
    if has_key(g:Itags_header_mapping, fExt)
        let rootName = fnamemodify(a:name, ':t:r')
        for ext in g:Itags_header_mapping[fExt]
            let hDefName = findfile(rootName .'.'. ext)
            if len(hDefName)
                let hDefName = fnamemodify(hDefName, ":p")
                let incl_line = [a:name, hDefName, 'g:Itags_Depth', '.tags']
                call add(fIncList, join(incl_line, "\t"))
            endif
        endfor
    endif
    return fIncList
endfunction

function s:createInclFile(name, dest)
    let fIncDict = {}
    let fIncList = s:createInclList(a:name)

    " Remove duplicates
    " On second thought, it might be better to leave this information...
    " for item in fIncList
        " endif
    " endfor
    " let fIncList = sort(keys(fIncDict))

    call writefile(fIncList, a:dest)
endfunction

function s:iTagMain(name)
    " Only run on normal buffers
    if &l:buftype != ''
        return
    endif

    setl notagrelative
    let b:processedFiles = {}
    if len(&inex)
        "inex changes the read-only variable v:fname, so we can't
            "use it unless we change the variable
        let b:origInex = &inex
        let &l:inex=substitute(&inex, 'v:fname', 'mName', 'g')
    endif
    let b:tags = ""
    let sm = &l:shm


    call s:handleFileTags(a:name, 0)

    if exists("b:origInex")
        let &l:inex=b:origInex
        unlet b:origInex
    endif
    unlet b:processedFiles
    execute 'setl tags+='.b:tags
    redraw!
endfunction

function s:Init()
    if !exists("g:Itags_Depth")
        let g:Itags_Depth = 1
    endif
    " Location of the exuberant ctags tool
    if !exists('g:Itags_Ctags_Cmd')
        if executable('exuberant-ctags')
            " On Debian Linux, exuberant ctags is installed
            " as exuberant-ctags
            let g:Itags_Ctags_Cmd = 'exuberant-ctags'
        elseif executable('exctags')
            " On Free-BSD, exuberant ctags is installed as exctags
            let g:Itags_Ctags_Cmd = 'exctags'
        elseif executable('ctags')
            let g:Itags_Ctags_Cmd = 'ctags'
        elseif executable('ctags.exe')
            let g:Itags_Ctags_Cmd = 'ctags.exe'
        elseif executable('tags')
            let g:Itags_Ctags_Cmd = 'tags'
        else
            echomsg 'intelliTags: Exuberant ctags (http://ctags.sf.net) ' .
                        \ 'not found in PATH. Plugin is not loaded.'
            " Skip loading the plugin
            finish
        endif
    endif
    if !exists("g:Itags_Ctags_Flags")
        let g:Itags_Ctags_Flags = "-n --extra=+q -R"
    endif
    let s:cmdString = g:Itags_Ctags_Cmd . ' '. g:Itags_Ctags_Flags . ' --fields=+k --tag-relative=yes -f "'
    if !exists("g:Itags_header_mapping")
        let g:Itags_header_mapping = {}
    endif
    if !exists("g:Itags_dir_name")
        " let g:Itags_dir_name = 'expand(''~/.tags/'' . fnameescape(substitute(dirName.''/''.fName, ''[/\\:\.]\+'', ''\.'', ''g'')))'
        let g:Itags_dir_name = 'expand(''~/.tags/'') . fnamemodify(dirName.''/''.fName, '':gs?[/\\:\.]\+?\.?'')'
        " let g:Itags_dir_name = "dirName . '/.tags/' . fName"
    endif

    " This seemed the best way to determine if it makes sense to
    "  try and run on the given buffer
    " ctags lists c++, but vim calls it cpp, etc...
    let typeMapping = {'c++': ['cpp'], 'c#': ['cs'], 'tcl': ['expect'], 'sh': ['csh', 'zsh'], }
    " let RevTypeMapping = {'cpp': 'c++', 'cs': 'c#', 'expect': 'tcl', 'csh': 'sh', 'zsh': 'sh', }
    let supportList = split(system(g:Itags_Ctags_Cmd.' --list-languages'), '\n')
    for type in supportList
        let type = tolower(type)
        if has_key(typeMapping, type)
            let supportList += typeMapping[type]
        endif
    endfor

    command! -nargs=0 -bar ItagsRun call s:iTagMain(expand("%:p"))
    command! -nargs=0 -bar ItagsRunLocal let b:Itags_Depth_local = g:Itags_Depth | let g:Itags_Depth=0 | ItagsRun | let g:Itags_Depth=b:Itags_Depth_local

    augroup iTagsAU
        au!
        execute "autocmd FileType " . join(supportList, ',') . ' ItagsRun'
        execute "autocmd FileType " . join(supportList, ',') . ' au BufWritePost <buffer> ItagsRunLocal'
    augroup END

    let s:forceTags = 0
    command! -nargs=0 -bar ItagsRegenTags let s:forceTags = 1 | ItagsRun | let s:forceTags=0

    let s:forceIncl = 0
    command! -nargs=0 -bar ItagsRegenIncl let s:forceIncl = 1 | ItagsRun | let s:forceIncl=0

    command! -nargs=0 -bar ItagsRegenAll let s:forceTags = 1 | let s:forceIncl = 1 | ItagsRun | let s:forceIncl=0 | let s:forceTags = 0

endfunction

function! s:WideMsg(cmd, msg)
    " Why not just echo!? Stupid 'Press enter to continue' prompt
    " See http://vim.wikia.com/wiki/How_to_print_full_screen_width_messages
    " let WINWIDTH = winwidth(0)
    let WINWIDTH = &l:columns
    let message = a:msg
    let message = message[:WINWIDTH-5]
    if version >= 730
        while strdisplaywidth(message) > (WINWIDTH-5)
            let message = message[:-2]
        endwhile
    endif

    let message = '''' . message . ''''

    let x=&ruler | let y=&showcmd
    set noruler noshowcmd
    redraw
    execute a:cmd . message
    let &ruler=x | let &showcmd=y
endfunction

call s:Init()
