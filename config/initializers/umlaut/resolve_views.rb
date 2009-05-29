  # Set up what partials and layouts to use for resolution services. 
  # Also sets up a mapping that explains for a div on the resolve menu,
  # what partial is used to fill it, and what ServiceTypeValues are possibly
  # displayed by that partial. 

  # This is used by the background updating scripts, and also used by the
  # partial APIs, in another config parameter below, partial_html_map, that by
  # default is based on bg_update_map

  # Use a custom resolve menu view, if you really can't configure
  # the existing one satisfactorily.
  # AppConfig::Base.resolve_view = 'local/my_institution_resolve_index.erb.html'


  # Use custom layouts for your local look and feel
  #AppConfig::Base.resolve_layout = "distribution/jhu_resolve"
  #AppConfig::Base.search_layout = 'distribution/jhu_search'

  # Use a custom partial for the local holdings block on the resolve page
  #AppConfig::Base.partial_for_holding = 'alternate/holding_alternate'


  # We list all of the divs and their content for the resolve menu.
  # We imagine a future Umlaut that takes much more config from here,
  # abstractly constructing the entire page from this. Right now,
  # it's re-used for background update and for the partial js api.
  # And the order of holdings and document_delivery in resolve_main_sections
  # does determine their order on the page, that's it. 
  
AppConfig::Base.resolve_main_sections = 
                         [
                          { :div_id => "cover_image",
                            :partial => "cover_image",
                            :service_type_values => ["cover_image"]
                          },
                          { :div_id => "search_inside_wrapper",
                            :partial => "search_inside",
                            :service_type_values => ["search_inside"]
                          },
                          { :div_id => "fulltext_wrapper",
                            :partial => "fulltext",
                            :service_type_values => ["fulltext"]
                          },
                          { :div_id => "excerpts_wrapper",
                            :partial => "excerpts",
                            :service_type_values => ["excerpts"]
                          },
                          { :div_id => "audio_wrapper",
                            :partial => "audio",
                            :service_type_values => ["audio"]
                          },
                          { :div_id => "holding", 
                          :partial => DependentConfig.new {AppConfig.param("partial_for_holding","holding")},
                            :service_type_values => ["holding","holding_search"]
                          },
                          { :div_id => "document_delivery",
                            :partial => "document_delivery",
                            :service_type_values => ["document_delivery"]},
                          { :div_id => 'tables_of_contents',
                            :partial => 'tables_of_contents',
                            :service_type_values => ["table_of_contents"]
                          },
                          { :div_id => 'abstracts',
                            :partial => "abstracts",
                            :service_type_values => ["abstract"]
                          }
                       ]

                          
AppConfig::Base.resolve_sidebar_sections = 
               [
                  { :div_id => 'related_items',
                    :partial => 'related_items',
                    :service_type_values => ['cited_by', 'similar']},
                  { :div_id => 'export_citation',
                    :partial => 'export',
                    :service_type_values => ['export_citation']},
                  {:div_id => "highlighted_links",
                   :partial => "highlighted_links_start",
                   :service_type_values => ["highlighted_link"]
                  }
                ]
                 
  
  # Divs to be updated by the background updater in resolve controller. See
  # background_update.rjs. Specifies certain div sections on the resolve menu--
  # what the div id is, what partial view is used to fill it, and what
  # ServiceTypeValues are generated. This data structure can then be used
  # by the background updater to automatically update certain divs on the page
  # as more info comes in, and to generate spinners in the right places.
  # Also includes specification of a div to put errors in, so error display
  # be updated when generated by a background service. 
  
  
  AppConfig::Base.bg_update_map = {:divs  =>    
  ( 
    DependentConfig.new { AppConfig::Base.resolve_main_sections } +
    DependentConfig.new{ AppConfig::Base.resolve_sidebar_sections }
  ) ,
              :error_div =>
                    { :div_id => 'service_errors',
                      :partial => 'service_errors'}
  }

                        
  # Map specifying portions of HTML to be generated and exposed by the
  # partial_html_sections action API in resolve controller.
  # In fact, this is the same information needed in bg_update_divs
  # above, so we store it in the same format and simply copy that
  # data. But a seperate variable is provided in case you have
  # a reason to make the partial_html_sections action deliver
  # different content than what is on the resolve page. 
  AppConfig::Base.partial_html_map = DependentConfig.new {AppConfig::Base.bg_update_map[:divs]}
