@IsTest
private class Gemini_API_Call_Test {
    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assert(req.getEndpoint().contains('callout:Gemini_API'));
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"candidates":[{"content":{"parts":[{"text":"grounded answer"}]},"finishReason":"STOP","index":0,"groundingMetadata":{"source":"web"}}]}');
            return res;
        }
    }
    private class AuthErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setStatus('Unauthorized');
            res.setBody('{"error":"do not expose"}');
            return res;
        }
    }
    @IsTest static void returnsGeminiText() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Gemini_API_Call.GeminiInput input = new Gemini_API_Call.GeminiInput();
        input.inputPrompt = 'Find current Salesforce news';
        input.model = 'gemini-2.0-flash';
        input.includeGoogleSearch = true;
        List<Gemini_API_Call.GeminiOutput> outputs = Gemini_API_Call.callGeminiAPI(new List<Gemini_API_Call.GeminiInput>{ input });
        System.assertEquals('grounded answer', outputs[0].responseText);
        System.assert(outputs[0].responseMetadata.contains('hasGroundingMetadata'));
    }
    @IsTest static void rejectsUnsupportedModel() {
        Gemini_API_Call.GeminiInput input = new Gemini_API_Call.GeminiInput();
        input.inputPrompt = 'test';
        input.model = 'unsafe-model';
        input.includeGoogleSearch = false;
        List<Gemini_API_Call.GeminiOutput> outputs = Gemini_API_Call.callGeminiAPI(new List<Gemini_API_Call.GeminiInput>{ input });
        System.assert(outputs[0].responseText.contains('Unsupported Gemini model'));
    }
    @IsTest static void sanitizesAuthError() {
        Test.setMock(HttpCalloutMock.class, new AuthErrorMock());
        Gemini_API_Call.GeminiInput input = new Gemini_API_Call.GeminiInput();
        input.inputPrompt = 'test';
        input.model = 'gemini-2.0-flash';
        input.includeGoogleSearch = false;
        List<Gemini_API_Call.GeminiOutput> outputs = Gemini_API_Call.callGeminiAPI(new List<Gemini_API_Call.GeminiInput>{ input });
        System.assert(outputs[0].responseText.contains('authentication failed'));
        System.assert(!outputs[0].responseText.contains('do not expose'));
    }
}
