public with sharing class Gemini_API_Call {

    // Input class to accept API key, input prompt, model selection,
    // an option to include Google Search grounding, and generationConfig parameters.
    public class GeminiInput {
        @InvocableVariable(label='API Key' required=true)
        public String apiKey;
        
        @InvocableVariable(label='Input Prompt' required=true)
        public String inputPrompt;
        
        // Define which Gemini model to use.
        @InvocableVariable(label='Model (Options: gemini-2.0-flash, gemini-1.5-pro, gemini-2.5-pro-exp-03-25, gemini-1.5-flash, gemini-1.5-flash-8b)' required=false)
        public String model;
        
        // Define whether to include Google Search grounding.
        // Set to true to include; false to omit.
        @InvocableVariable(label='Include Google Search Grounding (True/False)' required=true)
        public Boolean includeGoogleSearch;
        
        // Optional generation configuration parameters.
        // Temperature must be between 0 and 2. Defaults to 1 if not provided.
        @InvocableVariable(label='Temperature (0 - 2)' required=false)
        public Decimal temperature;
        
        // Top-P must be between 0 and 1. Defaults to 0.95 if not provided.
        @InvocableVariable(label='Top-P (0 - 1)' required=false)
        public Decimal topP;
        
        // Maximum Output Tokens must be between 0 and 8192. Defaults to 8192 if not provided.
        @InvocableVariable(label='Max Output Tokens (0 - 8192)' required=false)
        public Integer maxOutputTokens;
    }
    
    // Output class to return the generated content text and additional response metadata to the Flow.
    public class GeminiOutput {
        @InvocableVariable(label='Response Text')
        public String responseText;
        
        // Response Metadata includes finishReason, index, and groundingMetadata (if available)
        @InvocableVariable(label='Response Metadata')
        public String responseMetadata;
    }
    
    @InvocableMethod(label='Call Gemini API' description='Calls the Gemini API with a user-defined API key, prompt, model, and configurable generation parameters. Optionally include Google Search grounding.')
    public static List<GeminiOutput> callGeminiAPI(List<GeminiInput> inputList) {
        // Validate that at least one input record is provided.
        if(inputList == null || inputList.isEmpty()){
            throw new IllegalArgumentException('No input provided.');
        }
        
        GeminiInput input = inputList[0];
        String query = input.inputPrompt;
        
        // Set the model based on user input or default to Gemini 2.0 Pro Experimental 02-05.
        String model = String.isBlank(input.model) ? 'gemini-2.0-pro-exp-02-05' : input.model;
        
        // Build the endpoint URL using the chosen model.
        String endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/' 
                            + model 
                            + ':generateContent?key=' + input.apiKey;
        
        // Build the request body.
        Map<String, Object> requestBody = new Map<String, Object>();
        
        // Set up the "contents" section with the prompt text.
        List<Object> contents = new List<Object>();
        Map<String, Object> contentItem = new Map<String, Object>();
        List<Object> parts = new List<Object>();
        Map<String, Object> partItem = new Map<String, Object>();
        partItem.put('text', query);
        parts.add(partItem);
        contentItem.put('parts', parts);
        contents.add(contentItem);
        requestBody.put('contents', contents);
        
        // Optionally add the "tools" configuration based on the includeGoogleSearch flag.
        if(input.includeGoogleSearch) {
            List<Object> tools = new List<Object>();
            Map<String, Object> toolItem = new Map<String, Object>();
            toolItem.put('google_search', new Map<String, Object>());
            tools.add(toolItem);
            requestBody.put('tools', tools);
        }
        
        // Use user-defined generationConfig values or defaults if not provided.
        Decimal temperatureVal = (input.temperature != null) ? input.temperature : 1;
        Decimal topPVal = (input.topP != null) ? input.topP : 0.95;
        Integer maxOutputTokensVal = (input.maxOutputTokens != null) ? input.maxOutputTokens : 8192;
        
        // Add the "generationConfig" parameters.
        Map<String, Object> generationConfig = new Map<String, Object>{
            'temperature' => temperatureVal,
            'topK' => 64, // TopK remains fixed; adjust if needed.
            'topP' => topPVal,
            'maxOutputTokens' => maxOutputTokensVal,
            'responseMimeType' => 'text/plain'
        };
        requestBody.put('generationConfig', generationConfig);
        
        // Serialize the request body to JSON.
        String body = JSON.serialize(requestBody);
        
        // Set up the HTTP request.
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(body);
        // Increase the timeout to 120 seconds to prevent timeout errors.
        req.setTimeout(120000);
        
        Http http = new Http();
        GeminiOutput output = new GeminiOutput();
        
        try {
            HttpResponse res = http.send(req);
            if(res.getStatusCode() == 200) {
                // Parse the JSON response.
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                if(jsonResponse.containsKey('candidates')) {
                    List<Object> candidates = (List<Object>) jsonResponse.get('candidates');
                    if(candidates != null && !candidates.isEmpty()) {
                        Map<String, Object> candidate = (Map<String, Object>) candidates[0];
                        
                        // Extract and package response metadata.
                        String finishReason = candidate.containsKey('finishReason') ? String.valueOf(candidate.get('finishReason')) : 'N/A';
                        String indexVal = candidate.containsKey('index') ? String.valueOf(candidate.get('index')) : 'N/A';
                        String groundingMetadataStr = 'No grounding metadata present.';
                        if(candidate.containsKey('groundingMetadata')) {
                            groundingMetadataStr = JSON.serialize(candidate.get('groundingMetadata'));
                        }
                        Map<String, Object> metadataMap = new Map<String, Object>{
                            'finishReason' => finishReason,
                            'index' => indexVal,
                            'groundingMetadata' => groundingMetadataStr
                        };
                        output.responseMetadata = JSON.serialize(metadataMap);
                        
                        // Extract the text response if available.
                        if(candidate.containsKey('content')) {
                            Map<String, Object> content = (Map<String, Object>) candidate.get('content');
                            if(content.containsKey('parts')) {
                                List<Object> partsList = (List<Object>) content.get('parts');
                                if(partsList != null && !partsList.isEmpty()) {
                                    Map<String, Object> part = (Map<String, Object>) partsList[0];
                                    if(part.containsKey('text')) {
                                        output.responseText = (String) part.get('text');
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                output.responseText = 'Error: ' + res.getStatusCode() + ' ' + res.getStatus();
                output.responseMetadata = 'No response metadata available.';
            }
        } catch(Exception ex) {
            output.responseText = 'Exception: ' + ex.getMessage();
            output.responseMetadata = 'No response metadata available.';
        }
        
        // Return the response as a single-element list for the Flow.
        return new List<GeminiOutput>{ output };
    }
}