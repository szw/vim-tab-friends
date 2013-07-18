" Vim TabFriends - Make buffers and tabs friendship ;)
" Maintainer:   Szymon Wrozynski
" Version:      3.0.1
"
" Installation:
" Place in ~/.vim/plugin/tab_friends.vim or in case of Pathogen:
"
"     cd ~/.vim/bundle
"     git clone https://github.com/szw/vim-tab-friends.git
"
" License:
" Copyright (c) 2013 Szymon Wrozynski <szymon@wrozynski.com>
" Distributed under the same terms as Vim itself.
" Original BufferList plugin code - copyright (c) 2005 Robert Lillack <rob@lillack.de>
" Redistribution in any form with or without modification permitted.
" Licensed under MIT License conditions.
"
" Usage:
" https://github.com/szw/vim-tab-friends/blob/master/README.md

if exists('g:tab_friends_loaded')
  finish
endif
let g:tab_friends_loaded = 1

if !exists('g:tab_friends_height')
  let g:tab_friends_height = 1
endif

if !exists('g:tab_friends_max_height')
  let g:tab_friends_max_height = 25
endif

if !exists('g:tab_friends_show_unnamed')
  let g:tab_friends_show_unnamed = 2
endif

if !exists('g:tab_friends_set_default_mapping')
    let g:tab_friends_set_default_mapping = 1
endif

if !exists('g:tab_friends_default_mapping_key')
    let g:tab_friends_default_mapping_key = '<F2>'
endif

if !exists('g:tab_friends_cyclic_list')
  let g:tab_friends_cyclic_list = 1
endif

if !exists('g:tab_friends_max_jumps')
  let g:tab_friends_max_jumps = 100
endif

" 0 - no sort
" 1 - chronological
" 2 - alphanumeric
if !exists('g:tab_friends_default_sort_order')
  let g:tab_friends_default_sort_order = 1
endif

command! -nargs=0 -range TabFriends :call <SID>tab_friends_toggle(0)

if g:tab_friends_set_default_mapping
  silent! exe 'nnoremap <silent>' . g:tab_friends_default_mapping_key . ' :TabFriends<CR>'
  silent! exe 'vnoremap <silent>' . g:tab_friends_default_mapping_key . ' :TabFriends<CR>'
  silent! exe 'inoremap <silent>' . g:tab_friends_default_mapping_key . ' <C-[>:TabFriends<CR>'
endif

au BufEnter * call <SID>add_tab_friend()

let s:tab_friends_jumps = []
au BufEnter * call <SID>add_jump()

