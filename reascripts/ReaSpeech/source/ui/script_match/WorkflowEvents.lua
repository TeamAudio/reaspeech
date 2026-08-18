--[[

  WorkflowEvents.lua - Every Script Matching workflow event in one place

  This schema is enforced by EventEmitter at every emit and listen
  site: undeclared event names and payloads missing a required field
  raise immediately. Optional payload fields are noted in comments.
  Comments name the current emitters -> listeners.

]]--

WorkflowEvents = {
  schema = {
    -- Curation ------------------------------------------------------

    -- ScriptMatchWorkflow -> CurationNavigationUI, CurationCardUI
    needles_changed = {
      required = { 'needles' },
    },

    -- CurationNavigationUI -> CurationCardUI, CurationSuggestionsUI
    needle_navigated = {
      required = { 'needle_index', 'needle_id', 'needle' },
    },

    -- CurationCardUI -> CurationSuggestionsUI, ExportPhaseUI
    suggestions_generated = {
      required = { 'needle_id', 'suggestions' },
    },

    -- CurationSuggestionsUI -> CurationCardUI, ExportPhaseUI
    suggestion_decided = {
      required = { 'needle_id', 'suggestion_id', 'action', 'summary', 'timestamp' },
    },

    -- CurationSuggestionsUI -> ExportPhaseUI (slice ranges changed)
    suggestion_time_adjusted = {
      required = { 'needle_id', 'suggestion_id', 'start_time', 'end_time' },
    },

    -- ExportPreviewUI -> CurationNavigationUI, CurationSuggestionsUI:
    -- jump to a needle (and optionally focus one of its suggestions)
    curation_jump_requested = {
      required = { 'needle_id' },
    },

    -- OneshotRunner -> SessionStatus (diagnosis pass verdict landed)
    -- Optional: locator, verdict (nil when the diagnosis errored)
    needle_diagnosed = {
      required = { 'needle_id' },
    },

    -- CurationCardUI -> CurationSuggestionsUI
    -- Optional: suggestion_count, error_message
    job_status_changed = {
      required = { 'needle_id', 'status' },
    },

    -- Metadata ------------------------------------------------------

    -- NeedleMetadataService -> ExportTemplateEditorUI
    metadata_variables_changed = {
      required = { 'session_id', 'available_variables' },
    },

    -- Setup: script materials ---------------------------------------

    -- ScriptMaterialWorksheetUI, ScriptMaterialTagsMetadataLayerUI
    --   -> ScriptMaterialUI, ScriptMaterialExcelSpreadsheetUI
    script_material_updated = {
      required = { 'material' },
    },

    -- ScriptMaterialUI -> ScriptMaterialsUI
    script_material_unlinked = {
      required = { 'material' },
    },

    -- Export --------------------------------------------------------

    -- ExportDataService -> SessionStatus
    export_status_changed = {
      required = { 'export_id', 'status' },
    },

    -- Setup: audio tracks -------------------------------------------

    -- AudioTrackTagsMetadataLayerUI, AudioTrackTranscriptMetadataLayerUI
    --   -> ScriptMatchAudioTrackUI
    audio_track_metadata_layer_updated = {
      required = { 'track', 'layer' },
    },

    -- ScriptMatchAudioTrackConfigurationUI -> ScriptMatchAudioTrackUI
    audio_track_metadata_layer_removed = {
      required = { 'track', 'layer' },
    },
  }
}
