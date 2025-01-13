--[[

    Strings.en.lua - English localization strings

]] --

Strings = Strings or {}

Strings.pt = {
  _name = "Portuguese",
  _fallback = nil,

  _strings = {
    plugins = {
      asr = { -- ASRPlugin
        assert_app = "O aplicativo host do plugin é necessário",
        actions = { -- ASRActions
          assert_plugin = "plugin é necessário",
          selected_tracks_label = "Processar Pistas Selecionadas",
          selected_tracks_format = "Processar %sPistas Selecionada%s",
          selected_items_label = "Processar Artigos Selecionados",
          selected_items_format = "Processar %sArtigos Selecionado%s",
          all_items_label = "Processar Todos os Artigos",
          import_label = "Importar Transcrição",
          no_media_text = "Nenhum suporte encontrado para processar.",
          no_media_title = "Nenhuma mídia",
        },
      },
      settings = { -- SettingsPlugin
        controls = { -- SettingsControls
          assert_plugin = "plugin é necessário",
          font_size_label = "Tamanho da Fonte",
          logging_label = "Registo",
          logging_basic_long = "Ativar",
          logging_basic_short = "Ativar",
          logging_debug_long = "Depurar",
          logging_debug_short = "Depurar",
          locale_label = "Localidade",
        },
      },
    },
  },
}
