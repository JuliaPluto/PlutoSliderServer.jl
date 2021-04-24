"""
    Pluto Polyfill: don't use when/if Pluto implements this!
"""
module UpdateFromFile

export update_from_file

    import Pluto: update_save_run!, load_notebook_nobackup, ServerSession, Notebook, Cell
    function update_from_file(session::ServerSession, notebook::Notebook)
    	just_loaded = try
    		sleep(0.5) ## There seems to be a synchronization issue if your OS is VERYFAST 
    		load_notebook_nobackup(notebook.path)
    	catch e
    		@error "Skipping hot reload because loading the file went wrong" exception=(e,catch_backtrace())
    		return
    	end

    	old_codes = Dict(
    		id => c.code
    		for (id,c) in notebook.cells_dict
    	)
    	new_codes = Dict(
    		id => c.code
    		for (id,c) in just_loaded.cells_dict
    	)

    	added = setdiff(keys(new_codes), keys(old_codes))
    	removed = setdiff(keys(old_codes), keys(new_codes))
    	changed = let
    		remained = keys(old_codes) ∩ keys(new_codes)
    		filter(id -> old_codes[id] != new_codes[id], remained)
    	end

    	# @show added removed changed

    	for c in added
    		notebook.cells_dict[c] = just_loaded.cells_dict[c]
    	end
    	for c in removed
    		delete!(notebook.cells_dict, c)
    	end
    	for c in changed
    		notebook.cells_dict[c].code = new_codes[c]
    	end
    
    	notebook.cell_order = just_loaded.cell_order
    	update_save_run!(session, notebook, Cell[notebook.cells_dict[c] for c in union(added, changed)])
    end

end