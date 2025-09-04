# Search API Description Fix

## Problem Solved

The search API endpoints (`/api/v1/search`) were returning empty `description` and `descriptionHtml` fields for all videos.

## Root Cause

YouTube changed their search API response format from `videoRenderer` to `compactVideoRenderer`, and the new format does not include description snippets. Invidious was only parsing `videoRenderer` objects, causing it to miss the search results entirely.

## Solution

1. **Added `CompactVideoRendererParser`**: New parser that handles the modern `compactVideoRenderer` format used by YouTube in search results.

2. **Added `extend_desc` parameter**: Optional parameter to fetch full descriptions by making additional API calls to the video details endpoint.

## API Usage

### Default behavior (backward compatible)
```bash
curl "http://localhost:3000/api/v1/search?q=crystal"
```
- Fast response
- Empty `description` and `descriptionHtml` fields (same as before)
- No additional API calls

### Extended descriptions (new feature)
```bash
curl "http://localhost:3000/api/v1/search?q=crystal&extend_desc=true"
```
- Slower response (makes N additional API calls for N videos)
- Full `description` and `descriptionHtml` fields populated
- Graceful fallback if video details fetch fails

## Performance Considerations

- `extend_desc=true` makes one additional YouTube API call per video in the search results
- Typical search returns 20 videos = 20 additional API calls
- Use only when descriptions are actually needed
- Future optimization opportunities:
  - Batch fetching multiple video details in one call
  - Intelligent caching of video descriptions
  - Rate limiting protection

## Example Response Comparison

### Without extend_desc (default):
```json
[
  {
    "type": "video",
    "title": "Crystal Programming Language Tutorial",
    "videoId": "abc123",
    "description": "",
    "descriptionHtml": ""
  }
]
```

### With extend_desc=true:
```json
[
  {
    "type": "video", 
    "title": "Crystal Programming Language Tutorial",
    "videoId": "abc123",
    "description": "Learn Crystal programming in this comprehensive tutorial...",
    "descriptionHtml": "Learn <strong>Crystal</strong> programming in this comprehensive tutorial..."
  }
]
```

## Error Handling

- If fetching a video's description fails, the original search result is returned (with empty description)
- Errors are logged but do not break the search functionality
- Individual video description failures do not affect other videos in the search results

## Technical Implementation

- **CompactVideoRendererParser**: Handles YouTube's modern search result format
- **Automatic integration**: Uses existing parser chain architecture 
- **Backward compatibility**: Default behavior unchanged
- **Error resilience**: Graceful fallback for failed description fetches

## Debugging

To test the fix:

1. **Check if CompactVideoRendererParser is working**:
   ```bash
   # Should return results (not empty array)
   curl "http://localhost:3000/api/v1/search?q=test" | jq 'length'
   ```

2. **Test extended descriptions**:
   ```bash
   # Should have non-empty description fields
   curl "http://localhost:3000/api/v1/search?q=test&extend_desc=true" | jq '.[0].description'
   ```

3. **Performance monitoring**:
   ```bash
   # Check logs for "extend_desc requested" messages
   tail -f /var/log/invidious.log | grep "extend_desc"
   ```