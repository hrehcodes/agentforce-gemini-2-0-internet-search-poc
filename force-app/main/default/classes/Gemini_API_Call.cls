public with sharing class Gemini_API_Call {
    private static final String ENDPOINT_PREFIX = 'callout:Gemini_API/v1beta/models/';
    private static final Set<String> ALLOWED_MODELS = new Set<String>{ 'gemini-2.0-flash', 'gemini-1.5-pro', 'gemini-1.5-flash', 'gemini-1.5-flash-8b' };
    private static final Integer MAX_ATTEMPTS = 2;

    public class GeminiInput {
        @InvocableVariable(label='Input Prompt' required=true) public String inputPrompt;
        @InvocableVariable(label='Model' required=false) public String model;
        @InvocableVariable(label='Include Google Search Grounding' required=true) public Boolean includeGoogleSearch;
        @InvocableVariable(label='Temperature (0 - 2)' required=false) public Decimal temperature;
        @InvocableVariable(label='Top-P (0 - 1)' required=false) public Decimal topP;
        @InvocableVariable(label='Max Output Tokens (1 - 8192)' required=false) public Integer maxOutputTokens;
    }

    public class GeminiOutput {
        @InvocableVariable(label='Response Text') public String responseText;
        @InvocableVariable(label='Response Metadata') public String responseMetadata;
    }

    @InvocableMethod(label='Call Gemini API' description='Calls Gemini through the Gemini_API named credential. API keys are configured in External Credentials, not Flow inputs.')
    public static List<GeminiOutput> callGeminiAPI(List<GeminiInput> inputList) {
        if (inputList == null || inputList.isEmpty()) {
            throw new IllegalArgumentException('No input provided.');
        }
        List<GeminiOutput> outputs = new List<GeminiOutput>();
        for (GeminiInput input : inputList) {
            outputs.add(callOne(input));
        }
        return outputs;
    }

    private static GeminiOutput callOne(GeminiInput input) {
        GeminiOutput output = new GeminiOutput();
        try {
            if (input == null || String.isBlank(input.inputPrompt)) {
                output.responseText = 'Error: Input prompt is required.';
                output.responseMetadata = '{}';
                return output;
            }
            String model = normalizeModel(input.model);
            Map<String, Object> requestBody = new Map<String, Object>();
            requestBody.put('contents', new List<Object>{ new Map<String, Object>{ 'parts' => new List<Object>{ new Map<String, Object>{ 'text' => input.inputPrompt } } } });
            if (input.includeGoogleSearch == true) {
                requestBody.put('tools', new List<Object>{ new Map<String, Object>{ 'google_search' => new Map<String, Object>() } });
            }
            requestBody.put('generationConfig', new Map<String, Object>{
                'temperature' => clampDecimal(input.temperature, 1, 0, 2),
                'topP' => clampDecimal(input.topP, 0.95, 0, 1),
                'topK' => 64,
                'maxOutputTokens' => clampInteger(input.maxOutputTokens, 8192, 1, 8192),
                'responseMimeType' => 'text/plain'
            });

            HttpRequest req = new HttpRequest();
            req.setEndpoint(ENDPOINT_PREFIX + model + ':generateContent');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(60000);
            Http http = new Http();
            HttpResponse res;
            for (Integer attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
                res = http.send(req);
                Integer statusCode = res.getStatusCode();
                if (statusCode == 200) {
                    return parseSuccess(res.getBody());
                }
                if (!(statusCode == 429 || statusCode >= 500) || attempt == MAX_ATTEMPTS) {
                    output.responseText = sanitizeProviderError(statusCode, res.getStatus());
                    output.responseMetadata = '{}';
                    return output;
                }
            }
            output.responseText = 'Error: Gemini did not return a usable response.';
            output.responseMetadata = '{}';
        } catch (Exception ex) {
            output.responseText = 'Error: Gemini callout failed. ' + ex.getMessage();
            output.responseMetadata = '{}';
        }
        return output;
    }

    private static GeminiOutput parseSuccess(String body) {
        GeminiOutput output = new GeminiOutput();
        Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(body);
        List<Object> candidates = (List<Object>) jsonResponse.get('candidates');
        if (candidates == null || candidates.isEmpty()) {
            output.responseText = 'No Gemini candidates were returned.';
            output.responseMetadata = '{}';
            return output;
        }
        Map<String, Object> candidate = (Map<String, Object>) candidates[0];
        output.responseText = extractText(candidate);
        Map<String, Object> metadataMap = new Map<String, Object>{
            'finishReason' => String.valueOf(candidate.get('finishReason')),
            'index' => String.valueOf(candidate.get('index')),
            'hasGroundingMetadata' => candidate.containsKey('groundingMetadata')
        };
        output.responseMetadata = JSON.serialize(metadataMap);
        return output;
    }

    private static String extractText(Map<String, Object> candidate) {
        Map<String, Object> content = (Map<String, Object>) candidate.get('content');
        if (content == null) return 'No text content was returned.';
        List<Object> parts = (List<Object>) content.get('parts');
        if (parts == null || parts.isEmpty()) return 'No text content was returned.';
        List<String> texts = new List<String>();
        for (Object partObj : parts) {
            Map<String, Object> part = (Map<String, Object>) partObj;
            if (part.containsKey('text')) texts.add((String) part.get('text'));
        }
        return texts.isEmpty() ? 'No text content was returned.' : String.join(texts, '\n');
    }

    private static String normalizeModel(String input) {
        String model = String.isBlank(input) ? 'gemini-2.0-flash' : input.trim();
        if (!ALLOWED_MODELS.contains(model)) {
            throw new IllegalArgumentException('Unsupported Gemini model: ' + model);
        }
        return model;
    }
    private static Decimal clampDecimal(Decimal value, Decimal fallbackValue, Decimal minValue, Decimal maxValue) {
        Decimal v = value == null ? fallbackValue : value;
        if (v < minValue) return minValue;
        if (v > maxValue) return maxValue;
        return v;
    }
    private static Integer clampInteger(Integer value, Integer fallbackValue, Integer minValue, Integer maxValue) {
        Integer v = value == null ? fallbackValue : value;
        if (v < minValue) return minValue;
        if (v > maxValue) return maxValue;
        return v;
    }
    private static String sanitizeProviderError(Integer statusCode, String status) {
        if (statusCode == 401 || statusCode == 403) return 'Error: Gemini authentication failed. Verify the named credential principal is configured.';
        if (statusCode == 429) return 'Error: Gemini rate limit exceeded. Please try again later.';
        if (statusCode >= 500) return 'Error: Gemini is temporarily unavailable. Please try again later.';
        return 'Error: Gemini request failed with HTTP ' + statusCode + (String.isBlank(status) ? '.' : ' ' + status + '.');
    }
}