" toggled the buffer list on/off
function! <SID>tab_friends_toggle(internal)
  if !a:internal
    let s:tab_toggle = 1
    let s:nopmode = 0
    let s:search_letters = []
    let s:searchmode = 0
    if !exists("t:sort_order")
      let t:sort_order = g:tab_friends_default_sort_order
    endif
  endif

  " if we get called and the list is open --> close it
  let buflistnr = bufnr("__TAB_FRIENDS__")
  if bufexists(buflistnr)
    if bufwinnr(buflistnr) != -1
      call <SID>kill(buflistnr, 1)
      return
    else
      call <SID>kill(buflistnr, 0)
      if !a:internal
        let t:tab_friends_start_window = winnr()
        let t:tab_friends_winrestcmd = winrestcmd()
      endif
    endif
  elseif !a:internal
    let t:tab_friends_start_window = winnr()
    let t:tab_friends_winrestcmd = winrestcmd()
  endif

  let bufcount = bufnr('$')
  let displayedbufs = 0
  let activebuf = bufnr('')
  let buflist = []

  " create the buffer first & set it up
  exec 'silent! new __TAB_FRIENDS__'
  silent! exe "wincmd J"
  silent! exe "resize" g:tab_friends_height
  call <SID>set_up_buffer()

  let width = winwidth(0)

  " iterate through the buffers

  for i in range(1, bufcount)
    if s:tab_toggle && !exists('t:tab_friends_list[' . i . ']')
      continue
    endif

    let bufname = bufname(i)

    if g:tab_friends_show_unnamed && !strlen(bufname)
      if !((g:tab_friends_show_unnamed == 2) && !getbufvar(i, '&modified')) || (bufwinnr(i) != -1)
        let bufname = '[' . i . '*No Name]'
      endif
    endif

    if strlen(bufname) && getbufvar(i, '&modifiable') && getbufvar(i, '&buflisted')
      " adapt width and/or buffer name
      if strlen(bufname) + 6 > width
        let bufname = '…' . strpart(bufname, strlen(bufname) - width + 7)
      endif

      if !empty(s:search_letters) && !(bufname =~? "\\m" . join(s:search_letters, ".\\{-}"))
        continue
      endif

      let bufname = <SID>decorate_with_indicators(bufname, i)

      " count displayed buffers
      let displayedbufs += 1
      " fill the name with spaces --> gives a nice selection bar
      " use MAX width here, because the width may change inside of this 'for' loop
      while strlen(bufname) < width
        let bufname .= ' '
      endwhile
      " add the name to the list
      call add(buflist, { "text": '  ' . bufname . "\n", "number": i })
    endif
  endfor

  " set up window height
  if displayedbufs > g:tab_friends_height
    if displayedbufs < g:tab_friends_max_height
      silent! exe "resize " . displayedbufs
    else
      silent! exe "resize " . g:tab_friends_max_height
    endif
  endif

  call <SID>display_list(displayedbufs, buflist, width)

  let activebufline = <SID>find_activebufline(activebuf, buflist)

  " make the buffer count & the buffer numbers available
  " for our other functions
  let b:buflist = buflist
  let b:bufcount = displayedbufs
  let b:jumplines = <SID>create_jumplines(buflist, activebufline)

  " go to the correct line
  call <SID>move(activebufline)
  normal! zb
endfunction

function! <SID>create_jumplines(buflist, activebufline)
  let buffers = []
  for bufentry in a:buflist
    call add(buffers, bufentry.number)
  endfor

  if s:tab_toggle && exists("t:tab_friends_jumps")
    let bufferjumps = t:tab_friends_jumps
  else
    let bufferjumps = s:tab_friends_jumps
  endif

  let jumplines = []

  for jumpbuf in bufferjumps
    if bufwinnr(jumpbuf) == -1
      let jumpline = index(buffers, jumpbuf)
      if (jumpline >= 0)
        call add(jumplines, jumpline + 1)
      endif
    endif
  endfor

  call add(jumplines, a:activebufline)

  return reverse(<SID>unique_list(jumplines))
endfunction

function! <SID>clear_searchmode()
  let s:search_letters = []
  let s:searchmode = 0
  call <SID>kill(0, 0)
  call <SID>tab_friends_toggle(1)
endfunction

function! <SID>add_search_letter(letter)
  call add(s:search_letters, a:letter)
  call <SID>kill(0, 0)
  call <SID>tab_friends_toggle(1)
endfunction

function! <SID>remove_search_letter()
  call remove(s:search_letters, -1)
  call <SID>kill(0, 0)
  call <SID>tab_friends_toggle(1)
endfunction

function! <SID>switch_searchmode(switch)
  let s:searchmode = a:switch
  call <SID>kill(0, 0)
  call <SID>tab_friends_toggle(1)
endfunction

function! <SID>unique_list(list)
  return filter(copy(a:list), 'index(a:list, v:val, v:key + 1) == -1')
endfunction

function! <SID>decorate_with_indicators(name, bufnum)
  let indicators = ' '

  if bufwinnr(a:bufnum) != -1
    let indicators .= '∗'
  endif
  if getbufvar(a:bufnum, '&modified')
    let indicators .= '+'
  endif

  if len(indicators) > 1
    return a:name . indicators
  else
    return a:name
  endif
endfunction

function! <SID>find_activebufline(activebuf, buflist)
  let activebufline = 0
  for bufentry in a:buflist
    let activebufline += 1
    if a:activebuf == bufentry.number
      return activebufline
    endif
  endfor
  return activebufline
endfunction

