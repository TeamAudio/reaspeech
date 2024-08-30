import json
import re
import pandas as pd
from typing import List, Dict, Any
from fuzzywuzzy import fuzz
from collections import defaultdict
from io import BytesIO
import math
import numpy as np

# This function is called by the FastAPI endpoint
async def script_match(json_content: bytes, excel_content: bytes) -> List[Dict[str, Any]]:
    json_data = json.loads(json_content.decode('utf-8'))
    df_lines = pd.read_excel(BytesIO(excel_content), usecols=['Line Text', 'Character Name', 'File Prefix'])
    
    # Replace NaN with None in the DataFrame
    df_lines = df_lines.where(pd.notna(df_lines), None)
    
    results = process_json_transcript(json_data, df_lines)
    
    # Ensure all data is JSON serializable
    for line_result in results:
        line_result['matches'].sort(key=lambda x: x['score'], reverse=True)
        for match in line_result['matches']:
            match['score'] = float(match['score'])
            match['start_time'] = float(match['start_time'])
            match['end_time'] = float(match['end_time'])

    results = replace_nan_with_none(results)

    return results


def read_json_file(filepath: str) -> Dict[str, Any]:
    with open(filepath, 'r') as file:
        return json.load(file)

# replaces empty NaN's from cells with no data with None 
def replace_nan_with_none(obj):
    if isinstance(obj, float) and np.isnan(obj):
        return None
    elif isinstance(obj, dict):
        return {k: replace_nan_with_none(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [replace_nan_with_none(v) for v in obj]
    return obj

# simplified, doesn't handle punctuation, number-to-word conversion
def sanitize_string(input_str: str) -> str:
    return re.sub(r'[^\w\s]', '', input_str).lower()

# simplified, uses length of line words to search
def find_non_overlapping_matches(transcript: str, line: str, threshold: int = 70) -> List[Dict[str, Any]]:
    matches = []
    transcript_words = transcript.split()
    line_words = line.split()
    
    for i in range(len(transcript_words) - len(line_words) + 1):
        segment = ' '.join(transcript_words[i:i+len(line_words)])
        score = fuzz.ratio(sanitize_string(segment), sanitize_string(line))
        if score >= threshold:
            matches.append({
                'segment': segment,
                'start_index': i,
                'end_index': i + len(line_words) - 1,
                'score': score
            })
    
    matches.sort(key=lambda x: x['score'], reverse=True)
    
    non_overlapping_matches = []
    used_indices = set()
    for match in matches:
        if not any(idx in used_indices for idx in range(match['start_index'], match['end_index'] + 1)):
            non_overlapping_matches.append(match)
            used_indices.update(range(match['start_index'], match['end_index'] + 1))
    
    return non_overlapping_matches

# each file is processed as its own segment, to preserve assumed natural file extent boundaries
def process_json_transcript(json_data, df_lines):
    results = []

    # Group segments by file
    file_segments = {}
    for segment in json_data['segments']:
        file_name = segment['file']
        if file_name not in file_segments:
            file_segments[file_name] = []
        file_segments[file_name].append(segment)

    for _, line in df_lines.iterrows():
        line_result = {
            'line_text': line['Line Text'],
            'character_name': line['Character Name'],
            'file_name_prefix': line['File Prefix'],
            'matches': []
        }

        # Process each file separately
        for file_name, segments in file_segments.items():
            transcript = ' '.join(word['word'] for segment in segments for word in segment['words'])
            matches = find_non_overlapping_matches(transcript, line['Line Text'])

            for match in matches:
                start_time = None
                end_time = None
                current_index = 0

                for segment in segments:
                    segment_words = segment['words']
                    segment_length = len(segment_words)

                    if current_index <= match['start_index'] < current_index + segment_length:
                        start_word_index = match['start_index'] - current_index
                        end_word_index = min(match['end_index'] - current_index, segment_length - 1)

                        start_time = segment_words[start_word_index]['start']
                        end_time = segment_words[end_word_index]['end']
                        break

                    current_index += segment_length

                if start_time is not None and end_time is not None:
                    line_result['matches'].append({
                        'originating_file': file_name,
                        'transcript_text': match['segment'],
                        'start_time': start_time,
                        'end_time': end_time,
                        'score': match['score']
                    })

        results.append(line_result)

    return results

if __name__ == "__main__":
    json_filepath = '2barks.json'  # test transcript
    excel_filepath = '2barks_headers.xlsx'  # test script
    
    json_data = read_json_file(json_filepath)
    df_lines = pd.read_excel(excel_filepath, usecols=['Line Text', 'Character Name', 'File Prefix'])
    
    results = process_json_transcript(json_data, df_lines)
    
    # Sort matches within each line by score in descending order
    for line_result in results:
        line_result['matches'].sort(key=lambda x: x['score'], reverse=True)
    
    json_output = json.dumps(results, indent=2)
    print(json_output)
