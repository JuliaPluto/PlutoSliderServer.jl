module Configuration
    using Configurations
    import Pluto
    export SliderServerSettings, ExportSettings, PlutoDeploySettings
    
    @option struct SliderServerSettings
        exclude::Vector=String[]
        port::Integer=2345
        host="127.0.0.1"
        simulated_lag::Real=0
        serve_static_export_folder::Bool=true
    end
    
    @option struct ExportSettings
        output_dir::Union{Nothing,String}=nothing
        exclude::Vector=String[]
        ignore_cache::Vector=String[]
        pluto_cdn_root::Union{Nothing,String}=nothing
        baked_state::Bool=true
        baked_notebookfile::Bool=true
        offer_binder::Bool=true
        disable_ui::Bool=true
        cache_dir::Union{Nothing,String}=nothing
        slider_server_url::Union{Nothing,String}=nothing
        binder_url::Union{Nothing,String}=nothing
        create_index::Bool=true
    end
    
    @option struct PlutoDeploySettings
        SliderServer::SliderServerSettings=SliderServerSettings()
        Export::ExportSettings=ExportSettings()
        Pluto::Pluto.Configuration.Options=Pluto.Configuration.Options()
    end

end