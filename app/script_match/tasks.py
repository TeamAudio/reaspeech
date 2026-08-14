import logging
import os
from typing import Dict, List, Any
from app.celery_app import celery

logger = logging.getLogger(__name__)


def read_row_styles(spreadsheet_path: str) -> Dict[str, Dict[str, List[int]]]:
    """Return per-sheet row style info: 1-based "hidden" and "bold" row
    numbers (a row is bold when any non-empty cell in it has a bold font).

    pandas does not expose row visibility or styling, so this uses openpyxl
    directly. The workbook is passed as an open file object because
    load_workbook rejects paths without a recognized extension, and uploads
    arrive as extensionless temp files. Returns empty info for formats
    openpyxl cannot read (e.g. .xls).
    """
    styles: Dict[str, Dict[str, List[int]]] = {}
    try:
        import openpyxl
        with open(spreadsheet_path, 'rb') as f:
            workbook = openpyxl.load_workbook(f, read_only=False)
        for worksheet in workbook.worksheets:
            hidden = sorted(
                row_number
                for row_number, dimension in worksheet.row_dimensions.items()
                if dimension.hidden
            )
            bold = []
            for row in worksheet.iter_rows():
                for cell in row:
                    if cell.value is not None and cell.font and cell.font.bold:
                        bold.append(cell.row)
                        break
            styles[worksheet.title] = {"hidden": hidden, "bold": bold}
    except Exception as e:
        logger.warning(f"Could not read row style info: {e}")
    return styles

@celery.task(name="script_match.fuzzy_match", bind=True)
def fuzzy_match(
    self,
    needle: Dict[str, Any],
    audio_tracks: List[Dict[str, Any]],
    options: Dict[str, Any] = None
):
    """
    Perform fuzzy matching of needle text against audio track transcripts.
    
    Args:
        needle: Dictionary containing script content and metadata
        audio_tracks: List of audio track objects with transcript data
        options: Optional matching configuration (algorithms, thresholds, etc.)
    
    Returns:
        List of suggestion objects with confidence scores
    """
    needle_text = needle.get('content', '')
    logger.info(f"Starting fuzzy match for needle: '{needle_text}'")
    
    # STEP7_DEBUG: Log task input structure for validation
    logger.info(f"STEP7_DEBUG: Task received needle keys: {list(needle.keys())}")
    logger.info(f"STEP7_DEBUG: Task received {len(audio_tracks)} audio tracks")
    logger.info(f"STEP7_DEBUG: Task options: {options}")
    
    # Set default options
    options = options or {}
    max_suggestions = options.get('max_suggestions', 10)
    confidence_threshold = options.get('confidence_threshold', 0.1)
    
    # Update progress
    self.update_state(
        state='PROCESSING',
        meta={'progress': {'units': 'tracks', 'total': len(audio_tracks), 'current': 0}}
    )
    
    try:
        from .matching import FuzzyMatcher
        
        matcher = FuzzyMatcher(
            confidence_threshold=confidence_threshold,
            progress_callback=lambda current, total: self.update_state(
                state='PROCESSING',
                meta={'progress': {'units': 'tracks', 'total': total, 'current': current}}
            )
        )
        
        suggestions = matcher.match(needle, audio_tracks)
        
        # STEP7_DEBUG: Log raw suggestions before filtering
        logger.info(f"STEP7_DEBUG: Raw suggestions count: {len(suggestions)}")
        logger.debug(f"STEP7_DEBUG: Raw suggestions type: {type(suggestions[0]) if suggestions else 'N/A'}")
        
        # Convert dataclass objects to dictionaries for JSON serialization
        suggestions_dicts = []
        for suggestion in suggestions:
            if hasattr(suggestion, '__dict__'):
                # It's a dataclass, convert to dict
                suggestion_dict = {
                    'start_time': suggestion.start_time,
                    'end_time': suggestion.end_time,
                    'matching_text': suggestion.matching_text,
                    'track_guids': suggestion.track_guids,
                    'confidence': suggestion.confidence,
                    'match_type': getattr(suggestion, 'match_type', 'exact'),
                    'metadata': getattr(suggestion, 'metadata', {})
                }
            else:
                # Already a dict
                suggestion_dict = suggestion
            suggestions_dicts.append(suggestion_dict)
        
        # Filter and sort suggestions
        filtered_suggestions = [
            s for s in suggestions_dicts 
            if s['confidence'] >= confidence_threshold
        ]
        
        # Limit results
        if max_suggestions > 0:
            filtered_suggestions = filtered_suggestions[:max_suggestions]
        
        logger.info(f"Fuzzy match completed: {len(filtered_suggestions)} suggestions found")
        
        # STEP7_DEBUG: Log response structure for validation
        result = {
            'suggestions': filtered_suggestions,
            'stats': {
                'needle_text': needle_text,
                'total_suggestions': len(suggestions_dicts),
                'filtered_suggestions': len(filtered_suggestions),
                'tracks_processed': len(audio_tracks)
            }
        }
        
        logger.info(f"STEP7_DEBUG: Response structure - suggestions: {len(result['suggestions'])}, stats: {result['stats']}")
        if result['suggestions']:
            logger.debug(f"STEP7_DEBUG: First suggestion keys: {list(result['suggestions'][0].keys())}")
        
        return result
        
    except Exception as e:
        logger.error(f"Fuzzy match error: {str(e)}")
        raise


@celery.task(name="script_match.parse_spreadsheet", bind=True)
def parse_spreadsheet(
    self,
    spreadsheet_path: str,
    filename: str
):
    """
    Parse uploaded spreadsheet for script matching.
    This could eventually replace the sync version in webservice.py
    
    Args:
        spreadsheet_path: Path to uploaded spreadsheet file
        filename: Original filename
    
    Returns:
        Parsed spreadsheet data structure
    """
    logger.info(f"Parsing spreadsheet: {filename}")
    
    try:
        from pandas import read_excel, isna

        self.update_state(
            state='PARSING',
            meta={'progress': {'units': 'files', 'total': 1, 'current': 0}}
        )
        
        sheet_dict = read_excel(
            spreadsheet_path, 
            verbose=True, 
            header=None, 
            sheet_name=None, 
            na_values=['', 'NaT']
        )
        
        row_styles = read_row_styles(spreadsheet_path)

        def make_sheet(name, sheet):
            sheet_styles = row_styles.get(name, {})
            return {
                "config": {
                    "name": name,
                    "column_count": sheet.shape[1],
                    "row_count": sheet.shape[0],
                    "hidden_rows": sheet_styles.get("hidden", []),
                    "bold_rows": sheet_styles.get("bold", []),
                },
                "data": [[str(v_) if not isna(v_) else '' for v_ in list(v)] for _, v in sheet.iterrows()]
            }
        
        sheets = [make_sheet(name, s) for name, s in sheet_dict.items()]
        
        result = {
            "config": {
                "file_type": "excel",
                "file_name": filename,
                "sheets": len(sheets),
            },
            "sheets": sheets
        }
        
        logger.info(f"Spreadsheet parsed successfully: {len(sheets)} sheets")
        return result
        
    except Exception as e:
        logger.error(f"Spreadsheet parsing error: {str(e)}")
        raise
    finally:
        # Clean up temporary file
        try:
            os.unlink(spreadsheet_path)
        except:
            pass