function! <SID>kill(buflistnr, final)
  if a:buflistnr
    silent! exe ':' . a:buflistnr . 'bwipeout'
  else
    bwipeout
  end

  if a:final
    if exists("t:tab_friends_start_window")
      silent! exe t:tab_friends_start_window . "wincmd w"
    endif

    if exists("t:tab_friends_winrestcmd") && (winrestcmd() != t:tab_friends_winrestcmd)
      silent! exe t:tab_friends_winrestcmd

      if winrestcmd() != t:tab_friends_winrestcmd
        wincmd =
      endif
    endif
  endif
endfunction

function! <SID>keypressed(key)
  if s:nopmode
    if (a:key ==# "a") && !s:searchmode
      call <SID>toggle_tab()
    end

    if a:key ==# "BS"
      if s:searchmode
        if empty(s:search_letters)
          call <SID>clear_searchmode()
        else
          call <SID>remove_search_letter()
        endif
      elseif !empty(s:search_letters)
        call <SID>clear_searchmode()
      endif
    endif
    return
  endif

  if s:searchmode
    if a:key ==# "BS"
      if empty(s:search_letters)
        call <SID>clear_searchmode()
      else
        call <SID>remove_search_letter()
      endif
    elseif (a:key ==# "/") || (a:key ==# "CR")
      call <SID>switch_searchmode(0)
    elseif strlen(a:key) == 1
      call <SID>add_search_letter(a:key)
    endif
  else
    if a:key ==# "CR"
      call <SID>load_buffer()
    elseif a:key ==# "BS"
      call <SID>clear_searchmode()
    elseif a:key ==# "/"
      call <SID>switch_searchmode(1)
    elseif a:key ==# "v"
      call <SID>load_buffer("vs")
    elseif a:key ==# "s"
      call <SID>load_buffer("sp")
    elseif a:key ==# "t"
      call <SID>load_buffer("tabnew")
    elseif a:key ==# "o"
      call <SID>toggle_order()
    elseif a:key ==# "q"
      call <SID>kill(0, 1)
    elseif a:key ==# "j"
      call <SID>move("down")
    elseif a:key ==# "k"
      call <SID>move("up")
    elseif a:key ==# "p"
      call <SID>jump("previous")
    elseif a:key ==# "P"
      call <SID>jump("previous")
      call <SID>load_buffer()
    elseif a:key ==# "n"
      call <SID>jump("next")
    elseif a:key ==# "d"
      call <SID>delete_buffer()
    elseif a:key ==# "D"
      call <SID>delete_hidden_buffers()
    elseif a:key ==# "MouseDown"
      call <SID>move("up")
    elseif a:key ==# "MouseUp"
      call <SID>move("down")
    elseif a:key ==# "LeftRelease"
      call <SID>move("mouse")
    elseif a:key ==# "2-LeftMouse"
      call <SID>move("mouse")
      call <SID>load_buffer()
    elseif a:key ==# "Down"
      call feedkeys("j")
    elseif a:key ==# "Up"
      call feedkeys("k")
    elseif a:key ==# "Home"
      call <SID>move(1)
    elseif a:key ==# "End"
      call <SID>move(line("$"))
    elseif a:key ==# "a"
      call <SID>toggle_tab()
    elseif a:key ==# "f"
      call <SID>detach_tab_friend()
    elseif a:key ==# "F"
      call <SID>delete_foreign_buffers()
    endif
  endif
endfunction

function! <SID>set_up_buffer()
  setlocal noshowcmd
  setlocal noswapfile
  setlocal buftype=nofile
  setlocal bufhidden=delete
  setlocal nobuflisted
  setlocal nomodifiable
  setlocal nowrap
  setlocal nonumber

  if has('statusline')
    setl stl="hello "
    let &l:statusline = "TAB♡FRIENDS"
    if s:tab_toggle
      let &l:statusline .= " │ ∙"
    else
      let &l:statusline .= " │ ∷"
    endif

    if exists("t:sort_order")
      if t:sort_order == 1
        let &l:statusline .= " │ ₁²₃"
      elseif t:sort_order == 2
        let &l:statusline .= " │ авс"
      endif
    endif

    if s:searchmode || !empty(s:search_letters)
      let &l:statusline .= " │ →[" . join(s:search_letters, "")

      if s:searchmode
        let &l:statusline .= "_"
      endif

      let &l:statusline .= "]←"
    endif
  endif

  if &timeout
    let b:old_timeoutlen = &timeoutlen
    set timeoutlen=10
    au BufEnter <buffer> set timeoutlen=10
    au BufLeave <buffer> silent! exe "set timeoutlen=" . b:old_timeoutlen
  endif

  augroup TabFriendsLeave
    au!
    au BufLeave <buffer> call <SID>kill(0, 1)
  augroup END

  " set up syntax highlighting
  if has("syntax")
    syn clear
    syn match BufferNormal /  .*/
    syn match BufferSelected /> .*/hs=s+1
    hi def BufferNormal ctermfg=black ctermbg=white
    hi def BufferSelected ctermfg=white ctermbg=black
  endif

  " set up the keymap
  let lowercase_letters = "q w e r t y u i o p a s d f g h j k l z x c v b n m"
  let uppercase_letters = toupper(lowercase_letters)
  let numbers = "1 2 3 4 5 6 7 8 9 0"
  let special_chars = "CR BS / MouseDown MouseUp LeftDrag LeftRelease 2-LeftMouse Down Up Home End Left Right"
  let key_chars = split(lowercase_letters . " " . uppercase_letters . " " . numbers . " " . special_chars, " ")
  for key_char in key_chars
    if strlen(key_char) > 1
      let key = "<" . key_char . ">"
    else
      let key = key_char
    endif
    silent! exe "noremap <silent><buffer> " . key . " :call <SID>keypressed(\"" . key_char . "\")<CR>"
  endfor
endfunction

function! <SID>make_filler(width)
  " generate a variable to fill the buffer afterwards
  " (we need this for "full window" color :)
  let fill = "\n"
  let i = 0 | while i < a:width | let i += 1
    let fill = ' ' . fill
  endwhile

  return fill
endfunction

function! <SID>compare_bufentries(a, b)
  if t:sort_order == 1
    if s:tab_toggle
      if exists("t:tab_friends_list[" . a:a.number . "]") && exists("t:tab_friends_list[" . a:b.number . "]")
        return t:tab_friends_list[a:a.number] - t:tab_friends_list[a:b.number]
      endif
    endif
    return a:a.number - a:b.number
  elseif t:sort_order == 2
    if (a:a.text < a:b.text)
      return -1
    elseif (a:a.text > a:b.text)
      return 1
    else
      return 0
    endif
  endif
endfunction

function! <SID>SID()
  let fullname = expand("<sfile>")
  return matchstr(fullname, '<SNR>\d\+_')
endfunction

function! <SID>display_list(displayedbufs, buflist, width)
  setlocal modifiable
  if a:displayedbufs > 0
    if exists("t:sort_order")
      call sort(a:buflist, function(<SID>SID() . "compare_bufentries"))
    endif
    " input the buffer list, delete the trailing newline, & fill with blank lines
    let buftext = ""

    for bufentry in a:buflist
      let buftext .= bufentry.text
    endfor

    silent! put! =buftext
    " is there any way to NOT delete into a register? bummer...
    "normal! Gdd$
    normal! GkJ
    let fill = <SID>make_filler(a:width)
    while winheight(0) > line(".")
      silent! put =fill
    endwhile

    let s:nopmode = 0
  else
    let empty_list_message = "  List empty"
    let width = a:width

    if width < (strlen(empty_list_message) + 2)
      if strlen(empty_list_message) + 2 < g:tab_friends_max_width
        let width = strlen(empty_list_message) + 2
      else
        let width = g:tab_friends_max_width
        let empty_list_message = strpart(empty_list_message, 0, width - 3) . "…"
      endif
      silent! exe "vert resize " . width
    endif

    while strlen(empty_list_message) < width
      let empty_list_message .= ' '
    endwhile

    silent! put! =empty_list_message
    normal! GkJ

    let fill = <SID>make_filler(width)

    while winheight(0) > line(".")
      silent! put =fill
    endwhile

    normal! 0

    " handle vim segfault on calling bd/bw if there are no buffers listed
    let any_buffer_listed = 0
    for i in range(1, bufnr("$"))
      if buflisted(i)
        let any_buffer_listed = 1
        break
      endif
    endfor

    if !any_buffer_listed
      au! TabFriendsLeave BufLeave
      noremap <silent> <buffer> q :q<CR>
      noremap <silent> <buffer> a <Nop>
      if g:tab_friends_set_default_mapping
        silent! exe 'noremap <silent><buffer>' . g:tab_friends_default_mapping_key . ' :q<CR>'
      endif
    endif

    let s:nopmode = 1
  endif
  setlocal nomodifiable
endfunction

" move the selection bar of the list:
" where can be "up"/"down"/"mouse" or
" a line number
function! <SID>move(where)
  if b:bufcount < 1
    return
  endif
  let newpos = 0
  if !exists('b:lastline')
    let b:lastline = 0
  endif
  setlocal modifiable

  " the mouse was pressed: remember which line
  " and go back to the original location for now
  if a:where == "mouse"
    let newpos = line(".")
    call <SID>goto(b:lastline)
  endif

  " exchange the first char (>) with a space
  call setline(line("."), " ".strpart(getline(line(".")), 1))

  " go where the user want's us to go
  if a:where == "up"
    call <SID>goto(line(".")-1)
  elseif a:where == "down"
    call <SID>goto(line(".")+1)
  elseif a:where == "mouse"
    call <SID>goto(newpos)
  else
    call <SID>goto(a:where)
  endif

  " and mark this line with a >
  call setline(line("."), ">".strpart(getline(line(".")), 1))

  " remember this line, in case the mouse is clicked
  " (which automatically moves the cursor there)
  let b:lastline = line(".")

  setlocal nomodifiable
endfunction

" tries to set the cursor to a line of the buffer list
function! <SID>goto(line)
  if b:bufcount < 1 | return | endif
  if a:line < 1
    if g:tab_friends_cyclic_list
      call <SID>goto(b:bufcount - a:line)
    else
      call cursor(1, 1)
    endif
  elseif a:line > b:bufcount
    if g:tab_friends_cyclic_list
      call <SID>goto(a:line - b:bufcount)
    else
      call cursor(b:bufcount, 1)
    endif
  else
    call cursor(a:line, 1)
  endif
endfunction

function! <SID>jump(direction)
  if !exists("b:jumppos")
    let b:jumppos = 0
  endif

  if a:direction == "previous"
    let b:jumppos += 1

    if b:jumppos == len(b:jumplines)
      let b:jumppos = len(b:jumplines) - 1
    endif
  elseif a:direction == "next"
    let b:jumppos -= 1

    if b:jumppos < 0
      let b:jumppos = 0
    endif
  endif

  call <SID>move(string(b:jumplines[b:jumppos]))
endfunction

" loads the selected buffer
function! <SID>load_buffer(...)
  " get the selected buffer
  let nr = <SID>get_selected_buffer()
  " kill the buffer list
  call <SID>kill(0, 1)

  if !empty(a:000)
    exec ":" . a:1
  endif

  " ...and switch to the buffer number
  exec ":b " . nr
endfunction

function! <SID>load_buffer_into_window(winnr)
  if exists("t:tab_friends_start_window")
    let old_start_window = t:tab_friends_start_window
    let t:tab_friends_start_window = a:winnr
  endif
  call <SID>load_buffer()
  if exists("old_start_window")
    let t:tab_friends_start_window = old_start_window
  endif
endfunction

" deletes the selected buffer
function! <SID>delete_buffer()
  let nr = <SID>get_selected_buffer()
  if !getbufvar(str2nr(nr), '&modified')
    let selected_buffer_window = bufwinnr(str2nr(nr))
    if selected_buffer_window != -1
      call <SID>move("down")
      if <SID>get_selected_buffer() == nr
        call <SID>move("up")
        if <SID>get_selected_buffer() == nr
          call <SID>kill(0, 0)
        else
          call <SID>load_buffer_into_window(selected_buffer_window)
        endif
      else
        call <SID>load_buffer_into_window(selected_buffer_window)
      endif
    else
      call <SID>kill(0, 0)
    endif
    exec ":bdelete " . nr
    call <SID>tab_friends_toggle(1)
  endif
endfunction

function! <SID>keep_buffers_for_keys(dict)
  for b in range(1, bufnr('$'))
    if buflisted(b) && !has_key(a:dict, b) && !getbufvar(b, '&modified')
      exe ':bdelete ' . b
    endif
  endfor
endfunction

" deletes all hidden buffers
" taken from: http://stackoverflow.com/a/3180886
function! <SID>delete_hidden_buffers()
  let visible = {}
  for t in range(1, tabpagenr('$'))
    for b in tabpagebuflist(t)
      let visible[b] = 1
    endfor
  endfor
  call <SID>kill(0, 0)
  call <SID>keep_buffers_for_keys(visible)
  call <SID>tab_friends_toggle(1)
endfunction

" deletes all foreign (not tab friend) buffers
function! <SID>delete_foreign_buffers()
  let friends = {}
  for t in range(1, tabpagenr('$'))
    silent! call extend(friends, gettabvar(t, 'tab_friends_list'))
  endfor
  call <SID>kill(0, 0)
  call <SID>keep_buffers_for_keys(friends)
  call <SID>tab_friends_toggle(1)
endfunction

function! <SID>get_selected_buffer()
  let bufentry = b:buflist[line(".") - 1]
  return bufentry.number
endfunction

function! <SID>add_tab_friend()
  if !exists('t:tab_friends_list')
    let t:tab_friends_list = {}
  endif

  let current = bufnr('%')

  if !exists("t:tab_friends_list[" . current . "]") && getbufvar(current, '&modifiable') && getbufvar(current, '&buflisted') && current != bufnr("__TAB_FRIENDS__")
    let t:tab_friends_list[current] = len(t:tab_friends_list) + 1
  endif
endfunction

function! <SID>add_jump()
  if !exists("t:tab_friends_jumps")
    let t:tab_friends_jumps = []
  endif

  let current = bufnr('%')

  if getbufvar(current, '&modifiable') && getbufvar(current, '&buflisted') && current != bufnr("__TAB_FRIENDS__")
    call add(s:tab_friends_jumps, current)
    let s:tab_friends_jumps = <SID>unique_list(s:tab_friends_jumps)

    if len(s:tab_friends_jumps) > g:tab_friends_max_jumps + 1
      unlet s:tab_friends_jumps[0]
    endif

    call add(t:tab_friends_jumps, current)
    let t:tab_friends_jumps = <SID>unique_list(t:tab_friends_jumps)

    if len(t:tab_friends_jumps) > g:tab_friends_max_jumps + 1
      unlet t:tab_friends_jumps[0]
    endif
  endif
endfunction

function! <SID>toggle_tab()
  let s:tab_toggle = !s:tab_toggle
  call <SID>kill(0, 0)
  call <SID>tab_friends_toggle(1)
endfunction

function! <SID>toggle_order()
  if exists("t:sort_order")
    if t:sort_order == 1
      let t:sort_order = 2
    else
      let t:sort_order = 1
    endif

    call <SID>kill(0, 0)
    call <SID>tab_friends_toggle(1)
  endif
endfunction

function! <SID>detach_tab_friend()
  let nr = <SID>get_selected_buffer()
  if exists('t:tab_friends_list[' . nr . ']')
    let selected_buffer_window = bufwinnr(nr)
    if selected_buffer_window != -1
      call <SID>move("down")
      if <SID>get_selected_buffer() == nr
        call <SID>move("up")
        if <SID>get_selected_buffer() == nr
          return
        endif
      endif
      call <SID>load_buffer_into_window(selected_buffer_window)
    else
      call <SID>kill(0, 0)
    endif
    call remove(t:tab_friends_list, nr)
    call <SID>tab_friends_toggle(1)
  endif
endfunction

