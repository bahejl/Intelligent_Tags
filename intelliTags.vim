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

if exists('g:Itags_loaded')
    finish
endif
let g:Itags_loaded = 1

function s:handleFileTags(name, depth)
    call s:WideMsg("echo ", "Generating tags file for:\t" . a:name)

    " if isdirectory(a:name)
        " let dirName = fnamemodify(a:name, ":p:h:h")
        " let fName = fnamemodify(fnamemodify(a:name, ":p:h"), ":t")
    " else
        let dirName = fnamemodify(a:name, ":h")
        let fName = fnamemodify(a:name, ":t")
    " endif
    execute "let tName = " . g:Itags_dir_name . ".'.tags'"
    execute "let iName = " . g:Itags_dir_name . ".'.incl'"
    " let tName = expand(tName)
    " let iName = expand(iName)
    " let tName = dirName . fName . ".tags"
    " let iName = dirName . fName . ".incl"

    if !isdirectory(fnamemodify(tName, ":h"))
        call mkdir(fnamemodify(tName, ":h"))
    endif

    if getftime(a:name) > getftime(iName) || s:forceIncl
        call s:createInclFile(a:name, iName)
    endif

    if getftime(a:name) > getftime(tName) || s:forceTags
        silent! call system(s:cmdString . tName . '" "' . a:name . '"')
    endif
    " Why the triple escape? See :h option-backslash
    " execute 'setl tags+=' . fnameescape(fnameescape(fnameescape(findfile(tName))))
    let b:tags .= fnameescape(fnameescape(fnameescape(findfile(tName)))) . ','

    if a:depth - g:Itags_Depth == 0
        return
    endif

    let fIncList = []
    let fExt = fnamemodify(a:name, ":e")
    " let fExt = matchstr(a:name, '\.[^.\/]\+$')
    if has_key(g:Itags_header_mapping, fExt)
        let rootName = fnamemodify(a:name, ':r')
        for ext in g:Itags_header_mapping[fExt]
            " let hDefName = findfile(substitute(a:name, '\.[^.\/]\+$', ext, ""))
            let hDefName = findfile(rootName .'.'. ext) 
            if len(hDefName)
                call add(fIncList, [hDefName, g:Itags_Depth])
            endif
        endfor
    endif
    for fileName in readfile(iName)
        if len(fileName)
            call add(fIncList, [fileName, a:depth+1])
        endif
    endfor
    for [inc, depth] in fIncList
        if !has_key(b:processedFiles, inc)
            let b:processedFiles[inc] = 1
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
    let mFileName = findfile(a:name)
    if !len(mFileName)
        let mFileName = finddir(a:name)
    endif
    if len(mFileName)
        let mFileName = fnamemodify(mFileName, ":p")
        call add(fIncList, mFileName)
        " let fIncList += [mFileName]
    endif
    " Decided to move this functionality to handleFileTags:
        " + can specify a depth for the newly included files
        " - have to evaluate every run, instead of just when generating the
        "   includes
    " let fExt = matchstr(a:name, '\.[^.\/]$')
    " if has_key(g:Itags_header_mapping, fExt)
        " for ext in g:Itags_header_mapping[fExt]
            " let fIncList += s:findIncl(substitute(a:name, fExt, ext, ""))
        " endfor
    " endif
    return fIncList
endfunction

function s:createInclFile(name, dest)
    let fIncList = []
    let fIncDict = {}
    let fIncList += s:createInclList(a:name)

    " Remove duplicates, and sort
    for item in fIncList
        let fIncDict[item] = 1
    endfor
    let fIncList = sort(keys(fIncDict))

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
    setl 

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
    let s:cmdString = g:Itags_Ctags_Cmd . ' '. g:Itags_Ctags_Flags . ' --fields=+K --tag-relative=yes -f "'
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
    let supportList = split(system('ctags --list-languages'), '\n')
    for type in supportList
        let type = tolower(type)
        if has_key(typeMapping, type)
            let supportList += typeMapping[type]
        endif
    endfor

    command! -nargs=0 -bar ItagsRun call s:iTagMain(expand("%:p"))
    augroup iTagsAU
        au!
        for ft in supportList
            execute "autocmd FileType " . tolower(ft) . ' ItagsRun'
        endfor
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
    while strdisplaywidth(message) > (WINWIDTH-5)
        let message = message[:-2]
    endwhile
    let message = '''' . message . ''''

    let x=&ruler | let y=&showcmd
    set noruler noshowcmd
    redraw
    execute a:cmd . message
    let &ruler=x | let &showcmd=y
endfunction

call s:Init()
