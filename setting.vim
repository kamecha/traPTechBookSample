
let s:plugins = []

" dduの導入
call add(s:plugins, "vim-denops/denops.vim")
call add(s:plugins, "Shougo/ddu.vim")

" dduをコマンドラインから起動するためのプラグイン
call add(s:plugins, "Shougo/ddu-commands.vim")

" ui
call add(s:plugins, "Shougo/ddu-ui-ff")

" source
call add(s:plugins, "matsui54/ddu-source-help")
call add(s:plugins, "Shougo/ddu-source-action")
call add(s:plugins, "shun/ddu-source-rg")
call add(s:plugins, "Shougo/ddu-source-file")
call add(s:plugins, "Shougo/ddu-source-file_rec")
call add(s:plugins, "Shougo/ddu-kind-file")

" filter
call add(s:plugins, "yuki-yano/ddu-filter-fzf")
call add(s:plugins, "Shougo/ddu-filter-matcher_substring")

" color scheme
" defaultだとfloating windowの背景色が変わらないので、edgeを使用しています。
call add(s:plugins, "sainnhe/edge")

" ここの箇所はプラグインマネージャが自動的に設定してくれる箇所を手動で設定しています。
let s:repoPath = "~/.cache/dein/nvim/repos/github.com/"
for plugin in s:plugins
	let pluginPath = s:repoPath . plugin
	execute "set rtp+=" . pluginPath
endfor

" プラグインを読み込ませた後にcolor schemeを設定する
colorscheme edge

" === ↑上記がプラグインをvimに読みこませるための設定です。 ===
" === 一般的にプラグインマネージャーを使用します。 ===

" === ↓以下がdduの設定です。 ===

" global setting
call ddu#custom#patch_global(#{
			\ ui: "ff",
			\ uiParams: #{
			\   ff: #{
			\     startAutoAction: v:true,
			\     autoAction: #{ name: "preview" },
			\   }
			\ },
			\ sourceOptions: #{
			\   help: #{
			\     matchers: ["matcher_fzf"],
			\     sorters: ["sorter_fzf"]
			\   }
			\ },
			\ kindOptions: #{
			\   action: #{
			\     defaultAction: "do"
			\   }
			\ }
			\})

" === layout ===
call ddu#custom#patch_global("uiParams", #{
			\ ff: #{
			\   split: "floating",
			\   floatingBorder: "rounded",
			\   previewFloating: v:true,
			\   previewFloatingBorder: "rounded",
			\   winCol: "( &columns / 8 )",
			\   winRow: "( &lines / 8 )",
			\   winWidth: "( &columns - (&columns / 4) )",
			\   winHeight: "( &lines - (&lines / 4) )",
			\   previewCol: "( &columns / 8 )"
			\     . "+" . "( &columns - (&columns / 4) )" . "/2",
			\   previewRow: "( &lines / 8 )"
			\     . "+" . "( &lines - (&lines / 4) )" . "+1",
			\   previewWidth: 
			\     "("
			\     . "( &columns - (&columns / 4) )" . "-1"
			\     . ")"
			\     . "/ 2",
			\   previewHeight: "( &lines - (&lines / 4) )" . "- 2",
			\ }
			\})

function s:update_ddu_layout() abort
	let l:current = ddu#custom#get_current()
	if empty(l:current)
		return
	endif
	call ddu#ui#do_action("updateOptions", #{
				\ uiParams: #{
				\   ff: #{
				\     split: "floating",
				\     floatingBorder: "rounded",
				\     previewFloating: v:true,
				\     previewFloatingBorder: "rounded",
				\     winCol: "( &columns / 8 )",
				\     winRow: "( &lines / 8 )",
				\     winWidth: "( &columns - (&columns / 4) )",
				\     winHeight: "( &lines - (&lines / 4) )",
				\     previewCol: "( &columns / 8 )" . "+" . "( &columns - (&columns / 4) )" . "/2",
				\     previewRow: "( &lines / 8 )" . "+" . "( &lines - (&lines / 4) )" . "+1",
				\     previewWidth: "(" . "( &columns - (&columns / 4) )" . "- 1)" . "/ 2",
				\     previewHeight: "( &lines - (&lines / 4) )" . "- 2",
				\   }
				\ }
				\})
	call ddu#ui#do_action("redraw", #{ method: "uiRedraw" })
endfunction

autocmd VimResized * call s:update_ddu_layout()


" === custom action ===

" filterを動的に変更する
function s:change_filter(args) abort
	" souces type is string[] or dictioanry[]
	let l:beforeSources = a:args->get("options")->get("sources")
	let l:sourceOptions = a:args->get("options")->get("sourceOptions")
	let l:afterSources = []
	for l:beforeSource in l:beforeSources
		let l:after_source = {}
		let l:source_name = 
					\ l:beforeSource->type() == v:t_dict ?
					\   l:beforeSource->get("name") :
					\   l:beforeSource
		let l:after_source["name"] = l:source_name
		let l:source_option = 
					\ l:beforeSource->type() == v:t_dict ?
					\   l:beforeSource->get("options") :
					\   l:sourceOptions->get(l:source_name)
		if l:source_option->get("matchers") == ["matcher_fzf"]
			echo "change matcher: matcher_fzf -> matcher_substring"
			let l:after_source["options"] = #{ matchers: ["matcher_substring"] }
		endif
		if l:source_option->get("matchers") == ["matcher_substring"]
			echo "change matcher: matcher_substring -> matcher_fzf"
			let l:after_source["options"] = #{ matchers: ["matcher_fzf"], sorters: ["sorter_fzf"] }
		endif
		call add(l:afterSources, l:after_source)
	endfor
	call ddu#ui#do_action("updateOptions", #{ sources: l:afterSources })
	return 1 " RefreshItems
endfunction

call ddu#custom#action("ui", "ff", "changeFilter", function("s:change_filter"))

" fileソースからripgrep用ソースを開始する
function s:ripgrep_from_file(args) abort
	let l:paths = []
	for l:item in a:args->get("items")
		let l:action = l:item->get("action")
		let l:path = isdirectory(l:action->get("path")) ?
					\ l:action->get("path") :
					\ fnamemodify(l:action->get("path"), ":h")
		call add(l:paths, l:path)
	endfor
	call ddu#start(#{
				\ name: a:args->get("options")->get("name"),
				\ push: v:true,
				\ sources: [
				\   #{
				\     name: "rg",
				\     options: #{
				\       matchers: [],
				\       volatile: v:true,
				\     },
				\     params: #{ paths: l:paths }
				\   }
				\ ]
				\})
	return 0
endfunction

call ddu#custom#action("kind", "file", "ripgrep", function("s:ripgrep_from_file"))

" === keymap ===

function s:ddu_setting() abort
	nnoremap <buffer> <CR> <Cmd>call ddu#ui#do_action("itemAction")<CR>
	nnoremap <buffer> q <Cmd>call ddu#ui#do_action("quit")<CR>
	nnoremap <buffer> i <Cmd>call ddu#ui#do_action("openFilterWindow")<CR>
	nnoremap <buffer> a <Cmd>call ddu#ui#do_action("chooseAction")<CR>
	nnoremap <buffer> <Leader>f <Cmd>call ddu#ui#do_action("changeFilter")<CR>
endfunction

autocmd FileType ddu-ff call s:ddu_setting()

function s:ddu_filter_setting() abort
	inoremap <buffer> <C-l> <Esc><Cmd>call ddu#ui#do_action("leaveFilterWindow")<CR>
endfunction

autocmd FileType ddu-ff-filter call s:ddu_filter_setting()
